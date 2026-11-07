import 'package:flutter/material.dart';
import 'package:mori_ai/services/theme_store.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  static const _options = [
    _ThemeOption(
      mode: ThemeMode.system,
      icon: Icons.brightness_auto_rounded,
      title: '跟随系统',
      subtitle: '根据系统设置自动切换浅色或深色',
    ),
    _ThemeOption(
      mode: ThemeMode.light,
      icon: Icons.light_mode_rounded,
      title: '浅色模式',
      subtitle: '始终使用浅色外观',
    ),
    _ThemeOption(
      mode: ThemeMode.dark,
      icon: Icons.dark_mode_rounded,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                '选择 Mori 的显示方式',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
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
                child: Column(
                  children: [
                    for (var index = 0; index < _options.length; index++) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: colors.outlineVariant,
                        ),
                      _ThemeOptionTile(
                        option: _options[index],
                        selected: currentMode == _options[index].mode,
                        onTap: () => _select(context, _options[index].mode),
                      ),
                    ],
                  ],
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

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        option.icon,
        color: selected ? colors.primary : colors.onSurfaceVariant,
      ),
      title: Text(option.title),
      subtitle: Text(option.subtitle),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.primary)
          : const SizedBox(width: 24),
      selected: selected,
      onTap: onTap,
    );
  }
}
