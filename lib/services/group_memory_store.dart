import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/group_memory.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupMemoryStore {
  GroupMemoryStore._();

  static final GroupMemoryStore instance = GroupMemoryStore._();

  static const _entriesKey = 'group_memory_v1';
  static const _statesKey = 'group_memory_state_v1';
  static const _profilesKey = 'group_memory_profile_v1';
  static const maxEntriesPerGroup = 300;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Map<String, List<GroupMemoryEntry>> _byGroup = {};
  final Map<String, MemoryExtractionState> _states = {};
  final Map<String, GroupMemoryProfile> _profiles = {};

  Future<void> load() async {
    _byGroup.clear();
    _states.clear();
    _profiles.clear();

    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }

    if (preferences != null) {
      _loadEntries(preferences);
      _loadStates(preferences);
      _loadProfiles(preferences);
    }

    for (final entries in _byGroup.values) {
      entries.sort(_compareEntryDesc);
      _trim(entries);
    }
    revision.value++;
  }

  List<GroupMemoryEntry> allEntries({bool includeArchived = false}) {
    final all = <GroupMemoryEntry>[
      for (final entries in _byGroup.values)
        for (final entry in entries)
          if (includeArchived || entry.isActive) entry,
    ]..sort(_compareEntryDesc);
    return List<GroupMemoryEntry>.unmodifiable(all);
  }

  List<GroupMemoryEntry> entriesFor(
    String groupId, {
    bool includeArchived = false,
  }) {
    final entries = _byGroup[groupId.trim()];
    if (entries == null) {
      return const [];
    }
    return List<GroupMemoryEntry>.unmodifiable(
      entries.where((entry) => includeArchived || entry.isActive),
    );
  }

  GroupMemoryEntry? entryById(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    for (final entries in _byGroup.values) {
      for (final entry in entries) {
        if (entry.id == trimmed) {
          return entry;
        }
      }
    }
    return null;
  }

  MemoryExtractionState stateFor(String groupId) {
    return _states[groupId.trim()] ?? const MemoryExtractionState();
  }

  GroupMemoryProfile profileFor(String groupId) {
    final id = groupId.trim();
    return _profiles[id] ?? GroupMemoryProfile(groupId: id);
  }

  Future<void> saveEntry(GroupMemoryEntry raw) async {
    final entry = raw.normalized();
    if (entry.id.isEmpty ||
        entry.groupId.isEmpty ||
        entry.text.isEmpty ||
        entry.createdAtMs <= 0) {
      return;
    }
    final entries = _byGroup.putIfAbsent(entry.groupId, () => []);
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
    for (final entries in _byGroup.entries.toList()) {
      final before = entries.value.length;
      entries.value.removeWhere((entry) => entry.id == trimmed);
      if (entries.value.length != before) {
        changed = true;
        if (entries.value.isEmpty) {
          _byGroup.remove(entries.key);
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
    for (final entries in _byGroup.values) {
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

  Future<void> saveProfile(GroupMemoryProfile raw) async {
    final profile = raw.normalized();
    if (profile.groupId.isEmpty) {
      return;
    }
    if (profile.isEmpty) {
      if (_profiles.remove(profile.groupId) == null) {
        return;
      }
    } else {
      _profiles[profile.groupId] = profile;
    }
    revision.value++;
    await _persistProfiles();
  }

  Future<void> clearForGroup(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return;
    }
    final removedEntries = _byGroup.remove(id) != null;
    final removedState = _states.remove(id) != null;
    final removedProfile = _profiles.remove(id) != null;
    if (!removedEntries && !removedState && !removedProfile) {
      return;
    }
    revision.value++;
    await _persistEntries();
    await _persistStates();
    await _persistProfiles();
  }

  Future<void> saveState(String groupId, MemoryExtractionState next) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return;
    }
    _states[id] = next.normalized();
    await _persistStates();
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
          final entry = GroupMemoryEntry.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (entry.id.isEmpty ||
              entry.groupId.isEmpty ||
              entry.text.isEmpty ||
              entry.createdAtMs <= 0 ||
              !seen.add('${entry.groupId}|${entry.id}')) {
            continue;
          }
          _byGroup.putIfAbsent(entry.groupId, () => []).add(entry);
        } catch (_) {
          // 跳过损坏的群公共记忆。
        }
      }
    } catch (_) {
      // 群公共记忆损坏时保留其他数据。
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
          // 跳过损坏的群记忆状态。
        }
      }
    } catch (_) {
      // 群记忆状态损坏时保留记忆列表。
    }
  }

  void _loadProfiles(SharedPreferences preferences) {
    try {
      final raw = preferences.getString(_profilesKey);
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
          final profile = GroupMemoryProfile.fromJson(
            Map<String, dynamic>.from(item.value as Map),
          );
          final id = (item.key as String).trim();
          if (id.isEmpty || profile.isEmpty) {
            continue;
          }
          _profiles[id] = profile.copyWith(groupId: id);
        } catch (_) {
          // 跳过损坏的群印象。
        }
      }
    } catch (_) {
      // 群印象损坏时保留其他数据。
    }
  }

  void _trim(List<GroupMemoryEntry> entries) {
    final limit = maxEntriesPerGroup;
    if (entries.length <= limit) {
      return;
    }
    final removable = List<GroupMemoryEntry>.of(entries)
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

  int _compareEntryDesc(GroupMemoryEntry a, GroupMemoryEntry b) {
    final byUpdated = b.updatedAtMs.compareTo(a.updatedAtMs);
    if (byUpdated != 0) {
      return byUpdated;
    }
    return b.importance.compareTo(a.importance);
  }

  Future<void> _persistEntries() async {
    final all = <GroupMemoryEntry>[
      for (final entries in _byGroup.values) ...entries,
    ]..sort(_compareEntryDesc);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _entriesKey,
        jsonEncode([for (final entry in all) entry.toJson()]),
      );
    } catch (_) {
      // 群公共记忆保存失败不阻断聊天。
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
      // 群记忆状态保存失败不阻断聊天。
    }
  }

  Future<void> _persistProfiles() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _profilesKey,
        jsonEncode({
          for (final entry in _profiles.entries)
            entry.key: entry.value.toJson(),
        }),
      );
    } catch (_) {
      // 群印象保存失败不阻断聊天。
    }
  }
}
