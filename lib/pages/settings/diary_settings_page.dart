import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/diary_service.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/diary_character_settings_sheet.dart';
import 'package:mori_ai/widgets/number_setting_field.dart';

class DiarySettingsPage extends StatefulWidget {
  const DiarySettingsPage({super.key});

  @override
  State<DiarySettingsPage> createState() => _DiarySettingsPageState();
}

class _DiarySettingsPageState extends State<DiarySettingsPage> {
  bool _writing = false;

  Future<void> _save(DiarySettings next) async {
    try {
      await DiaryStore.instance.saveSettings(next);
    } catch (_) {
      if (mounted) {
        _showSnackBar('保存日记设置失败，请重试');
      }
    }
  }

  Future<void> _pickTime() async {
    final settings = DiaryStore.instance.settings.value;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.timeMinutes ~/ 60,
        minute: settings.timeMinutes % 60,
      ),
    );
    if (picked == null) {
      return;
    }
    await _save(
      settings.copyWith(timeMinutes: picked.hour * 60 + picked.minute),
    );
  }

  Future<void> _writeNow() async {
    final cards = CharacterStore.instance.cards.value;
    if (cards.isEmpty) {
      _showSnackBar('还没有可用的角色卡');
      return;
    }

    final character = await showModalBottomSheet<CharacterProfile>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('让谁写今天的日记？'),
                subtitle: Text('会使用今天有意义的聊天和活动生成一篇日记'),
              ),
              for (final card in cards)
                ListTile(
                  leading: CharacterAvatar(character: card, size: 40),
                  title: Text(card.displayName),
                  onTap: () => Navigator.of(sheetContext).pop(card),
                ),
            ],
          ),
        );
      },
    );
    if (character == null || !mounted) {
      return;
    }

    setState(() => _writing = true);
    try {
      await DiaryService.instance.writeNow(character.id);
      if (mounted) {
        _showSnackBar('已生成「${character.displayName}」今天的日记');
      }
    } on DiaryException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('生成日记失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _writing = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('日记')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          DiaryStore.instance.settings,
          CharacterStore.instance.cards,
        ]),
        builder: (context, _) {
          final settings = DiaryStore.instance.settings.value;
          return ListView(
            padding: MoriTheme.pagePadding,
            children: [
              const MoriPageIntro(
                text: '角色会在每天固定时间，从聊天与动态里提炼真正值得记住的事，写下一篇日记。日记只保存在本机。',
              ),
              MoriSectionHeader(
                label: '每日日记',
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              ),
              MoriSettingsGroup(
                children: [
                  MoriSettingsSwitchTile(
                    icon: MoriIcons.diary,
                    title: '启用每日日记',
                    subtitle: '全局默认开关；单个角色可以在下面单独覆盖。',
                    value: settings.enabled,
                    onChanged: (value) {
                      unawaited(_save(settings.copyWith(enabled: value)));
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.clock,
                    title: '全局默认写作时间',
                    subtitle: '每天 ${settings.timeLabel} 左右；单个角色可覆盖',
                    showChevron: false,
                    trailing: Text(
                      settings.timeLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _pickTime,
                  ),
                  MoriSettingsSwitchTile(
                    icon: MoriIcons.brain,
                    title: '让角色记得最近的日记',
                    subtitle: '单聊和主动消息会参考最近写过的日记。',
                    value: settings.recallEnabled,
                    onChanged: (value) {
                      unawaited(_save(settings.copyWith(recallEnabled: value)));
                    },
                  ),
                  if (settings.recallEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: NumberSettingField(
                        label: '召回日记条数',
                        value: settings.recallCount,
                        min: 0,
                        helperText:
                            '0 表示不注入；最多 ${DiarySettings.maxRecallCount} 条。',
                        onChanged: (value) {
                          unawaited(
                            _save(settings.copyWith(recallCount: value)),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const MoriSectionHeader(label: '手动写作'),
              MoriSettingsGroup(
                children: [
                  MoriSettingsTile(
                    icon: MoriIcons.editNote,
                    title: '立即写一篇',
                    subtitle: '选择角色，按今天的素材生成日记',
                    showChevron: false,
                    trailing: _writing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Icon(
                            MoriIcons.chevron,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                    onTap: _writing ? null : _writeNow,
                  ),
                ],
              ),
              const MoriSectionHeader(label: '角色单独设置'),
              const MoriPageIntro(
                text: '默认使用上面的全局开关和时间；点角色可以单独覆盖开关和写作时间。',
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              ),
              if (CharacterStore.instance.cards.value.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    '还没有角色卡。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                MoriSettingsGroup(
                  dividerIndent: 66,
                  children: [
                    for (final card in CharacterStore.instance.cards.value)
                      _CharacterDiaryTile(character: card, settings: settings),
                  ],
                ),
              const MoriSectionHeader(label: '只记录有意义的内容'),
              Text(
                '角色会从当天的聊天、主动消息、群聊发言和动态里提炼真正值得记住的事，'
                '跳过寒暄、重复和无信息量的短句，不会把全部聊天记录照搬进日记。\n\n'
                '每篇自动日记会调用一次当前模型。应用退到后台或被系统关闭时可能错过当天，重新打开后会尽量补写。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CharacterDiaryTile extends StatelessWidget {
  const _CharacterDiaryTile({required this.character, required this.settings});

  final CharacterProfile character;
  final DiarySettings settings;

  @override
  Widget build(BuildContext context) {
    final custom = settings.hasOverride(character.id);
    final enabled = settings.isEnabledFor(character.id);
    final timeLabel = settings.timeLabelFor(character.id);
    final mode = custom ? '单独设置' : '跟随全局';
    final status = enabled ? '每天 $timeLabel 写' : '不自动写';

    return MoriSettingsTile(
      leading: CharacterAvatar(character: character, size: 40),
      title: character.displayName,
      subtitle: '$mode · $status',
      trailing: const Icon(MoriIcons.tune, size: 18),
      onTap: () =>
          showDiaryCharacterSettingsSheet(context, character: character),
    );
  }
}
