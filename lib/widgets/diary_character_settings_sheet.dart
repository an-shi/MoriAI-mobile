import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

Future<void> showDiaryCharacterSettingsSheet(
  BuildContext context, {
  required CharacterProfile character,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _DiaryCharacterSettingsSheet(character: character),
  );
}

class _DiaryCharacterSettingsSheet extends StatefulWidget {
  const _DiaryCharacterSettingsSheet({required this.character});

  final CharacterProfile character;

  @override
  State<_DiaryCharacterSettingsSheet> createState() =>
      _DiaryCharacterSettingsSheetState();
}

class _DiaryCharacterSettingsSheetState
    extends State<_DiaryCharacterSettingsSheet> {
  Future<void> _save(DiarySettings next) async {
    try {
      await DiaryStore.instance.saveSettings(next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('保存日记设置失败，请重试')));
      }
    }
  }

  Future<void> _setFollowGlobal(DiarySettings settings) async {
    await _save(settings.clearCharacterSettings(widget.character.id));
  }

  Future<void> _setCustom(DiarySettings settings) async {
    final id = widget.character.id;
    await _save(
      settings.setCharacterSettings(
        id,
        DiaryCharacterSettings(
          enabled: settings.isEnabledFor(id),
          timeMinutes: settings.timeMinutesFor(id),
        ),
      ),
    );
  }

  Future<void> _setEnabled(DiarySettings settings, bool enabled) async {
    final current = settings.settingsFor(widget.character.id);
    if (current == null) {
      return;
    }
    await _save(
      settings.setCharacterSettings(
        widget.character.id,
        current.copyWith(enabled: enabled),
      ),
    );
  }

  Future<void> _pickTime(DiarySettings settings) async {
    final current = settings.settingsFor(widget.character.id);
    if (current == null) {
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.timeMinutes ~/ 60,
        minute: current.timeMinutes % 60,
      ),
    );
    if (picked == null) {
      return;
    }
    await _save(
      settings.setCharacterSettings(
        widget.character.id,
        current.copyWith(timeMinutes: picked.hour * 60 + picked.minute),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedBuilder(
      animation: DiaryStore.instance.settings,
      builder: (context, _) {
        final settings = DiaryStore.instance.settings.value;
        final custom = settings.settingsFor(widget.character.id);
        final enabled = settings.isEnabledFor(widget.character.id);
        final timeLabel = settings.timeLabelFor(widget.character.id);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CharacterAvatar(
                    character: widget.character,
                    size: 44,
                  ),
                  title: Text(
                    '${widget.character.displayName}的日记',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text('每个角色每天最多一篇'),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('跟随全局'),
                      selected: custom == null,
                      onSelected: (selected) {
                        if (selected) {
                          unawaited(_setFollowGlobal(settings));
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('单独设置'),
                      selected: custom != null,
                      onSelected: (selected) {
                        if (selected) {
                          unawaited(_setCustom(settings));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (custom == null)
                  MoriSettingsGroup(
                    padding: const EdgeInsets.all(14),
                    children: [
                      Text(
                        '当前跟随全局：${settings.enabled ? '已开启' : '已关闭'}'
                        ' · 每天 ${settings.timeLabel} 左右写一篇。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  )
                else
                  MoriSettingsGroup(
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        secondary: MoriIconBadge(
                          icon: MoriIcons.diary,
                          size: 32,
                        ),
                        title: const Text('每天写日记'),
                        subtitle: Text(
                          custom.enabled
                              ? '每天 ${custom.timeLabel} 左右写一篇'
                              : '这个角色不会自动写日记',
                        ),
                        value: custom.enabled,
                        onChanged: (value) {
                          unawaited(_setEnabled(settings, value));
                        },
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        leading: const MoriIconBadge(
                          icon: MoriIcons.clock,
                          size: 32,
                        ),
                        title: const Text('写作时间'),
                        subtitle: const Text('单独设置优先于全局时间'),
                        trailing: Text(
                          custom.timeLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          unawaited(_pickTime(settings));
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  '当前生效：${enabled ? '已开启' : '已关闭'} · 每天 $timeLabel',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
