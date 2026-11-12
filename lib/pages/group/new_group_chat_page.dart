import 'package:flutter/material.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class NewGroupChatPage extends StatefulWidget {
  const NewGroupChatPage({super.key});

  @override
  State<NewGroupChatPage> createState() => _NewGroupChatPageState();
}

class _NewGroupChatPageState extends State<NewGroupChatPage> {
  final _nameController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_creating) {
      return;
    }
    if (_selectedIds.length < 2) {
      _showSnackBar('至少选择两个角色');
      return;
    }

    final cards = CharacterStore.instance.cards.value;
    final selectedCards = [
      for (final card in cards)
        if (_selectedIds.contains(card.id)) card,
    ];
    final fallbackName = selectedCards
        .take(3)
        .map((card) => card.displayName)
        .join('、');
    final name = _nameController.text.trim().isEmpty
        ? fallbackName
        : _nameController.text.trim();

    setState(() => _creating = true);
    try {
      final group = await GroupStore.instance.createGroup(
        name: name,
        memberIds: _selectedIds.toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(group);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('创建群聊失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
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
    final cards = CharacterStore.instance.cards.value;
    final canCreate = _selectedIds.length >= 2 && !_creating;

    return Scaffold(
      appBar: AppBar(title: const Text('新建群聊')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const MoriPageIntro(text: '选择参与群聊的角色卡。发送消息后，群成员会依次回复。'),
          MoriSettingsGroup(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            children: [
              TextField(
                controller: _nameController,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '群聊名称',
                  hintText: '留空则使用成员名称',
                  counterText: '',
                ),
              ),
            ],
          ),
          MoriSectionHeader(
            label: '选择成员',
            trailing: Text(
              '已选 ${_selectedIds.length} 人',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (cards.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '至少需要两张角色卡才能创建群聊。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            MoriSettingsGroup(
              dividerIndent: 66,
              children: [
                for (final card in cards)
                  CheckboxListTile(
                    value: _selectedIds.contains(card.id),
                    onChanged: _creating
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedIds.add(card.id);
                              } else {
                                _selectedIds.remove(card.id);
                              }
                            });
                          },
                    secondary: CharacterAvatar(character: card, size: 40),
                    title: Text(card.displayName),
                    subtitle: Text(card.type.label),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.7),
              width: 0.8,
            ),
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: canCreate ? _createGroup : null,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(MoriIcons.groupAdd, size: 18),
            label: Text(
              _selectedIds.length < 2
                  ? '至少选择两个角色'
                  : '创建群聊（${_selectedIds.length} 人）',
            ),
          ),
        ),
      ),
    );
  }
}
