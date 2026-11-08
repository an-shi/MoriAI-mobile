import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/diary_generator.dart';
import 'package:mori_ai/services/diary_store.dart';

/// 每天在设定时间为每个角色写一篇日记。
///
/// 当前为本地前台实现：应用退到后台时暂停计时，恢复时补检查一次。
class DiaryService with WidgetsBindingObserver {
  DiaryService._({DiaryGenerator? generator, DateTime Function()? now})
    : _generator = generator ?? DiaryGenerator(),
      _now = now ?? DateTime.now;

  @visibleForTesting
  DiaryService.test({DiaryGenerator? generator, DateTime Function()? now})
    : this._(generator: generator, now: now);

  static final DiaryService instance = DiaryService._();

  static const _checkInterval = Duration(seconds: 30);
  static const _retryDelay = Duration(minutes: 30);
  static const _catchUpUntilHour = 6;

  final DiaryGenerator _generator;
  final DateTime Function() _now;
  final Set<String> _generating = {};

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
    DiaryStore.instance.settings.addListener(_handleSettingsChanged);
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
    DiaryStore.instance.settings.removeListener(_handleSettingsChanged);
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

  /// 立即检查一次。用于设置页测试和手动排查。
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

  /// 手动为某个角色写今天的日记，已存在时会替换。
  Future<DiaryEntry> writeNow(String characterId) async {
    final character = CharacterStore.instance.cardById(characterId);
    if (character == null) {
      throw const DiaryException('角色卡不存在或已被删除。');
    }
    final now = _now();
    final day = DateTime(now.year, now.month, now.day);
    return _generateAndSave(character, day, now);
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
    final settings = DiaryStore.instance.settings.value;
    if (!_generator.isConfigured) {
      return;
    }
    final anyEnabled = CharacterStore.instance.cards.value.any(
      (card) => settings.isEnabledFor(card.id),
    );
    if (!anyEnabled) {
      return;
    }

    _checking = true;
    try {
      final now = _now();
      _lastCheckAt = now;
      for (final card in CharacterStore.instance.cards.value) {
        if (_generating.contains(card.id)) {
          continue;
        }
        if (!settings.isEnabledFor(card.id)) {
          continue;
        }
        final day = _targetDay(settings.timeMinutesFor(card.id), now);
        if (day == null) {
          continue;
        }
        final dateKey = diaryDateKey(day);
        final state = DiaryStore.instance.stateFor(card.id);
        if (DiaryStore.instance.entryFor(card.id, dateKey) != null) {
          if (state.lastSuccessDate != dateKey) {
            await _markSuccess(card.id, dateKey);
          }
          continue;
        }
        if (state.lastSuccessDate == dateKey) {
          continue;
        }
        if (state.lastAttemptDate == dateKey &&
            state.nextRetryAtMs > now.millisecondsSinceEpoch) {
          continue;
        }

        try {
          await _generateAndSave(card, day, now);
        } catch (error) {
          _lastError = _messageOf(error);
          _lastErrorAt = now;
        }
        // 每轮只写一篇，避免多个角色同时发起模型请求。
        break;
      }
    } finally {
      _checking = false;
    }
  }

  DateTime? _targetDay(int timeMinutes, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(
      today.year,
      today.month,
      today.day,
      timeMinutes ~/ 60,
      timeMinutes % 60,
    );
    if (!now.isBefore(scheduled)) {
      return today;
    }
    if (now.hour < _catchUpUntilHour) {
      return today.subtract(const Duration(days: 1));
    }
    return null;
  }

  Future<DiaryEntry> _generateAndSave(
    CharacterProfile character,
    DateTime day,
    DateTime now,
  ) async {
    if (_generating.contains(character.id)) {
      throw const DiaryException('这个角色正在写日记，请稍后再试。');
    }
    _generating.add(character.id);
    try {
      final dateKey = diaryDateKey(day);
      final before = DiaryStore.instance.stateFor(character.id);
      await DiaryStore.instance.saveState(
        character.id,
        before.copyWith(
          lastAttemptDate: dateKey,
          lastAttemptAtMs: now.millisecondsSinceEpoch,
          nextRetryAtMs: 0,
          lastError: '',
        ),
      );

      try {
        final entry = await _generator.generateForDay(character, day, now: now);
        if (entry == null) {
          throw const DiaryException('这次没有生成日记内容，请稍后再试。');
        }
        if (CharacterStore.instance.cardById(character.id) == null) {
          throw const DiaryException('角色卡不存在或已被删除。');
        }
        await DiaryStore.instance.saveEntry(entry);
        await _markSuccess(character.id, dateKey);
        _lastError = null;
        _lastErrorAt = null;
        return entry;
      } catch (error) {
        final message = _messageOf(error);
        await DiaryStore.instance.saveState(
          character.id,
          before.copyWith(
            lastAttemptDate: dateKey,
            lastAttemptAtMs: now.millisecondsSinceEpoch,
            nextRetryAtMs: now.add(_retryDelay).millisecondsSinceEpoch,
            lastError: message,
          ),
        );
        rethrow;
      }
    } finally {
      _generating.remove(character.id);
    }
  }

  Future<void> _markSuccess(String characterId, String dateKey) async {
    final state = DiaryStore.instance.stateFor(characterId);
    await DiaryStore.instance.saveState(
      characterId,
      state.copyWith(lastSuccessDate: dateKey, lastError: '', nextRetryAtMs: 0),
    );
  }

  String _messageOf(Object error) {
    if (error is DiaryException) {
      return error.message;
    }
    final message = error.toString().trim();
    return message.isEmpty ? '生成日记失败。' : message;
  }
}
