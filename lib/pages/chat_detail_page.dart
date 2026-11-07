import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/pages/character/character_chat_settings_page.dart';
import 'package:mori_ai/pages/chat_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class ChatDetailPage extends StatelessWidget {
  const ChatDetailPage({super.key});

  void _openSettings(BuildContext context) {
    final characterId = CharacterStore.instance.activeCard.id;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CharacterChatSettingsPage(characterId: characterId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ValueListenableBuilder<CharacterProfile>(
          valueListenable: CharacterStore.instance.profile,
          builder: (context, character, _) {
            return Row(
              children: [
                CharacterAvatar(character: character, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    character.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () => _openSettings(context),
            tooltip: '聊天设置',
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: const ChatPage(),
    );
  }
}
