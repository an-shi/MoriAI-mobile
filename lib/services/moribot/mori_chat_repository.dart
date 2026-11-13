import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/moribot/mori_models.dart';
import 'package:mori_ai/services/moribot/mori_bot_client.dart';
import 'package:mori_ai/services/moribot/mori_cache_store.dart';
import 'package:mori_ai/services/moribot/mori_session_store.dart';

/// Server-backed state for characters, conversations and messages.
///
/// Every list in this repository is a view over MoriBot data. The local cache
/// is only used to paint the first frame and survives as long as the device is
/// paired.
class MoriChatRepository {
  MoriChatRepository({
    MoriBotClient? client,
    MoriCacheStore? cache,
    MoriSessionStore? session,
  }) : _client = client ?? MoriBotClient.instance,
       _cache = cache ?? MoriCacheStore.instance,
       _session = session ?? MoriSessionStore.instance;

  static final MoriChatRepository instance = MoriChatRepository();

  final MoriBotClient _client;
  final MoriCacheStore _cache;
  final MoriSessionStore _session;

  final ValueNotifier<List<MoriCharacter>> characters =
      ValueNotifier<List<MoriCharacter>>(const []);
  final ValueNotifier<List<MoriConversation>> conversations =
      ValueNotifier<List<MoriConversation>>(const []);
  final ValueNotifier<bool> loadingCharacters = ValueNotifier<bool>(false);
  final ValueNotifier<bool> loadingConversations = ValueNotifier<bool>(false);
  final ValueNotifier<bool> loadingMoreConversations = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> hasMoreConversations = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  bool _initialized = false;
  int _conversationOffset = 0;

  Future<void> initialize({bool force = false}) async {
    if (_initialized && !force) {
      return;
    }
    _initialized = true;

    final cachedCharacters = await _cache.loadCharacters();
    final cachedConversations = await _cache.loadConversations();
    if (cachedCharacters.isNotEmpty && characters.value.isEmpty) {
      characters.value = List<MoriCharacter>.unmodifiable(cachedCharacters);
    }
    if (cachedConversations.isNotEmpty && conversations.value.isEmpty) {
      _setConversations(cachedConversations, persist: false);
    }

    await Future.wait([
      refreshCharacters(showLoading: characters.value.isEmpty),
      refreshConversations(showLoading: conversations.value.isEmpty),
    ]);
  }

  Future<void> refreshAll() {
    return Future.wait([
      refreshCharacters(showLoading: false),
      refreshConversations(showLoading: false),
    ]);
  }

  Future<void> refreshCharacters({bool showLoading = true}) async {
    if (showLoading) {
      loadingCharacters.value = true;
    }
    try {
      final result = await _guard(_client.characters);
      characters.value = List<MoriCharacter>.unmodifiable(result);
      await _cache.saveCharacters(result);
      lastError.value = null;
    } on MoriApiException catch (error) {
      lastError.value = error.message;
    } finally {
      loadingCharacters.value = false;
    }
  }

  Future<void> refreshConversations({bool showLoading = true}) async {
    if (showLoading) {
      loadingConversations.value = true;
    }
    try {
      final page = await _guard(
        () => _client.conversations(limit: 50, offset: 0),
      );
      _conversationOffset = page.conversations.length;
      hasMoreConversations.value = page.hasMore;
      _setConversations(page.conversations);
      lastError.value = null;
    } on MoriApiException catch (error) {
      lastError.value = error.message;
    } finally {
      loadingConversations.value = false;
    }
  }

  Future<void> loadMoreConversations() async {
    if (loadingMoreConversations.value || !hasMoreConversations.value) {
      return;
    }
    loadingMoreConversations.value = true;
    try {
      final page = await _guard(
        () => _client.conversations(limit: 50, offset: _conversationOffset),
      );
      _conversationOffset += page.conversations.length;
      hasMoreConversations.value = page.hasMore;
      final byId = {
        for (final conversation in conversations.value)
          conversation.id: conversation,
      };
      for (final conversation in page.conversations) {
        byId[conversation.id] = conversation;
      }
      _setConversations(byId.values.toList(growable: false));
      lastError.value = null;
    } on MoriApiException catch (error) {
      lastError.value = error.message;
    } finally {
      loadingMoreConversations.value = false;
    }
  }

  MoriCharacter? characterById(int id) {
    for (final character in characters.value) {
      if (character.id == id) {
        return character;
      }
    }
    return null;
  }

  MoriCharacter characterForConversation(MoriConversation conversation) {
    return characterById(conversation.characterId) ??
        MoriCharacter(
          id: conversation.characterId,
          name: conversation.characterName,
          avatar: conversation.characterAvatar,
          chatAvailable: conversation.characterAvailable,
        );
  }

