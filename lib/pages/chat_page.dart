import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/config/mori_config.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/utils/chat_text_utils.dart';
import 'package:mori_ai/utils/group_chat_utils.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/user_avatar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.group});

  final GroupProfile? group;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _supportedImageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  };

  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _service = ChatService();
  final _imagePicker = ImagePicker();

  bool _isSending = false;
  bool _hasText = false;
  ChatImage? _pendingImage;
  String _loadedConversationId = '';
  String? _pendingHistoryConversationId;
  int _historyLoadToken = 0;
  int _messageSequence = 0;

  bool get _isGroup => widget.group != null;

  String get _conversationId =>
      widget.group?.id ?? CharacterStore.instance.activeCard.id;

  List<CharacterProfile> get _groupMembers {
    final group = widget.group;
    if (group == null) {
      return const [];
    }

    final members = <CharacterProfile>[];
    for (final memberId in group.memberIds) {
      final card = CharacterStore.instance.cardById(memberId);
      if (card != null) {
        members.add(card);
      }
    }
    return members;
  }

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
    ModelStore.instance.selection.addListener(_handleModelConfigChanged);
    ModelStore.instance.modelCatalog.addListener(_handleModelConfigChanged);
    CharacterStore.instance.profile.addListener(_handleCharacterChanged);
    CharacterStore.instance.cards.addListener(_handleCharactersChanged);
    UserProfileStore.instance.profile.addListener(_handleUserProfileChanged);
    if (!_isGroup) {
      CharacterStore.instance.activeCardId.addListener(
        _handleActiveCardChanged,
      );
    }
    _loadHistory(_conversationId);
  }

  @override
  void dispose() {
    ModelStore.instance.selection.removeListener(_handleModelConfigChanged);
    ModelStore.instance.modelCatalog.removeListener(_handleModelConfigChanged);
    CharacterStore.instance.profile.removeListener(_handleCharacterChanged);
    CharacterStore.instance.cards.removeListener(_handleCharactersChanged);
    UserProfileStore.instance.profile.removeListener(_handleUserProfileChanged);
    if (!_isGroup) {
      CharacterStore.instance.activeCardId.removeListener(
        _handleActiveCardChanged,
      );
    }
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadHistory(String conversationId) async {
    final token = ++_historyLoadToken;
    final loadedMessages = await ChatHistoryStore.instance.loadFor(
      conversationId,
    );
    if (!mounted || token != _historyLoadToken) {
      return;
    }
    if (!_isGroup && CharacterStore.instance.activeCard.id != conversationId) {
      return;
    }

    final messages = [
      for (final message in loadedMessages)
        _isGroup ? _normalizeGroupMessage(message) : message,
    ];

    setState(() {
      _messages
        ..clear()
        ..addAll(messages);
      _loadedConversationId = conversationId;
      _pendingImage = null;
    });
    _scrollToLatest();
  }

  ChatMessage _normalizeGroupMessage(ChatMessage message) {
    if (message.isUser) {
      return message.copyWith(senderId: 'user', senderName: _groupUserName());
    }

    final sender = CharacterStore.instance.cardById(message.senderId);
    final senderName = sender?.displayName ?? message.senderName;
    var content = message.content;
    for (final name in {senderName, message.senderName}) {
      if (name.trim().isNotEmpty) {
        content = stripLeadingSpeakerName(content, name);
      }
    }
    return message.copyWith(senderName: senderName, content: content);
  }

  void _handleActiveCardChanged() {
    if (_isGroup) {
      return;
    }

    final cardId = CharacterStore.instance.activeCard.id;
    if (_isSending) {
      _pendingHistoryConversationId = cardId;
      return;
    }
    _loadHistory(cardId);
  }

  void _handleCharactersChanged() {
    if (mounted && _isGroup) {
      setState(() {});
    }
  }

  void _handleUserProfileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveHistory(String conversationId) async {
    await ChatHistoryStore.instance.saveFor(
      conversationId,
      List<ChatMessage>.unmodifiable(_messages),
    );
  }

  String _newMessageId() {
    _messageSequence++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_messageSequence';
  }

  void _handleModelConfigChanged() {
    if (!mounted) {
      return;
    }

    final supportsVision = ModelStore.instance.supportsVision(
      ModelStore.instance.selection.value,
    );
    if (!supportsVision && _pendingImage != null) {
      setState(() => _pendingImage = null);
    } else {
      setState(() {});
    }
  }

  void _handleCharacterChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText == _hasText) {
      return;
    }
    setState(() => _hasText = hasText);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: _AttachmentOption(
                  icon: Icons.photo_library_outlined,
                  label: '照片',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _AttachmentOption(
                  icon: Icons.photo_camera_outlined,
                  label: '拍摄',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) {
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null || !mounted) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      if (bytes.isEmpty) {
        _showSnackBar('图片读取失败，请重新选择。');
        return;
      }
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        _showSnackBar('图片不能超过 8 MB，请选择更小的图片。');
        return;
      }

      final mimeType = _imageMimeType(file);
      if (!_supportedImageMimeTypes.contains(mimeType)) {
        _showSnackBar('仅支持 JPEG、PNG、GIF、WebP 格式的图片。');
        return;
      }

      setState(() {
        _pendingImage = ChatImage(bytes: bytes, mimeType: mimeType);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('无法选择图片，请检查相册或相机权限。');
    }
  }

  String _imageMimeType(XFile file) {
    final mimeType = file.mimeType?.trim().toLowerCase();
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }

    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.webp')) {
      return 'image/webp';
    }
    if (name.endsWith('.gif')) {
      return 'image/gif';
    }
    if (name.endsWith('.heic')) {
      return 'image/heic';
    }
    if (name.endsWith('.heif')) {
      return 'image/heif';
    }
    return 'image/jpeg';
  }

  String _groupUserName() {
    final name = UserProfileStore.instance.profile.value.name.trim();
    return name.isEmpty ? '用户' : name;
  }

  String _buildGroupSystemPrompt(
    CharacterProfile speaker,
    List<CharacterProfile> members,
  ) {
    final group = widget.group!;
    final memberNames = members.map((member) => member.displayName).join('、');
    final userName = _groupUserName();
    return '''
${MoriConfig.buildSystemPrompt(speaker)}

你正在群聊「${group.displayName}」中。
AI 群成员有：$memberNames。
用户在聊天记录中显示为「$userName」。
聊天记录中，带名称前缀的消息用于区分发送者：以「$userName」开头的是用户本人发送的，其他名称开头的是对应的 AI 成员。没有名称前缀的助理消息是你自己之前发送的内容。
请只以「${speaker.displayName}」的身份回复用户最新的消息，不要代替其他成员或用户发言，不要把其他 AI 成员的发言误认为自己的发言，也不要重复其他成员已经说过的内容。
直接输出回复正文，不要在正文开头添加任何人的名字或角色名前缀，界面会自动显示发送者名称。''';
  }

  Future<bool> _streamReply({
    required CharacterProfile responder,
    required String conversationId,
    required ModelProvider provider,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required bool showSender,
  }) async {
    final history = showSender
        ? buildGroupRequestHistory(_messages, responderId: responder.id)
        : List<ChatMessage>.of(_messages);
    final assistantMessage = ChatMessage(
      id: _newMessageId(),
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      senderId: showSender ? responder.id : '',
      senderName: showSender ? responder.displayName : '',
    );

    setState(() => _messages.add(assistantMessage));
    _scrollToLatest(animate: true);

    final assistantIndex = _messages.length - 1;
    final buffer = StringBuffer();
    final prefix = showSender ? '${responder.displayName}：' : '';

    String visibleContent() {
      final raw = buffer.toString();
      return showSender
          ? stripLeadingSpeakerName(raw, responder.displayName)
          : raw;
    }

    try {
      await for (final chunk in _service.streamChat(
        history,
        provider: provider,
        apiKey: apiKey,
        model: model,
        systemPrompt: systemPrompt,
      )) {
        if (!mounted) {
          return false;
        }

        buffer.write(chunk);
        setState(() {
          _messages[assistantIndex] = _messages[assistantIndex].copyWith(
            content: visibleContent(),
          );
        });
        _scrollToLatest();
      }

      if (!mounted) {
        return false;
      }
      final finalContent = visibleContent();
      if (finalContent.trim().isEmpty) {
        setState(() => _messages.removeAt(assistantIndex));
        _showSnackBar('$prefix没有返回内容，请再试一次。');
        return false;
      }
      setState(() {
        _messages[assistantIndex] = _messages[assistantIndex].copyWith(
          content: finalContent,
        );
      });
      return true;
    } on ChatServiceException catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        if (visibleContent().trim().isEmpty) {
          _messages.removeAt(assistantIndex);
        }
      });
      _showSnackBar('$prefix${error.message}');
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      setState(() {
        if (visibleContent().trim().isEmpty) {
          _messages.removeAt(assistantIndex);
        }
      });
      _showSnackBar('$prefix发送失败，请稍后重试。');
      return false;
    } finally {
      await _saveHistory(conversationId);
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }

    final text = _inputController.text.trim();
    final attachedImage = _pendingImage;
    if (text.isEmpty && attachedImage == null) {
      return;
    }

    final conversationId = _conversationId;
    if (_loadedConversationId != conversationId) {
      _showSnackBar('正在加载聊天记录，请稍候');
      return;
    }

    final selection = ModelStore.instance.selection.value;
    final provider =
        ModelProviderCatalog.byId(selection.providerId) ??
        ModelProviderCatalog.defaultProvider;
    final apiKey = ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '';
    if (apiKey.isEmpty) {
      _showSnackBar('请先在「设置 > 模型」中填写 ${provider.name} API Key。');
      return;
    }
    if (!selection.hasModel) {
      _showSnackBar('请先在「设置 > 模型」中选择一个模型。');
      return;
    }
    if (attachedImage != null &&
        !ModelStore.instance.supportsVision(selection)) {
      _showSnackBar('当前模型不支持图片识别，请切换支持图片的模型。');
      return;
    }

    final members = _isGroup ? _groupMembers : const <CharacterProfile>[];
    if (_isGroup && members.isEmpty) {
      _showSnackBar('群聊中没有可用角色');
      return;
    }

    final model = selection.modelId;
    final responder = _isGroup ? null : CharacterStore.instance.profile.value;
    final userMessage = ChatMessage(
      id: _newMessageId(),
      role: ChatRole.user,
      content: text,
      image: attachedImage,
      createdAt: DateTime.now(),
      senderId: _isGroup ? 'user' : '',
      senderName: _isGroup ? _groupUserName() : '',
    );

    _inputController.clear();

    setState(() {
      _messages.add(userMessage);
      _pendingImage = null;
      _isSending = true;
    });
    _scrollToLatest(animate: true);

    await _saveHistory(conversationId);

    try {
      if (_isGroup) {
        for (final member in members) {
          if (!mounted) {
            break;
          }
          final success = await _streamReply(
            responder: member,
            conversationId: conversationId,
            provider: provider,
            apiKey: apiKey,
            model: model,
            systemPrompt: _buildGroupSystemPrompt(member, members),
            showSender: true,
          );
          if (!success) {
            break;
          }
        }
      } else {
        final character = responder!;
        await _streamReply(
          responder: character,
          conversationId: conversationId,
          provider: provider,
          apiKey: apiKey,
          model: model,
          systemPrompt: MoriConfig.buildSystemPrompt(character),
          showSender: false,
        );
      }
    } finally {
      await _saveHistory(conversationId);
      if (mounted) {
        setState(() => _isSending = false);
        if (!_isGroup) {
          final pendingConversationId = _pendingHistoryConversationId;
          _pendingHistoryConversationId = null;
          if (pendingConversationId != null) {
            await _loadHistory(pendingConversationId);
          }
        }
      }
    }
  }

  void _scrollToLatest({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _shouldShowTime(int index) {
    final current = _messages[index].createdAt;
    if (current == null) {
      return false;
    }
    if (index == 0) {
      return true;
    }

    final previous = _messages[index - 1].createdAt;
    if (previous == null) {
      return true;
    }

    final currentDate = DateTime(current.year, current.month, current.day);
    final previousDate = DateTime(previous.year, previous.month, previous.day);
    if (currentDate != previousDate) {
      return true;
    }
    return current.difference(previous).inMinutes >= 5;
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final hourMinute =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    final dayDifference = today.difference(date).inDays;

    if (dayDifference == 0) {
      return hourMinute;
    }
    if (dayDifference == 1) {
      return '昨天 $hourMinute';
    }
    if (time.year == now.year) {
      return '${time.month}月${time.day}日 $hourMinute';
    }
    return '${time.year}/${time.month}/${time.day} $hourMinute';
  }

  @override
  Widget build(BuildContext context) {
    final canAttachImage = ModelStore.instance.supportsVision(
      ModelStore.instance.selection.value,
    );
    final character = CharacterStore.instance.profile.value;
    final userProfile = UserProfileStore.instance.profile.value;

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const SizedBox.expand()
              : ListView.builder(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isGroup = _isGroup;

                    final Widget avatar;
                    var senderName = '';
                    var showSenderName = false;
                    if (message.isUser) {
                      avatar = UserAvatar(profile: userProfile, size: 34);
                    } else if (isGroup) {
                      final sender =
                          CharacterStore.instance.cardById(message.senderId) ??
                          CharacterProfile(
                            id: message.senderId,
                            name: message.senderName,
                          );
                      avatar = CharacterAvatar(character: sender, size: 34);
                      senderName = message.senderName.isNotEmpty
                          ? message.senderName
                          : sender.displayName;
                      showSenderName = true;
                    } else {
                      avatar = CharacterAvatar(character: character, size: 34);
                    }

                    return Column(
                      children: [
                        if (_shouldShowTime(index))
                          _TimeLabel(
                            text: _formatTimestamp(message.createdAt!),
                          ),
                        _ChatBubble(
                          message: message,
                          avatar: avatar,
                          showSenderName: showSenderName,
                          senderName: senderName,
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (_pendingImage != null)
          _PendingImagePreview(
            image: _pendingImage!,
            onRemove: () => setState(() => _pendingImage = null),
          ),
        _Composer(
          controller: _inputController,
          canSend: (_hasText || _pendingImage != null) && !_isSending,
          canAttachImage: canAttachImage,
          isSending: _isSending,
          onAttachImage: _pickImage,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.canAttachImage,
    required this.isSending,
    required this.onAttachImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool canAttachImage;
  final bool isSending;
  final VoidCallback onAttachImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: '发消息…',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (canAttachImage) ...[
            IconButton.filledTonal(
              onPressed: isSending ? null : onAttachImage,
              tooltip: '发送图片',
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 4),
          ],
          IconButton.filled(
            onPressed: canSend ? onSend : null,
            tooltip: '发送',
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _PendingImagePreview extends StatelessWidget {
  const _PendingImagePreview({required this.image, required this.onRemove});

  final ChatImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: Image.memory(
                  image.bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colors.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: Material(
                color: colors.surfaceContainerHighest,
                elevation: 1,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: colors.primary),
              const SizedBox(height: 10),
              Text(label, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.avatar,
    this.showSenderName = false,
    this.senderName = '',
  });

  final ChatMessage message;
  final Widget avatar;
  final bool showSenderName;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isUser = message.isUser;
    final hasImage = message.image != null;
    final waiting = !isUser && message.content.isEmpty && !hasImage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSenderName && !isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                  ),
                  padding: hasImage
                      ? const EdgeInsets.all(6)
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                  ),
                  child: waiting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasImage)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 220,
                                    maxHeight: 280,
                                  ),
                                  child: Image.memory(
                                    message.image!.bytes,
                                    fit: BoxFit.cover,
                                    semanticLabel: '图片',
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 180,
                                        height: 120,
                                        color: colors.surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (message.content.isNotEmpty)
                              Padding(
                                padding: hasImage
                                    ? const EdgeInsets.fromLTRB(6, 8, 6, 2)
                                    : EdgeInsets.zero,
                                child: Text(
                                  message.content,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: isUser
                                        ? colors.onPrimary
                                        : colors.onSurface,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }
}
