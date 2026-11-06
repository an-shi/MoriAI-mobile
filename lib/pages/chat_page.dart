import 'package:flutter/material.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/deepseek_service.dart';
import 'package:mori_ai/services/model_store.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _suggestions = ['今天有点累，陪我聊聊', '给我讲点轻松的事', '帮我理一理思绪'];

  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _service = DeepSeekService();

  bool _isSending = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText == _hasText) {
      return;
    }
    setState(() => _hasText = hasText);
  }

  Future<void> _sendMessage([String? preset]) async {
    if (_isSending) {
      return;
    }

    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty) {
      return;
    }

    final apiKey = ApiKeyStore.instance.apiKey.value?.trim() ?? '';
    if (apiKey.isEmpty) {
      _showSnackBar('请先在「设置」中填写 DeepSeek API Key。');
      return;
    }

    final model = ModelStore.instance.model.value;

    _inputController.clear();

    final history = [
      ..._messages,
      ChatMessage(role: ChatRole.user, content: text),
    ];

    setState(() {
      _messages
        ..add(ChatMessage(role: ChatRole.user, content: text))
        ..add(const ChatMessage(role: ChatRole.assistant, content: ''));
      _isSending = true;
    });
    _scrollToLatest(animate: true);

    final assistantIndex = _messages.length - 1;
    final buffer = StringBuffer();

    try {
      await for (final chunk in _service.streamChat(
        history,
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
    } on DeepSeekException catch (error) {
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
    return Column(
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: ApiKeyStore.instance.apiKey,
          builder: (context, apiKey, _) {
            if (apiKey != null && apiKey.trim().isNotEmpty) {
              return const SizedBox.shrink();
            }
            return const _ApiKeyNotice();
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
        _Composer(
          controller: _inputController,
          canSend: _hasText && !_isSending,
          isSending: _isSending,
          onSend: () => _sendMessage(),
        ),
      ],
    );
  }
}

class _ApiKeyNotice extends StatelessWidget {
  const _ApiKeyNotice();

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
              '未配置 API Key：请到「设置」中填写',
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
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool isSending;
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isUser = message.isUser;
    final waiting = !isUser && message.content.isEmpty;

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                  : Text(
                      message.content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isUser ? colors.onPrimary : colors.onSurface,
                        height: 1.45,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
