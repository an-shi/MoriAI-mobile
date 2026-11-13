import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/pages/moribot/account_page.dart';
import 'package:mori_ai/pages/moribot/character_list_page.dart';
import 'package:mori_ai/pages/moribot/chat_page.dart';
import 'package:mori_ai/pages/moribot/conversation_list_page.dart';
import 'package:mori_ai/services/moribot/mori_chat_repository.dart';
import 'package:mori_ai/services/moribot/mori_realtime_service.dart';
import 'package:mori_ai/services/moribot/mori_session_store.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _titles = ['对话', '角色', '设置'];

  static const _pages = [
    MoriConversationListPage(),
    MoriCharacterListPage(),
    MoriAccountPage(),
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(MoriChatRepository.instance.initialize());
    unawaited(MoriRealtimeService.instance.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(MoriSessionStore.instance.refreshMe(silent: true));
      unawaited(MoriChatRepository.instance.refreshAll());
      unawaited(MoriRealtimeService.instance.start());
    }
  }

  Future<void> _createConversation() async {
    final conversation = await pickAndCreateMoriConversation(context);
    if (conversation == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MoriChatPage(conversation: conversation),
      ),
    );
    if (mounted) {
      await MoriChatRepository.instance.refreshConversations(
        showLoading: false,
      );
    }
  }

  Future<void> _refreshCurrentTab() async {
    if (_currentIndex == 1) {
      await MoriChatRepository.instance.refreshCharacters(showLoading: false);
    } else {
      await MoriChatRepository.instance.refreshConversations(
        showLoading: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isChatTab = _currentIndex == 0;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: _AccountBadge(onTap: () => setState(() => _currentIndex = 2)),
        ),
        title: Text(_titles[_currentIndex]),
        centerTitle: false,
        actions: [
          if (isChatTab)
            IconButton(
              tooltip: '新建对话',
              onPressed: _createConversation,
              icon: const Icon(MoriIcons.plus, size: 22),
            )
          else if (_currentIndex == 1)
            IconButton(
              tooltip: '刷新角色卡',
              onPressed: _refreshCurrentTab,
              icon: const Icon(MoriIcons.refresh, size: 21),
            ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: DecoratedBox(
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
            if (index == 1 &&
                MoriChatRepository.instance.characters.value.isEmpty) {
              unawaited(
                MoriChatRepository.instance.refreshCharacters(
                  showLoading: true,
                ),
              );
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(MoriIcons.chat),
              selectedIcon: Icon(MoriIcons.chat),
              label: '对话',
            ),
            NavigationDestination(
              icon: Icon(MoriIcons.user),
              selectedIcon: Icon(MoriIcons.user),
              label: '角色',
            ),
            NavigationDestination(
              icon: Icon(MoriIcons.settings),
              selectedIcon: Icon(MoriIcons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ValueListenableBuilder<MoriSessionSnapshot>(
      valueListenable: MoriSessionStore.instance.snapshot,
      builder: (context, snapshot, _) {
        final name = snapshot.user?.effectiveDisplayName ?? 'Mori';
        final initial = name.trim().isEmpty
            ? 'M'
            : String.fromCharCode(name.trim().runes.first);
        return Tooltip(
          message: '账户与连接',
          child: InkWell(
            borderRadius: BorderRadius.circular(MoriRadius.pill),
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer,
                    colors.primary.withValues(alpha: 0.62),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
