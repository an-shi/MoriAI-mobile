import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/chat_burst_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatBurstSettingsStore {
  ChatBurstSettingsStore._();

  static final ChatBurstSettingsStore instance = ChatBurstSettingsStore._();

  static const _settingsKey = 'chat_burst_settings_v1';

  final ValueNotifier<ChatBurstSettings> settings =
      ValueNotifier<ChatBurstSettings>(ChatBurstSettings.defaults);

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_settingsKey);
      if (raw == null || raw.isEmpty) {
        settings.value = ChatBurstSettings.defaults;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        settings.value = ChatBurstSettings.defaults;
        return;
      }
      settings.value = ChatBurstSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      settings.value = ChatBurstSettings.defaults;
    }
  }

  Future<void> save(ChatBurstSettings next) async {
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
        throw StateError('Failed to save chat burst settings');
      }
    } catch (_) {
      settings.value = previous;
      rethrow;
    }
  }

  Future<void> setGlobalTendency(ChatBurstTendency tendency) {
    return save(settings.value.copyWith(globalTendency: tendency));
  }

  Future<void> setCharacterTendency(
    String characterId,
    ChatBurstTendency tendency,
  ) {
    final overrides = Map<String, ChatBurstTendency>.of(
      settings.value.characterTendencies,
    );
    if (tendency == ChatBurstTendency.followGlobal) {
      overrides.remove(characterId);
    } else {
      overrides[characterId] = tendency;
    }
    return save(settings.value.copyWith(characterTendencies: overrides));
  }

  Future<void> setTendencyRange(
    ChatBurstTendency tendency,
    ChatBurstRange range,
  ) {
    if (tendency != ChatBurstTendency.natural &&
        tendency != ChatBurstTendency.active) {
      return Future<void>.value();
    }
    final ranges = Map<ChatBurstTendency, ChatBurstRange>.of(
      settings.value.tendencyRanges,
    );
    ranges[tendency] = range.normalized();
    return save(settings.value.copyWith(tendencyRanges: ranges));
  }
}