  MoriConversation? conversationById(String id) {
    for (final conversation in conversations.value) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  Future<MoriConversation> createConversation(
    int characterId, {
    String title = '',
  }) async {
    final conversation = await _guard(
      () => _client.createConversation(characterId: characterId, title: title),
    );
    await upsertConversation(conversation);
    return conversation;
  }

  Future<MoriConversation> renameConversation(
    String conversationId,
    String title,
  ) async {
    final conversation = await _guard(
      () => _client.renameConversation(conversationId, title),
    );
    await upsertConversation(conversation);
    return conversation;
  }

  Future<void> deleteConversation(String conversationId) async {
    await _guard(() => _client.deleteConversation(conversationId));
    final next = [
      for (final conversation in conversations.value)
        if (conversation.id != conversationId) conversation,
    ];
    _setConversations(next);
    await _cache.deleteMessages(conversationId);
  }

  Future<MoriConversation> refreshConversation(String conversationId) async {
    final conversation = await _guard(
      () => _client.conversation(conversationId),
    );
    await upsertConversation(conversation);
    return conversation;
  }

  Future<void> upsertConversation(MoriConversation conversation) async {
    final byId = {for (final item in conversations.value) item.id: item};
    byId[conversation.id] = conversation;
    _setConversations(byId.values.toList(growable: false));
  }

  Future<List<MoriMessage>> cachedMessages(String conversationId) {
    return _cache.loadMessages(conversationId);
  }

  Future<MoriMessagePage> fetchLatestMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final page = await _guard(
      () => _client.messages(conversationId, limit: limit),
    );
    await _mergeCachedMessages(conversationId, page.messages);
    return page;
  }

  Future<MoriMessagePage> fetchMessagesAfter(
    String conversationId,
    int afterId, {
    int limit = 100,
  }) async {
    final page = await _guard(
      () => _client.messages(conversationId, limit: limit, afterId: afterId),
    );
    await _mergeCachedMessages(conversationId, page.messages);
    return page;
  }

  Future<MoriMessagePage> fetchMessagesBefore(
    String conversationId,
    int beforeId, {
    int limit = 50,
  }) async {
    final page = await _guard(
      () => _client.messages(conversationId, limit: limit, beforeId: beforeId),
    );
    await _mergeCachedMessages(conversationId, page.messages);
    return page;
  }

  Future<MoriSendResult> sendMessage(
    String conversationId, {
    required String content,
    required String clientMessageId,
    bool speech = false,
  }) async {
    final result = await _guard(
      () => _client.sendMessage(
        conversationId,
        content: content,
        clientMessageId: clientMessageId,
        speech: speech,
      ),
    );
    await upsertConversation(result.conversation);
    await _mergeCachedMessages(conversationId, [
      result.userMessage,
      result.assistantMessage,
    ]);
    return result;
  }

  Future<void> saveMessages(
    String conversationId,
    List<MoriMessage> messages,
  ) async {
    await _cache.saveMessages(conversationId, messages);
  }

  Future<void> clearCache() async {
    await _cache.clearAll();
    _initialized = false;
    _conversationOffset = 0;
    hasMoreConversations.value = false;
  }

  void reset() {
    characters.value = const [];
    conversations.value = const [];
    loadingCharacters.value = false;
    loadingConversations.value = false;
    loadingMoreConversations.value = false;
    hasMoreConversations.value = false;
    lastError.value = null;
    _initialized = false;
    _conversationOffset = 0;
  }

  void _setConversations(
    Iterable<MoriConversation> next, {
    bool persist = true,
  }) {
    final sorted = next.toList(growable: false)
      ..sort((a, b) {
        final aTime = a.activityAt;
        final bTime = b.activityAt;
        if (aTime == null && bTime == null) {
          return a.id.compareTo(b.id);
        }
        if (aTime == null) {
          return 1;
        }
        if (bTime == null) {
          return -1;
        }
        return bTime.compareTo(aTime);
      });
    conversations.value = List<MoriConversation>.unmodifiable(sorted);
    if (persist) {
      // The cache is optional and writes are intentionally fire-and-forget.
      _cache.saveConversations(sorted);
    }
  }

  Future<void> _mergeCachedMessages(
    String conversationId,
    List<MoriMessage> fetched,
  ) async {
    if (fetched.isEmpty) {
      return;
    }
    final existing = await _cache.loadMessages(conversationId);
    final byId = {for (final message in existing) message.id: message};
    for (final message in fetched) {
      if (message.id > 0) {
        byId[message.id] = message;
      }
    }
    await _cache.saveMessages(
      conversationId,
      byId.values.toList(growable: false),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MoriApiException catch (error) {
      if (error.isUnauthorized) {
        await _session.invalidate(notice: '设备已被撤销或授权已失效，请重新配对');
        reset();
      }
      rethrow;
    }
  }
}
