import 'package:flutter/material.dart';
import 'package:mori_ai/models/moribot/mori_models.dart';
import 'package:mori_ai/pages/moribot/chat_page.dart';
import 'package:mori_ai/services/moribot/mori_chat_repository.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/moribot/mori_character_avatar.dart';

/// Lets the user choose a character and creates a server-side conversation.
Future<MoriConversation?> pickAndCreateMoriConversation(
  BuildContext context,
) async {
  final repository = MoriChatRepository.instance;
  if (repository.characters.value.isEmpty) {
    await repository.refreshCharacters(showLoading: false);
  }
  final characters = repository.characters.value
      .where((character) => character.chatAvailable)
      .toList(growable: false);
  if (!context.mounted) {
    return null;
  }
  if (characters.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('没有可用的角色卡，请先在 MoriBot 后台添加')),
      );
    return null;
  }

  final selected = await showModalBottomSheet<MoriCharacter>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return _CharacterPickerSheet(characters: characters);
    },
  );
  if (selected == null || !context.mounted) {
    return null;
  }

  try {
    return await repository.createConversation(selected.id);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
    return null;
  }
}

class MoriConversationListPage extends StatefulWidget {
  const MoriConversationListPage({super.key});

  @override
  State<MoriConversationListPage> createState() =>
      _MoriConversationListPageState();
}

class _MoriConversationListPageState extends State<MoriConversationListPage> {
  final _scrollController = ScrollController();
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      MoriChatRepository.instance.loadMoreConversations();
    }
  }

  Future<void> _refresh() async {
    await MoriChatRepository.instance.refreshConversations(showLoading: false);
  }

  Future<void> _open(MoriConversation conversation) async {
    if (_openingId != null) {
      return;
    }
    setState(() => _openingId = conversation.id);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MoriChatPage(conversation: conversation),
        ),
      );
      if (mounted) {
        await _refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _openingId = null);
      }
    }
  }

  Future<void> _createConversation() async {
    final conversation = await pickAndCreateMoriConversation(context);
    if (conversation == null || !mounted) {
      return;
    }
    await _open(conversation);
  }

  Future<void> _showActions(MoriConversation conversation) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
            child: MoriSettingsGroup(
              dividerIndent: 60,
              children: [
                MoriSettingsTile(
                  icon: MoriIcons.edit,
                  title: '重命名会话',
                  onTap: () => Navigator.of(sheetContext).pop('rename'),
                ),
                MoriSettingsTile(
                  icon: MoriIcons.trash,
                  title: '删除会话',
                  danger: true,
                  showChevron: false,
                  onTap: () => Navigator.of(sheetContext).pop('delete'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (action == 'rename') {
      await _rename(conversation);
    } else if (action == 'delete') {
      await _delete(conversation);
    }
  }

  Future<void> _rename(MoriConversation conversation) async {
    final controller = TextEditingController(
      text: conversation.title.trim().isEmpty
          ? conversation.characterName
          : conversation.title,
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
      await MoriChatRepository.instance.renameConversation(
        conversation.id,
        title,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _delete(MoriConversation conversation) async {
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
      await MoriChatRepository.instance.deleteConversation(conversation.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('会话已删除')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  String? _formatTime(DateTime? time) {
    if (time == null) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
    if (difference == 1) {
      return '昨天';
    }
    if (time.year == now.year) {
      return '${time.month}/${time.day}';
    }
    return '${time.year}/${time.month}/${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final repository = MoriChatRepository.instance;

    return ValueListenableBuilder<List<MoriConversation>>(
      valueListenable: repository.conversations,
      builder: (context, conversations, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: repository.loadingConversations,
          builder: (context, loading, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: repository.lastError,
              builder: (context, error, _) {
                if (conversations.isEmpty && loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (conversations.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.12,
                        ),
                        MoriEmptyState(
                          icon: MoriIcons.chats,
                          title: '还没有会话',
                          message:
                              error ?? '选择一个角色开始聊天。会话和消息会保存在你的 MoriBot 服务器上。',
                          actions: [
                            FilledButton.icon(
                              onPressed: _createConversation,
                              icon: const Icon(MoriIcons.plus, size: 18),
                              label: const Text('开始对话'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 2, bottom: 20),
                    itemCount: conversations.length + (error == null ? 0 : 1),
                    separatorBuilder: (context, index) => Divider(
                      height: 0.8,
                      thickness: 0.8,
                      indent: 82,
                      endIndent: 14,
                      color: colors.outlineVariant.withValues(alpha: 0.8),
                    ),
                    itemBuilder: (context, index) {
                      if (error != null && index == 0) {
                        return _ErrorBanner(message: error);
                      }
                      final conversation =
                          conversations[error == null ? index : index - 1];
                      final timeLabel = _formatTime(conversation.lastMessageAt);
                      final opening = _openingId == conversation.id;
                      return ListTile(
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(
                          14,
                          9,
                          14,
                          9,
                        ),
                        minVerticalPadding: 9,
                        horizontalTitleGap: 12,
                        leading: MoriConversationAvatar(
                          conversation: conversation,
                          size: 54,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                conversation.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (conversation.title.trim().isNotEmpty &&
                                conversation.title.trim() !=
                                    conversation.displayName) ...[
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  conversation.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: 0.78,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (!conversation.characterAvailable) ...[
                              const SizedBox(width: 6),
                              Icon(
                                MoriIcons.alert,
                                size: 13,
                                color: colors.error.withValues(alpha: 0.8),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            conversation.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 13.8,
                              height: 1.35,
                            ),
                          ),
                        ),
                        trailing: opening
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : SizedBox(
                                width: 54,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (timeLabel != null)
                                      Text(
                                        timeLabel,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    if (conversation.messageCount > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${conversation.messageCount} 条',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant
                                                  .withValues(alpha: 0.72),
                                              fontSize: 10,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                        onLongPress: () => _showActions(conversation),
                        onTap: () => _open(conversation),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CharacterPickerSheet extends StatelessWidget {
  const _CharacterPickerSheet({required this.characters});

  final List<MoriCharacter> characters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选择角色',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(MoriIcons.close, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 18),
              itemCount: characters.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 0.8, thickness: 0.8, indent: 72),
              itemBuilder: (context, index) {
                final character = characters[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 7,
                  ),
                  leading: MoriCharacterAvatar(character: character, size: 44),
                  title: Text(
                    character.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    character.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(MoriIcons.chevron, size: 18),
                  onTap: () => Navigator.of(context).pop(character),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(MoriRadius.medium),
      ),
      child: Row(
        children: [
          Icon(MoriIcons.alert, size: 16, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
