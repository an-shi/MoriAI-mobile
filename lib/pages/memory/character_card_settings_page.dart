import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/pages/memory/character_card_edit_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
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

    final cardId = CharacterStore.instance.createCardId();
    final initialName = CharacterStore.instance.nextCardName();

    setState(() => _busy = true);
    bool? saved;
    try {
      saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => CharacterCardEditPage(
            cardId: cardId,
            isNew: true,
            initialName: initialName,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }

    if (saved == true && mounted) {
      _showSnackBar('角色卡已创建');
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
          content: Text('确定删除「${card.displayName}」吗？该角色的聊天记录、动态和相关评论也会一起删除。'),
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
        animation: CharacterStore.instance.cards,
        builder: (context, _) {
          final cards = CharacterStore.instance.cards.value;
          final canDelete = CharacterStore.instance.canDeleteCards;

          return ListView(
            padding: MoriTheme.pagePadding,
            children: [
              const MoriPageIntro(text: '点击角色卡进入编辑。角色卡决定角色的称呼、性格和开场白。'),
              MoriSettingsGroup(
                dividerIndent: 66,
                children: [
                  for (final card in cards)
                    _CharacterCardTile(
                      card: card,
                      canDelete: canDelete && !_busy,
                      onEdit: () => _openEditor(card),
                      onDelete: () => _deleteCard(card),
                    ),
                  MoriSettingsTile(
                    icon: MoriIcons.plus,
                    title: '新建角色卡',
                    subtitle: '保存后才会添加到角色卡列表',
                    enabled: !_busy,
                    onTap: _addCard,
                  ),
                ],
              ),
              if (!canDelete) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '至少保留一张角色卡。新建其他角色卡后才可以删除当前角色卡。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
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
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final CharacterProfile card;
  final bool canDelete;
  final VoidCallback onEdit;
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
      trailing: IconButton(
        onPressed: canDelete ? onDelete : null,
        tooltip: canDelete ? '删除角色卡' : '至少保留一张角色卡',
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
      ),
      onTap: onEdit,
    );
  }
}
