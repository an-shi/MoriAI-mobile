import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/group_memory.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/group_memory_service.dart';
import 'package:mori_ai/services/group_memory_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/group_avatar.dart';

class GroupMemoryPage extends StatefulWidget {
  const GroupMemoryPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupMemoryPage> createState() => _GroupMemoryPageState();
}

class _GroupMemoryPageState extends State<GroupMemoryPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query) {
      return;
    }
    setState(() => _query = next);
  }

  List<GroupMemoryEntry> _filtered(List<GroupMemoryEntry> entries) {
    final query = _query.toLowerCase();
    if (query.isEmpty) {
      return entries;
    }
    return entries
        .where(
          (entry) =>
              entry.text.toLowerCase().contains(query) ||
              entry.tags.any((tag) => tag.toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  Future<void> _extractNow() async {
    if (_extracting) {
      return;
    }
    setState(() => _extracting = true);
    try {
      final count = await GroupMemoryService.instance.extractNow(
        widget.groupId,
      );
      if (mounted) {
        _showSnackBar(count > 0 ? '更新了 $count 项群公共内容' : '没有发现新的群公共记忆');
      }
    } on MemoryException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('整理群公共记忆失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _extracting = false);
      }
    }
  }

  Future<void> _editProfile(GroupMemoryProfile profile) async {
    final result = await showDialog<GroupMemoryProfile>(
      context: context,
      builder: (_) =>
          _GroupProfileEditorDialog(groupId: widget.groupId, profile: profile),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      await GroupMemoryStore.instance.saveProfile(result);
      if (mounted) {
        _showSnackBar('群印象已保存');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('保存群印象失败，请重试');
      }
    }
  }

  Future<void> _addMemory() async {
    final result = await showDialog<_GroupMemoryDraft>(
      context: context,
      builder: (_) => const _GroupMemoryEditorDialog(),
    );
    if (result == null || !mounted) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await GroupMemoryStore.instance.saveEntry(
        GroupMemoryEntry(
          id: 'gmem_manual_${widget.groupId}_${now}_${now % 1000}',
          groupId: widget.groupId,
          text: result.text,
          category: result.category,
          importance: result.importance,
          tags: result.tags,
          source: MemorySource.manual,
          createdAtMs: now,
          updatedAtMs: now,
        ),
      );
      if (mounted) {
        _showSnackBar('群公共记忆已添加');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('添加群公共记忆失败，请重试');
      }
    }
  }

  Future<void> _editMemory(GroupMemoryEntry entry) async {
    final result = await showDialog<_GroupMemoryDraft>(
      context: context,
      builder: (_) => _GroupMemoryEditorDialog(entry: entry),
    );
    if (result == null || !mounted) {
      return;
    }
    try {
      await GroupMemoryStore.instance.saveEntry(
        entry.copyWith(
          text: result.text,
          category: result.category,
          importance: result.importance,
          tags: result.tags,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (mounted) {
        _showSnackBar('群公共记忆已更新');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('更新群公共记忆失败，请重试');
      }
    }
  }

  Future<void> _deleteMemory(GroupMemoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除群公共记忆'),
        content: const Text('确定删除这条群公共记忆吗？删除后无法恢复。'),
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
    await GroupMemoryStore.instance.deleteEntry(entry.id);
    if (mounted) {
      _showSnackBar('群公共记忆已删除');
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空群公共记忆'),
        content: const Text('确定清空这个群的群印象和全部公共记忆吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          MoriDangerButton(
            label: '清空',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await GroupMemoryStore.instance.clearForGroup(widget.groupId);
    if (mounted) {
      _showSnackBar('群公共记忆已清空');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('群公共记忆'),
        actions: [
          IconButton(
            tooltip: '立即整理',
            onPressed: _extracting ? null : _extractNow,
            icon: _extracting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(MoriIcons.autoFix, size: 21),
          ),
          PopupMenuButton<String>(
            tooltip: '群公共记忆操作',
            onSelected: (value) {
              if (value == 'clear') {
                _clearAll();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'clear', child: Text('清空群公共记忆')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMemory,
        icon: const Icon(MoriIcons.plus, size: 20),
        label: const Text('添加共同记忆'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          GroupMemoryStore.instance.revision,
          GroupStore.instance.groups,
        ]),
        builder: (context, _) {
          final group = GroupStore.instance.groupById(widget.groupId);
          if (group == null) {
            return const Center(child: Text('群聊不存在或已被删除'));
          }
          final profile = GroupMemoryStore.instance.profileFor(group.id);
          final entries = _filtered(
            GroupMemoryStore.instance.entriesFor(group.id),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _GroupHeader(group: group),
              const SizedBox(height: 14),
              _buildProfileCard(group, profile, theme, colors),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索群公共记忆',
                  prefixIcon: const Icon(MoriIcons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          onPressed: _searchController.clear,
                          icon: const Icon(MoriIcons.close, size: 18),
                        ),
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MoriRadius.medium),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                _EmptyGroupMemory(hasQuery: _query.isNotEmpty)
              else
                for (final entry in entries)
                  _GroupMemoryCard(
                    entry: entry,
                    onEdit: () => _editMemory(entry),
                    onDelete: () => _deleteMemory(entry),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(
    GroupProfile group,
    GroupMemoryProfile profile,
    ThemeData theme,
    ColorScheme colors,
  ) {
    return MoriSettingsGroup(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '群印象',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '编辑群印象',
                  onPressed: () => _editProfile(profile),
                  icon: const Icon(MoriIcons.edit, size: 18),
                ),
              ],
            ),
            if (profile.isEmpty)
              Text(
                '还没有群印象。群聊闲置后会自动整理，也可以手动填写。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else ...[
              if (profile.summary.isNotEmpty)
                _ProfileLine(label: '群氛围', value: profile.summary),
              if (profile.sharedHabits.isNotEmpty)
                _ProfileLine(label: '共同话题', value: profile.sharedHabits),
              if (profile.recentFocus.isNotEmpty)
                _ProfileLine(label: '最近在聊', value: profile.recentFocus),
              if (profile.importantDates.isNotEmpty)
                _ProfileLine(
                  label: '重要日期',
                  value: profile.importantDates.join('、'),
                ),
            ],
            const SizedBox(height: 4),
            Text(
              '群公共记忆只在这个群召回，不会进入单聊或其他群。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final GroupProfile group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        GroupAvatar(group: group, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${group.memberIds.length} 位成员',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

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

class _GroupMemoryCard extends StatelessWidget {
  const _GroupMemoryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final GroupMemoryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 12, 0, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.75),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Tag(
                      label: entry.categoryLabel,
                      color: colors.primaryContainer,
                      textColor: colors.onPrimaryContainer,
                    ),
                    _Tag(
                      label: entry.sourceLabel,
                      color: colors.surfaceContainerHighest,
                      textColor: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in entry.tags)
                        _Tag(
                          label: tag,
                          color: colors.secondaryContainer,
                          textColor: colors.onSecondaryContainer,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${_timeLabel(entry.updatedAtMs)} · '
                  '重要性 ${entry.importance.toStringAsFixed(1)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '群记忆操作',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
              PopupMenuItem<String>(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: textColor),
      ),
    );
  }
}

class _EmptyGroupMemory extends StatelessWidget {
  const _EmptyGroupMemory({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return MoriEmptyState(
      icon: hasQuery ? MoriIcons.searchOff : MoriIcons.groupRound,
      title: hasQuery ? '没有找到相关群公共记忆' : '还没有群公共记忆',
      message: hasQuery ? '换一个关键词试试。' : '群聊闲置后会自动整理大家共同经历和群印象。',
      compact: true,
    );
  }
}

class _GroupMemoryDraft {
  const _GroupMemoryDraft({
    required this.text,
    required this.category,
    required this.importance,
    required this.tags,
  });

  final String text;
  final MemoryCategory category;
  final double importance;
  final List<String> tags;
}

class _GroupMemoryEditorDialog extends StatefulWidget {
  const _GroupMemoryEditorDialog({this.entry});

  final GroupMemoryEntry? entry;

  @override
  State<_GroupMemoryEditorDialog> createState() =>
      _GroupMemoryEditorDialogState();
}

class _GroupMemoryEditorDialogState extends State<_GroupMemoryEditorDialog> {
  late final TextEditingController _textController;
  late final TextEditingController _tagsController;
  late MemoryCategory _category;
  late double _importance;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _textController = TextEditingController(text: entry?.text ?? '');
    _tagsController = TextEditingController(text: entry?.tags.join('、') ?? '');
    _category = entry?.category ?? MemoryCategory.event;
    _importance = entry?.importance ?? 0.6;
    _textController.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_handleChanged);
    _textController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _handleChanged() => setState(() {});

  String _importanceLabel(double value) {
    return switch (value) {
      0.3 => '低',
      0.5 => '普通',
      0.7 => '重要',
      0.9 => '很重要',
      _ => value.toStringAsFixed(1),
    };
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _GroupMemoryDraft(
        text: text,
        category: _category,
        importance: _importance,
        tags: _tagsController.text
            .split(RegExp(r'[,，、\s]+'))
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? '添加群公共记忆' : '编辑群公共记忆'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _textController,
                minLines: 2,
                maxLines: 5,
                maxLength: GroupMemoryEntry.maxTextLength,
                decoration: const InputDecoration(
                  labelText: '共同记忆',
                  hintText: '例如：大家约好下个月一起去看展',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MemoryCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: '类型'),
                items: [
                  for (final category in MemoryCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                initialValue: _importance,
                decoration: const InputDecoration(labelText: '重要性'),
                items: [
                  for (final value in ({
                    0.3,
                    0.5,
                    0.7,
                    0.9,
                    _importance,
                  }.toList()..sort()))
                    DropdownMenuItem(
                      value: value,
                      child: Text(_importanceLabel(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _importance = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: '标签（可选）',
                  hintText: '用逗号或顿号分隔',
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
        FilledButton(
          onPressed: _textController.text.trim().isEmpty ? null : _submit,
          child: Text(widget.entry == null ? '添加' : '保存'),
        ),
      ],
    );
  }
}

class _GroupProfileEditorDialog extends StatefulWidget {
  const _GroupProfileEditorDialog({
    required this.groupId,
    required this.profile,
  });

  final String groupId;
  final GroupMemoryProfile profile;

  @override
  State<_GroupProfileEditorDialog> createState() =>
      _GroupProfileEditorDialogState();
}

class _GroupProfileEditorDialogState extends State<_GroupProfileEditorDialog> {
  late final TextEditingController _summaryController;
  late final TextEditingController _habitsController;
  late final TextEditingController _recentController;
  late final TextEditingController _datesController;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _summaryController = TextEditingController(text: profile.summary);
    _habitsController = TextEditingController(text: profile.sharedHabits);
    _recentController = TextEditingController(text: profile.recentFocus);
    _datesController = TextEditingController(
      text: profile.importantDates.join('\n'),
    );
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _habitsController.dispose();
    _recentController.dispose();
    _datesController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      GroupMemoryProfile(
        groupId: widget.groupId,
        summary: _summaryController.text,
        sharedHabits: _habitsController.text,
        recentFocus: _recentController.text,
        importantDates: _datesController.text
            .split(RegExp(r'[\n,，、]'))
            .map((date) => date.trim())
            .where((date) => date.isNotEmpty)
            .toList(growable: false),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑群印象'),
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
                maxLength: GroupMemoryProfile.maxFieldLength,
                decoration: const InputDecoration(
                  labelText: '群氛围',
                  hintText: '这个群是什么样、成员之间是什么氛围和关系',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _habitsController,
                minLines: 2,
                maxLines: 4,
                maxLength: GroupMemoryProfile.maxFieldLength,
                decoration: const InputDecoration(
                  labelText: '共同话题',
                  hintText: '群里反复出现的共同话题、梗和相处习惯',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _recentController,
                minLines: 2,
                maxLines: 4,
                maxLength: GroupMemoryProfile.maxFieldLength,
                decoration: const InputDecoration(
                  labelText: '最近在聊',
                  hintText: '群里最近在忙的事、共同计划或近况',
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
                  hintText: '一行一个',
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
