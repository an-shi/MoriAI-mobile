import 'dart:convert';

import 'package:mori_ai/models/moribot/mori_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rebuildable local cache for server-owned data.
///
/// MoriBot remains the source of truth. The cache is intentionally simple: it
/// speeds up cold starts and keeps the last page of a conversation visible
/// while the network request is in flight.
class MoriCacheStore {
  MoriCacheStore._();

  static final MoriCacheStore instance = MoriCacheStore._();

  static const _prefix = 'moribot_cache_v1_';
  static const _charactersKey = '${_prefix}characters';
  static const _conversationsKey = '${_prefix}conversations';
  static const _messagesPrefix = '${_prefix}messages_';
  static const _maxCachedMessages = 500;

  Future<List<MoriCharacter>> loadCharacters() async {
    final items = await _loadList(_charactersKey);
    final characters = <MoriCharacter>[];
    for (final item in items) {
      final map = readMoriObject(item);
      if (map != null) {
        characters.add(MoriCharacter.fromJson(map));
      }
    }
    return characters;
  }

  Future<void> saveCharacters(List<MoriCharacter> characters) {
    return _saveList(_charactersKey, [
      for (final character in characters) character.toJson(),
    ]);
  }

  Future<List<MoriConversation>> loadConversations() async {
    final items = await _loadList(_conversationsKey);
    final conversations = <MoriConversation>[];
    for (final item in items) {
      final map = readMoriObject(item);
      if (map != null) {
        conversations.add(MoriConversation.fromJson(map));
      }
    }
    return conversations;
  }

  Future<void> saveConversations(List<MoriConversation> conversations) {
    return _saveList(_conversationsKey, [
      for (final conversation in conversations) conversation.toJson(),
    ]);
  }

  Future<List<MoriMessage>> loadMessages(String conversationId) async {
    final items = await _loadList(_messagesKey(conversationId));
    final messages = <MoriMessage>[];
    for (final item in items) {
      final map = readMoriObject(item);
      if (map != null) {
        messages.add(MoriMessage.fromJson(map));
      }
    }
    messages.sort((a, b) => a.id.compareTo(b.id));
    return messages;
  }

  Future<void> saveMessages(
    String conversationId,
    List<MoriMessage> messages,
  ) async {
    final persisted = [
      for (final message in messages)
        if (message.id > 0 && message.status == MoriMessageStatus.sent)
          message.toJson(),
    ]..sort((a, b) => readMoriInt(a['id']).compareTo(readMoriInt(b['id'])));
    final start = persisted.length > _maxCachedMessages
        ? persisted.length - _maxCachedMessages
        : 0;
    await _saveList(_messagesKey(conversationId), persisted.sublist(start));
  }

  Future<void> deleteMessages(String conversationId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_messagesKey(conversationId));
    } catch (_) {
      // The cache is optional and may always be rebuilt from the server.
    }
  }

  Future<void> clearAll() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final keys = preferences
          .getKeys()
          .where((key) => key.startsWith(_prefix))
          .toList(growable: false);
      for (final key in keys) {
        await preferences.remove(key);
      }
    } catch (_) {
      // Ignore cache cleanup failures.
    }
  }

  // Kept as list<dynamic> so old cache entries with unknown fields still load.
  Future<List<Object?>> _loadList(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(key);
      if (raw == null || raw.isEmpty) {
        return const [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const [];
      }
      final data = decoded['items'];
      return data is List ? data : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveList(String key, List<Object?> items) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        key,
        jsonEncode({'version': 1, 'items': items}),
      );
    } catch (_) {
      // A failed cache write must never block the UI or a server request.
    }
  }

  String _messagesKey(String conversationId) =>
      '$_messagesPrefix${Uri.encodeComponent(conversationId)}';
}
