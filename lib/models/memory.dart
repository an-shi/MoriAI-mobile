enum MemoryCategory { fact, preference, relationship, plan, event, impression }

extension MemoryCategoryLabel on MemoryCategory {
  String get label => switch (this) {
    MemoryCategory.fact => '事实',
    MemoryCategory.preference => '喜好',
    MemoryCategory.relationship => '关系',
    MemoryCategory.plan => '计划',
    MemoryCategory.event => '经历',
    MemoryCategory.impression => '印象',
  };
}

enum MemorySource { auto, manual }

extension MemorySourceLabel on MemorySource {
  String get label => switch (this) {
    MemorySource.auto => '自动整理',
    MemorySource.manual => '手动添加',
  };
}

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.characterId,
    required this.text,
    this.category = MemoryCategory.fact,
    this.importance = 0.5,
    this.tags = const [],
    this.source = MemorySource.auto,
    this.conversationId = '',
    this.aboutName = '',
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.lastAccessedAtMs = 0,
    this.accessCount = 0,
    this.isActive = true,
    this.archivedAtMs = 0,
  });

  static const maxTextLength = 300;
  static const maxTags = 5;

  final String id;
  final String characterId;
  final String text;
  final MemoryCategory category;
  final double importance;
  final List<String> tags;
  final MemorySource source;
  final String conversationId;
  final String aboutName;
  final int createdAtMs;
  final int updatedAtMs;
  final int lastAccessedAtMs;
  final int accessCount;
  final bool isActive;
  final int archivedAtMs;

  String get categoryLabel => category.label;

  String get sourceLabel => source.label;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  MemoryEntry normalized() {
    final trimmedText = text.trim();
    final normalizedTags = <String>[];
    for (final raw in tags) {
      final tag = raw.trim();
      if (tag.isEmpty || normalizedTags.contains(tag)) {
        continue;
      }
      normalizedTags.add(tag.length > 20 ? tag.substring(0, 20) : tag);
      if (normalizedTags.length >= maxTags) {
        break;
      }
    }
    final created = createdAtMs < 0 ? 0 : createdAtMs;
    final updated = updatedAtMs < created ? created : updatedAtMs;
    return MemoryEntry(
      id: id.trim(),
      characterId: characterId.trim(),
      text: trimmedText.length > maxTextLength
          ? trimmedText.substring(0, maxTextLength)
          : trimmedText,
      category: category,
      importance: importance.clamp(0, 1).toDouble(),
      tags: List<String>.unmodifiable(normalizedTags),
      source: source,
      conversationId: conversationId.trim(),
      aboutName: aboutName.trim(),
      createdAtMs: created,
      updatedAtMs: updated,
      lastAccessedAtMs: lastAccessedAtMs < 0 ? 0 : lastAccessedAtMs,
      accessCount: accessCount < 0 ? 0 : accessCount,
      isActive: isActive,
      archivedAtMs: archivedAtMs < 0 ? 0 : archivedAtMs,
    );
  }

  MemoryEntry copyWith({
    String? id,
    String? characterId,
    String? text,
    MemoryCategory? category,
    double? importance,
    List<String>? tags,
    MemorySource? source,
    String? conversationId,
    String? aboutName,
    int? createdAtMs,
    int? updatedAtMs,
    int? lastAccessedAtMs,
    int? accessCount,
    bool? isActive,
    int? archivedAtMs,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      text: text ?? this.text,
      category: category ?? this.category,
      importance: importance ?? this.importance,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      conversationId: conversationId ?? this.conversationId,
      aboutName: aboutName ?? this.aboutName,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      lastAccessedAtMs: lastAccessedAtMs ?? this.lastAccessedAtMs,
      accessCount: accessCount ?? this.accessCount,
      isActive: isActive ?? this.isActive,
      archivedAtMs: archivedAtMs ?? this.archivedAtMs,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'characterId': characterId,
    'text': text,
    'category': category.name,
    'importance': importance,
    'tags': tags,
    'source': source.name,
    'conversationId': conversationId,
    'aboutName': aboutName,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'lastAccessedAtMs': lastAccessedAtMs,
    'accessCount': accessCount,
    'isActive': isActive,
    'archivedAtMs': archivedAtMs,
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    int readInt(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    double readDouble(String key, double fallback) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      return fallback;
    }

    MemoryCategory readCategory(Object? raw) {
      for (final value in MemoryCategory.values) {
        if (value.name == raw) {
          return value;
        }
      }
      return MemoryCategory.fact;
    }

    MemorySource readSource(Object? raw) {
      for (final value in MemorySource.values) {
        if (value.name == raw) {
          return value;
        }
      }
      return MemorySource.auto;
    }

    final rawTags = json['tags'];
    final tags = <String>[
      if (rawTags is List)
        for (final tag in rawTags)
          if (tag is String) tag,
    ];
    final createdAt = readInt('createdAtMs');
    return MemoryEntry(
      id: readString('id'),
      characterId: readString('characterId'),
      text: readString('text'),
      category: readCategory(json['category']),
      importance: readDouble('importance', 0.5),
      tags: tags,
      source: readSource(json['source']),
      conversationId: readString('conversationId'),
      aboutName: readString('aboutName'),
      createdAtMs: createdAt,
      updatedAtMs: readInt('updatedAtMs'),
      lastAccessedAtMs: readInt('lastAccessedAtMs'),
      accessCount: readInt('accessCount'),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      archivedAtMs: readInt('archivedAtMs'),
    ).normalized();
  }
}

