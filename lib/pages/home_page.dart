import 'package:flutter/material.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/pages/chat_detail_page.dart';
import 'package:mori_ai/pages/chat_list_page.dart';
import 'package:mori_ai/pages/group/group_chat_detail_page.dart';
import 'package:mori_ai/pages/group/new_group_chat_page.dart';
import 'package:mori_ai/pages/memory_page.dart';
import 'package:mori_ai/pages/moments_page.dart';
import 'package:mori_ai/pages/profile/personal_settings_page.dart';
import 'package:mori_ai/pages/settings_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/local_notification_service.dart';
import 'package:mori_ai/services/unread_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/widgets/user_avatar.dart';
import 'package:mori_ai/widgets/user_profile_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _titles = ['对话', '记忆与角色卡', '动态'];

  static const _pages = [ChatListPage(), MemoryPage(), MomentsPage()];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  bool get _isChatTab => _currentIndex == 0;

  bool _openingNotification = false;

  @override
  void initState() {
    super.initState();
    UnreadStore.instance.counts.addListener(_handleUnreadChanged);
    LocalNotificationService.instance.pendingConversationId.addListener(
      _handleNotificationNavigation,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationNavigation();
    });
  }

  @override
  void dispose() {
    UnreadStore.instance.counts.removeListener(_handleUnreadChanged);
    LocalNotificationService.instance.pendingConversationId.removeListener(
      _handleNotificationNavigation,
    );
    super.dispose();
  }

  void _handleUnreadChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleNotificationNavigation() async {
    if (_openingNotification) {
      return;
    }
    final conversationId =
        LocalNotificationService.instance.pendingConversationId.value;
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }
    LocalNotificationService.instance.pendingConversationId.value = null;
    if (!mounted || CharacterStore.instance.cardById(conversationId) == null) {
      return;
    }
    _openingNotification = true;
    setState(() => _currentIndex = 0);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailPage(characterId: conversationId),
      ),
    );
    _openingNotification = false;
  }

  Future<void> _openDrawerPage(Widget page) async {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    });
  }

  Future<void> _openPersonalSettings() {
    return _openDrawerPage(const PersonalSettingsPage());
  }

  Future<void> _openSettings() {
    return _openDrawerPage(const SettingsPage());
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
      icon: const Icon(MoriIcons.plus, size: 23),
      tooltip: '更多',
      splashRadius: 22,
      onSelected: _handleAddMenu,
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'group',
          child: Row(
            children: [
              Icon(MoriIcons.groupAdd, size: 18),
              SizedBox(width: 12),
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
        final colors = Theme.of(context).colorScheme;
        return Tooltip(
          message: '个人资料',
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                ),
                child: UserAvatar(profile: profile, size: 32),
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
    final unread = UnreadStore.instance.totalCount;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leadingWidth: _isChatTab ? 64 : null,
        leading: _isChatTab ? _buildUserAction() : null,
        title: Text(_titles[_currentIndex]),
        centerTitle: false,
        actions: _isChatTab ? [_buildAddAction()] : null,
      ),
      drawer: _isChatTab
          ? UserProfileDrawer(
              onOpenProfile: _openPersonalSettings,
              onOpenSettings: _openSettings,
            )
          : null,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: keyboardVisible
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  if (index == _currentIndex) {
                    return;
                  }
                  setState(() => _currentIndex = index);
                },
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: const Icon(MoriIcons.chat),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: const Icon(MoriIcons.chat),
                    ),
                    label: '对话',
                  ),
                  const NavigationDestination(
                    icon: Icon(MoriIcons.memory),
                    selectedIcon: Icon(MoriIcons.memory),
                    label: '记忆与角色卡',
                  ),
                  const NavigationDestination(
                    icon: Icon(MoriIcons.moments),
                    selectedIcon: Icon(MoriIcons.moments),
                    label: '动态',
                  ),
                ],
              ),
            ),
    );
  }
}
