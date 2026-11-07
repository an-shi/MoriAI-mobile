import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/pages/memory/character_card_edit_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class CharacterChatSettingsPage extends StatelessWidget {
  const CharacterChatSettingsPage({super.key, required this.characterId});

  final String characterId;

  Future<void> _openCardEditor(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CharacterCardEditPage(cardId: characterId),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('角色卡已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('聊天设置')),
      body: ValueListenableBuilder<List<CharacterProfile>>(
        valueListenable: CharacterStore.instance.cards,
        builder: (context, cards, _) {
          CharacterProfile? character;
          for (final card in cards) {
            if (card.id == characterId) {
              character = card;
              break;
            }
          }
          if (character == null) {
            return const Center(child: Text('角色卡不存在或已被删除'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CharacterAvatar(character: character, size: 48),
                  title: Text(
                    character.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(character.type.label),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Icon(Icons.badge_outlined, color: colors.primary),
                  title: const Text('角色卡设置'),
                  subtitle: const Text('修改角色设定、头像、开场白等内容'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openCardEditor(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
