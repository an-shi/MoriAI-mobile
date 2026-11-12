import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/pages/character/character_chat_settings_page.dart';
import 'package:mori_ai/pages/chat_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class ChatDetailPage extends StatelessWidget {
  const ChatDetailPage({super.key, required this.characterId});

  final String characterId;

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CharacterChatSettingsPage(characterId: characterId),
      ),
    );
  }

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
            appBar: AppBar(title: const Text('聊天')),
            body: const MoriEmptyState(
              icon: MoriIcons.user,
              title: '角色卡不存在',
              message: '这张角色卡可能已被删除。',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 2,
            title: Row(
              children: [
                CharacterAvatar(character: character, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.5,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        character.type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => _openSettings(context),
                tooltip: '聊天设置',
                icon: const Icon(MoriIcons.more),
              ),
            ],
          ),
          body: ChatPage(characterId: characterId),
        );
      },
    );
  }
}
