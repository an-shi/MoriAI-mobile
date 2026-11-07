import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 管理应用外观（跟随系统 / 浅色 / 深色）。
class ThemeStore {
  ThemeStore._();

  static final ThemeStore instance = ThemeStore._();

  static const _prefsKey = 'theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      themeMode.value = _parse(preferences.getString(_prefsKey));
    } catch (_) {
      themeMode.value = ThemeMode.system;
    }
  }

  Future<void> save(ThemeMode mode) async {
    final previous = themeMode.value;
    if (previous == mode) {
      return;
    }

    themeMode.value = mode;

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(_prefsKey, mode.name);
      if (!saved) {
        throw StateError('Failed to save theme mode');
      }
    } catch (_) {
      themeMode.value = previous;
      rethrow;
    }
  }

  ThemeMode _parse(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
