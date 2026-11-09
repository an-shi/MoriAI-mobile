import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/group_memory.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/group_memory_extractor.dart';
import 'package:mori_ai/services/group_memory_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/utils/memory_search.dart';

/// 从群聊里自动整理群公共记忆和群印象。
class GroupMemoryService with WidgetsBindingObserver {
  GroupMemoryService._({
    GroupMemoryExtractor? extractor,
    DateTime Function()? now,
  }) : _extractor = extractor ?? GroupMemoryExtractor(),
       _now = now ?? DateTime.now;

  @visibleForTesting
  GroupMemoryService.test({
    GroupMemoryExtractor? extractor,
    DateTime Function()? now,
  }) : this._(extractor: extractor, now: now);

  static final GroupMemoryService instance = GroupMemoryService._();

  static const _checkInterval = Duration(minutes: 1);
  static const _retryDelay = Duration(minutes: 30);
  static const _maxBatchMessages = 40;
  static const _bootstrapWindow = 40;

  final GroupMemoryExtractor _extractor;
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

  /// 手动整理某个群的公共记忆，不等群聊闲置，最多处理两批消息。
  Future<int> extractNow(String groupId) async {
    final group = GroupStore.instance.groupById(groupId);
    if (group == null) {
      throw const MemoryException('群聊不存在或已被删除。');
    }
    final history = await ChatHistoryStore.instance.loadFor(
      group.id,
      includeImages: false,
    );
    var total = 0;
    for (var batch = 0; batch < 2; batch++) {
      final state = GroupMemoryStore.instance.stateFor(group.id);
      final pending = _pendingMessages(group.id, history, state);
      if (pending.isEmpty) {
        if (total == 0) {
          throw const MemoryException('这个群还没有新的聊天可以整理。');
        }
        break;
      }
      if (pending.length < 2) {
        if (total == 0) {
          throw const MemoryException('群聊内容太少，暂时不用整理。');
        }
        break;
      }
      total += await _extractBatch(group, pending, now: _now());
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
    if (!settings.enabled ||
        !settings.groupMemoryEnabled ||
        !settings.autoExtract) {
      return;
    }
    if (!_extractor.isConfigured) {
      return;
    }

    _checking = true;
    try {
      final now = _now();
      _lastCheckAt = now;
      for (final group in GroupStore.instance.groups.value) {
        if (_processing.contains(group.id)) {
          continue;
        }
        final state = GroupMemoryStore.instance.stateFor(group.id);
        if (state.nextRetryAtMs > now.millisecondsSinceEpoch) {
          continue;
        }
        final summary = await ChatHistoryStore.instance.summaryFor(group.id);
        final lastMessageAt = summary?.createdAt;
        if (lastMessageAt != null &&
            now.difference(lastMessageAt).inMinutes <
                settings.extractIdleMinutes) {
          continue;
        }
        final history = await ChatHistoryStore.instance.loadFor(
          group.id,
          includeImages: false,
        );
        final pending = _pendingMessages(group.id, history, state);
        if (pending.length < settings.extractMinMessages) {
          continue;
        }
        try {
          await _extractBatch(group, pending, now: now);
          _lastError = null;
          _lastErrorAt = null;
        } catch (error) {
          _lastError = _messageOf(error);
          _lastErrorAt = now;
        }
        // 每轮只整理一个群，避免同时发起多个模型请求。
        break;
      }
    } finally {
      _checking = false;
    }
  }

  List<ChatMessage> _pendingMessages(
    String groupId,
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
    GroupProfile group,
    List<ChatMessage> pending, {
    required DateTime now,
  }) async {
    if (_processing.contains(group.id)) {
      throw const MemoryException('这个群正在整理公共记忆，请稍后再试。');
    }
    _processing.add(group.id);
    final before = GroupMemoryStore.instance.stateFor(group.id);
    final batch = pending.length > _maxBatchMessages
        ? pending.take(_maxBatchMessages).toList(growable: false)
        : pending;
    try {
      final currentGroup = GroupStore.instance.groupById(group.id);
      if (currentGroup == null) {
        throw const MemoryException('群聊不存在或已被删除。');
      }
      final members = _membersOf(currentGroup);
      final existing = GroupMemoryStore.instance.entriesFor(group.id);
      final profile = GroupMemoryStore.instance.profileFor(group.id);
      final result = await _extractor.extract(
        group: currentGroup,
        members: members,
        messages: batch,
        existing: existing,
        profile: profile,
      );
      if (GroupStore.instance.groupById(group.id) == null) {
        throw const MemoryException('群聊不存在或已被删除。');
      }
      final current = List<GroupMemoryEntry>.of(existing);
      var changed = 0;
      for (final candidate in result.candidates) {
        changed += await _applyCandidate(
          group: group,
          candidate: candidate,
          current: current,
          now: now,
        );
      }
      if (await _applyProfile(group, result.profile, now: now)) {
        changed++;
      }
      await GroupMemoryStore.instance.saveState(
        group.id,
        before.copyWith(
          lastProcessedMessageId: batch.last.id,
          lastProcessedAtMs: now.millisecondsSinceEpoch,
          lastError: '',
          nextRetryAtMs: 0,
        ),
      );
      return changed;
    } catch (error) {
      await GroupMemoryStore.instance.saveState(
        group.id,
        before.copyWith(
          lastProcessedAtMs: now.millisecondsSinceEpoch,
          lastError: _messageOf(error),
          nextRetryAtMs: now.add(_retryDelay).millisecondsSinceEpoch,
        ),
      );
      rethrow;
    } finally {
      _processing.remove(group.id);
    }
  }

  List<CharacterProfile> _membersOf(GroupProfile group) {
    return [
      for (final id in group.memberIds)
        if (CharacterStore.instance.cardById(id) != null)
          CharacterStore.instance.cardById(id)!,
    ];
  }

  Future<int> _applyCandidate({
    required GroupProfile group,
    required GroupMemoryCandidate candidate,
    required List<GroupMemoryEntry> current,
    required DateTime now,
  }) async {
    final existingIndex = current.indexWhere(
      (entry) => entry.isActive && isSameMemoryFact(entry.text, candidate.text),
    );
    final nowMs = now.millisecondsSinceEpoch;
    if (existingIndex >= 0) {
      final existing = current[existingIndex];
      final tags = <String>{
        ...existing.tags,
        ...candidate.tags,
      }.take(GroupMemoryEntry.maxTags).toList(growable: false);
      final updated = existing.copyWith(
        text: candidate.text.length > existing.text.length
            ? candidate.text
            : existing.text,
        category: existing.category == MemoryCategory.event
            ? candidate.category
            : existing.category,
        importance: max(existing.importance, candidate.importance),
        tags: tags,
        updatedAtMs: nowMs,
      );
      current[existingIndex] = updated;
      await GroupMemoryStore.instance.saveEntry(updated);
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
      await GroupMemoryStore.instance.archiveEntry(old.id, archivedAtMs: nowMs);
      current.remove(old);
    }

    final entry = GroupMemoryEntry(
      id: 'gmem_${group.id}_${now.microsecondsSinceEpoch}_${current.length}',
      groupId: group.id,
      text: candidate.text,
      category: candidate.category,
      importance: candidate.importance,
      tags: candidate.tags,
      source: MemorySource.auto,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    ).normalized();
    current.add(entry);
    await GroupMemoryStore.instance.saveEntry(entry);
    return 1;
  }

  Future<bool> _applyProfile(
    GroupProfile group,
    GroupMemoryProfile incoming, {
    required DateTime now,
  }) async {
    if (incoming.isEmpty) {
      return false;
    }
    final current = GroupMemoryStore.instance.profileFor(group.id);
    final dates = <String>[...current.importantDates];
    for (final date in incoming.importantDates) {
      if (!dates.contains(date)) {
        dates.add(date);
      }
    }
    final next = current.copyWith(
      groupId: group.id,
      summary: incoming.summary.isNotEmpty ? incoming.summary : current.summary,
      sharedHabits: incoming.sharedHabits.isNotEmpty
          ? incoming.sharedHabits
          : current.sharedHabits,
      recentFocus: incoming.recentFocus.isNotEmpty
          ? incoming.recentFocus
          : current.recentFocus,
      importantDates: dates.isEmpty ? current.importantDates : dates,
      updatedAtMs: now.millisecondsSinceEpoch,
    );
    if (next.summary == current.summary &&
        next.sharedHabits == current.sharedHabits &&
        next.recentFocus == current.recentFocus &&
        _sameDates(next.importantDates, current.importantDates)) {
      return false;
    }
    await GroupMemoryStore.instance.saveProfile(next);
    return true;
  }

  bool _sameDates(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  String _messageOf(Object error) {
    if (error is MemoryException) {
      return error.message;
    }
    final message = error.toString().trim();
    return message.isEmpty ? '整理群公共记忆失败。' : message;
  }
}
