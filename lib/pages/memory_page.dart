import 'package:flutter/material.dart';
import 'package:mori_ai/pages/memory/character_card_settings_page.dart';
import 'package:mori_ai/pages/memory/diary_page.dart';
import 'package:mori_ai/pages/memory/memory_dossier_page.dart';
import 'package:mori_ai/pages/memory/memory_library_page.dart';

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          '选择要管理的内容',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _MemoryMenuTile(
                icon: Icons.auto_stories_outlined,
                title: '记忆',
                subtitle: '查看和管理角色记住的事',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MemoryLibraryPage(),
                    ),
                  );
                },
              ),
              Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
              _MemoryMenuTile(
                icon: Icons.badge_outlined,
                title: '人物档案',
                subtitle: '查看对方档案和待跟进话题',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MemoryDossierPage(),
                    ),
                  );
                },
              ),
              Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
              _MemoryMenuTile(
                icon: Icons.menu_book_outlined,
                title: '日记',
                subtitle: '查看角色每天写下的日记',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const DiaryPage()),
                  );
                },
              ),
              Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
              _MemoryMenuTile(
                icon: Icons.style_outlined,
                title: '角色卡',
                subtitle: '管理角色设定与人格',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CharacterCardSettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoryMenuTile extends StatelessWidget {
  const _MemoryMenuTile({
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
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colors.onSecondaryContainer),
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
