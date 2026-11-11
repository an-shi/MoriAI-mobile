import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/chat_reply_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatReplySettingsStore {
  ChatReplySettingsStore._();

  static final ChatReplySettingsStore instance = ChatReplySettingsStore._();

  static const _key = 'chat_reply_settings_v1';

  final ValueNotifier<ChatReplySettings> settings =
      ValueNotifier<ChatReplySettings>(ChatReplySettings.defaults);

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null || raw.isEmpty) {
        settings.value = ChatReplySettings.defaults;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        settings.value = ChatReplySettings.defaults;
        return;
      }
      settings.value = ChatReplySettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      settings.value = ChatReplySettings.defaults;
    }
  }

  Future<void> save(ChatReplySettings next) async {
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
        throw StateError('Failed to save chat reply settings');
      }
    } catch (_) {
      settings.value = previous;
      rethrow;
    }
  }
}