class MemorySettings {
  const MemorySettings({
    this.enabled = true,
    this.autoExtract = true,
    this.recallCount = 6,
    this.extractIdleMinutes = 10,
    this.extractMinMessages = 8,
    this.maxMemoriesPerCharacter = 500,
  });

  static const defaults = MemorySettings();

  final bool enabled;
  final bool autoExtract;
  final int recallCount;
  final int extractIdleMinutes;
  final int extractMinMessages;
  final int maxMemoriesPerCharacter;

  MemorySettings normalized() {
    return MemorySettings(
      enabled: enabled,
      autoExtract: autoExtract,
      recallCount: recallCount.clamp(0, 20).toInt(),
      extractIdleMinutes: extractIdleMinutes < 1 ? 1 : extractIdleMinutes,
      extractMinMessages: extractMinMessages < 2 ? 2 : extractMinMessages,
      maxMemoriesPerCharacter: maxMemoriesPerCharacter < 10
          ? 10
          : maxMemoriesPerCharacter,
    );
  }

  MemorySettings copyWith({
    bool? enabled,
    bool? autoExtract,
    int? recallCount,
    int? extractIdleMinutes,
    int? extractMinMessages,
    int? maxMemoriesPerCharacter,
  }) {
    return MemorySettings(
      enabled: enabled ?? this.enabled,
      autoExtract: autoExtract ?? this.autoExtract,
      recallCount: recallCount ?? this.recallCount,
      extractIdleMinutes: extractIdleMinutes ?? this.extractIdleMinutes,
      extractMinMessages: extractMinMessages ?? this.extractMinMessages,
      maxMemoriesPerCharacter:
          maxMemoriesPerCharacter ?? this.maxMemoriesPerCharacter,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'autoExtract': autoExtract,
    'recallCount': recallCount,
    'extractIdleMinutes': extractIdleMinutes,
    'extractMinMessages': extractMinMessages,
    'maxMemoriesPerCharacter': maxMemoriesPerCharacter,
  };

  factory MemorySettings.fromJson(Map<String, dynamic> json) {
    bool readBool(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    int readInt(String key, int fallback) {
      final value = json[key];
      return value is int ? value : fallback;
    }

    return MemorySettings(
      enabled: readBool('enabled', defaults.enabled),
      autoExtract: readBool('autoExtract', defaults.autoExtract),
      recallCount: readInt('recallCount', defaults.recallCount),
      extractIdleMinutes: readInt(
        'extractIdleMinutes',
        defaults.extractIdleMinutes,
      ),
      extractMinMessages: readInt(
        'extractMinMessages',
        defaults.extractMinMessages,
      ),
      maxMemoriesPerCharacter: readInt(
        'maxMemoriesPerCharacter',
        defaults.maxMemoriesPerCharacter,
      ),
    ).normalized();
  }
}

class MemoryExtractionState {
  const MemoryExtractionState({
    this.lastProcessedMessageId = '',
    this.lastProcessedAtMs = 0,
    this.lastError = '',
    this.nextRetryAtMs = 0,
  });

  final String lastProcessedMessageId;
  final int lastProcessedAtMs;
  final String lastError;
  final int nextRetryAtMs;

  MemoryExtractionState normalized() {
    return MemoryExtractionState(
      lastProcessedMessageId: lastProcessedMessageId.trim(),
      lastProcessedAtMs: lastProcessedAtMs < 0 ? 0 : lastProcessedAtMs,
      lastError: lastError.trim(),
      nextRetryAtMs: nextRetryAtMs < 0 ? 0 : nextRetryAtMs,
    );
  }

  MemoryExtractionState copyWith({
    String? lastProcessedMessageId,
    int? lastProcessedAtMs,
    String? lastError,
    int? nextRetryAtMs,
  }) {
    return MemoryExtractionState(
      lastProcessedMessageId:
          lastProcessedMessageId ?? this.lastProcessedMessageId,
      lastProcessedAtMs: lastProcessedAtMs ?? this.lastProcessedAtMs,
      lastError: lastError ?? this.lastError,
      nextRetryAtMs: nextRetryAtMs ?? this.nextRetryAtMs,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'lastProcessedMessageId': lastProcessedMessageId,
    'lastProcessedAtMs': lastProcessedAtMs,
    'lastError': lastError,
    'nextRetryAtMs': nextRetryAtMs,
  };

  factory MemoryExtractionState.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    int readInt(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    return MemoryExtractionState(
      lastProcessedMessageId: readString('lastProcessedMessageId'),
      lastProcessedAtMs: readInt('lastProcessedAtMs'),
      lastError: readString('lastError'),
      nextRetryAtMs: readInt('nextRetryAtMs'),
    ).normalized();
  }
}

class MemoryException implements Exception {
  const MemoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
