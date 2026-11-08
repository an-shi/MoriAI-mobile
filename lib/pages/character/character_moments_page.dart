import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/pages/moments_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class CharacterMomentsPage extends StatelessWidget {
  const CharacterMomentsPage({super.key, required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<List<CharacterProfile>>(
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
          return Scaffold(
            appBar: AppBar(title: const Text('动态')),
            body: const Center(child: Text('角色卡不存在或已被删除')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CharacterAvatar(character: character, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        character.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '动态',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: MomentsPage(
            authorId: character.id,
            showComposer: false,
            showCharacterAction: false,
            headerLabel: '最新动态',
          ),
        );
      },
    );
  }
}
