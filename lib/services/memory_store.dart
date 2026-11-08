import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryStore {
  MemoryStore._();

  static final MemoryStore instance = MemoryStore._();

  static const _settingsKey = 'memory_settings_v1';
  static const _entriesKey = 'character_memory_v1';
  static const _statesKey = 'memory_state_v1';

  final ValueNotifier<MemorySettings> settings = ValueNotifier<MemorySettings>(
    MemorySettings.defaults,
  );
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Map<String, List<MemoryEntry>> _byCharacter = {};
  final Map<String, MemoryExtractionState> _states = {};

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
      settings.value = MemorySettings.defaults;
    }

    for (final entries in _byCharacter.values) {
      entries.sort(_compareEntryDesc);
      _trim(entries);
    }
    revision.value++;
  }

  List<MemoryEntry> allEntries({bool includeArchived = false}) {
    final all = <MemoryEntry>[
      for (final entries in _byCharacter.values)
        for (final entry in entries)
          if (includeArchived || entry.isActive) entry,
    ]..sort(_compareEntryDesc);
    return List<MemoryEntry>.unmodifiable(all);
  }

  List<MemoryEntry> entriesFor(
    String characterId, {
    bool includeArchived = false,
  }) {
    final entries = _byCharacter[characterId.trim()];
    if (entries == null) {
      return const [];
    }
    return List<MemoryEntry>.unmodifiable(
      entries.where((entry) => includeArchived || entry.isActive),
    );
  }

  MemoryEntry? entryById(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    for (final entries in _byCharacter.values) {
      for (final entry in entries) {
        if (entry.id == trimmed) {
          return entry;
        }
      }
    }
    return null;
  }

  MemoryExtractionState stateFor(String characterId) {
    return _states[characterId.trim()] ?? const MemoryExtractionState();
  }

  Future<void> saveEntry(MemoryEntry raw) async {
    final entry = raw.normalized();
    if (entry.id.isEmpty ||
        entry.characterId.isEmpty ||
        entry.text.isEmpty ||
        entry.createdAtMs <= 0) {
      return;
    }
    final entries = _byCharacter.putIfAbsent(entry.characterId, () => []);
    entries.removeWhere((item) => item.id == entry.id);
    entries.add(entry);
    entries.sort(_compareEntryDesc);
    _trim(entries);
    revision.value++;
    await _persistEntries();
  }

  Future<void> deleteEntry(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return;
    }
    var changed = false;
    for (final entries in _byCharacter.entries.toList()) {
      final before = entries.value.length;
      entries.value.removeWhere((entry) => entry.id == trimmed);
      if (entries.value.length != before) {
        changed = true;
        if (entries.value.isEmpty) {
          _byCharacter.remove(entries.key);
        }
      }
    }
    if (!changed) {
      return;
    }
    revision.value++;
    await _persistEntries();
  }

  Future<void> archiveEntry(String id, {int archivedAtMs = 0}) async {
    final entry = entryById(id);
    if (entry == null) {
      return;
    }
    await saveEntry(
      entry.copyWith(
        isActive: false,
        archivedAtMs: archivedAtMs > 0
            ? archivedAtMs
            : DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> touch(Iterable<String> ids) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final wanted = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (wanted.isEmpty) {
      return;
    }
    var changed = false;
    for (final entries in _byCharacter.values) {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        if (!entry.isActive || !wanted.contains(entry.id)) {
          continue;
        }
        entries[index] = entry.copyWith(
          lastAccessedAtMs: now,
          accessCount: entry.accessCount + 1,
        );
        changed = true;
      }
    }
    if (!changed) {
      return;
    }
    await _persistEntries();
  }

  Future<void> clearForCharacter(String characterId) async {
    final id = characterId.trim();
    if (id.isEmpty) {
      return;
    }
    final removedEntries = _byCharacter.remove(id) != null;
    final removedState = _states.remove(id) != null;
    if (!removedEntries && !removedState) {
      return;
    }
    revision.value++;
    await _persistEntries();
    await _persistStates();
  }

  Future<void> saveState(String characterId, MemoryExtractionState next) async {
    final id = characterId.trim();
    if (id.isEmpty) {
      return;
    }
    _states[id] = next.normalized();
    await _persistStates();
  }

  Future<void> saveSettings(MemorySettings next) async {
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
        throw StateError('Failed to save memory settings');
      }
      var trimmed = false;
      for (final entries in _byCharacter.values) {
        final before = entries.length;
        _trim(entries);
        if (entries.length != before) {
          trimmed = true;
        }
      }
      if (trimmed) {
        revision.value++;
        await _persistEntries();
      }
    } catch (_) {
      settings.value = previous;
      revision.value++;
      rethrow;
    }
  }

  void _loadSettings(SharedPreferences preferences) {
    try {
      final raw = preferences.getString(_settingsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          settings.value = MemorySettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          return;
        }
      }
      settings.value = MemorySettings.defaults;
    } catch (_) {
      settings.value = MemorySettings.defaults;
    }
  }

  void _loadEntries(SharedPreferences preferences) {
    try {
      final raw = preferences.getString(_entriesKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      final seen = <String>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        try {
          final entry = MemoryEntry.fromJson(Map<String, dynamic>.from(item));
          if (entry.id.isEmpty ||
              entry.characterId.isEmpty ||
              entry.text.isEmpty ||
              entry.createdAtMs <= 0 ||
              !seen.add('${entry.characterId}|${entry.id}')) {
            continue;
          }
          _byCharacter.putIfAbsent(entry.characterId, () => []).add(entry);
        } catch (_) {
          // 跳过损坏的记忆记录。
        }
      }
    } catch (_) {
      // 记忆列表损坏时保留设置和其他数据。
    }
  }

  void _loadStates(SharedPreferences preferences) {
    try {
      final raw = preferences.getString(_statesKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      for (final item in decoded.entries) {
        if (item.key is! String || item.value is! Map) {
          continue;
        }
        try {
          _states[item.key as String] = MemoryExtractionState.fromJson(
            Map<String, dynamic>.from(item.value as Map),
          );
        } catch (_) {
          // 跳过损坏的记忆状态。
        }
      }
    } catch (_) {
      // 记忆状态损坏时保留记忆列表。
    }
  }

  void _trim(List<MemoryEntry> entries) {
    final limit = settings.value.maxMemoriesPerCharacter;
    if (entries.length <= limit) {
      return;
    }
    final removable = List<MemoryEntry>.of(entries)
      ..sort((a, b) {
        final byActive = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
        if (byActive != 0) {
          return byActive;
        }
        final bySource = (a.source == MemorySource.manual ? 1 : 0).compareTo(
          b.source == MemorySource.manual ? 1 : 0,
        );
        if (bySource != 0) {
          return bySource;
        }
        final byImportance = a.importance.compareTo(b.importance);
        if (byImportance != 0) {
          return byImportance;
        }
        return a.updatedAtMs.compareTo(b.updatedAtMs);
      });
    final removeIds = removable
        .take(entries.length - limit)
        .map((entry) => entry.id)
        .toSet();
    entries.removeWhere((entry) => removeIds.contains(entry.id));
  }

  int _compareEntryDesc(MemoryEntry a, MemoryEntry b) {
    final byUpdated = b.updatedAtMs.compareTo(a.updatedAtMs);
    if (byUpdated != 0) {
      return byUpdated;
    }
    return b.importance.compareTo(a.importance);
  }

  Future<void> _persistEntries() async {
    final all = <MemoryEntry>[
      for (final entries in _byCharacter.values) ...entries,
    ]..sort(_compareEntryDesc);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _entriesKey,
        jsonEncode([for (final entry in all) entry.toJson()]),
      );
    } catch (_) {
      // 记忆保存失败不阻断聊天，下一次写入会继续尝试。
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
      // 记忆状态保存失败不阻断聊天。
    }
  }
}
