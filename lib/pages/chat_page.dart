import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _suggestions = ['今天有点累，陪我聊聊', '给我讲点轻松的事', '帮我理一理思绪'];
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

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
    ModelStore.instance.selection.addListener(_handleModelConfigChanged);
    ModelStore.instance.modelCatalog.addListener(_handleModelConfigChanged);
  }

  @override
  void dispose() {
    ModelStore.instance.selection.removeListener(_handleModelConfigChanged);
    ModelStore.instance.modelCatalog.removeListener(_handleModelConfigChanged);
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
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

  Future<void> _sendMessage([String? preset]) async {
    if (_isSending) {
      return;
    }

    final text = (preset ?? _inputController.text).trim();
    final attachedImage = _pendingImage;
    if (text.isEmpty && attachedImage == null) {
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

    final model = selection.modelId;
    final userMessage = ChatMessage(
      role: ChatRole.user,
      content: text,
      image: attachedImage,
    );

    _inputController.clear();

    final history = [..._messages, userMessage];

    setState(() {
      _messages
        ..add(userMessage)
        ..add(const ChatMessage(role: ChatRole.assistant, content: ''));
      _pendingImage = null;
      _isSending = true;
    });
    _scrollToLatest(animate: true);

    final assistantIndex = _messages.length - 1;
    final buffer = StringBuffer();

    try {
      await for (final chunk in _service.streamChat(
        history,
        provider: provider,
        apiKey: apiKey,
        model: model,
      )) {
        if (!mounted) {
          return;
        }

        buffer.write(chunk);
        setState(() {
          _messages[assistantIndex] = ChatMessage(
            role: ChatRole.assistant,
            content: buffer.toString(),
          );
        });
        _scrollToLatest();
      }

      if (!mounted) {
        return;
      }
      if (buffer.isEmpty) {
        setState(() => _messages.removeAt(assistantIndex));
        _showSnackBar('Mori 没有返回内容，请再试一次。');
      }
    } on ChatServiceException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (buffer.isEmpty) {
          _messages.removeAt(assistantIndex);
        }
      });
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (buffer.isEmpty) {
          _messages.removeAt(assistantIndex);
        }
      });
      _showSnackBar('发送失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
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

  @override
  Widget build(BuildContext context) {
    final canAttachImage = ModelStore.instance.supportsVision(
      ModelStore.instance.selection.value,
    );

    return Column(
      children: [
        ValueListenableBuilder<ModelSelection>(
          valueListenable: ModelStore.instance.selection,
          builder: (context, selection, _) {
            final provider =
                ModelProviderCatalog.byId(selection.providerId) ??
                ModelProviderCatalog.defaultProvider;

            return ValueListenableBuilder<String?>(
              valueListenable: ApiKeyStore.instance.keyFor(
                selection.providerId,
              ),
              builder: (context, apiKey, _) {
                final hasKey = apiKey != null && apiKey.trim().isNotEmpty;
                if (hasKey && selection.hasModel) {
                  return const SizedBox.shrink();
                }

                return _ModelSetupNotice(
                  message: hasKey
                      ? '尚未选择模型：请到「设置 > 模型」中选择'
                      : '未配置 ${provider.name} API Key：请到「设置 > 模型」中填写',
                );
              },
            );
          },
        ),
        Expanded(
          child: _messages.isEmpty
              ? _WelcomeView(
                  suggestions: _suggestions,
                  onSuggestionSelected: (text) => _sendMessage(text),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) =>
                      _ChatBubble(message: _messages[index]),
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
          onSend: () => _sendMessage(),
        ),
      ],
    );
  }
}

class _ModelSetupNotice extends StatelessWidget {
  const _ModelSetupNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.key_off_outlined,
            size: 18,
            color: colors.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.spa_rounded,
                      size: 38,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '嗨，我是 Mori',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今天想聊点什么？',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in suggestions)
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: () => onSuggestionSelected(suggestion),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                hintText: '和 Mori 说点什么…',
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
  const _ChatBubble({required this.message});

  final ChatMessage message;

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
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.primaryContainer,
              child: Icon(
                Icons.spa_rounded,
                size: 16,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              padding: hasImage
                  ? const EdgeInsets.all(6)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isUser ? colors.primary : colors.surfaceContainerHighest,
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
          ),
        ],
      ),
    );
  }
}
