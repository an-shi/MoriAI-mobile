import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mori_ai/models/moribot/mori_models.dart';
import 'package:mori_ai/services/moribot/mori_audio_player.dart';
import 'package:mori_ai/services/moribot/mori_bot_client.dart';
import 'package:mori_ai/services/moribot/mori_chat_repository.dart';
import 'package:mori_ai/services/moribot/mori_realtime_service.dart';
import 'package:mori_ai/ui/mori_chat_background.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/moribot/mori_cached_image.dart';
import 'package:mori_ai/widgets/moribot/mori_character_avatar.dart';
import 'package:mori_ai/widgets/mori_message_text.dart';

class MoriChatPage extends StatefulWidget {
  const MoriChatPage({super.key, required this.conversation});

  final MoriConversation conversation;

  @override
  State<MoriChatPage> createState() => _MoriChatPageState();
}

class _MoriChatPageState extends State<MoriChatPage>
    with WidgetsBindingObserver {
  static final _random = Random();

  final _messages = <MoriMessage>[];
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();

  late MoriConversation _conversation;
  MoriCharacter? _character;
  int _loadToken = 0;
  bool _initialLoading = true;
  bool _loadingOlder = false;
  bool _hasMoreOlder = false;
  bool _sending = false;
  bool _speechEnabled = false;
  bool _hasText = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _character = MoriChatRepository.instance.characterById(
      _conversation.characterId,
    );
    _inputController.addListener(_handleInputChanged);
    MoriChatRepository.instance.conversations.addListener(
      _handleRepositoryChanged,
    );
    MoriChatRepository.instance.characters.addListener(
      _handleRepositoryChanged,
    );
    MoriRealtimeService.instance.lastEvent.addListener(_handleRealtimeEvent);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadInitial());
    if (_character == null) {
      unawaited(
        MoriChatRepository.instance.refreshCharacters(showLoading: false),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MoriChatRepository.instance.conversations.removeListener(
      _handleRepositoryChanged,
    );
    MoriChatRepository.instance.characters.removeListener(
      _handleRepositoryChanged,
    );
    MoriRealtimeService.instance.lastEvent.removeListener(_handleRealtimeEvent);
    unawaited(MoriAudioPlayer.instance.stop());
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLatest(silent: true));
    }
  }

  bool get _canSend =>
      !_initialLoading &&
      !_sending &&
      _conversation.characterAvailable &&
      (_character?.chatAvailable ?? true);

  bool get _characterAvailable =>
      _conversation.characterAvailable && (_character?.chatAvailable ?? true);

  void _handleInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleRepositoryChanged() {
    if (!mounted) {
      return;
    }
    final conversation = MoriChatRepository.instance.conversationById(
      _conversation.id,
    );
    final character = MoriChatRepository.instance.characterById(
      _conversation.characterId,
    );
    if (conversation == null && character == null) {
      return;
    }
    setState(() {
      if (conversation != null) {
        _conversation = conversation;
      }
      if (character != null) {
        _character = character;
        if (!character.speechAvailable) {
          _speechEnabled = false;
        }
      }
    });
  }

  void _handleRealtimeEvent() {
    final event = MoriRealtimeService.instance.lastEvent.value;
    if (event == null) {
      return;
    }
    final conversationId = event['conversation_id'];
    if (conversationId is String && conversationId == _conversation.id) {
      unawaited(_refreshLatest(silent: true));
    }
  }

  Future<void> _loadInitial() async {
    final conversationId = _conversation.id;
    final token = ++_loadToken;
    setState(() {
      _initialLoading = true;
      _error = null;
    });

    final cached = await MoriChatRepository.instance.cachedMessages(
      conversationId,
    );
    if (!mounted || token != _loadToken) {
      return;
    }
    if (cached.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(cached);
        _initialLoading = false;
        _hasMoreOlder = true;
      });
      _scrollToBottom(force: true);
    }

    try {
      if (cached.isEmpty) {
        final page = await MoriChatRepository.instance.fetchLatestMessages(
          conversationId,
        );
        if (!mounted || token != _loadToken) {
          return;
        }
        _mergeMessages(page.messages, clear: true);
        _hasMoreOlder = page.hasMore;
      } else {
        await _syncAfter(cached.last.id, token);
      }
    } on MoriApiException catch (error) {
      if (mounted && token == _loadToken) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _initialLoading = false);
        _scrollToBottom(force: cached.isEmpty);
      }
    }
  }

  Future<void> _syncAfter(int afterId, int token) async {
    var cursor = afterId;
    for (var pageIndex = 0; pageIndex < 5; pageIndex++) {
      final page = await MoriChatRepository.instance.fetchMessagesAfter(
        _conversation.id,
        cursor,
      );
      if (!mounted || token != _loadToken) {
        return;
      }
      _mergeMessages(page.messages);
      if (!page.hasMore || page.messages.isEmpty) {
        return;
      }
      cursor = page.latestId ?? page.messages.last.id;
    }
  }

  Future<void> _refreshLatest({bool silent = false}) async {
    try {
      final page = await MoriChatRepository.instance.fetchLatestMessages(
        _conversation.id,
      );
      if (!mounted) {
        return;
      }
      _mergeMessages(page.messages);
      if (!silent) {
        setState(() => _error = null);
        _scrollToBottom();
      }
    } on MoriApiException catch (error) {
      if (mounted && !silent) {
        setState(() => _error = error.message);
      }
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder) {
      return;
    }
    int? beforeId;
    for (final message in _messages) {
      if (message.id > 0) {
        beforeId = message.id;
        break;
      }
    }
    if (beforeId == null) {
      setState(() => _hasMoreOlder = false);
      return;
    }

    final oldMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    setState(() => _loadingOlder = true);
    try {
      final page = await MoriChatRepository.instance.fetchMessagesBefore(
        _conversation.id,
        beforeId,
      );
      if (!mounted) {
        return;
      }
      _mergeMessages(page.messages);
      setState(() => _hasMoreOlder = page.hasMore);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        final newMax = _scrollController.position.maxScrollExtent;
        final target = oldPixels + (newMax - oldMax);
        _scrollController.jumpTo(target.clamp(0.0, newMax));
      });
    } on MoriApiException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  void _mergeMessages(Iterable<MoriMessage> incoming, {bool clear = false}) {
    if (!mounted) {
      return;
    }
    final byId = <int, MoriMessage>{};
    if (!clear) {
      for (final message in _messages) {
        byId[message.id] = message;
      }
    }
    for (final message in incoming) {
      if (message.id <= 0) {
        continue;
      }
      if (message.clientMessageId.isNotEmpty) {
        byId.removeWhere(
          (id, existing) =>
              id < 0 &&
              existing.clientMessageId.isNotEmpty &&
              existing.clientMessageId == message.clientMessageId,
        );
      }
      byId[message.id] = message;
    }
    final next = byId.values.toList(growable: false)..sort(_compareMessages);
    setState(() {
      _messages
        ..clear()
        ..addAll(next);
    });
    unawaited(
      MoriChatRepository.instance.saveMessages(_conversation.id, _messages),
    );
  }

  int _compareMessages(MoriMessage a, MoriMessage b) {
    final aPending = a.status != MoriMessageStatus.sent;
    final bPending = b.status != MoriMessageStatus.sent;
    if (aPending != bPending) {
      return aPending ? 1 : -1;
    }
    if (aPending) {
      final aTime = a.createdAt ?? DateTime.now();
      final bTime = b.createdAt ?? DateTime.now();
      final result = aTime.compareTo(bTime);
      return result == 0 ? a.id.compareTo(b.id) : result;
    }
    return a.id.compareTo(b.id);
  }

  void _scrollToBottom({bool animate = true, bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (animate && !force) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  String _newClientMessageId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(0x7fffffff);
    return 'mm-$timestamp-$salt';
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || !_canSend) {
      return;
    }
    final clientMessageId = _newClientMessageId();
    final pending = MoriMessage(
      id: -DateTime.now().microsecondsSinceEpoch,
      conversationId: _conversation.id,
      role: 'user',
      content: text,
      clientMessageId: clientMessageId,
      createdAt: DateTime.now(),
      status: MoriMessageStatus.pending,
    );

    _inputController.clear();
    setState(() {
      _messages.add(pending);
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final result = await MoriChatRepository.instance.sendMessage(
        _conversation.id,
        content: text,
        clientMessageId: clientMessageId,
        speech: _speechEnabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _conversation = result.conversation;
        _messages.removeWhere(
          (message) =>
              message.id < 0 && message.clientMessageId == clientMessageId,
        );
      });
      _mergeMessages([result.userMessage, result.assistantMessage]);
      _scrollToBottom();
    } on MoriApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.removeWhere(
          (message) =>
              message.id < 0 && message.clientMessageId == clientMessageId,
        );
        if (_inputController.text.trim().isEmpty) {
          _inputController.text = text;
          _inputController.selection = TextSelection.collapsed(
            offset: text.length,
          );
        }
      });
      _showSnackBar(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.removeWhere(
          (message) =>
              message.id < 0 && message.clientMessageId == clientMessageId,
        );
        if (_inputController.text.trim().isEmpty) {
          _inputController.text = text;
        }
      });
      _showSnackBar('发送失败：$error');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _renameConversation() async {
    final controller = TextEditingController(
      text: _conversation.title.trim().isEmpty
          ? _conversation.characterName
          : _conversation.title,
    );
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('重命名会话'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(hintText: '会话标题'),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(dialogContext).pop(trimmed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.of(dialogContext).pop(trimmed);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (title == null || !mounted) {
      return;
    }
    try {
      final updated = await MoriChatRepository.instance.renameConversation(
        _conversation.id,
        title,
      );
      if (mounted) {
        setState(() => _conversation = updated);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('$error');
      }
    }
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除会话'),
          content: const Text('会话的全部消息、语音和图片都会从服务器删除，且无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await MoriChatRepository.instance.deleteConversation(_conversation.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('$error');
      }
    }
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'rename':
        unawaited(_renameConversation());
        return;
      case 'delete':
        unawaited(_deleteConversation());
        return;
      case 'refresh':
        unawaited(_refreshLatest());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final character = _character;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (character != null)
              MoriCharacterAvatar(character: character, size: 34)
            else
              MoriConversationAvatar(conversation: _conversation, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conversation.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16.5,
                    ),
                  ),
                  if (_conversation.title.trim().isNotEmpty &&
                      _conversation.title.trim() !=
                          _conversation.displayName) ...[
                    const SizedBox(height: 1),
                    Text(
                      _conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: '会话操作',
            onSelected: _handleMenu,
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(MoriIcons.refresh, size: 18),
                    SizedBox(width: 10),
                    Text('刷新消息'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(MoriIcons.edit, size: 18),
                    SizedBox(width: 10),
                    Text('重命名会话'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(MoriIcons.trash, size: 18),
                    SizedBox(width: 10),
                    Text('删除会话'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            _ChatBanner(
              message: _error!,
              actionLabel: '重试',
              onAction: () => _refreshLatest(),
            ),
          if (!_characterAvailable)
            const _ChatBanner(
              message: '这个角色已被停用，当前会话暂时无法继续发送消息。',
              isWarning: true,
            ),
          Expanded(child: MoriChatBackground(child: _buildMessageList(theme))),
          if (_characterAvailable)
            _buildComposer(theme)
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    if (_initialLoading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final children = <Widget>[];
    if (_hasMoreOlder || _loadingOlder) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Center(
            child: _loadingOlder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton.icon(
                    onPressed: _loadOlder,
                    icon: const Icon(MoriIcons.clock, size: 15),
                    label: const Text('加载更早的消息'),
                  ),
          ),
        ),
      );
    }

    if (_messages.isEmpty && !_sending) {
      children.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(30, 90, 30, 30),
          child: Column(
            children: [
              Icon(MoriIcons.chat, size: 32),
              SizedBox(height: 12),
              Text('发送一条消息开始聊天', textAlign: TextAlign.center),
              SizedBox(height: 5),
              Text('回复由 MoriBot 根据角色卡生成', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    for (final message in _messages) {
      children.add(
        _MessageRow(
          message: message,
          character: _character,
          onImageTap: _openImage,
        ),
      );
    }

    if (_sending) {
      children.add(const _TypingIndicator());
    }

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: children,
    );
  }

  Widget _buildComposer(ThemeData theme) {
    final colors = theme.colorScheme;
    final palette = context.chatPalette;
    final speechAvailable = _character?.speechAvailable ?? false;
    final canSend = _hasText && _canSend;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: palette.composerBackground,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.7),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (speechAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: IconButton(
                  tooltip: _speechEnabled ? '关闭语音回复' : '语音回复',
                  onPressed: () {
                    setState(() => _speechEnabled = !_speechEnabled);
                  },
                  icon: Icon(
                    _speechEnabled ? MoriIcons.volume : MoriIcons.volumeOff,
                    size: 21,
                    color: _speechEnabled
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: 8000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                inputFormatters: [LengthLimitingTextInputFormatter(8000)],
                decoration: InputDecoration(
                  hintText: '发消息…',
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: theme.brightness == Brightness.light ? 0.55 : 0.45,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MoriRadius.xlarge),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: IconButton.filled(
                tooltip: '发送',
                onPressed: canSend ? _send : null,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(MoriIcons.send, size: 19),
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: colors.primary,
                  disabledBackgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onPrimary,
                  disabledForegroundColor: colors.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImage(MoriImage image) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Center(
                    child: MoriCachedImage(url: image.url, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: SafeArea(
                  child: IconButton(
                    tooltip: '关闭',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(MoriIcons.close),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.character,
    required this.onImageTap,
  });

  final MoriMessage message;
  final MoriCharacter? character;
  final void Function(MoriImage image) onImageTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.chatPalette;
    final isUser = message.isUser;
    final colors = theme.colorScheme;
    final textColor = isUser ? palette.outgoingText : palette.incomingText;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: EdgeInsets.fromLTRB(
        message.images.isEmpty ? 12 : 6,
        message.images.isEmpty ? 8 : 6,
        message.images.isEmpty ? 12 : 6,
        7,
      ),
      decoration: BoxDecoration(
        color: isUser ? palette.outgoingBubble : palette.incomingBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(MoriRadius.bubble),
          topRight: const Radius.circular(MoriRadius.bubble),
          bottomLeft: Radius.circular(isUser ? MoriRadius.bubble : 5),
          bottomRight: Radius.circular(isUser ? 5 : MoriRadius.bubble),
        ),
        border: Border.all(
          color: isUser
              ? palette.outgoingBubble.withValues(alpha: 0)
              : palette.incomingBorder,
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final image in message.images) ...[
            GestureDetector(
              onTap: () => onImageTap(image),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MoriRadius.medium),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 160,
                    maxWidth: 240,
                    maxHeight: 240,
                  ),
                  child: MoriCachedImage(
                    url: image.url,
                    fit: BoxFit.cover,
                    width: 240,
                  ),
                ),
              ),
            ),
            if (message.content.trim().isNotEmpty || message.speech != null)
              const SizedBox(height: 7),
          ],
          if (message.content.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: message.images.isEmpty ? 0 : 6,
              ),
              child: MoriMessageText(
                text: message.content,
                baseStyle: theme.textTheme.bodyMedium!.copyWith(
                  color: textColor,
                  fontSize: 15.2,
                  height: 1.45,
                ),
                isUser: isUser,
              ),
            ),
          if (message.speech != null) ...[
            _SpeechChip(message: message),
            if (message.content.trim().isNotEmpty) const SizedBox(height: 3),
          ],
          if (message.content.trim().isEmpty &&
              message.images.isEmpty &&
              message.speech == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '（空回复）',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.55),
                ),
              ),
            ),
          const SizedBox(height: 3),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: message.images.isEmpty ? 0 : 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor.withValues(alpha: 0.58),
                    fontSize: 9.5,
                  ),
                ),
                if (!isUser && message.model.trim().isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      message.model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColor.withValues(alpha: 0.42),
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
                if (message.status == MoriMessageStatus.pending) ...[
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 9,
                    height: 9,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.2,
                      color: textColor.withValues(alpha: 0.55),
                    ),
                  ),
                ],
                if (message.status == MoriMessageStatus.failed) ...[
                  const SizedBox(width: 4),
                  Icon(MoriIcons.alert, size: 10, color: colors.error),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(isUser ? 36 : 0, 3, isUser ? 2 : 36, 3),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            if (character != null)
              MoriCharacterAvatar(character: character!, size: 28)
            else
              const SizedBox(width: 28),
            const SizedBox(width: 7),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  static String _formatTime(DateTime? time) {
    if (time == null) {
      return '';
    }
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _SpeechChip extends StatelessWidget {
  const _SpeechChip({required this.message});

  final MoriMessage message;

  @override
  Widget build(BuildContext context) {
    final speech = message.speech!;
    final theme = Theme.of(context);
    final palette = context.chatPalette;
    final textColor = message.isUser
        ? palette.outgoingText
        : palette.incomingText;
    final key = 'message-${message.id}';

    return ValueListenableBuilder<String?>(
      valueListenable: MoriAudioPlayer.instance.playingKey,
      builder: (context, playingKey, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: MoriAudioPlayer.instance.loading,
          builder: (context, loading, _) {
            final isPlaying = playingKey == key;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(MoriRadius.pill),
                onTap: loading && !isPlaying
                    ? null
                    : () async {
                        try {
                          await MoriAudioPlayer.instance.toggle(
                            key: key,
                            url: speech.url,
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(content: Text('$error')));
                          }
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(MoriRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (loading && !isPlaying)
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.7,
                            color: textColor,
                          ),
                        )
                      else
                        Icon(
                          isPlaying ? MoriIcons.pause : MoriIcons.play,
                          size: 15,
                          color: textColor,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '语音 · ${_formatBytes(speech.byteLength)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '音频';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final palette = context.chatPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 36, 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.incomingBubble,
              shape: BoxShape.circle,
              border: Border.all(color: palette.incomingBorder, width: 0.7),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: palette.incomingText.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: palette.incomingBubble,
              borderRadius: BorderRadius.circular(MoriRadius.bubble),
              border: Border.all(color: palette.incomingBorder, width: 0.7),
            ),
            child: Text(
              '正在回复…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.incomingText.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBanner extends StatelessWidget {
  const _ChatBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isWarning = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = isWarning
        ? colors.surfaceContainerHighest
        : colors.errorContainer.withValues(alpha: 0.6);
    final foreground = isWarning
        ? colors.onSurfaceVariant
        : colors.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      color: background,
      child: Row(
        children: [
          Icon(
            isWarning ? MoriIcons.alert : MoriIcons.wifiOff,
            size: 15,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
