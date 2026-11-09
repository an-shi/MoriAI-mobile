import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 按会话保存未读数。当前主要用于角色主动消息。
class UnreadStore {
  UnreadStore._();

  static final UnreadStore instance = UnreadStore._();

  static const _key = 'unread_conversations_v1';

  final ValueNotifier<Map<String, int>> counts =
      ValueNotifier<Map<String, int>>(const {});

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null || raw.isEmpty) {
        counts.value = const {};
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        counts.value = const {};
        return;
      }
      final result = <String, int>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! int) {
          continue;
        }
        final id = (entry.key as String).trim();
        final count = entry.value as int;
        if (id.isEmpty || count <= 0) {
          continue;
        }
        result[id] = count;
      }
      counts.value = Map<String, int>.unmodifiable(result);
    } catch (_) {
      counts.value = const {};
    }
  }

  int countFor(String conversationId) {
    return counts.value[conversationId.trim()] ?? 0;
  }

  bool hasUnread(String conversationId) => countFor(conversationId) > 0;

  int get totalCount {
    var total = 0;
    for (final count in counts.value.values) {
      total += count;
    }
    return total;
  }

  Future<void> markUnread(String conversationId, {int count = 1}) async {
    final id = conversationId.trim();
    if (id.isEmpty || count <= 0) {
      return;
    }
    final next = Map<String, int>.from(counts.value);
    next[id] = (next[id] ?? 0) + count;
    counts.value = Map<String, int>.unmodifiable(next);
    await _persist();
  }

  Future<void> markRead(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty || !counts.value.containsKey(id)) {
      return;
    }
    final next = Map<String, int>.from(counts.value)..remove(id);
    counts.value = Map<String, int>.unmodifiable(next);
    await _persist();
  }

  Future<void> clearForConversation(String conversationId) {
    return markRead(conversationId);
  }

  Future<void> _persist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key, jsonEncode(counts.value));
    } catch (_) {
      // 未读数保存失败不阻断聊天。
    }
  }
}
