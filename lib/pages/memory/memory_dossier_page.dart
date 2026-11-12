import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class MemoryDossierPage extends StatelessWidget {
  const MemoryDossierPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('人物档案')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          MemoryStore.instance.revision,
          CharacterStore.instance.cards,
        ]),
        builder: (context, _) {
          final cards = CharacterStore.instance.cards.value;
          if (cards.isEmpty) {
            return Center(
              child: Text(
                '还没有角色卡。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                '人物档案记录对方的稳定信息和最近状态；未完成话题会在后续聊天里被自然追问。'
                '档案和话题只在本机保存，只注入单聊和主动消息，群聊不会读取。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final card in cards) _CharacterDossierCard(character: card),
            ],
          );
        },
      ),
    );
  }
}

class _CharacterDossierCard extends StatelessWidget {
  const _CharacterDossierCard({required this.character});

  final CharacterProfile character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = MemoryStore.instance.profileFor(character.id);
    final topics = MemoryStore.instance.openTopicsFor(
      character.id,
      includeResolved: true,
    );

    return Card(
      elevation: 0,
      color: theme.brightness == Brightness.light
          ? colors.surfaceContainerLowest
          : colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.6),
          width: 0.7,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CharacterAvatar(character: character, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    character.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '编辑人物档案',
                  onPressed: () => _editProfile(context, profile),
                  icon: const Icon(MoriIcons.edit),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (profile.isEmpty)
              Text(
                '还没有人物档案。角色整理记忆时会自动生成，也可以手动填写。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else ...[
              if (profile.summary.isNotEmpty)
                _DossierLine(label: '对方是谁', value: profile.summary),
              if (profile.preferences.isNotEmpty)
                _DossierLine(label: '稳定喜好', value: profile.preferences),
              if (profile.recentFocus.isNotEmpty)
                _DossierLine(label: '最近状态', value: profile.recentFocus),
              if (profile.importantDates.isNotEmpty)
                _DossierLine(
                  label: '重要日期',
                  value: profile.importantDates.join('、'),
                ),
              if (profile.updatedAtMs > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '更新于 ${_timeLabel(profile.updatedAtMs)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '未完成话题',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addTopic(context),
                  icon: const Icon(MoriIcons.plus, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
            if (topics.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '还没有待跟进的事。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final topic in topics)
                _TopicRow(
                  topic: topic,
                  onEdit: () => _editTopic(context, topic),
                  onResolve: () => _resolveTopic(context, topic),
                  onDelete: () => _deleteTopic(context, topic),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, MemoryProfile profile) async {
    final result = await showDialog<MemoryProfile>(
      context: context,
      builder: (_) =>
          _ProfileEditorDialog(character: character, profile: profile),
    );
    if (result == null || !context.mounted) {
      return;
    }
    try {
      await MemoryStore.instance.saveProfile(result);
      if (context.mounted) {
        _showSnackBar(context, '人物档案已保存');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnackBar(context, '保存人物档案失败，请重试');
      }
    }
  }

  Future<void> _addTopic(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _TopicEditorDialog(),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await MemoryStore.instance.saveOpenTopic(
        MemoryOpenTopic(
          id: 'topic_manual_${character.id}_${now}_${now % 1000}',
          characterId: character.id,
          text: text,
          importance: 0.7,
          createdAtMs: now,
          updatedAtMs: now,
        ),
      );
      if (context.mounted) {
        _showSnackBar(context, '待跟进话题已添加');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnackBar(context, '添加待跟进话题失败，请重试');
      }
    }
  }

  Future<void> _editTopic(BuildContext context, MemoryOpenTopic topic) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TopicEditorDialog(topic: topic),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) {
      return;
    }
    try {
      await MemoryStore.instance.saveOpenTopic(
        topic.copyWith(
          text: text,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (context.mounted) {
        _showSnackBar(context, '待跟进话题已更新');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnackBar(context, '更新待跟进话题失败，请重试');
      }
    }
  }

  Future<void> _resolveTopic(
    BuildContext context,
    MemoryOpenTopic topic,
  ) async {
    try {
      await MemoryStore.instance.resolveOpenTopic(topic.id);
      if (context.mounted) {
        _showSnackBar(context, '已标记为解决');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnackBar(context, '更新话题状态失败，请重试');
      }
    }
  }

  Future<void> _deleteTopic(BuildContext context, MemoryOpenTopic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除待跟进话题'),
        content: const Text('确定删除这条话题吗？删除后无法恢复。'),
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
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await MemoryStore.instance.deleteOpenTopic(topic.id);
      if (context.mounted) {
        _showSnackBar(context, '待跟进话题已删除');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnackBar(context, '删除待跟进话题失败，请重试');
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DossierLine extends StatelessWidget {
  const _DossierLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.onEdit,
    required this.onResolve,
    required this.onDelete,
  });

  final MemoryOpenTopic topic;
  final VoidCallback onEdit;
  final VoidCallback onResolve;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final resolved = !topic.isOpen;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
      decoration: BoxDecoration(
        color: resolved
            ? colors.surfaceContainerHighest.withValues(alpha: 0.45)
            : colors.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            resolved ? MoriIcons.checkCircleOutline : MoriIcons.circle,
            size: 18,
            color: resolved ? colors.onSurfaceVariant : colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: resolved ? colors.onSurfaceVariant : null,
                    decoration: resolved ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${topic.statusLabel} · ${_timeLabel(topic.updatedAtMs)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '话题操作',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'resolve') {
                onResolve();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
              if (!resolved)
                const PopupMenuItem<String>(
                  value: 'resolve',
                  child: Text('标记为已解决'),
                ),
              const PopupMenuItem<String>(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileEditorDialog extends StatefulWidget {
  const _ProfileEditorDialog({required this.character, required this.profile});

  final CharacterProfile character;
  final MemoryProfile profile;

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController _summaryController;
  late final TextEditingController _preferencesController;
  late final TextEditingController _recentFocusController;
  late final TextEditingController _datesController;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _summaryController = TextEditingController(text: profile.summary);
    _preferencesController = TextEditingController(text: profile.preferences);
    _recentFocusController = TextEditingController(text: profile.recentFocus);
    _datesController = TextEditingController(
      text: profile.importantDates.join('\n'),
    );
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _preferencesController.dispose();
    _recentFocusController.dispose();
    _datesController.dispose();
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dates = _datesController.text
        .split(RegExp(r'[\n,，、]'))
        .map((date) => date.trim())
        .where((date) => date.isNotEmpty)
        .toList(growable: false);
    Navigator.of(context).pop(
      MemoryProfile(
        characterId: widget.character.id,
        summary: _summaryController.text,
        preferences: _preferencesController.text,
        recentFocus: _recentFocusController.text,
        importantDates: dates,
        updatedAtMs: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.character.displayName}的人物档案'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _summaryController,
                minLines: 2,
                maxLines: 4,
                maxLength: MemoryProfile.maxFieldLength,
                decoration: const InputDecoration(
                  labelText: '对方是谁',
                  hintText: '身份、称呼、和角色的关系',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _preferencesController,
                minLines: 2,
                maxLines: 4,
                maxLength: MemoryProfile.maxFieldLength,
                decoration: const InputDecoration(
                  labelText: '稳定喜好',
                  hintText: '长期喜欢、不喜欢和习惯',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _recentFocusController,
                minLines: 2,
                maxLines: 4,
                maxLength: MemoryProfile.maxFieldLength,
                decoration: const InputDecoration(
                  labelText: '最近状态',
                  hintText: '最近在忙什么、重要计划或近况',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _datesController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '重要日期（可选）',
                  hintText: '一行一个，例如：12 月 24 日约好一起看电影',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _TopicEditorDialog extends StatefulWidget {
  const _TopicEditorDialog({this.topic});

  final MemoryOpenTopic? topic;

  @override
  State<_TopicEditorDialog> createState() => _TopicEditorDialogState();
}

class _TopicEditorDialogState extends State<_TopicEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.topic?.text ?? '');
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.topic == null ? '添加待跟进话题' : '编辑待跟进话题'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          maxLength: MemoryOpenTopic.maxTextLength,
          decoration: const InputDecoration(
            labelText: '话题内容',
            hintText: '例如：用户说下周要去看牙医，还没告诉我结果',
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.topic == null ? '添加' : '保存'),
        ),
      ],
    );
  }
}

String _timeLabel(int timestampMs) {
  final time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final days = today.difference(day).inDays;
  if (days <= 0) {
    return '今天';
  }
  if (days == 1) {
    return '昨天';
  }
  if (days < 7) {
    return '$days 天前';
  }
  final month = time.month.toString().padLeft(2, '0');
  final date = time.day.toString().padLeft(2, '0');
  if (time.year == now.year) {
    return '$month-$date';
  }
  return '${time.year}-$month-$date';
}
