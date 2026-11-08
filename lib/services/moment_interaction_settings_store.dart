import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/moment_interaction_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MomentInteractionSettingsStore {
  MomentInteractionSettingsStore._();

  static final MomentInteractionSettingsStore instance =
      MomentInteractionSettingsStore._();

  static const _settingsKey = 'moment_interaction_settings_v1';

  final ValueNotifier<MomentInteractionSettings> settings =
      ValueNotifier<MomentInteractionSettings>(
        MomentInteractionSettings.defaults,
      );

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_settingsKey);
      if (raw == null || raw.isEmpty) {
        settings.value = MomentInteractionSettings.defaults;
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        settings.value = MomentInteractionSettings.defaults;
        return;
      }
      settings.value = MomentInteractionSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      settings.value = MomentInteractionSettings.defaults;
    }
  }

  Future<void> save(MomentInteractionSettings next) async {
    final normalized = next.normalized();
    final previous = settings.value;
    settings.value = normalized;

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _settingsKey,
        jsonEncode(normalized.toJson()),
      );
      if (!saved) {
        throw StateError('Failed to save moment interaction settings');
      }
    } catch (_) {
      settings.value = previous;
      rethrow;
    }
  }
}
