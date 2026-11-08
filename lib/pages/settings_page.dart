import 'package:flutter/material.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/pages/settings/about_settings_page.dart';
import 'package:mori_ai/pages/settings/appearance_settings_page.dart';
import 'package:mori_ai/pages/settings/model_settings_page.dart';
import 'package:mori_ai/pages/settings/moment_interaction_settings_page.dart';
import 'package:mori_ai/pages/settings/proactive_message_settings_page.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/moment_interaction_settings_store.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:mori_ai/services/theme_store.dart';

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
        ]),
        builder: (context, _) {
          final theme = Theme.of(context);
          final colors = theme.colorScheme;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                '偏好设置',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsMenuCard(
                children: [
                  _SettingsMenuTile(
                    icon: Icons.memory_rounded,
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
                  const _SettingsMenuDivider(),
                  _SettingsMenuTile(
                    icon: Icons.palette_outlined,
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
                  const _SettingsMenuDivider(),
                  _SettingsMenuTile(
                    icon: Icons.auto_awesome_outlined,
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
                  const _SettingsMenuDivider(),
                  _SettingsMenuTile(
                    icon: Icons.notifications_active_outlined,
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
              const SizedBox(height: 16),
              Text(
                '其他',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsMenuCard(
                children: [
                  _SettingsMenuTile(
                    icon: Icons.info_outline_rounded,
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

  String _momentInteractionSummary() {
    final settings = MomentInteractionSettingsStore.instance.settings.value;
    final comments = settings.autoCommentCount <= 0
        ? '评论关闭'
        : '评论 ${settings.autoCommentCount} 人';
    final replies = settings.autoReplyDepth <= 0
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
    return '$silence · $scheduled · 每日 ${settings.dailyLimit} 条';
  }
}

class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colors.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _SettingsMenuDivider extends StatelessWidget {
  const _SettingsMenuDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
