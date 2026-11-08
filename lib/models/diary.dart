const int diaryDefaultTimeMinutes = 22 * 60 + 30;

String diaryDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? diaryDateFromKey(String value) {
  final trimmed = value.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    return null;
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null || diaryDateKey(parsed) != trimmed) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String diaryTimeLabel(int minutes) {
  final normalized = minutes.clamp(0, 24 * 60 - 1);
  final hour = (normalized ~/ 60).toString().padLeft(2, '0');
  final minute = (normalized % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

int diaryTimeFromLabel(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) {
    return diaryDefaultTimeMinutes;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return diaryDefaultTimeMinutes;
  }
  return hour * 60 + minute;
}

class DiaryCharacterSettings {
  const DiaryCharacterSettings({
    this.enabled = true,
    this.timeMinutes = diaryDefaultTimeMinutes,
  });

  static const defaults = DiaryCharacterSettings();

  final bool enabled;
  final int timeMinutes;

  String get timeLabel => diaryTimeLabel(timeMinutes);

  DiaryCharacterSettings normalized() {
    return DiaryCharacterSettings(
      enabled: enabled,
      timeMinutes: timeMinutes.clamp(0, 24 * 60 - 1).toInt(),
    );
  }

  DiaryCharacterSettings copyWith({bool? enabled, int? timeMinutes}) {
    return DiaryCharacterSettings(
      enabled: enabled ?? this.enabled,
      timeMinutes: timeMinutes ?? this.timeMinutes,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'timeMinutes': timeMinutes,
  };

  factory DiaryCharacterSettings.fromJson(Map<String, dynamic> json) {
    final rawEnabled = json['enabled'];
    final rawTime = json['timeMinutes'];
    return DiaryCharacterSettings(
      enabled: rawEnabled is bool ? rawEnabled : defaults.enabled,
      timeMinutes: rawTime is int ? rawTime : defaults.timeMinutes,
    ).normalized();
  }
}

class DiarySettings {
  const DiarySettings({
    this.enabled = false,
    this.timeMinutes = diaryDefaultTimeMinutes,
    this.characterSettings = const {},
  });

  static const defaults = DiarySettings();

  final bool enabled;
  final int timeMinutes;

  /// 按角色覆盖全局配置；没有记录表示跟随全局。
  final Map<String, DiaryCharacterSettings> characterSettings;

  String get timeLabel => diaryTimeLabel(timeMinutes);

  DiaryCharacterSettings? settingsFor(String characterId) {
    return characterSettings[characterId.trim()];
  }

  bool hasOverride(String characterId) {
    return characterSettings.containsKey(characterId.trim());
  }

  bool isEnabledFor(String characterId) {
    return settingsFor(characterId)?.enabled ?? enabled;
  }

  int timeMinutesFor(String characterId) {
    return settingsFor(characterId)?.timeMinutes ?? timeMinutes;
  }

  String timeLabelFor(String characterId) {
    return diaryTimeLabel(timeMinutesFor(characterId));
  }

  DiarySettings setCharacterSettings(
    String characterId,
    DiaryCharacterSettings settings,
  ) {
    final id = characterId.trim();
    if (id.isEmpty) {
      return this;
    }
    return copyWith(
      characterSettings: {...characterSettings, id: settings.normalized()},
    );
  }

  DiarySettings clearCharacterSettings(String characterId) {
    final id = characterId.trim();
    if (id.isEmpty || !characterSettings.containsKey(id)) {
      return this;
    }
    final next = Map<String, DiaryCharacterSettings>.from(characterSettings)
      ..remove(id);
    return copyWith(characterSettings: next);
  }

  DiarySettings normalized() {
    final normalizedCharacters = <String, DiaryCharacterSettings>{};
    for (final entry in characterSettings.entries) {
      final id = entry.key.trim();
      if (id.isEmpty) {
        continue;
      }
      normalizedCharacters[id] = entry.value.normalized();
    }
    return DiarySettings(
      enabled: enabled,
      timeMinutes: timeMinutes.clamp(0, 24 * 60 - 1).toInt(),
      characterSettings: Map<String, DiaryCharacterSettings>.unmodifiable(
        normalizedCharacters,
      ),
    );
  }

  DiarySettings copyWith({
    bool? enabled,
    int? timeMinutes,
    Map<String, DiaryCharacterSettings>? characterSettings,
  }) {
    return DiarySettings(
      enabled: enabled ?? this.enabled,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      characterSettings: characterSettings ?? this.characterSettings,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'timeMinutes': timeMinutes,
    'characters': {
      for (final entry in characterSettings.entries)
        entry.key: entry.value.toJson(),
    },
  };

  factory DiarySettings.fromJson(Map<String, dynamic> json) {
    final rawEnabled = json['enabled'];
    final rawTime = json['timeMinutes'];
    final characters = <String, DiaryCharacterSettings>{};
    final rawCharacters = json['characters'];
    if (rawCharacters is Map) {
      for (final entry in rawCharacters.entries) {
        if (entry.key is! String || entry.value is! Map) {
          continue;
        }
        try {
          final id = (entry.key as String).trim();
          if (id.isEmpty) {
            continue;
          }
          characters[id] = DiaryCharacterSettings.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (_) {
          // 跳过损坏的单角色日记设置。
        }
      }
    }
    return DiarySettings(
      enabled: rawEnabled is bool ? rawEnabled : defaults.enabled,
      timeMinutes: rawTime is int ? rawTime : defaults.timeMinutes,
      characterSettings: characters,
    ).normalized();
  }
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.characterId,
    required this.dateKey,
    required this.content,
    required this.createdAtMs,
    this.moodValue = 0,
    this.moodLabel = '',
    this.messageCount = 0,
  });

  static const maxContentLength = 2000;

  final String id;
  final String characterId;
  final String dateKey;
  final String content;
  final int createdAtMs;
  final int moodValue;
  final String moodLabel;
  final int messageCount;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  DateTime? get date => diaryDateFromKey(dateKey);

  DiaryEntry normalized() {
    final trimmedContent = content.trim();
    return DiaryEntry(
      id: id.trim(),
      characterId: characterId.trim(),
      dateKey: dateKey.trim(),
      content: trimmedContent.length > maxContentLength
          ? trimmedContent.substring(0, maxContentLength)
          : trimmedContent,
      createdAtMs: createdAtMs < 0 ? 0 : createdAtMs,
      moodValue: moodValue.clamp(0, 100).toInt(),
      moodLabel: moodLabel.trim(),
      messageCount: messageCount < 0 ? 0 : messageCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'characterId': characterId,
    'dateKey': dateKey,
    'content': content,
    'createdAtMs': createdAtMs,
    'moodValue': moodValue,
    'moodLabel': moodLabel,
    'messageCount': messageCount,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    int readInt(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    return DiaryEntry(
      id: readString('id'),
      characterId: readString('characterId'),
      dateKey: readString('dateKey'),
      content: readString('content'),
      createdAtMs: readInt('createdAtMs'),
      moodValue: readInt('moodValue'),
      moodLabel: readString('moodLabel'),
      messageCount: readInt('messageCount'),
    ).normalized();
  }
}

class DiaryState {
  const DiaryState({
    this.lastAttemptDate = '',
    this.lastSuccessDate = '',
    this.lastAttemptAtMs = 0,
    this.nextRetryAtMs = 0,
    this.lastError = '',
  });

  final String lastAttemptDate;
  final String lastSuccessDate;
  final int lastAttemptAtMs;
  final int nextRetryAtMs;
  final String lastError;

  DiaryState normalized() {
    return DiaryState(
      lastAttemptDate: lastAttemptDate.trim(),
      lastSuccessDate: lastSuccessDate.trim(),
      lastAttemptAtMs: lastAttemptAtMs < 0 ? 0 : lastAttemptAtMs,
      nextRetryAtMs: nextRetryAtMs < 0 ? 0 : nextRetryAtMs,
      lastError: lastError.trim(),
    );
  }

  DiaryState copyWith({
    String? lastAttemptDate,
    String? lastSuccessDate,
    int? lastAttemptAtMs,
    int? nextRetryAtMs,
    String? lastError,
  }) {
    return DiaryState(
      lastAttemptDate: lastAttemptDate ?? this.lastAttemptDate,
      lastSuccessDate: lastSuccessDate ?? this.lastSuccessDate,
      lastAttemptAtMs: lastAttemptAtMs ?? this.lastAttemptAtMs,
      nextRetryAtMs: nextRetryAtMs ?? this.nextRetryAtMs,
      lastError: lastError ?? this.lastError,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'lastAttemptDate': lastAttemptDate,
    'lastSuccessDate': lastSuccessDate,
    'lastAttemptAtMs': lastAttemptAtMs,
    'nextRetryAtMs': nextRetryAtMs,
    'lastError': lastError,
  };

  factory DiaryState.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    int readInt(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    return DiaryState(
      lastAttemptDate: readString('lastAttemptDate'),
      lastSuccessDate: readString('lastSuccessDate'),
      lastAttemptAtMs: readInt('lastAttemptAtMs'),
      nextRetryAtMs: readInt('nextRetryAtMs'),
      lastError: readString('lastError'),
    ).normalized();
  }
}

class DiaryException implements Exception {
  const DiaryException(this.message);

  final String message;

  @override
  String toString() => message;
}
