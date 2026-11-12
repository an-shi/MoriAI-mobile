import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_conversation_summary.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/pages/chat_detail_page.dart';
import 'package:mori_ai/pages/group/group_chat_detail_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/pinned_conversation_store.dart';
import 'package:mori_ai/services/unread_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/group_avatar.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<CharacterProfile> _cards = const [];
  List<GroupProfile> _groups = const [];
  Map<String, ChatConversationSummary?> _summaries = const {};
  int _loadToken = 0;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _cards = CharacterStore.instance.cards.value;
    _groups = GroupStore.instance.groups.value;
    CharacterStore.instance.cards.addListener(_handleConversationsChanged);
    GroupStore.instance.groups.addListener(_handleConversationsChanged);
    PinnedConversationStore.instance.pinnedIds.addListener(
      _handlePinnedChanged,
    );
    ChatHistoryStore.instance.messageAppended.addListener(
      _handleHistoryAppended,
    );
    UnreadStore.instance.counts.addListener(_handleUnreadChanged);
    _loadSummaries();
  }

  @override
  void dispose() {
    CharacterStore.instance.cards.removeListener(_handleConversationsChanged);
    GroupStore.instance.groups.removeListener(_handleConversationsChanged);
    PinnedConversationStore.instance.pinnedIds.removeListener(
      _handlePinnedChanged,
    );
    ChatHistoryStore.instance.messageAppended.removeListener(
      _handleHistoryAppended,
    );
    UnreadStore.instance.counts.removeListener(_handleUnreadChanged);
    super.dispose();
  }

  void _handleUnreadChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handlePinnedChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleHistoryAppended() {
    if (mounted) {
      _loadSummaries();
    }
  }

  void _handleConversationsChanged() {
    _cards = CharacterStore.instance.cards.value;
    _groups = GroupStore.instance.groups.value;
    if (mounted) {
      setState(() {});
    }
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final token = ++_loadToken;
    final ids = <String>[
      for (final card in _cards) card.id,
      for (final group in _groups) group.id,
    ];
    final summaries = await Future.wait([
      for (final id in ids)
        ChatHistoryStore.instance
            .summaryFor(id)
            .then((summary) => MapEntry(id, summary)),
    ]);

    if (!mounted || token != _loadToken) {
      return;
    }

    setState(() {
      _summaries = {for (final entry in summaries) entry.key: entry.value};
    });
  }

  Future<void> _openChat(CharacterProfile card) async {
    if (_openingChat) {
      return;
    }

    setState(() => _openingChat = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatDetailPage(characterId: card.id),
        ),
      );
      if (mounted) {
        await _loadSummaries();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('打开聊天失败，请重试')));
    } finally {
      if (mounted) {
        setState(() => _openingChat = false);
      }
    }
  }

  Future<void> _openGroupChat(GroupProfile group) async {
    if (_openingChat) {
      return;
    }

    setState(() => _openingChat = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupChatDetailPage(group: group),
        ),
      );
      if (mounted) {
        await _loadSummaries();
      }
    } finally {
      if (mounted) {
        setState(() => _openingChat = false);
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

  String _cleanPreview(String preview) {
    return preview.replaceAll('```', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _showConversationMenu({
    required BuildContext tileContext,
    required _ConversationEntry entry,
    required bool isPinned,
  }) async {
    final box = tileContext.findRenderObject();
    final overlay = Overlay.of(tileContext).context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox) {
      return;
    }

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final anchorX = topLeft.dx + 32;
    final anchorY = topLeft.dy + box.size.height / 2;
    final position = RelativeRect.fromLTRB(
      anchorX,
      anchorY,
      overlay.size.width - anchorX,
      overlay.size.height - anchorY,
    );

    final selected = await showMenu<String>(
      context: tileContext,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          child: Row(
            children: [
              Icon(MoriIcons.pin, size: 18),
              const SizedBox(width: 12),
              Text(isPinned ? '取消置顶' : '置顶'),
            ],
          ),
        ),
      ],
    );

    if (selected != 'pin') {
      return;
    }

    try {
      await PinnedConversationStore.instance.setPinned(entry.id, !isPinned);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('置顶操作失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_cards.isEmpty && _groups.isEmpty) {
      return const MoriEmptyState(
        icon: MoriIcons.chats,
        title: '还没有会话',
        message: '创建角色卡后，和他们的对话会出现在这里。',
      );
    }

    final pinnedIds = PinnedConversationStore.instance.pinnedIds.value;
    final entries =
        <_ConversationEntry>[
          for (var index = 0; index < _cards.length; index++)
            _ConversationEntry(
              id: _cards[index].id,
              name: _cards[index].displayName,
              card: _cards[index],
              order: index,
            ),
          for (var index = 0; index < _groups.length; index++)
            _ConversationEntry(
              id: _groups[index].id,
              name: _groups[index].displayName,
              group: _groups[index],
              order: _cards.length + index,
            ),
        ]..sort((a, b) {
          final aPinned = pinnedIds.contains(a.id);
          final bPinned = pinnedIds.contains(b.id);
          if (aPinned != bPinned) {
            return aPinned ? -1 : 1;
          }

          final aTime = _summaries[a.id]?.createdAt;
          final bTime = _summaries[b.id]?.createdAt;
          if (aTime == null && bTime == null) {
            return a.order.compareTo(b.order);
          }
          if (aTime == null) {
            return 1;
          }
          if (bTime == null) {
            return -1;
          }
          final result = bTime.compareTo(aTime);
          return result == 0 ? a.order.compareTo(b.order) : result;
        });

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: colors.surface,
      onRefresh: _loadSummaries,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 2, bottom: 12),
        itemCount: entries.length,
        separatorBuilder: (context, index) => Divider(
          height: 0.8,
          thickness: 0.8,
          indent: 82,
          endIndent: 14,
          color: colors.outlineVariant.withValues(alpha: 0.8),
        ),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final summary = _summaries[entry.id];
          final timeLabel = _formatTime(summary?.createdAt);
          final preview = summary == null
              ? (entry.group != null
                    ? '${entry.group!.memberIds.length} 位成员'
                    : '暂无消息')
              : _cleanPreview(summary.preview);
          final isPinned = pinnedIds.contains(entry.id);
          final unread = UnreadStore.instance.countFor(entry.id);
          final hasUnread = unread > 0;

          return Builder(
            builder: (tileContext) {
              return ListTile(
                tileColor: isPinned ? colors.surfaceContainerLow : null,
                contentPadding: const EdgeInsetsDirectional.fromSTEB(
                  14,
                  9,
                  14,
                  9,
                ),
                minVerticalPadding: 9,
                horizontalTitleGap: 12,
                leading: entry.card != null
                    ? CharacterAvatar(character: entry.card!, size: 54)
                    : GroupAvatar(group: entry.group!, size: 54),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (isPinned) ...[
                      const SizedBox(width: 5),
                      Icon(
                        MoriIcons.pin,
                        size: 12.5,
                        color: colors.primary.withValues(alpha: 0.8),
                      ),
                    ],
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasUnread
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                      fontSize: 13.8,
                      height: 1.35,
                    ),
                  ),
                ),
                trailing: (timeLabel == null && !hasUnread)
                    ? null
                    : SizedBox(
                        width: 54,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (timeLabel != null)
                              Text(
                                timeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: hasUnread
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (hasUnread) ...[
                              const SizedBox(height: 5),
                              Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(
                                    MoriRadius.pill,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onPrimary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                onLongPress: () => _showConversationMenu(
                  tileContext: tileContext,
                  entry: entry,
                  isPinned: isPinned,
                ),
                onTap: () {
                  if (entry.group != null) {
                    _openGroupChat(entry.group!);
                  } else if (entry.card != null) {
                    _openChat(entry.card!);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationEntry {
  const _ConversationEntry({
    required this.id,
    required this.name,
    required this.order,
    this.card,
    this.group,
  });

  final String id;
  final String name;
  final int order;
  final CharacterProfile? card;
  final GroupProfile? group;
}
