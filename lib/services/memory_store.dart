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
  static const _profilesKey = 'character_memory_profile_v1';
  static const _topicsKey = 'character_memory_topics_v1';
  static const maxOpenTopicsPerCharacter = 50;

  final ValueNotifier<MemorySettings> settings = ValueNotifier<MemorySettings>(
    MemorySettings.defaults,
  );
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Map<String, List<MemoryEntry>> _byCharacter = {};
  final Map<String, MemoryExtractionState> _states = {};
  final Map<String, MemoryProfile> _profiles = {};
  final Map<String, List<MemoryOpenTopic>> _topics = {};

  Future<void> load() async {
    _byCharacter.clear();
    _states.clear();
    _profiles.clear();
    _topics.clear();

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
      _loadProfiles(preferences);
      _loadTopics(preferences);
    } else {
      settings.value = MemorySettings.defaults;
    }

    for (final entries in _byCharacter.values) {
      entries.sort(_compareEntryDesc);
      _trim(entries);
    }
    for (final topics in _topics.values) {
      topics.sort(_compareTopicDesc);
      _trimTopics(topics);
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

  MemoryProfile profileFor(String characterId) {
    final id = characterId.trim();
    return _profiles[id] ?? MemoryProfile(characterId: id);
  }

  List<MemoryOpenTopic> openTopicsFor(
    String characterId, {
    bool includeResolved = false,
  }) {
    final topics = _topics[characterId.trim()];
    if (topics == null) {
      return const [];
    }
    return List<MemoryOpenTopic>.unmodifiable(
      topics.where((topic) => includeResolved || topic.isOpen),
    );
  }

  MemoryOpenTopic? openTopicById(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    for (final topics in _topics.values) {
      for (final topic in topics) {
        if (topic.id == trimmed) {
          return topic;
        }
      }
    }
    return null;
  }

  Future<void> saveProfile(MemoryProfile raw) async {
    final profile = raw.normalized();
    if (profile.characterId.isEmpty) {
      return;
    }
    if (profile.isEmpty) {
      if (_profiles.remove(profile.characterId) == null) {
        return;
      }
    } else {
      _profiles[profile.characterId] = profile;
    }
    revision.value++;
    await _persistProfiles();
  }

  Future<void> saveOpenTopic(MemoryOpenTopic raw) async {
    final topic = raw.normalized();
    if (topic.id.isEmpty ||
        topic.characterId.isEmpty ||
        topic.text.isEmpty ||
        topic.createdAtMs <= 0) {
      return;
    }
    final topics = _topics.putIfAbsent(topic.characterId, () => []);
    topics.removeWhere((item) => item.id == topic.id);
    topics.add(topic);
    topics.sort(_compareTopicDesc);
    _trimTopics(topics);
    revision.value++;
    await _persistTopics();
  }

  Future<void> resolveOpenTopic(String id, {int resolvedAtMs = 0}) async {
    final topic = openTopicById(id);
    if (topic == null || !topic.isOpen) {
      return;
    }
    final now = resolvedAtMs > 0
        ? resolvedAtMs
        : DateTime.now().millisecondsSinceEpoch;
    await saveOpenTopic(
      topic.copyWith(
        status: MemoryOpenTopicStatus.resolved,
        updatedAtMs: now,
        resolvedAtMs: now,
      ),
    );
  }

  Future<void> deleteOpenTopic(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return;
    }
    var changed = false;
    for (final topics in _topics.entries.toList()) {
      final before = topics.value.length;
      topics.value.removeWhere((topic) => topic.id == trimmed);
      if (topics.value.length != before) {
        changed = true;
        if (topics.value.isEmpty) {
          _topics.remove(topics.key);
        }
      }
    }
    if (!changed) {
      return;
    }
    revision.value++;
    await _persistTopics();
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
    final removedProfile = _profiles.remove(id) != null;
    final removedTopics = _topics.remove(id) != null;
    if (!removedEntries && !removedState && !removedProfile && !removedTopics) {
      return;
    }
    revision.value++;
    await _persistEntries();
    await _persistStates();
    await _persistProfiles();
    await _persistTopics();
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
          final profile = MemoryProfile.fromJson(
            Map<String, dynamic>.from(item.value as Map),
          );
          final id = (item.key as String).trim();
          if (id.isEmpty || profile.isEmpty) {
            continue;
          }
          _profiles[id] = profile.copyWith(characterId: id);
        } catch (_) {
          // 跳过损坏的人物档案。
        }
      }
    } catch (_) {
      // 人物档案损坏时保留记忆列表和其他数据。
    }
  }

  void _loadTopics(SharedPreferences preferences) {
    try {
      final raw = preferences.getString(_topicsKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      for (final item in decoded.entries) {
        if (item.key is! String || item.value is! List) {
          continue;
        }
        final id = (item.key as String).trim();
        if (id.isEmpty) {
          continue;
        }
        final seen = <String>{};
        for (final value in item.value as List) {
          if (value is! Map) {
            continue;
          }
          try {
            final topic = MemoryOpenTopic.fromJson(
              Map<String, dynamic>.from(value),
            );
            if (topic.id.isEmpty ||
                topic.text.isEmpty ||
                topic.createdAtMs <= 0 ||
                !seen.add(topic.id)) {
              continue;
            }
            _topics
                .putIfAbsent(id, () => [])
                .add(topic.copyWith(characterId: id));
          } catch (_) {
            // 跳过损坏的未完成话题。
          }
        }
      }
    } catch (_) {
      // 未完成话题损坏时保留其他记忆数据。
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

  int _compareTopicDesc(MemoryOpenTopic a, MemoryOpenTopic b) {
    final byOpen = (a.isOpen ? 0 : 1).compareTo(b.isOpen ? 0 : 1);
    if (byOpen != 0) {
      return byOpen;
    }
    final byUpdated = b.updatedAtMs.compareTo(a.updatedAtMs);
    if (byUpdated != 0) {
      return byUpdated;
    }
    return b.importance.compareTo(a.importance);
  }

  void _trimTopics(List<MemoryOpenTopic> topics) {
    if (topics.length <= maxOpenTopicsPerCharacter) {
      return;
    }
    final removable = List<MemoryOpenTopic>.of(topics)
      ..sort((a, b) {
        final byStatus = (a.isOpen ? 1 : 0).compareTo(b.isOpen ? 1 : 0);
        if (byStatus != 0) {
          return byStatus;
        }
        final byImportance = a.importance.compareTo(b.importance);
        if (byImportance != 0) {
          return byImportance;
        }
        return a.updatedAtMs.compareTo(b.updatedAtMs);
      });
    final removeIds = removable
        .take(topics.length - maxOpenTopicsPerCharacter)
        .map((topic) => topic.id)
        .toSet();
    topics.removeWhere((topic) => removeIds.contains(topic.id));
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
      // 人物档案保存失败不阻断聊天。
    }
  }

  Future<void> _persistTopics() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _topicsKey,
        jsonEncode({
          for (final entry in _topics.entries)
            entry.key: [for (final topic in entry.value) topic.toJson()],
        }),
      );
    } catch (_) {
      // 未完成话题保存失败不阻断聊天。
    }
  }
}
