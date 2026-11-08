import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiaryStore {
  DiaryStore._();

  static final DiaryStore instance = DiaryStore._();

  static const _settingsKey = 'diary_settings_v1';
  static const _entriesKey = 'character_diary_v1';
  static const _statesKey = 'diary_state_v1';
  static const maxEntriesPerCharacter = 365;

  final ValueNotifier<DiarySettings> settings = ValueNotifier<DiarySettings>(
    DiarySettings.defaults,
  );
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Map<String, List<DiaryEntry>> _byCharacter = {};
  final Map<String, DiaryState> _states = {};

  Future<void> load() async {
    _byCharacter.clear();
    _states.clear();

    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }

    if (preferences != null) {
      _loadSettings(preferences);
      _loadEntries(preferences);
      _loadStates(preferences);
    } else {
      settings.value = DiarySettings.defaults;
    }

    for (final entries in _byCharacter.values) {
      entries.sort(_compareEntryDesc);
      _trim(entries);
    }
    revision.value++;
  }

  void _loadSettings(SharedPreferences preferences) {
    try {
      final rawSettings = preferences.getString(_settingsKey);
      if (rawSettings != null && rawSettings.isNotEmpty) {
        final decoded = jsonDecode(rawSettings);
        if (decoded is Map) {
          settings.value = DiarySettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          return;
        }
      }
      settings.value = DiarySettings.defaults;
    } catch (_) {
      settings.value = DiarySettings.defaults;
    }
  }

  void _loadEntries(SharedPreferences preferences) {
    try {
      final rawEntries = preferences.getString(_entriesKey);
      if (rawEntries == null || rawEntries.isEmpty) {
        return;
      }
      final decoded = jsonDecode(rawEntries);
      if (decoded is! List) {
        return;
      }
      final seen = <String>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        try {
          final entry = DiaryEntry.fromJson(Map<String, dynamic>.from(item));
          if (entry.id.isEmpty ||
              entry.characterId.isEmpty ||
              entry.dateKey.isEmpty ||
              entry.content.isEmpty ||
              entry.createdAtMs <= 0 ||
              diaryDateFromKey(entry.dateKey) == null ||
              !seen.add(_entryKey(entry.characterId, entry.dateKey))) {
            continue;
          }
          _byCharacter.putIfAbsent(entry.characterId, () => []).add(entry);
        } catch (_) {
          // 跳过损坏的日记记录。
        }
      }
    } catch (_) {
      // 日记列表损坏时保留其他数据，至少不阻断应用启动。
    }
  }

  void _loadStates(SharedPreferences preferences) {
    try {
      final rawStates = preferences.getString(_statesKey);
      if (rawStates == null || rawStates.isEmpty) {
        return;
      }
      final decoded = jsonDecode(rawStates);
      if (decoded is! Map) {
        return;
      }
      for (final item in decoded.entries) {
        if (item.key is! String || item.value is! Map) {
          continue;
        }
        try {
          _states[item.key as String] = DiaryState.fromJson(
            Map<String, dynamic>.from(item.value as Map),
          );
        } catch (_) {
          // 跳过损坏的日记状态。
        }
      }
    } catch (_) {
      // 日记状态损坏时保留日记列表。
    }
  }

  List<DiaryEntry> allEntries() {
    final all = <DiaryEntry>[
      for (final entries in _byCharacter.values) ...entries,
    ]..sort(_compareEntryDesc);
    return List<DiaryEntry>.unmodifiable(all);
  }

  List<DiaryEntry> entriesFor(String characterId) {
    final entries = _byCharacter[characterId];
    if (entries == null) {
      return const [];
    }
    return List<DiaryEntry>.unmodifiable(entries);
  }

  DiaryEntry? entryFor(String characterId, String dateKey) {
    final entries = _byCharacter[characterId];
    if (entries == null) {
      return null;
    }
    for (final entry in entries) {
      if (entry.dateKey == dateKey) {
        return entry;
      }
    }
    return null;
  }

  DiaryState stateFor(String characterId) {
    return _states[characterId] ?? const DiaryState();
  }

  Future<void> saveEntry(DiaryEntry raw) async {
    final entry = raw.normalized();
    if (entry.id.isEmpty ||
        entry.characterId.isEmpty ||
        entry.dateKey.isEmpty ||
        entry.content.isEmpty ||
        entry.createdAtMs <= 0 ||
        diaryDateFromKey(entry.dateKey) == null) {
      return;
    }
    final entries = _byCharacter.putIfAbsent(entry.characterId, () => []);
    entries.removeWhere((item) => item.dateKey == entry.dateKey);
    entries.add(entry);
    entries.sort(_compareEntryDesc);
    _trim(entries);
    revision.value++;
    await _persistEntries();
  }

  Future<void> deleteEntry(String entryId) async {
    final id = entryId.trim();
    if (id.isEmpty) {
      return;
    }
    var changed = false;
    for (final entry in _byCharacter.entries.toList()) {
      final before = entry.value.length;
      entry.value.removeWhere((item) => item.id == id);
      if (entry.value.length != before) {
        changed = true;
        if (entry.value.isEmpty) {
          _byCharacter.remove(entry.key);
        }
      }
    }
    if (!changed) {
      return;
    }
    revision.value++;
    await _persistEntries();
  }

  Future<void> clearForCharacter(String characterId) async {
    final id = characterId.trim();
    if (id.isEmpty) {
      return;
    }
    final removedEntries = _byCharacter.remove(id) != null;
    final removedState = _states.remove(id) != null;
    var removedSettings = false;
    if (settings.value.hasOverride(id)) {
      try {
        await saveSettings(settings.value.clearCharacterSettings(id));
        removedSettings = true;
      } catch (_) {
        // 清理单角色设置失败时至少继续清理日记和状态。
      }
    }
    if (!removedEntries && !removedState && !removedSettings) {
      return;
    }
    revision.value++;
    await _persistEntries();
    await _persistStates();
  }

  Future<void> saveState(String characterId, DiaryState next) async {
    final id = characterId.trim();
    if (id.isEmpty) {
      return;
    }
    _states[id] = next.normalized();
    await _persistStates();
  }

  Future<void> saveSettings(DiarySettings next) async {
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
        throw StateError('Failed to save diary settings');
      }
    } catch (_) {
      settings.value = previous;
      revision.value++;
      rethrow;
    }
  }

  void _trim(List<DiaryEntry> entries) {
    if (entries.length <= maxEntriesPerCharacter) {
      return;
    }
    // 列表按日期倒序排列，末尾是最旧的日记。
    entries.removeRange(maxEntriesPerCharacter, entries.length);
  }

  int _compareEntryDesc(DiaryEntry a, DiaryEntry b) {
    final byDate = b.dateKey.compareTo(a.dateKey);
    if (byDate != 0) {
      return byDate;
    }
    return b.createdAtMs.compareTo(a.createdAtMs);
  }

  String _entryKey(String characterId, String dateKey) {
    return '$characterId|$dateKey';
  }

  Future<void> _persistEntries() async {
    final all = allEntries();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _entriesKey,
        jsonEncode([for (final entry in all) entry.toJson()]),
      );
    } catch (_) {
      // 日记保存失败不阻断应用，下一次写入会继续尝试。
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
      // 日记状态保存失败不阻断应用。
    }
  }
}
