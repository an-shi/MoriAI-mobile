import 'package:flutter/material.dart';
import 'package:mori_ai/models/moribot/mori_models.dart';
import 'package:mori_ai/pages/moribot/chat_page.dart';
import 'package:mori_ai/services/moribot/mori_chat_repository.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/moribot/mori_character_avatar.dart';

class MoriCharacterListPage extends StatefulWidget {
  const MoriCharacterListPage({super.key});

  @override
  State<MoriCharacterListPage> createState() => _MoriCharacterListPageState();
}

class _MoriCharacterListPageState extends State<MoriCharacterListPage> {
  final _opening = <int>{};

  Future<void> _refresh() async {
    await MoriChatRepository.instance.refreshCharacters(showLoading: false);
  }

  MoriConversation? _latestConversationFor(int characterId) {
    for (final conversation
        in MoriChatRepository.instance.conversations.value) {
      if (conversation.characterId == characterId) {
        return conversation;
      }
    }
    return null;
  }

  Future<void> _openCharacter(
    MoriCharacter character, {
    bool forceNew = false,
  }) async {
    if (!character.chatAvailable) {
      _showMessage('${character.displayName} 暂时没有可用的对话模型');
      return;
    }
    if (!_opening.add(character.id)) {
      return;
    }
    setState(() {});

    try {
      var conversation = forceNew ? null : _latestConversationFor(character.id);
      conversation ??= await MoriChatRepository.instance.createConversation(
        character.id,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MoriChatPage(conversation: conversation!),
        ),
      );
      if (mounted) {
        await MoriChatRepository.instance.refreshConversations(
          showLoading: false,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage('$error');
      }
    } finally {
      _opening.remove(character.id);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repository = MoriChatRepository.instance;

    return ValueListenableBuilder<List<MoriCharacter>>(
      valueListenable: repository.characters,
      builder: (context, characters, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: repository.loadingCharacters,
          builder: (context, loading, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: repository.lastError,
              builder: (context, error, _) {
                if (characters.isEmpty && loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (characters.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.12,
                        ),
                        MoriEmptyState(
                          icon: MoriIcons.user,
                          title: '还没有角色卡',
                          message: error ?? '请先在 MoriBot 后台创建并启用角色卡，再回到这里刷新。',
                          actions: [
                            FilledButton.tonalIcon(
                              onPressed: _refresh,
                              icon: const Icon(MoriIcons.refresh, size: 18),
                              label: const Text('重新加载'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                    children: [
                      const MoriPageIntro(
                        text: '角色卡由 MoriBot 后台统一管理。点击角色继续上次的会话，右侧按钮可以开始一段新对话。',
                      ),
                      if (error != null) ...[
                        _ErrorBanner(message: error),
                        const SizedBox(height: 10),
                      ],
                      for (final character in characters) ...[
                        _CharacterCard(
                          character: character,
                          opening: _opening.contains(character.id),
                          onTap: () => _openCharacter(character),
                          onNewChat: () =>
                              _openCharacter(character, forceNew: true),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.opening,
    required this.onTap,
    required this.onNewChat,
  });

  final MoriCharacter character;
  final bool opening;
  final VoidCallback onTap;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Material(
      color: isLight
          ? colors.surfaceContainerLowest
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MoriRadius.large),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.58),
          width: 0.7,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: opening ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoriCharacterAvatar(character: character, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      character.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        MoriAvailabilityPill(
                          label: character.chatAvailable ? '对话' : '对话不可用',
                          available: character.chatAvailable,
                          icon: MoriIcons.chat,
                        ),
                        if (character.speechAvailable)
                          const MoriAvailabilityPill(
                            label: '语音',
                            available: true,
                            icon: MoriIcons.volume,
                          ),
                        if (character.imageAvailable)
                          const MoriAvailabilityPill(
                            label: '图片',
                            available: true,
                            icon: MoriIcons.image,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (opening)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: '新建会话',
                  onPressed: character.chatAvailable ? onNewChat : null,
                  icon: const Icon(MoriIcons.plus, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(MoriRadius.medium),
      ),
      child: Row(
        children: [
          Icon(MoriIcons.alert, size: 16, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
