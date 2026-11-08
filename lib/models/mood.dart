import 'dart:math';

const List<String> _moodUpWords = [
  '喜欢你',
  '爱你',
  '想你',
  '可爱',
  '好看',
  '漂亮',
  '聪明',
  '真棒',
  '厉害',
  '牛',
  '谢谢',
  '辛苦',
  '晚安',
  '早安',
  '抱抱',
  '摸摸',
  '贴贴',
  '乖',
  '宝贝',
  '爱了',
  '哈哈哈',
  '好吃',
  '请你吃',
];

const List<String> _moodDownWords = [
  '讨厌',
  '滚',
  '烦死',
  '闭嘴',
  '笨',
  '蠢',
  '傻',
  '丑',
  '垃圾',
  '废物',
  '恶心',
  '无聊',
  '走开',
  '别理我',
  '不理你',
  '别说话',
  '生气',
  '难过',
  '烦人',
];

String moodLabel(int value) {
  if (value >= 85) {
    return '超开心';
  }
  if (value >= 70) {
    return '心情不错';
  }
  if (value >= 50) {
    return '平平常常';
  }
  if (value >= 35) {
    return '有点低落';
  }
  return '不太开心';
}

String moodStyle(int value) {
  if (value >= 85) {
    return '话多一点、语气活泼，爱用语气词和感叹，更愿意接话、开玩笑';
  }
  if (value >= 70) {
    return '语气轻快，爱开点小玩笑，回得积极一些';
  }
  if (value >= 50) {
    return '';
  }
  if (value >= 35) {
    return '话少一点、句子短，回得有点懒；有人关心你会慢慢好起来';
  }
  return '有点小脾气、带点委屈，回得简短，可能会怼一句（但别伤人）；被哄、被夸会消气';
}

class MoodEffects {
  const MoodEffects({
    required this.sticker,
    required this.voice,
    required this.delay,
    required this.chatty,
  });

  final double sticker;
  final double voice;
  final double delay;
  final double chatty;
}

MoodEffects moodEffects(int value) {
  if (value >= 85) {
    return const MoodEffects(
      sticker: 1.6,
      voice: 1.5,
      delay: 0.85,
      chatty: 1.5,
    );
  }
  if (value >= 70) {
    return const MoodEffects(
      sticker: 1.25,
      voice: 1.2,
      delay: 0.92,
      chatty: 1.2,
    );
  }
  if (value >= 50) {
    return const MoodEffects(sticker: 1, voice: 1, delay: 1, chatty: 1);
  }
  if (value >= 35) {
    return const MoodEffects(sticker: 0.5, voice: 0.6, delay: 1.3, chatty: 0.6);
  }
  return const MoodEffects(sticker: 0.3, voice: 0.4, delay: 1.5, chatty: 0.4);
}

int scoreMoodText(String text) {
  var score = 0;
  for (final word in _moodUpWords) {
    if (text.contains(word)) {
      score += 6;
    }
  }
  for (final word in _moodDownWords) {
    if (text.contains(word)) {
      score -= 8;
    }
  }
  return score.clamp(-20, 20).toInt();
}

class MoodSettings {
  const MoodSettings({
    this.enabled = true,
    this.base = 60,
    this.halfLifeHours = 3,
  });

  static const defaults = MoodSettings();

  final bool enabled;
  final int base;
  final int halfLifeHours;

  MoodSettings normalized() {
    return MoodSettings(
      enabled: enabled,
      base: base.clamp(0, 100).toInt(),
      halfLifeHours: halfLifeHours.clamp(1, 24).toInt(),
    );
  }

  MoodSettings copyWith({bool? enabled, int? base, int? halfLifeHours}) {
    return MoodSettings(
      enabled: enabled ?? this.enabled,
      base: base ?? this.base,
      halfLifeHours: halfLifeHours ?? this.halfLifeHours,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'base': base,
    'halfLifeHours': halfLifeHours,
  };

  factory MoodSettings.fromJson(Map<String, dynamic> json) {
    bool readBool(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    int readInt(String key, int fallback) {
      final value = json[key];
      return value is int ? value : fallback;
    }

    return MoodSettings(
      enabled: readBool('enabled', defaults.enabled),
      base: readInt('base', defaults.base),
      halfLifeHours: readInt('halfLifeHours', defaults.halfLifeHours),
    ).normalized();
  }
}

class MoodHistoryEntry {
  const MoodHistoryEntry({
    required this.atMs,
    required this.from,
    required this.to,
    required this.reason,
  });

  final int atMs;
  final int from;
  final int to;
  final String reason;

  Map<String, dynamic> toJson() => {
    'atMs': atMs,
    'from': from,
    'to': to,
    'reason': reason,
  };

  factory MoodHistoryEntry.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    return MoodHistoryEntry(
      atMs: readInt('atMs'),
      from: readInt('from'),
      to: readInt('to'),
      reason: json['reason'] is String ? (json['reason'] as String).trim() : '',
    );
  }
}

class MoodState {
  const MoodState({
    this.value = 60,
    this.updatedAtMs = 0,
    this.reason = '',
    this.history = const [],
  });

  final int value;
  final int updatedAtMs;
  final String reason;
  final List<MoodHistoryEntry> history;

  MoodState normalized(MoodSettings settings) {
    return MoodState(
      value: value.clamp(0, 100).toInt(),
      updatedAtMs: updatedAtMs < 0 ? 0 : updatedAtMs,
      reason: reason.trim(),
      history: List<MoodHistoryEntry>.unmodifiable(history.take(50)),
    );
  }

  MoodState decayed(MoodSettings settings, DateTime now) {
    if (updatedAtMs <= 0) {
      return MoodState(
        value: settings.base,
        updatedAtMs: now.millisecondsSinceEpoch,
        reason: '',
        history: history,
      );
    }
    final hours = max(
      0.0,
      (now.millisecondsSinceEpoch - updatedAtMs) / Duration.millisecondsPerHour,
    );
    final decayedValue =
        settings.base +
        (value - settings.base) *
            pow(0.5, hours / settings.halfLifeHours).toDouble();
    return MoodState(
      value: decayedValue.round().clamp(0, 100).toInt(),
      updatedAtMs: now.millisecondsSinceEpoch,
      reason: reason,
      history: history,
    );
  }

  MoodState copyWith({
    int? value,
    int? updatedAtMs,
    String? reason,
    List<MoodHistoryEntry>? history,
  }) {
    return MoodState(
      value: value ?? this.value,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      reason: reason ?? this.reason,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'updatedAtMs': updatedAtMs,
    'reason': reason,
    'history': [for (final entry in history) entry.toJson()],
  };

  factory MoodState.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      return value is int ? value : fallback;
    }

    final rawHistory = json['history'];
    final history = <MoodHistoryEntry>[];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map) {
          try {
            history.add(
              MoodHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (_) {
            // 跳过损坏的历史记录。
          }
        }
      }
    }

    return MoodState(
      value: readInt('value', 60),
      updatedAtMs: readInt('updatedAtMs', 0),
      reason: json['reason'] is String ? (json['reason'] as String).trim() : '',
      history: history,
    );
  }
}

class MoodSnapshot {
  const MoodSnapshot({
    required this.value,
    required this.updatedAtMs,
    required this.reason,
    required this.history,
  });

  final int value;
  final int updatedAtMs;
  final String reason;
  final List<MoodHistoryEntry> history;

  String get label => moodLabel(value);

  String get style => moodStyle(value);

  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
}
