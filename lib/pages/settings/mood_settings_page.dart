import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/number_setting_field.dart';

class MoodSettingsPage extends StatelessWidget {
  const MoodSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('心情')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          MoodStore.instance.settings,
          MoodStore.instance.revision,
          CharacterStore.instance.cards,
        ]),
        builder: (context, _) {
          final settings = MoodStore.instance.settings.value;
          final characters = CharacterStore.instance.cards.value;
          return ListView(
            padding: MoriTheme.pagePadding,
            children: [
              const MoriPageIntro(
                text: '聊天里的话会让心情起伏，心情会自然影响语气和回复节奏。默认根据关键词判断；开启模型判断后会结合上下文理解语气，但会增加一次模型调用。',
              ),
              MoriSectionHeader(
                label: '心情设置',
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              ),
              MoriSettingsGroup(
                children: [
                  MoriSettingsSwitchTile(
                    icon: MoriIcons.mood,
                    title: '启用心情',
                    subtitle: '聊天里的话会让心情起伏，心情会自然影响语气和回复节奏。',
                    value: settings.enabled,
                    onChanged: (value) {
                      unawaited(
                        MoodStore.instance.saveSettings(
                          settings.copyWith(enabled: value),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    child: Column(
                      children: [
                        NumberSettingField(
                          label: '心情基线',
                          value: settings.base,
                          min: 0,
                          helperText: '0-100，默认 60。心情会慢慢回到这个值。',
                          onChanged: (value) {
                            unawaited(
                              MoodStore.instance.saveSettings(
                                settings.copyWith(base: value),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        NumberSettingField(
                          label: '半衰期（小时）',
                          value: settings.halfLifeHours,
                          min: 1,
                          helperText: '默认 3 小时。心情偏离基线后，大约经过这么久会回到一半。',
                          onChanged: (value) {
                            unawaited(
                              MoodStore.instance.saveSettings(
                                settings.copyWith(halfLifeHours: value),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '使用模型判断心情',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '单聊每次用户发言会多调用一次模型；关闭时使用本地关键词判断。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          value: settings.modelJudgeEnabled,
                          onChanged: settings.enabled
                              ? (value) {
                                  unawaited(
                                    MoodStore.instance.saveSettings(
                                      settings.copyWith(
                                        modelJudgeEnabled: value,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const MoriSectionHeader(label: '角色心情'),
              if (characters.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                  child: Text(
                    '还没有角色卡。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                MoriSettingsGroup(
                  children: [
                    for (final card in characters)
                      _MoodCharacterRow(
                        characterId: card.id,
                        characterName: card.displayName,
                        avatar: CharacterAvatar(character: card, size: 40),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MoodCharacterRow extends StatelessWidget {
  const _MoodCharacterRow({
    required this.characterId,
    required this.characterName,
    required this.avatar,
  });

  final String characterId;
  final String characterName;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final snapshot = MoodStore.instance.snapshotFor(characterId);
    final lastUpdated = snapshot.updatedAtMs <= 0
        ? '还没有心情记录'
        : _formatTime(snapshot.updatedAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        characterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    Text(
                      '${snapshot.label} · ${snapshot.value}/100',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: snapshot.value / 100,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.reason.isEmpty
                      ? lastUpdated
                      : '${snapshot.reason} · $lastUpdated',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '重置心情',
            onPressed: () {
              unawaited(MoodStore.instance.reset(characterId));
            },
            icon: const Icon(MoriIcons.reset, size: 18),
          ),
        ],
      ),
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
