import 'package:mori_ai/models/memory.dart';

class GroupMemoryEntry {
  const GroupMemoryEntry({
    required this.id,
    required this.groupId,
    required this.text,
    this.category = MemoryCategory.event,
    this.importance = 0.5,
    this.tags = const [],
    this.source = MemorySource.auto,
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
  final String groupId;
  final String text;
  final MemoryCategory category;
  final double importance;
  final List<String> tags;
  final MemorySource source;
  final int createdAtMs;
  final int updatedAtMs;
  final int lastAccessedAtMs;
  final int accessCount;
  final bool isActive;
  final int archivedAtMs;

  String get categoryLabel => category.label;

  String get sourceLabel => source.label;

  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  GroupMemoryEntry normalized() {
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
    return GroupMemoryEntry(
      id: id.trim(),
      groupId: groupId.trim(),
      text: trimmedText.length > maxTextLength
          ? trimmedText.substring(0, maxTextLength)
          : trimmedText,
      category: category,
      importance: importance.clamp(0, 1).toDouble(),
      tags: List<String>.unmodifiable(normalizedTags),
      source: source,
      createdAtMs: created,
      updatedAtMs: updated,
      lastAccessedAtMs: lastAccessedAtMs < 0 ? 0 : lastAccessedAtMs,
      accessCount: accessCount < 0 ? 0 : accessCount,
      isActive: isActive,
      archivedAtMs: archivedAtMs < 0 ? 0 : archivedAtMs,
    );
  }

  GroupMemoryEntry copyWith({
    String? id,
    String? groupId,
    String? text,
    MemoryCategory? category,
    double? importance,
    List<String>? tags,
    MemorySource? source,
    int? createdAtMs,
    int? updatedAtMs,
    int? lastAccessedAtMs,
    int? accessCount,
    bool? isActive,
    int? archivedAtMs,
  }) {
    return GroupMemoryEntry(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      text: text ?? this.text,
      category: category ?? this.category,
      importance: importance ?? this.importance,
      tags: tags ?? this.tags,
      source: source ?? this.source,
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
    'groupId': groupId,
    'text': text,
    'category': category.name,
    'importance': importance,
    'tags': tags,
    'source': source.name,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'lastAccessedAtMs': lastAccessedAtMs,
    'accessCount': accessCount,
    'isActive': isActive,
    'archivedAtMs': archivedAtMs,
  };

  factory GroupMemoryEntry.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    int readInt(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    MemoryCategory readCategory(Object? raw) {
      for (final value in MemoryCategory.values) {
        if (value.name == raw) {
          return value;
        }
      }
      return MemoryCategory.event;
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
    return GroupMemoryEntry(
      id: readString('id'),
      groupId: readString('groupId'),
      text: readString('text'),
      category: readCategory(json['category']),
      importance: json['importance'] is num
          ? (json['importance'] as num).toDouble()
          : 0.5,
      tags: [
        if (rawTags is List)
          for (final tag in rawTags)
            if (tag is String) tag,
      ],
      source: readSource(json['source']),
      createdAtMs: readInt('createdAtMs'),
      updatedAtMs: readInt('updatedAtMs'),
      lastAccessedAtMs: readInt('lastAccessedAtMs'),
      accessCount: readInt('accessCount'),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      archivedAtMs: readInt('archivedAtMs'),
    ).normalized();
  }
}

class GroupMemoryProfile {
  const GroupMemoryProfile({
    this.groupId = '',
    this.summary = '',
    this.sharedHabits = '',
    this.recentFocus = '',
    this.importantDates = const [],
    this.updatedAtMs = 0,
  });

  static const maxFieldLength = 300;
  static const maxImportantDates = 5;
  static const maxDateLength = 40;

  final String groupId;

  /// 群是什么样、成员之间是什么氛围和关系。
  final String summary;

  /// 群里反复出现的共同话题、梗和相处习惯。
  final String sharedHabits;

  /// 群里最近在忙的事、共同计划或近况。
  final String recentFocus;

  /// 群里的重要日期或约定。
  final List<String> importantDates;

  final int updatedAtMs;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      sharedHabits.trim().isEmpty &&
      recentFocus.trim().isEmpty &&
      importantDates.isEmpty;

  bool get isNotEmpty => !isEmpty;

  GroupMemoryProfile normalized() {
    String clip(String value) {
      final trimmed = value.trim();
      return trimmed.length > maxFieldLength
          ? trimmed.substring(0, maxFieldLength)
          : trimmed;
    }

    final dates = <String>[];
    for (final raw in importantDates) {
      final date = raw.trim();
      if (date.isEmpty || dates.contains(date)) {
        continue;
      }
      dates.add(
        date.length > maxDateLength ? date.substring(0, maxDateLength) : date,
      );
      if (dates.length >= maxImportantDates) {
        break;
      }
    }
    return GroupMemoryProfile(
      groupId: groupId.trim(),
      summary: clip(summary),
      sharedHabits: clip(sharedHabits),
      recentFocus: clip(recentFocus),
      importantDates: List<String>.unmodifiable(dates),
      updatedAtMs: updatedAtMs < 0 ? 0 : updatedAtMs,
    );
  }

  GroupMemoryProfile copyWith({
    String? groupId,
    String? summary,
    String? sharedHabits,
    String? recentFocus,
    List<String>? importantDates,
    int? updatedAtMs,
  }) {
    return GroupMemoryProfile(
      groupId: groupId ?? this.groupId,
      summary: summary ?? this.summary,
      sharedHabits: sharedHabits ?? this.sharedHabits,
      recentFocus: recentFocus ?? this.recentFocus,
      importantDates: importantDates ?? this.importantDates,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    ).normalized();
  }

  List<String> toContextLines() {
    return [
      if (summary.trim().isNotEmpty) '- 群氛围：${summary.trim()}',
      if (sharedHabits.trim().isNotEmpty) '- 共同话题：${sharedHabits.trim()}',
      if (recentFocus.trim().isNotEmpty) '- 最近在聊：${recentFocus.trim()}',
      if (importantDates.isNotEmpty) '- 重要日期：${importantDates.join('、')}',
    ];
  }

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'summary': summary,
    'sharedHabits': sharedHabits,
    'recentFocus': recentFocus,
    'importantDates': importantDates,
    'updatedAtMs': updatedAtMs,
  };

  factory GroupMemoryProfile.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    final rawDates = json['importantDates'];
    return GroupMemoryProfile(
      groupId: readString('groupId'),
      summary: readString('summary'),
      sharedHabits: readString('sharedHabits'),
      recentFocus: readString('recentFocus'),
      importantDates: [
        if (rawDates is List)
          for (final date in rawDates)
            if (date is String) date,
      ],
      updatedAtMs: json['updatedAtMs'] is int ? json['updatedAtMs'] as int : 0,
    ).normalized();
  }
}
