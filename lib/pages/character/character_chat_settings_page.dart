import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_burst_settings.dart';
import 'package:mori_ai/models/proactive_message_state.dart';
import 'package:mori_ai/pages/character/character_moments_page.dart';
import 'package:mori_ai/pages/memory/character_card_edit_page.dart';
import 'package:mori_ai/pages/settings/proactive_message_settings_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_burst_settings_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_queue_store.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:mori_ai/services/proactive_message_service.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:mori_ai/services/unread_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/diary_character_settings_sheet.dart';
import 'package:mori_ai/widgets/number_setting_field.dart';

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
            MoriDangerButton(
              label: '删除',
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
      await UnreadStore.instance.clearForConversation(characterId);
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
            padding: MoriTheme.pagePadding,
            children: [
              MoriSettingsGroup(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: CharacterAvatar(character: character, size: 64),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              character.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              character.type.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const MoriSectionHeader(label: '最近状态'),
              _MoodStatusCard(characterId: character.id),
              const SizedBox(height: 12),
              _DiaryCharacterCard(character: character),
              const MoriSectionHeader(label: '角色内容'),
              MoriSettingsGroup(
                children: [
                  MoriSettingsTile(
                    icon: MoriIcons.moments,
                    title: '动态',
                    subtitle: '查看「${character.displayName}」发布的动态',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CharacterMomentsPage(characterId: character!.id),
                        ),
                      );
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.badge,
                    title: '角色卡设置',
                    subtitle: '修改角色设定、头像、开场白等内容',
                    onTap: () => _openCardEditor(context),
                  ),
                ],
              ),
              const MoriSectionHeader(label: '聊天行为'),
              _BurstTendencyCard(
                characterId: character.id,
                characterName: character.displayName,
              ),
              const SizedBox(height: 12),
              _ProactiveConversationCard(
                characterId: character.id,
                characterName: character.displayName,
              ),
              const MoriSectionHeader(label: '数据'),
              MoriSettingsGroup(
                children: [
                  MoriSettingsTile(
                    icon: MoriIcons.erase,
                    title: '删除聊天记录',
                    subtitle: '清空与该角色的全部本地聊天记录',
                    danger: true,
                    showChevron: false,
                    onTap: () => _deleteHistory(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiaryCharacterCard extends StatelessWidget {
  const _DiaryCharacterCard({required this.character});

  final CharacterProfile character;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DiaryStore.instance.settings,
      builder: (context, _) {
        final settings = DiaryStore.instance.settings.value;
        final custom = settings.hasOverride(character.id);
        final enabled = settings.isEnabledFor(character.id);
        final timeLabel = settings.timeLabelFor(character.id);
        final mode = custom ? '单独设置' : '跟随全局';
        final status = enabled ? '每天 $timeLabel 写' : '不自动写';

        return MoriSettingsGroup(
          children: [
            MoriSettingsTile(
              icon: MoriIcons.diary,
              title: '日记',
              subtitle: '$mode · $status',
              onTap: () => showDiaryCharacterSettingsSheet(
                context,
                character: character,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoodStatusCard extends StatelessWidget {
  const _MoodStatusCard({required this.characterId});

  final String characterId;

  Future<void> _resetMood(BuildContext context) async {
    await MoodStore.instance.reset(characterId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('心情已重置')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([
        MoodStore.instance.settings,
        MoodStore.instance.revision,
      ]),
      builder: (context, _) {
        final enabled = MoodStore.instance.settings.value.enabled;
        final snapshot = MoodStore.instance.snapshotFor(characterId);
        final hasRecord = snapshot.updatedAtMs > 0;
        final updatedAt = hasRecord ? _formatTime(snapshot.updatedAt) : '';
        final detail = snapshot.reason.isEmpty
            ? (hasRecord ? updatedAt : '还没有心情记录')
            : (hasRecord ? '${snapshot.reason} · $updatedAt' : snapshot.reason);

        return MoriSettingsGroup(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MoriIconBadge(icon: MoriIcons.mood, size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '心情',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (enabled)
                      IconButton(
                        tooltip: '重置心情',
                        onPressed: () => unawaited(_resetMood(context)),
                        icon: const Icon(MoriIcons.reset, size: 18),
                      ),
                  ],
                ),
                if (!enabled)
                  Text(
                    '心情已关闭，可在「设置 > 心情」中开启。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Text(
                        snapshot.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${snapshot.value}/100',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: snapshot.value / 100,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return '今天 $hh:$mm';
    }
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hh:$mm';
  }
}

class _BurstTendencyCard extends StatelessWidget {
  const _BurstTendencyCard({
    required this.characterId,
    required this.characterName,
  });

  final String characterId;
  final String characterName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ValueListenableBuilder<ChatBurstSettings>(
      valueListenable: ChatBurstSettingsStore.instance.settings,
      builder: (context, settings, _) {
        final override =
            settings.characterTendencies[characterId] ??
            ChatBurstTendency.followGlobal;
        final effective = settings.tendencyFor(characterId);
        final range = settings.rangeFor(effective);
        return MoriSettingsGroup(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MoriIconBadge(icon: MoriIcons.chats, size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '聊天连发倾向',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '只影响「$characterName」的回复。选择“跟随全局”时使用聊天设置里的全局倾向。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tendency in ChatBurstTendency.values)
                      ChoiceChip(
                        label: Text(tendency.label),
                        selected: override == tendency,
                        onSelected: (_) {
                          unawaited(
                            ChatBurstSettingsStore.instance
                                .setCharacterTendency(characterId, tendency),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '当前生效：${effective.label}（全局：${settings.globalTendency.label}）',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  effective == ChatBurstTendency.off
                      ? '当前范围：不启用自动拆条'
                      : '当前范围：${range.minMessages}-${range.maxMessages} 条，'
                            '每条约 ${range.minChars}-${range.maxChars} 字（在全局聊天设置中调整）',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
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
    if (_loading || _saving) {
      return;
    }
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
    return AnimatedBuilder(
      animation: ProactiveMessageStore.instance.settings,
      builder: (context, _) {
        final global = ProactiveMessageStore.instance.settings.value;
        final enabled = _state?.enabled ?? true;
        final dailyLimit = _state?.dailyLimit ?? 0;
        final effectiveLimit = dailyLimit > 0
            ? dailyLimit
            : dailyLimit < 0
            ? -1
            : global.dailyLimit;
        final effectiveLimitLabel = effectiveLimit < 0
            ? '无上限'
            : '$effectiveLimit 条';
        final subtitle = !global.enabled
            ? '全局自动消息未开启，开启后该设置才会生效'
            : enabled
            ? '开启后，「${widget.characterName}」会主动找你'
            : '该角色不会主动发消息';

        return MoriSettingsGroup(
          children: [
            MoriSettingsSwitchTile(
              icon: MoriIcons.bell,
              title: '允许主动消息',
              subtitle: subtitle,
              value: enabled,
              onChanged: _loading || _saving ? null : _setEnabled,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: NumberSettingField(
                label: '该角色每日上限',
                value: dailyLimit,
                min: 0,
                allowUnlimited: true,
                helperText: dailyLimit < 0
                    ? '当前该角色无上限；0 表示跟随全局（$effectiveLimitLabel）。'
                    : '0 表示跟随全局（$effectiveLimitLabel）；负数表示该角色无上限。',
                onChanged: _setDailyLimit,
              ),
            ),
            MoriSettingsTile(
              icon: MoriIcons.tune,
              title: '全局自动消息设置',
              subtitle: '调整沉默间隔、定时问候和免打扰',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProactiveMessageSettingsPage(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
