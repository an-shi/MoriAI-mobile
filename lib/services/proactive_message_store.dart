import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';
import 'package:mori_ai/models/proactive_message_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProactiveMessageStore {
  ProactiveMessageStore._();

  static final ProactiveMessageStore instance = ProactiveMessageStore._();

  static const _settingsKey = 'proactive_message_settings_v1';
  static const _statePrefix = 'proactive_message_state_v1_';

  final ValueNotifier<ProactiveMessageSettings> settings =
      ValueNotifier<ProactiveMessageSettings>(
        ProactiveMessageSettings.defaults,
      );

  final Map<String, ProactiveMessageState> _stateCache = {};

  Future<void> load() async {
    _stateCache.clear();
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_settingsKey);
      if (raw == null || raw.isEmpty) {
        settings.value = ProactiveMessageSettings.defaults;
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        settings.value = ProactiveMessageSettings.defaults;
        return;
      }
      settings.value = ProactiveMessageSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      settings.value = ProactiveMessageSettings.defaults;
    }
  }

  Future<void> saveSettings(ProactiveMessageSettings next) async {
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
        throw StateError('Failed to save proactive message settings');
      }
    } catch (_) {
      settings.value = previous;
      rethrow;
    }
  }

  Future<ProactiveMessageState?> loadState(String conversationId) async {
    final cached = _stateCache[conversationId];
    if (cached != null) {
      return cached;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_stateKey(conversationId));
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final state = ProactiveMessageState.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      _stateCache[conversationId] = state;
      return state;
    } catch (_) {
      return null;
    }
  }

  ProactiveMessageState? cachedState(String conversationId) {
    return _stateCache[conversationId];
  }

  Future<void> saveState(
    String conversationId,
    ProactiveMessageState next,
  ) async {
    final normalized = next.normalized();
    _stateCache[conversationId] = normalized;

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _stateKey(conversationId),
        jsonEncode(normalized.toJson()),
      );
      if (!saved) {
        throw StateError('Failed to save proactive message state');
      }
    } catch (_) {
      // 自动消息状态保存失败时保留内存状态，下次保存会继续尝试。
    }
  }

  Future<void> deleteState(String conversationId) async {
    _stateCache.remove(conversationId);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_stateKey(conversationId));
    } catch (_) {
      // 忽略自动消息状态清理失败。
    }
  }

  String _stateKey(String conversationId) => '$_statePrefix$conversationId';
}
