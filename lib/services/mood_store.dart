import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/mood.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoodStore {
  MoodStore._();

  static final MoodStore instance = MoodStore._();

  static const _settingsKey = 'mood_settings_v1';
  static const _statesKey = 'character_mood_v1';
  static const _maxHistory = 50;

  final ValueNotifier<MoodSettings> settings = ValueNotifier<MoodSettings>(
    MoodSettings.defaults,
  );
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Map<String, MoodState> _states = {};

  Future<void> load() async {
    _states.clear();
    try {
      final preferences = await SharedPreferences.getInstance();
      final rawSettings = preferences.getString(_settingsKey);
      if (rawSettings != null && rawSettings.isNotEmpty) {
        final decoded = jsonDecode(rawSettings);
        if (decoded is Map) {
          settings.value = MoodSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } else {
        settings.value = MoodSettings.defaults;
      }

      final rawStates = preferences.getString(_statesKey);
      if (rawStates != null && rawStates.isNotEmpty) {
        final decoded = jsonDecode(rawStates);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is! String || entry.value is! Map) {
              continue;
            }
            try {
              _states[entry.key as String] = MoodState.fromJson(
                Map<String, dynamic>.from(entry.value as Map),
              ).normalized(settings.value);
            } catch (_) {
              // 跳过损坏的角色心情记录。
            }
          }
        }
      }
    } catch (_) {
      settings.value = MoodSettings.defaults;
      _states.clear();
    }
    revision.value++;
  }

  MoodSnapshot snapshotFor(String characterId, {DateTime? now}) {
    final currentSettings = settings.value;
    final time = now ?? DateTime.now();
    final rawState =
        _states[characterId] ??
        MoodState(value: currentSettings.base, updatedAtMs: 0, reason: '');
    final state = rawState.decayed(currentSettings, time);
    return MoodSnapshot(
      value: state.value,
      updatedAtMs: rawState.updatedAtMs <= 0 ? 0 : state.updatedAtMs,
      reason: state.reason,
      history: state.history,
    );
  }

  String contextLine(String characterId) {
    if (!settings.value.enabled) {
      return '';
    }
    final snapshot = snapshotFor(characterId);
    final style = snapshot.style;
    if (style.isEmpty) {
      return '';
    }
    final reason = snapshot.reason.isEmpty ? '' : '，因为${snapshot.reason}';
    return '（你现在${snapshot.label}$reason。这会自然影响你说话：$style。不用说出来自己心情如何。）';
  }

  double delayFactor(String characterId) {
    if (!settings.value.enabled) {
      return 1;
    }
    return moodEffects(snapshotFor(characterId).value).delay;
  }

  Future<void> observe(
    String characterId,
    String text, {
    bool direct = true,
    bool owner = false,
  }) async {
    if (!settings.value.enabled || characterId.isEmpty || text.trim().isEmpty) {
      return;
    }
    final baseDelta = scoreMoodText(text);
    if (baseDelta == 0) {
      return;
    }
    final delta = (baseDelta * (direct ? 1 : 0.3) * (owner ? 1.5 : 1)).round();
    if (delta == 0) {
      return;
    }
    final who = owner ? '用户' : '有人';
    await nudge(characterId, delta, '$who说「${_clip(text, 20)}」');
  }

  Future<void> nudge(String characterId, int delta, String reason) async {
    if (!settings.value.enabled || characterId.isEmpty || delta == 0) {
      return;
    }
    final currentSettings = settings.value;
    final now = DateTime.now();
    final before = snapshotFor(characterId, now: now).value;
    final after = (before + delta).clamp(5, 100).toInt();
    final raw = _states[characterId];
    final history = [
      MoodHistoryEntry(
        atMs: now.millisecondsSinceEpoch,
        from: before,
        to: after,
        reason: reason.trim(),
      ),
      ...?raw?.history,
    ].take(_maxHistory).toList(growable: false);
    _states[characterId] = MoodState(
      value: after,
      updatedAtMs: now.millisecondsSinceEpoch,
      reason: reason.trim(),
      history: history,
    ).normalized(currentSettings);
    revision.value++;
    await _persistStates();
  }

  Future<void> reset(String characterId) async {
    if (_states.remove(characterId) == null) {
      return;
    }
    revision.value++;
    await _persistStates();
  }

  Future<void> saveSettings(MoodSettings next) async {
    final normalized = next.normalized();
    final previous = settings.value;
    settings.value = normalized;
    revision.value++;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _settingsKey,
        jsonEncode(normalized.toJson()),
      );
      if (!saved) {
        throw StateError('Failed to save mood settings');
      }
    } catch (_) {
      settings.value = previous;
      revision.value++;
      rethrow;
    }
  }

  Future<void> _persistStates() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _statesKey,
        jsonEncode({
          for (final entry in _states.entries) entry.key: entry.value.toJson(),
        }),
      );
    } catch (_) {
      // 心情保存失败不阻断聊天。
    }
  }

  String _clip(String text, int max) {
    final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.length > max ? '${value.substring(0, max)}…' : value;
  }
}
