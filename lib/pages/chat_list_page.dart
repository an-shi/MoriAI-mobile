import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_conversation_summary.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/pages/chat_detail_page.dart';
import 'package:mori_ai/pages/group/group_chat_detail_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/group_store.dart';
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
    _loadSummaries();
  }

  @override
  void dispose() {
    CharacterStore.instance.cards.removeListener(_handleConversationsChanged);
    GroupStore.instance.groups.removeListener(_handleConversationsChanged);
    super.dispose();
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
      if (CharacterStore.instance.activeCard.id != card.id) {
        await CharacterStore.instance.selectCard(card.id);
      }
      if (!mounted) {
        return;
      }

      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ChatDetailPage()));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_cards.isEmpty && _groups.isEmpty) {
      return const Center(child: Text('还没有会话'));
    }

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
      onRefresh: _loadSummaries,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 84,
          endIndent: 16,
          color: colors.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final summary = _summaries[entry.id];
          final timeLabel = _formatTime(summary?.createdAt);
          final preview =
              summary?.preview ??
              (entry.group != null
                  ? '${entry.group!.memberIds.length} 位成员'
                  : '暂无消息');

          return ListTile(
            contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            leading: entry.card != null
                ? CharacterAvatar(character: entry.card!, size: 52)
                : GroupAvatar(group: entry.group!, size: 52),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (timeLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    timeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: summary == null
                      ? colors.onSurfaceVariant.withValues(alpha: 0.7)
                      : colors.onSurfaceVariant,
                ),
              ),
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
