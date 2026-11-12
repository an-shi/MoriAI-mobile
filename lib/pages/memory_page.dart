import 'package:flutter/material.dart';
import 'package:mori_ai/pages/memory/character_card_settings_page.dart';
import 'package:mori_ai/pages/memory/diary_page.dart';
import 'package:mori_ai/pages/memory/memory_dossier_page.dart';
import 'package:mori_ai/pages/memory/memory_library_page.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: MoriTheme.pagePadding,
      children: [
        const MoriSectionHeader(
          label: '选择要管理的内容',
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
        ),
        MoriSettingsGroup(
          children: [
            MoriSettingsTile(
              icon: MoriIcons.memory,
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
            MoriSettingsTile(
              icon: MoriIcons.badge,
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
            MoriSettingsTile(
              icon: MoriIcons.diary,
              title: '日记',
              subtitle: '查看角色每天写下的日记',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DiaryPage()),
                );
              },
            ),
            MoriSettingsTile(
              icon: MoriIcons.style,
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
        const MoriSectionHeader(label: '小提示'),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '记忆、人物档案和日记只保存在本机，随时可以在这里查看或清理。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
