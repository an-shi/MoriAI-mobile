import 'package:flutter/material.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/pages/settings/diary_settings_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/widgets/avatar_fallback.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  Future<void> _deleteEntry(BuildContext context, DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除日记'),
          content: const Text('确定删除这篇日记吗？删除后无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            MoriDangerButton(
              label: '删除',
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await DiaryStore.instance.deleteEntry(entry.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('日记已删除')));
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DiarySettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日记'),
        actions: [
          IconButton(
            tooltip: '日记设置',
            onPressed: () => _openSettings(context),
            icon: const Icon(MoriIcons.settings, size: 21),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          DiaryStore.instance.revision,
          DiaryStore.instance.settings,
          CharacterStore.instance.cards,
        ]),
        builder: (context, _) {
          final entries = DiaryStore.instance.allEntries();
          if (entries.isEmpty) {
            final settings = DiaryStore.instance.settings.value;
            final anyEnabled = CharacterStore.instance.cards.value.any(
              (card) => settings.isEnabledFor(card.id),
            );
            final emptyHint = anyEnabled
                ? '日记已开启，角色会按各自的写作时间自动写；也可以现在去设置里手动写一篇。'
                : '在「设置 > 日记」开启每日自动写作后，角色会在每天晚上写下当天值得记住的事。';
            return MoriEmptyState(
              icon: MoriIcons.diary,
              title: '还没有日记',
              message: emptyHint,
              actions: [
                MoriActionButton(
                  label: '去设置',
                  icon: MoriIcons.settings,
                  onPressed: () => _openSettings(context),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _DiaryCard(
                entry: entry,
                onDelete: () => _deleteEntry(context, entry),
              );
            },
          );
        },
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.entry, required this.onDelete});

  final DiaryEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final character = CharacterStore.instance.cardById(entry.characterId);
    final avatar = character == null
        ? const AvatarFallback(label: '已删除的角色', size: 42, icon: MoriIcons.user)
        : CharacterAvatar(character: character, size: 42);
    final name = character?.displayName ?? '已删除的角色';
    final dateLabel = _dateLabel(entry.dateKey);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 8, 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.75),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.moodLabel.isEmpty
                          ? dateLabel
                          : '$dateLabel · 心情 ${entry.moodLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '日记操作',
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(value: 'delete', child: Text('删除日记')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              entry.content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(String dateKey) {
    final date = diaryDateFromKey(dateKey);
    if (date == null) {
      return dateKey;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final prefix = date == today
        ? '今天'
        : date == yesterday
        ? '昨天'
        : '';
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final year = date.year == now.year ? '' : '${date.year}年';
    final base =
        '$year${date.month}月${date.day}日 星期${weekdays[date.weekday - 1]}';
    return prefix.isEmpty ? base : '$prefix · $base';
  }
}
