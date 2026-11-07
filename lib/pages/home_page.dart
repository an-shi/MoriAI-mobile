import 'package:flutter/material.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/pages/chat_list_page.dart';
import 'package:mori_ai/pages/group/group_chat_detail_page.dart';
import 'package:mori_ai/pages/group/new_group_chat_page.dart';
import 'package:mori_ai/pages/memory_page.dart';
import 'package:mori_ai/pages/profile/personal_settings_page.dart';
import 'package:mori_ai/pages/settings_page.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/widgets/user_avatar.dart';
import 'package:mori_ai/widgets/user_profile_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _titles = ['对话', '记忆与角色卡', '设置'];

  static const _pages = [ChatListPage(), MemoryPage(), SettingsPage()];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  bool get _isChatTab => _currentIndex == 0;

  Future<void> _openPersonalSettings() async {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PersonalSettingsPage()),
      );
    });
  }

  Future<void> _openCreateGroup() async {
    final group = await Navigator.of(context).push<GroupProfile>(
      MaterialPageRoute<GroupProfile>(builder: (_) => const NewGroupChatPage()),
    );
    if (group != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupChatDetailPage(group: group),
        ),
      );
    }
  }

  void _handleAddMenu(String value) {
    if (value == 'group') {
      _openCreateGroup();
    }
  }

  Widget _buildAddAction() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.add_rounded),
      tooltip: '更多',
      onSelected: _handleAddMenu,
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'group',
          child: Row(
            children: [
              Icon(Icons.group_add_outlined),
              SizedBox(width: 10),
              Text('新建群聊'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserAction() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileStore.instance.profile,
      builder: (context, profile, _) {
        return Tooltip(
          message: '个人资料',
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(profile: profile, size: 30),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 64),
                    child: Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leadingWidth: _isChatTab ? 132 : null,
        leading: _isChatTab ? _buildUserAction() : null,
        title: Text(_titles[_currentIndex]),
        centerTitle: false,
        actions: _isChatTab ? [_buildAddAction()] : null,
      ),
      drawer: _isChatTab
          ? UserProfileDrawer(onOpenProfile: _openPersonalSettings)
          : null,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: keyboardVisible
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                if (index == _currentIndex) {
                  return;
                }
                setState(() => _currentIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: '对话',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories_rounded),
                  label: '记忆与角色卡',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: '设置',
                ),
              ],
            ),
    );
  }
}
