import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/memory_extractor.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/utils/memory_search.dart';

/// 从单聊里自动提炼长期记忆，并在需要时召回。
class MemoryService with WidgetsBindingObserver {
  MemoryService._({MemoryExtractor? extractor, DateTime Function()? now})
    : _extractor = extractor ?? MemoryExtractor(),
      _now = now ?? DateTime.now;

  @visibleForTesting
  MemoryService.test({MemoryExtractor? extractor, DateTime Function()? now})
    : this._(extractor: extractor, now: now);

  static final MemoryService instance = MemoryService._();

  static const _checkInterval = Duration(minutes: 1);
  static const _retryDelay = Duration(minutes: 30);
  static const _maxBatchMessages = 40;
  static const _bootstrapWindow = 40;

  final MemoryExtractor _extractor;
  final DateTime Function() _now;
  final Set<String> _processing = {};

  Timer? _timer;
  bool _started = false;
  bool _appActive = true;
  bool _checking = false;
  DateTime? _lastCheckAt;
  DateTime? _lastErrorAt;
  String? _lastError;

  bool get isRunning => _started && _appActive;

  DateTime? get lastCheckAt => _lastCheckAt;

  DateTime? get lastErrorAt => _lastErrorAt;

  String? get lastError => _lastError;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    MemoryStore.instance.settings.addListener(_handleSettingsChanged);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _scheduleTimer();
    unawaited(_checkAll());
  }

  @visibleForTesting
  void stop() {
    if (!_started) {
      return;
    }
    _started = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    MemoryStore.instance.settings.removeListener(_handleSettingsChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) {
      return;
    }
    _appActive = active;
    if (active) {
      _scheduleTimer();
      unawaited(_checkAll());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> checkNow() async {
    final wasStarted = _started;
    _started = true;
    _appActive = true;
    try {
      await _checkAll();
    } finally {
      _started = wasStarted;
    }
  }

  @visibleForTesting
  Future<void> runCheckForTest() => checkNow();

  /// 手动整理某个角色的记忆，不等聊天闲置，最多处理两批消息。
  Future<int> extractNow(String characterId) async {
    final character = CharacterStore.instance.cardById(characterId);
    if (character == null) {
      throw const MemoryException('角色卡不存在或已被删除。');
    }
    final history = await ChatHistoryStore.instance.loadFor(
      character.id,
      includeImages: false,
    );
    var total = 0;
    for (var batch = 0; batch < 2; batch++) {
      final state = MemoryStore.instance.stateFor(character.id);
      final pending = _pendingMessages(character.id, history, state);
      if (pending.isEmpty) {
        if (total == 0) {
          throw const MemoryException('还没有新的聊天可以整理。');
        }
        break;
      }
      if (pending.length < 2) {
        if (total == 0) {
          throw const MemoryException('聊天内容太少，暂时不用整理。');
        }
        break;
      }
      total += await _extractBatch(character, pending, now: _now());
    }
    return total;
  }

  void _scheduleTimer() {
    _timer?.cancel();
    if (!_started || !_appActive) {
      return;
    }
    _timer = Timer.periodic(_checkInterval, (_) {
      unawaited(_checkAll());
    });
  }

  void _handleSettingsChanged() {
    if (_started && _appActive) {
      unawaited(_checkAll());
    }
  }

  Future<void> _checkAll() async {
    if (!_started || !_appActive || _checking) {
      return;
    }
    final settings = MemoryStore.instance.settings.value;
    if (!settings.enabled || !settings.autoExtract) {
      return;
    }
    if (!_extractor.isConfigured) {
      return;
    }

    _checking = true;
    try {
      final now = _now();
      _lastCheckAt = now;
      for (final character in CharacterStore.instance.cards.value) {
        if (_processing.contains(character.id)) {
          continue;
        }
        final state = MemoryStore.instance.stateFor(character.id);
        if (state.nextRetryAtMs > now.millisecondsSinceEpoch) {
          continue;
        }
        final summary = await ChatHistoryStore.instance.summaryFor(
          character.id,
        );
        final lastMessageAt = summary?.createdAt;
        if (lastMessageAt != null &&
            now.difference(lastMessageAt).inMinutes <
                settings.extractIdleMinutes) {
          continue;
        }
        final history = await ChatHistoryStore.instance.loadFor(
          character.id,
          includeImages: false,
        );
        final pending = _pendingMessages(character.id, history, state);
        if (pending.length < settings.extractMinMessages) {
          continue;
        }
        try {
          await _extractBatch(character, pending, now: now);
          _lastError = null;
          _lastErrorAt = null;
        } catch (error) {
          _lastError = _messageOf(error);
          _lastErrorAt = now;
        }
        // 每轮只整理一个角色，避免同时发起多个模型请求。
        break;
      }
    } finally {
      _checking = false;
    }
  }

  List<ChatMessage> _pendingMessages(
    String characterId,
    List<ChatMessage> history,
    MemoryExtractionState state,
  ) {
    final valid = history
        .where((message) => message.content.trim().isNotEmpty)
        .toList(growable: false);
    if (valid.isEmpty) {
      return const [];
    }
    var start = max(0, valid.length - _bootstrapWindow);
    final cursor = state.lastProcessedMessageId;
    if (cursor.isNotEmpty) {
      final index = valid.indexWhere((message) => message.id == cursor);
      if (index >= 0) {
        start = index + 1;
      }
    }
    if (start >= valid.length) {
      return const [];
    }
    return valid.sublist(start);
  }

  Future<int> _extractBatch(
    CharacterProfile character,
    List<ChatMessage> pending, {
    required DateTime now,
  }) async {
    if (_processing.contains(character.id)) {
      throw const MemoryException('这个角色正在整理记忆，请稍后再试。');
    }
    _processing.add(character.id);
    final before = MemoryStore.instance.stateFor(character.id);
    final batch = pending.length > _maxBatchMessages
        ? pending.take(_maxBatchMessages).toList(growable: false)
        : pending;
    try {
      final existing = MemoryStore.instance.entriesFor(character.id);
      final result = await _extractor.extract(
        character: character,
        messages: batch,
        existing: existing,
      );
      if (CharacterStore.instance.cardById(character.id) == null) {
        throw const MemoryException('角色卡不存在或已被删除。');
      }
      final current = List<MemoryEntry>.of(existing);
      var changed = 0;
      for (final candidate in result.candidates) {
        changed += await _applyCandidate(
          character: character,
          candidate: candidate,
          current: current,
          now: now,
        );
      }
      await MemoryStore.instance.saveState(
        character.id,
        before.copyWith(
          lastProcessedMessageId: batch.last.id,
          lastProcessedAtMs: now.millisecondsSinceEpoch,
          lastError: '',
          nextRetryAtMs: 0,
        ),
      );
      return changed;
    } catch (error) {
      await MemoryStore.instance.saveState(
        character.id,
        before.copyWith(
          lastProcessedAtMs: now.millisecondsSinceEpoch,
          lastError: _messageOf(error),
          nextRetryAtMs: now.add(_retryDelay).millisecondsSinceEpoch,
        ),
      );
      rethrow;
    } finally {
      _processing.remove(character.id);
    }
  }

  Future<int> _applyCandidate({
    required CharacterProfile character,
    required MemoryCandidate candidate,
    required List<MemoryEntry> current,
    required DateTime now,
  }) async {
    final existingIndex = current.indexWhere(
      (entry) => entry.isActive && isSameMemoryFact(entry.text, candidate.text),
    );
    final nowMs = now.millisecondsSinceEpoch;
    final userName = UserProfileStore.instance.profile.value.name.trim();
    if (existingIndex >= 0) {
      final existing = current[existingIndex];
      final tags = <String>{
        ...existing.tags,
        ...candidate.tags,
      }.take(MemoryEntry.maxTags).toList(growable: false);
      final updated = existing.copyWith(
        text: candidate.text.length > existing.text.length
            ? candidate.text
            : existing.text,
        category: existing.category == MemoryCategory.fact
            ? candidate.category
            : existing.category,
        importance: max(existing.importance, candidate.importance),
        tags: tags,
        updatedAtMs: nowMs,
        aboutName: userName.isEmpty ? existing.aboutName : userName,
      );
      current[existingIndex] = updated;
      await MemoryStore.instance.saveEntry(updated);
      return 1;
    }

    final conflicts = current
        .where(
          (entry) =>
              entry.isActive &&
              memorySimilarity(entry.text, candidate.text) >= 0.6 &&
              memoryConflicting(entry.text, candidate.text),
        )
        .toList(growable: false);
    for (final old in conflicts) {
      if (old.importance > candidate.importance) {
        return 0;
      }
    }
    for (final old in conflicts) {
      await MemoryStore.instance.archiveEntry(old.id, archivedAtMs: nowMs);
      current.remove(old);
    }

    final entry = MemoryEntry(
      id: 'mem_${character.id}_${now.microsecondsSinceEpoch}_${current.length}',
      characterId: character.id,
      text: candidate.text,
      category: candidate.category,
      importance: candidate.importance,
      tags: candidate.tags,
      source: MemorySource.auto,
      conversationId: character.id,
      aboutName: userName,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    ).normalized();
    current.add(entry);
    await MemoryStore.instance.saveEntry(entry);
    return 1;
  }

  String _messageOf(Object error) {
    if (error is MemoryException) {
      return error.message;
    }
    final message = error.toString().trim();
    return message.isEmpty ? '整理记忆失败。' : message;
  }
}
