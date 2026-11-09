import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/mood_store.dart';
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
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      secondary: Icon(
                        Icons.mood_outlined,
                        color: colors.primary,
                      ),
                      title: const Text('启用心情'),
                      subtitle: const Text('聊天里的话会让心情起伏，心情会自然影响语气和回复节奏。'),
                      value: settings.enabled,
                      onChanged: (value) {
                        unawaited(
                          MoodStore.instance.saveSettings(
                            settings.copyWith(enabled: value),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: colors.outlineVariant,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('使用模型判断心情'),
                            subtitle: const Text(
                              '单聊每次用户发言会多调用一次模型；关闭时使用本地关键词判断。',
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
              ),
              const SizedBox(height: 12),
              Text(
                '默认根据聊天关键词判断心情；开启模型判断后会结合上下文理解语气，但会增加一次模型调用。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '角色心情',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (CharacterStore.instance.cards.value.isEmpty)
                Text(
                  '还没有角色卡。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              for (final card in CharacterStore.instance.cards.value)
                _MoodCharacterCard(
                  characterId: card.id,
                  characterName: card.displayName,
                  avatar: CharacterAvatar(character: card, size: 42),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MoodCharacterCard extends StatelessWidget {
  const _MoodCharacterCard({
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

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${snapshot.label} · ${snapshot.value}/100',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: snapshot.value / 100,
                      minHeight: 6,
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
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
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
