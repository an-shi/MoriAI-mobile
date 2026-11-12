import 'package:flutter/material.dart';
import 'package:mori_ai/services/theme_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  static const _options = [
    _ThemeOption(
      mode: ThemeMode.system,
      icon: MoriIcons.sunMoon,
      title: '跟随系统',
      subtitle: '根据系统设置自动切换浅色或深色',
    ),
    _ThemeOption(
      mode: ThemeMode.light,
      icon: MoriIcons.sun,
      title: '浅色模式',
      subtitle: '始终使用浅色外观',
    ),
    _ThemeOption(
      mode: ThemeMode.dark,
      icon: MoriIcons.moonDark,
      title: '深色模式',
      subtitle: '始终使用深色外观',
    ),
  ];

  Future<void> _select(BuildContext context, ThemeMode mode) async {
    try {
      await ThemeStore.instance.save(mode);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('外观设置保存失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeStore.instance.themeMode,
        builder: (context, currentMode, _) {
          return ListView(
            padding: MoriTheme.pagePadding,
            children: [
              const MoriPageIntro(
                text: '选择 Mori 的显示方式。薄荷绿与奶白色会在浅色模式下呈现，深色模式则使用柔和的墨绿色。',
              ),
              const MoriSectionHeader(
                label: '主题',
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              ),
              MoriSettingsGroup(
                children: [
                  for (final option in _options)
                    MoriSettingsTile(
                      icon: option.icon,
                      title: option.title,
                      subtitle: option.subtitle,
                      showChevron: false,
                      trailing: currentMode == option.mode
                          ? Icon(
                              MoriIcons.checkCircle,
                              size: 20,
                              color: colors.primary,
                            )
                          : SizedBox(
                              width: 20,
                              height: 20,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                      onTap: () => _select(context, option.mode),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '深色模式也会保留薄荷绿作为强调色，并降低背景亮度以减少夜间眩光。',
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

class _ThemeOption {
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
}
