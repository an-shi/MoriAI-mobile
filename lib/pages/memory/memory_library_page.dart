import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/pages/memory/memory_settings_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/memory_service.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/utils/memory_search.dart';
import 'package:mori_ai/widgets/avatar_fallback.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class MemoryLibraryPage extends StatefulWidget {
  const MemoryLibraryPage({super.key});

  @override
  State<MemoryLibraryPage> createState() => _MemoryLibraryPageState();
}

class _MemoryLibraryPageState extends State<MemoryLibraryPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _characterFilter;
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

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MemorySettingsPage()));
  }

  Future<void> _addMemory() async {
    final result = await showDialog<_MemoryEditorResult>(
      context: context,
      builder: (_) =>
          _MemoryEditorDialog(preferredCharacterId: _characterFilter),
    );
    if (result == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = MemoryEntry(
      id: 'mem_manual_${result.characterId}_${now}_${now % 1000}',
      characterId: result.characterId,
      text: result.text,
      category: result.category,
      importance: result.importance,
      tags: result.tags,
      source: MemorySource.manual,
      conversationId: result.characterId,
      createdAtMs: now,
      updatedAtMs: now,
    ).normalized();
    await MemoryStore.instance.saveEntry(entry);
    if (mounted) {
      _showSnackBar('记忆已添加');
    }
  }

  Future<void> _editMemory(MemoryEntry entry) async {
    final result = await showDialog<_MemoryEditorResult>(
      context: context,
      builder: (_) => _MemoryEditorDialog(entry: entry),
    );
    if (result == null) {
      return;
    }
    await MemoryStore.instance.saveEntry(
      entry.copyWith(
        text: result.text,
        category: result.category,
        importance: result.importance,
        tags: result.tags,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (mounted) {
      _showSnackBar('记忆已更新');
    }
  }

  Future<void> _deleteMemory(MemoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记忆'),
        content: const Text('确定删除这条记忆吗？删除后无法恢复。'),
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
    await MemoryStore.instance.deleteEntry(entry.id);
    if (mounted) {
      _showSnackBar('记忆已删除');
    }
  }

  Future<void> _extractNow() async {
    if (_extracting) {
      return;
    }
    final character = await _pickCharacter(title: '整理谁的记忆？');
    if (character == null || !mounted) {
      return;
    }
    setState(() => _extracting = true);
    try {
      final count = await MemoryService.instance.extractNow(character.id);
      if (mounted) {
        _showSnackBar(count > 0 ? '更新了 $count 项长期内容' : '没有发现新的长期记忆');
      }
    } on MemoryException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('整理记忆失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _extracting = false);
      }
    }
  }

  Future<CharacterProfile?> _pickCharacter({required String title}) async {
    final cards = CharacterStore.instance.cards.value;
    if (cards.isEmpty) {
      _showSnackBar('还没有可用的角色卡');
      return null;
    }
    if (cards.length == 1) {
      return cards.first;
    }
    return showModalBottomSheet<CharacterProfile>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(title)),
            for (final card in cards)
              ListTile(
                leading: CharacterAvatar(character: card, size: 40),
                title: Text(card.displayName),
                onTap: () => Navigator.of(sheetContext).pop(card),
              ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<MemoryEntry> _filteredEntries(List<MemoryEntry> entries) {
    final filtered = entries
        .where(
          (entry) =>
              _characterFilter == null || entry.characterId == _characterFilter,
        )
        .toList(growable: false);
    if (_query.isEmpty) {
      return filtered;
    }
    final hits = searchMemories(
      filtered,
      _query,
      limit: filtered.length,
      minScore: 0.01,
      fallbackToImportant: false,
    );
    return [for (final hit in hits) hit.entry];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆'),
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
          IconButton(
            tooltip: '记忆设置',
            onPressed: _openSettings,
            icon: const Icon(MoriIcons.settings, size: 21),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMemory,
        icon: const Icon(MoriIcons.plus, size: 20),
        label: const Text('添加记忆'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          MemoryStore.instance.revision,
          CharacterStore.instance.cards,
        ]),
        builder: (context, _) {
          final cards = CharacterStore.instance.cards.value;
          final entries = _filteredEntries(MemoryStore.instance.allEntries());
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索记忆',
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
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ChoiceChip(
                      label: const Text('全部'),
                      selected: _characterFilter == null,
                      onSelected: (_) => setState(() {
                        _characterFilter = null;
                      }),
                    ),
                    for (final card in cards) ...[
                      const SizedBox(width: 7),
                      ChoiceChip(
                        label: Text(card.displayName),
                        selected: _characterFilter == card.id,
                        onSelected: (_) => setState(() {
                          _characterFilter = card.id;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyMemoryState(
                        hasQuery: _query.isNotEmpty,
                        onAdd: _addMemory,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _MemoryCard(
                            entry: entry,
                            onEdit: () => _editMemory(entry),
                            onDelete: () => _deleteMemory(entry),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final MemoryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final character = CharacterStore.instance.cardById(entry.characterId);
    final avatar = character == null
        ? const AvatarFallback(label: '已删除的角色', size: 40, icon: MoriIcons.user)
        : CharacterAvatar(character: character, size: 40);
    final name = character?.displayName ?? '已删除的角色';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.75),
            width: 0.8,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(2, 12, 0, 14),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _MemoryTag(
                          label: entry.categoryLabel,
                          color: colors.primaryContainer,
                          textColor: colors.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        _MemoryTag(
                          label: entry.sourceLabel,
                          color: colors.surfaceContainerHighest,
                          textColor: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.text,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in entry.tags)
                            _MemoryTag(
                              label: tag,
                              color: colors.secondaryContainer,
                              textColor: colors.onSecondaryContainer,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${_timeLabel(entry.updatedAt)} · '
                      '重要性 ${entry.importance.toStringAsFixed(1)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '记忆操作',
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
        ],
      ),
    );
  }

  String _timeLabel(DateTime time) {
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
}

class _MemoryTag extends StatelessWidget {
  const _MemoryTag({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return MoriTag(label: label, background: color, foreground: textColor);
  }
}

class _EmptyMemoryState extends StatelessWidget {
  const _EmptyMemoryState({required this.hasQuery, required this.onAdd});

  final bool hasQuery;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return MoriEmptyState(
      icon: hasQuery ? MoriIcons.searchOff : MoriIcons.brain,
      title: hasQuery ? '没有找到相关记忆' : '还没有记忆',
      message: hasQuery ? '换一个关键词试试。' : '角色会在聊天闲置后自动整理值得长期记住的事，也可以手动添加。',
      compact: true,
      actions: [
        if (!hasQuery)
          MoriActionButton(
            label: '添加记忆',
            icon: MoriIcons.plus,
            onPressed: onAdd,
          ),
      ],
    );
  }
}

class _MemoryEditorResult {
  const _MemoryEditorResult({
    required this.characterId,
    required this.text,
    required this.category,
    required this.importance,
    required this.tags,
  });

  final String characterId;
  final String text;
  final MemoryCategory category;
  final double importance;
  final List<String> tags;
}

class _MemoryEditorDialog extends StatefulWidget {
  const _MemoryEditorDialog({this.entry, this.preferredCharacterId});

  final MemoryEntry? entry;
  final String? preferredCharacterId;

  @override
  State<_MemoryEditorDialog> createState() => _MemoryEditorDialogState();
}

class _MemoryEditorDialogState extends State<_MemoryEditorDialog> {
  late final TextEditingController _textController;
  late final TextEditingController _tagsController;
  late String _characterId;
  late MemoryCategory _category;
  late double _importance;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final cards = CharacterStore.instance.cards.value;
    _characterId =
        entry?.characterId ??
        widget.preferredCharacterId ??
        (cards.isEmpty ? '' : cards.first.id);
    _textController = TextEditingController(text: entry?.text ?? '');
    _tagsController = TextEditingController(text: entry?.tags.join('、') ?? '');
    _category = entry?.category ?? MemoryCategory.fact;
    _importance = entry?.importance ?? 0.5;
    _textController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty || _characterId.isEmpty) {
      return;
    }
    final tags = _tagsController.text
        .split(RegExp(r'[,，、\s]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    Navigator.of(context).pop(
      _MemoryEditorResult(
        characterId: _characterId,
        text: text,
        category: _category,
        importance: _importance,
        tags: tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = CharacterStore.instance.cards.value;
    return AlertDialog(
      title: Text(_isEditing ? '编辑记忆' : '添加记忆'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isEditing)
                DropdownButtonFormField<String>(
                  initialValue: _characterId.isEmpty ? null : _characterId,
                  decoration: const InputDecoration(labelText: '角色'),
                  items: [
                    for (final card in cards)
                      DropdownMenuItem(
                        value: card.id,
                        child: Text(card.displayName),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _characterId = value);
                    }
                  },
                ),
              if (!_isEditing) const SizedBox(height: 12),
              TextField(
                controller: _textController,
                minLines: 2,
                maxLines: 5,
                maxLength: MemoryEntry.maxTextLength,
                decoration: const InputDecoration(
                  labelText: '记忆内容',
                  hintText: '例如：对方喜欢在晚上喝热牛奶',
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
                items: const [
                  DropdownMenuItem(value: 0.3, child: Text('低')),
                  DropdownMenuItem(value: 0.5, child: Text('普通')),
                  DropdownMenuItem(value: 0.7, child: Text('重要')),
                  DropdownMenuItem(value: 0.9, child: Text('很重要')),
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
          onPressed: _textController.text.trim().isEmpty || _characterId.isEmpty
              ? null
              : _submit,
          child: Text(_isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }
}
