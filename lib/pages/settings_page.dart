import 'package:flutter/material.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/chat_burst_settings.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/pages/memory/memory_settings_page.dart';
import 'package:mori_ai/pages/settings/about_settings_page.dart';
import 'package:mori_ai/pages/settings/appearance_settings_page.dart';
import 'package:mori_ai/pages/settings/chat_settings_page.dart';
import 'package:mori_ai/pages/settings/diary_settings_page.dart';
import 'package:mori_ai/pages/settings/model_settings_page.dart';
import 'package:mori_ai/pages/settings/moment_interaction_settings_page.dart';
import 'package:mori_ai/pages/settings/mood_settings_page.dart';
import 'package:mori_ai/pages/settings/proactive_message_settings_page.dart';
import 'package:mori_ai/services/chat_burst_settings_store.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/moment_interaction_settings_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:mori_ai/services/theme_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          ModelStore.instance.selection,
          ModelStore.instance.activePresetId,
          ModelStore.instance.presets,
          ThemeStore.instance.themeMode,
          MomentInteractionSettingsStore.instance.settings,
          ProactiveMessageStore.instance.settings,
          ChatBurstSettingsStore.instance.settings,
          MoodStore.instance.settings,
          DiaryStore.instance.settings,
          MemoryStore.instance.settings,
        ]),
        builder: (context, _) {
          return ListView(
            padding: MoriTheme.pagePadding,
            children: [
              const MoriSectionHeader(
                label: '偏好设置',
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              ),
              MoriSettingsGroup(
                children: [
                  MoriSettingsTile(
                    icon: MoriIcons.cpu,
                    title: '模型',
                    subtitle: _modelSummary(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ModelSettingsPage(),
                        ),
                      );
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.palette,
                    title: '外观',
                    subtitle: _themeModeLabel(
                      ThemeStore.instance.themeMode.value,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AppearanceSettingsPage(),
                        ),
                      );
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.chats,
                    title: '聊天',
                    subtitle: _chatBurstSummary(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChatSettingsPage(),
                        ),
                      );
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.mood,
                    title: '心情',
                    subtitle: _moodSummary(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MoodSettingsPage(),
                        ),
                      );
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.diary,
                    title: '日记',
                    subtitle: _diarySummary(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DiarySettingsPage(),
                        ),
                      );
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.brain,
                    title: '记忆',
                    subtitle: _memorySummary(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MemorySettingsPage(),
                        ),
                      );
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.sparkles,
                    title: '动态互动',
                    subtitle: _momentInteractionSummary(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MomentInteractionSettingsPage(),
                        ),
                      );
                    },
                  ),
                  MoriSettingsTile(
                    icon: MoriIcons.bell,
                    title: '自动消息',
                    subtitle: _proactiveMessageSummary(),
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
              const MoriSectionHeader(label: '其他'),
              MoriSettingsGroup(
                children: [
                  MoriSettingsTile(
                    icon: MoriIcons.info,
                    title: '关于 Mori',
                    subtitle: '版本 1.0.0',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 22, 4, 0),
                child: Text(
                  'Mori 1.0.0',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _modelSummary() {
    final selection = ModelStore.instance.selection.value;
    final provider =
        ModelProviderCatalog.byId(selection.providerId) ??
        ModelProviderCatalog.defaultProvider;

    if (!selection.hasModel) {
      return '${provider.name} · 尚未选择模型';
    }

    final activeId = ModelStore.instance.activePresetId.value;
    ModelPreset? activePreset;
    for (final preset in ModelStore.instance.presets.value) {
      if (preset.id == activeId) {
        activePreset = preset;
        break;
      }
    }

    if (activePreset != null) {
      return activePreset.name;
    }
    return '${provider.name} · ${selection.modelId}';
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色模式',
      ThemeMode.dark => '深色模式',
    };
  }

  String _chatBurstSummary() {
    return '连发倾向：${ChatBurstSettingsStore.instance.settings.value.globalTendency.label}';
  }

  String _moodSummary() {
    final settings = MoodStore.instance.settings.value;
    return settings.enabled ? '已开启 · 基线 ${settings.base}' : '已关闭';
  }

  String _diarySummary() {
    final settings = DiaryStore.instance.settings.value;
    final enabledOverrides = settings.characterSettings.values
        .where((value) => value.enabled)
        .length;
    if (!settings.enabled && enabledOverrides == 0) {
      return '已关闭';
    }
    if (!settings.enabled) {
      return '全局关闭 · $enabledOverrides 个角色单独开启';
    }
    final overrides = settings.characterSettings.isEmpty
        ? ''
        : ' · ${settings.characterSettings.length} 个单独设置';
    return '已开启 · 每天 ${settings.timeLabel}$overrides';
  }

  String _memorySummary() {
    final settings = MemoryStore.instance.settings.value;
    if (!settings.enabled) {
      return '已关闭';
    }
    return '已开启 · 召回 ${settings.recallCount} 条'
        '${settings.autoExtract ? ' · 自动整理' : ''}';
  }

  String _momentInteractionSummary() {
    final settings = MomentInteractionSettingsStore.instance.settings.value;
    final comments = settings.autoCommentCount < 0
        ? '评论无上限'
        : settings.autoCommentCount == 0
        ? '评论关闭'
        : '评论 ${settings.autoCommentCount} 人';
    final replies = settings.autoReplyDepth < 0
        ? '回复无上限'
        : settings.autoReplyDepth == 0
        ? '回复关闭'
        : '回复 ${settings.autoReplyDepth} 层';
    return '$comments · $replies';
  }

  String _proactiveMessageSummary() {
    final settings = ProactiveMessageStore.instance.settings.value;
    if (!settings.enabled) {
      return '关闭';
    }
    final silence = settings.silenceEnabled
        ? '沉默 ${settings.silenceMinMinutes}-${settings.silenceMaxMinutes} 分钟'
        : '沉默关闭';
    final scheduled = settings.scheduledEnabled
        ? '定时 ${settings.scheduledTimes.length} 个'
        : '定时关闭';
    final daily = settings.dailyLimit < 0
        ? '每日无上限'
        : '每日 ${settings.dailyLimit} 条';
    return '$silence · $scheduled · $daily';
  }
}
