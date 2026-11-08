import 'package:shared_preferences/shared_preferences.dart';

class ChatQueueStore {
  ChatQueueStore._();

  static final ChatQueueStore instance = ChatQueueStore._();

  static const _keyPrefix = 'chat_queue_v1_';

  Future<List<String>> loadFor(String conversationId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw =
          preferences.getStringList(_prefsKey(conversationId)) ?? const [];
      final result = <String>[];
      final ids = <String>{};
      for (final id in raw) {
        final normalized = id.trim();
        if (normalized.isNotEmpty && ids.add(normalized)) {
          result.add(normalized);
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveFor(String conversationId, List<String> messageIds) async {
    try {
      final ids = <String>[];
      final seen = <String>{};
      for (final id in messageIds) {
        final normalized = id.trim();
        if (normalized.isNotEmpty && seen.add(normalized)) {
          ids.add(normalized);
        }
      }

      final preferences = await SharedPreferences.getInstance();
      if (ids.isEmpty) {
        await preferences.remove(_prefsKey(conversationId));
      } else {
        await preferences.setStringList(_prefsKey(conversationId), ids);
      }
    } catch (_) {
      // 队列持久化失败不阻断当前对话。
    }
  }

  String _prefsKey(String conversationId) {
    return '$_keyPrefix$conversationId';
  }
}
