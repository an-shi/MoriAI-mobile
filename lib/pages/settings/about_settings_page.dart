import 'package:flutter/material.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 36, 16, 36),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primaryContainer,
                        colors.primary.withValues(alpha: 0.72),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    MoriIcons.leaf,
                    size: 42,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Mori',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '温柔、真诚的 AI 陪伴助手',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const MoriSectionHeader(label: '应用信息'),
          const MoriSettingsGroup(
            children: [
              MoriSettingsTile(
                icon: MoriIcons.tag,
                title: '版本',
                trailing: Text('1.0.0'),
                showChevron: false,
              ),
              MoriSettingsTile(
                icon: MoriIcons.cpu,
                title: '模型服务',
                subtitle: '由你配置的模型供应商提供',
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Mori 不会将你的 API Key 上传到除所选供应商之外的任何服务。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
