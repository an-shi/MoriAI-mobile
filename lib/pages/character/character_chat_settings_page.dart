import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';
import 'package:mori_ai/models/proactive_message_state.dart';
import 'package:mori_ai/pages/character/character_moments_page.dart';
import 'package:mori_ai/pages/memory/character_card_edit_page.dart';
import 'package:mori_ai/pages/settings/proactive_message_settings_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_queue_store.dart';
import 'package:mori_ai/services/proactive_message_service.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
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

  Future<void> _deleteHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除聊天记录'),
          content: const Text('确定删除该角色的全部聊天记录吗？删除后无法恢复。'),
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
    if (confirmed != true) {
      return;
    }

    try {
      await ChatHistoryStore.instance.deleteConversation(characterId);
      await ChatQueueStore.instance.saveFor(characterId, const []);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('聊天记录已删除')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('删除聊天记录失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
            appBar: AppBar(title: const Text('角色设置')),
            body: const Center(child: Text('角色卡不存在或已被删除')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(character.displayName)),
          body: ListView(
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
                  leading: Icon(
                    Icons.dynamic_feed_outlined,
                    color: colors.primary,
                  ),
                  title: const Text('动态'),
                  subtitle: Text('查看「${character.displayName}」发布的动态'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CharacterMomentsPage(characterId: character!.id),
                      ),
                    );
                  },
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
              const SizedBox(height: 16),
              _ProactiveConversationCard(
                characterId: character.id,
                characterName: character.displayName,
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
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: colors.error,
                  ),
                  title: Text('删除聊天记录', style: TextStyle(color: colors.error)),
                  subtitle: const Text('清空与该角色的全部本地聊天记录'),
                  onTap: () => _deleteHistory(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProactiveConversationCard extends StatefulWidget {
  const _ProactiveConversationCard({
    required this.characterId,
    required this.characterName,
  });

  final String characterId;
  final String characterName;

  @override
  State<_ProactiveConversationCard> createState() =>
      _ProactiveConversationCardState();
}

class _ProactiveConversationCardState
    extends State<_ProactiveConversationCard> {
  ProactiveMessageState? _state;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await ProactiveMessageService.instance.conversationState(
      widget.characterId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() {
      _state = (_state ?? const ProactiveMessageState()).copyWith(
        enabled: enabled,
      );
      _saving = true;
    });
    try {
      await ProactiveMessageService.instance.updateConversationConfig(
        widget.characterId,
        enabled: enabled,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _setDailyLimit(int dailyLimit) async {
    setState(() {
      _state = (_state ?? const ProactiveMessageState()).copyWith(
        dailyLimit: dailyLimit,
      );
    });
    try {
      await ProactiveMessageService.instance.updateConversationConfig(
        widget.characterId,
        dailyLimit: dailyLimit,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('保存自动消息设置失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedBuilder(
      animation: ProactiveMessageStore.instance.settings,
      builder: (context, _) {
        final global = ProactiveMessageStore.instance.settings.value;
        final enabled = _state?.enabled ?? true;
        final dailyLimit = _state?.dailyLimit ?? 0;
        final effectiveLimit = dailyLimit > 0 ? dailyLimit : global.dailyLimit;
        final subtitle = !global.enabled
            ? '全局自动消息未开启，开启后该设置才会生效'
            : enabled
            ? '开启后，「${widget.characterName}」会主动找你'
            : '该角色不会主动发消息';

        return Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Icon(
                  Icons.notifications_active_outlined,
                  color: colors.primary,
                ),
                title: const Text('允许主动消息'),
                subtitle: Text(subtitle),
                value: enabled,
                onChanged: _loading || _saving ? null : _setEnabled,
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '该角色每日上限',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          dailyLimit > 0
                              ? '$dailyLimit 条'
                              : '跟随全局（$effectiveLimit 条）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: dailyLimit.toDouble(),
                      min: 0,
                      max: ProactiveMessageSettings.maxDailyLimit.toDouble(),
                      divisions: ProactiveMessageSettings.maxDailyLimit,
                      label: dailyLimit > 0 ? '$dailyLimit 条' : '跟随全局',
                      onChanged: _loading || _saving
                          ? null
                          : (value) {
                              setState(() {
                                _state =
                                    (_state ?? const ProactiveMessageState())
                                        .copyWith(dailyLimit: value.round());
                              });
                            },
                      onChangeEnd: (value) => _setDailyLimit(value.round()),
                    ),
                    Text(
                      '0 表示跟随全局每日总上限；全局总上限仍会生效。',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(Icons.tune_rounded, color: colors.primary),
                title: const Text('全局自动消息设置'),
                subtitle: const Text('调整沉默间隔、定时问候和免打扰'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProactiveMessageSettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
