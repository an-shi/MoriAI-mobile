import 'package:flutter/material.dart';
import 'package:mori_ai/pages/chat_page.dart';
import 'package:mori_ai/pages/memory_page.dart';
import 'package:mori_ai/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _titles = ['对话', '记忆与人格卡', '设置'];

  static const _pages = [ChatPage(), MemoryPage(), SettingsPage()];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex]), centerTitle: false),
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
                  label: '记忆与人格卡',
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
