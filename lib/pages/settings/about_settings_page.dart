import 'package:flutter/material.dart';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.spa_rounded,
                    size: 40,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mori',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '温柔、真诚的 AI 陪伴助手',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.tag_rounded),
                  title: Text('版本'),
                  trailing: Text('1.0.0'),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.outlineVariant,
                ),
                const ListTile(
                  leading: Icon(Icons.memory_rounded),
                  title: Text('模型服务'),
                  subtitle: Text('由你配置的模型供应商提供'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mori 不会将你的 API Key 上传到除所选供应商之外的任何服务。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
