import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 管理会话列表的置顶状态。
///
/// 角色卡单聊和群聊共用同一套会话 ID。
class PinnedConversationStore {
  PinnedConversationStore._();

  static final PinnedConversationStore instance = PinnedConversationStore._();

  static const _pinnedKey = 'pinned_conversations_v1';

  final ValueNotifier<Set<String>> pinnedIds = ValueNotifier<Set<String>>(
    const {},
  );

  bool isPinned(String conversationId) {
    return pinnedIds.value.contains(conversationId);
  }

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(_pinnedKey) ?? const [];
      pinnedIds.value = Set<String>.unmodifiable({
        for (final id in raw)
          if (id.trim().isNotEmpty) id.trim(),
      });
    } catch (_) {
      pinnedIds.value = const {};
    }
  }

  Future<void> toggle(String conversationId) async {
    await setPinned(conversationId, !isPinned(conversationId));
  }

  Future<void> setPinned(String conversationId, bool pinned) async {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }

    final next = Set<String>.of(pinnedIds.value);
    if (pinned) {
      next.add(id);
    } else {
      next.remove(id);
    }
    if (setEquals(next, pinnedIds.value)) {
      return;
    }

    final previous = pinnedIds.value;
    pinnedIds.value = Set<String>.unmodifiable(next);

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(
        _pinnedKey,
        next.toList(growable: false),
      );
      if (!saved) {
        throw StateError('Failed to save pinned conversations');
      }
    } catch (_) {
      pinnedIds.value = previous;
      rethrow;
    }
  }
}
