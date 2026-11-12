import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/memory_service.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/number_setting_field.dart';

class MemorySettingsPage extends StatefulWidget {
  const MemorySettingsPage({super.key});

  @override
  State<MemorySettingsPage> createState() => _MemorySettingsPageState();
}

class _MemorySettingsPageState extends State<MemorySettingsPage> {
  bool _extracting = false;

  Future<void> _save(MemorySettings next) async {
    try {
      await MemoryStore.instance.saveSettings(next);
    } catch (_) {
      if (mounted) {
        _showSnackBar('保存记忆设置失败，请重试');
      }
    }
  }

  Future<CharacterProfile?> _pickCharacter({required String title}) async {
    final cards = CharacterStore.instance.cards.value;
    if (cards.isEmpty) {
      _showSnackBar('还没有可用的角色卡');
      return null;
    }
    if (cards.length == 1) {
      return cards.first;
    }
    return showModalBottomSheet<CharacterProfile>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(title)),
            for (final card in cards)
              ListTile(
                leading: CharacterAvatar(character: card, size: 40),
                title: Text(card.displayName),
                onTap: () => Navigator.of(sheetContext).pop(card),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _extractNow() async {
    if (_extracting) {
      return;
    }
    final character = await _pickCharacter(title: '整理谁的记忆？');
    if (character == null || !mounted) {
      return;
    }
    setState(() => _extracting = true);
    try {
      final count = await MemoryService.instance.extractNow(character.id);
      if (mounted) {
        _showSnackBar(count > 0 ? '更新了 $count 项长期内容' : '没有发现新的长期记忆');
      }
    } on MemoryException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('整理记忆失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _extracting = false);
      }
    }
  }

  Future<void> _clearForCharacter() async {
    final character = await _pickCharacter(title: '清空谁的记忆？');
    if (character == null || !mounted) {
      return;
    }
    final count = MemoryStore.instance.entriesFor(character.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空记忆'),
        content: Text('确定清空「${character.displayName}」的全部 $count 条记忆吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          MoriDangerButton(
            label: '清空',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await MemoryStore.instance.clearForCharacter(character.id);
    if (mounted) {
      _showSnackBar('已清空「${character.displayName}」的记忆');
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
      appBar: AppBar(title: const Text('记忆设置')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          MemoryStore.instance.settings,
          CharacterStore.instance.cards,
        ]),
        builder: (context, _) {
          final settings = MemoryStore.instance.settings.value;
          return ListView(
            padding: MoriTheme.pagePadding,
            children: [
              const MoriPageIntro(
                text: '长期记忆会从单聊里提炼值得记住的事，并在合适的对话里自然召回。群聊不会读取单聊记忆。',
              ),
              MoriSectionHeader(
                label: '记忆功能',
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              ),
              MoriSettingsGroup(
                children: [
                  MoriSettingsSwitchTile(
                    icon: MoriIcons.brain,
                    title: '启用长期记忆',
                    subtitle: '关闭后不自动整理记忆，也不会在聊天里召回记忆。',
                    value: settings.enabled,
                    onChanged: (value) {
                      unawaited(_save(settings.copyWith(enabled: value)));
                    },
                  ),
                  MoriSettingsSwitchTile(
                    icon: MoriIcons.autoFix,
                    title: '自动整理记忆',
                    subtitle: '聊天闲置一段时间后，从单聊里提炼值得长期记住的事。',
                    value: settings.autoExtract,
                    onChanged: settings.enabled
                        ? (value) {
                            unawaited(
                              _save(settings.copyWith(autoExtract: value)),
                            );
                          }
                        : null,
                  ),
                  MoriSettingsSwitchTile(
                    icon: MoriIcons.groupRound,
                    title: '启用群聊公共记忆',
                    subtitle: '整理群公共记忆和群印象，只在对应群聊里召回。',
                    value: settings.groupMemoryEnabled,
                    onChanged: settings.enabled
                        ? (value) {
                            unawaited(
                              _save(
                                settings.copyWith(groupMemoryEnabled: value),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
              MoriSectionHeader(label: '整理与召回'),
              MoriSettingsGroup(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                children: [
                  NumberSettingField(
                    label: '每次召回条数',
                    value: settings.recallCount,
                    min: 0,
                    helperText: '0 表示不在聊天中召回；最多 20 条，避免占用过多上下文。',
                    onChanged: (value) {
                      unawaited(_save(settings.copyWith(recallCount: value)));
                    },
                  ),
                  const SizedBox(height: 12),
                  NumberSettingField(
                    label: '自动整理闲置时间（分钟）',
                    value: settings.extractIdleMinutes,
                    min: 1,
                    helperText: '聊天停止这么久后，才会开始整理记忆。',
                    onChanged: (value) {
                      unawaited(
                        _save(settings.copyWith(extractIdleMinutes: value)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  NumberSettingField(
                    label: '自动整理最少消息数',
                    value: settings.extractMinMessages,
                    min: 2,
                    helperText: '新聊天达到这么多条后才会调用模型整理。',
                    onChanged: (value) {
                      unawaited(
                        _save(settings.copyWith(extractMinMessages: value)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  NumberSettingField(
                    label: '每个角色最多记忆数',
                    value: settings.maxMemoriesPerCharacter,
                    min: 10,
                    helperText: '超过后会优先清理低重要性的自动记忆。',
                    onChanged: (value) {
                      unawaited(
                        _save(
                          settings.copyWith(maxMemoriesPerCharacter: value),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const MoriSectionHeader(label: '手动操作'),
              MoriSettingsGroup(
                children: [
                  MoriSettingsTile(
                    icon: MoriIcons.autoFix,
                    title: '立即整理记忆',
                    subtitle: '不等聊天闲置，马上整理一个角色的近期聊天',
                    showChevron: false,
                    trailing: _extracting
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
                    onTap: _extracting ? null : _extractNow,
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.erase,
                    title: '清空某个角色的记忆',
                    subtitle: '删除后无法恢复',
                    danger: true,
                    showChevron: false,
                    onTap: _clearForCharacter,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '自动整理会调用当前模型；关闭自动整理后仍然可以手动整理。删除角色卡时会同步删除该角色的记忆。',
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
