import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/system_context_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemContextSettingsStore {
  SystemContextSettingsStore._();

  static final SystemContextSettingsStore instance =
      SystemContextSettingsStore._();

  static const _key = 'system_context_settings_v1';

  final ValueNotifier<SystemContextSettings> settings =
      ValueNotifier<SystemContextSettings>(SystemContextSettings.defaults);

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null || raw.isEmpty) {
        settings.value = SystemContextSettings.defaults;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        settings.value = SystemContextSettings.defaults;
        return;
      }
      settings.value = SystemContextSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      settings.value = SystemContextSettings.defaults;
    }
  }

  Future<void> save(SystemContextSettings next) async {
    final normalized = next.normalized();
    final previous = settings.value;
    settings.value = normalized;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _key,
        jsonEncode(normalized.toJson()),
      );
      if (!saved) {
        throw StateError('Failed to save system context settings');
      }
    } catch (_) {
      settings.value = previous;
      rethrow;
    }
  }
}
