import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/diary_service.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/diary_character_settings_sheet.dart';

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
                        Icons.menu_book_outlined,
                        color: colors.primary,
                      ),
                      title: const Text('启用每日日记'),
                      subtitle: const Text('全局默认开关；单个角色可以在下面单独覆盖。'),
                      value: settings.enabled,
                      onChanged: (value) {
                        unawaited(_save(settings.copyWith(enabled: value)));
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: colors.outlineVariant,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Icon(
                        Icons.schedule_outlined,
                        color: colors.primary,
                      ),
                      title: const Text('全局默认写作时间'),
                      subtitle: Text('每天 ${settings.timeLabel} 左右；单个角色可覆盖'),
                      trailing: Text(
                        settings.timeLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: _pickTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                  leading: Icon(
                    Icons.edit_note_outlined,
                    color: colors.primary,
                  ),
                  title: const Text('立即写一篇'),
                  subtitle: const Text('选择角色，按今天的素材生成日记'),
                  trailing: _writing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _writing ? null : _writeNow,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '角色单独设置',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '默认使用上面的全局开关和时间；点角色可以单独覆盖开关和写作时间。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (CharacterStore.instance.cards.value.isEmpty)
                Text(
                  '还没有角色卡。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                Card(
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < CharacterStore.instance.cards.value.length;
                        index++
                      ) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                            color: colors.outlineVariant,
                          ),
                        _CharacterDiaryTile(
                          character: CharacterStore.instance.cards.value[index],
                          settings: settings,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                '只记录有意义的内容',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '角色会从当天的聊天、主动消息、群聊发言和动态里提炼真正值得记住的事，'
                '跳过寒暄、重复和无信息量的短句，不会把全部聊天记录照搬进日记。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '日记只保存在本机；每篇自动日记会调用一次当前模型。'
                '应用退到后台或被系统关闭时可能错过当天，重新打开后会尽量补写。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CharacterAvatar(character: character, size: 40),
      title: Text(character.displayName),
      subtitle: Text('$mode · $status'),
      trailing: const Icon(Icons.tune_rounded),
      onTap: () =>
          showDiaryCharacterSettingsSheet(context, character: character),
    );
  }
}
