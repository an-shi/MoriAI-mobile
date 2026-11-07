import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/pages/memory/character_card_edit_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class CharacterCardSettingsPage extends StatefulWidget {
  const CharacterCardSettingsPage({super.key});

  @override
  State<CharacterCardSettingsPage> createState() =>
      _CharacterCardSettingsPageState();
}

class _CharacterCardSettingsPageState extends State<CharacterCardSettingsPage> {
  bool _busy = false;

  Future<void> _openEditor(CharacterProfile card) async {
    if (_busy) {
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CharacterCardEditPage(cardId: card.id),
      ),
    );
    if (saved == true && mounted) {
      _showSnackBar('角色卡已保存');
    }
  }

  Future<void> _addCard() async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    CharacterProfile? card;
    try {
      card = await CharacterStore.instance.addCard();
    } catch (_) {
      if (mounted) {
        _showSnackBar('新建角色卡失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }

    if (card != null && mounted) {
      await _openEditor(card);
    }
  }

  Future<void> _selectCard(CharacterProfile card) async {
    if (_busy || card.id == CharacterStore.instance.activeCard.id) {
      return;
    }

    setState(() => _busy = true);
    try {
      await CharacterStore.instance.selectCard(card.id);
      if (!mounted) {
        return;
      }
      _showSnackBar('已切换到「${card.displayName}」');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('切换角色卡失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteCard(CharacterProfile card) async {
    if (_busy) {
      return;
    }
    if (!CharacterStore.instance.canDeleteCards) {
      _showSnackBar('至少保留一张角色卡');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除角色卡'),
          content: Text('确定删除「${card.displayName}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
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

    setState(() => _busy = true);
    try {
      await CharacterStore.instance.deleteCard(card.id);
      if (!mounted) {
        return;
      }
      _showSnackBar('角色卡已删除');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('删除角色卡失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
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

    return Scaffold(
      appBar: AppBar(title: const Text('角色卡')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          CharacterStore.instance.cards,
          CharacterStore.instance.activeCardId,
        ]),
        builder: (context, _) {
          final cards = CharacterStore.instance.cards.value;
          final activeId = CharacterStore.instance.activeCard.id;
          final canDelete = CharacterStore.instance.canDeleteCards;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                '点击角色卡进入编辑；点击右侧圆圈切换当前对话使用的角色。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: colors.outlineVariant,
                        ),
                      _CharacterCardTile(
                        card: cards[index],
                        selected: cards[index].id == activeId,
                        canDelete: canDelete && !_busy,
                        onEdit: () => _openEditor(cards[index]),
                        onSelect: () => _selectCard(cards[index]),
                        onDelete: () => _deleteCard(cards[index]),
                      ),
                    ],
                    Divider(height: 1, color: colors.outlineVariant),
                    ListTile(
                      enabled: !_busy,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Icon(
                        Icons.add_circle_outline,
                        color: colors.primary,
                      ),
                      title: const Text('新建角色卡'),
                      subtitle: const Text('创建后会进入编辑页面'),
                      onTap: _addCard,
                    ),
                  ],
                ),
              ),
              if (!canDelete) ...[
                const SizedBox(height: 8),
                Text(
                  '至少保留一张角色卡。新建其他角色卡后才可以删除当前角色卡。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CharacterCardTile extends StatelessWidget {
  const _CharacterCardTile({
    required this.card,
    required this.selected,
    required this.canDelete,
    required this.onEdit,
    required this.onSelect,
    required this.onDelete,
  });

  final CharacterProfile card;
  final bool selected;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: CharacterAvatar(character: card, size: 44),
      title: Row(
        children: [
          Flexible(
            child: Text(card.displayName, overflow: TextOverflow.ellipsis),
          ),
          if (card.isPreset) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '预设',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${card.type.label} · ${card.summaryText}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: selected ? null : onSelect,
            tooltip: selected ? '当前使用中' : '使用这张角色卡',
            style: IconButton.styleFrom(
              disabledForegroundColor: colors.primary,
            ),
            icon: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
          IconButton(
            onPressed: canDelete ? onDelete : null,
            tooltip: canDelete ? '删除角色卡' : '至少保留一张角色卡',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      selected: selected,
      onTap: onEdit,
    );
  }
}
