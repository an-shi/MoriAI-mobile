class ProactiveMessageState {
  const ProactiveMessageState({
    this.enabled = true,
    this.dailyLimit = 0,
    this.lastActivityAtMs = 0,
    this.nextSilenceAtMs = 0,
    this.lastProactiveAtMs = 0,
    this.lastUserMessageAtMs = 0,
    this.lastAssistantAtMs = 0,
    this.lastAssistantMessageId = '',
    this.lastAssistantText = '',
    this.nudgedMessageId = '',
    this.unansweredCount = 0,
    this.dailyDate = '',
    this.dailyCount = 0,
    this.firedSlots = const [],
  });

  final bool enabled;

  /// 0 表示跟随全局每日总上限。
  final int dailyLimit;
  final int lastActivityAtMs;
  final int nextSilenceAtMs;
  final int lastProactiveAtMs;
  final int lastUserMessageAtMs;
  final int lastAssistantAtMs;
  final String lastAssistantMessageId;
  final String lastAssistantText;
  final String nudgedMessageId;
  final int unansweredCount;
  final String dailyDate;
  final int dailyCount;
  final List<String> firedSlots;

  DateTime? get lastActivityAt => _toDateTime(lastActivityAtMs);

  DateTime? get nextSilenceAt => _toDateTime(nextSilenceAtMs);

  DateTime? get lastProactiveAt => _toDateTime(lastProactiveAtMs);

  DateTime? get lastUserMessageAt => _toDateTime(lastUserMessageAtMs);

  DateTime? get lastAssistantAt => _toDateTime(lastAssistantAtMs);

  ProactiveMessageState normalized() {
    final slots = <String>[];
    final seen = <String>{};
    for (final slot in firedSlots) {
      final normalized = slot.trim();
      if (normalized.isNotEmpty && seen.add(normalized)) {
        slots.add(normalized);
      }
    }
    return ProactiveMessageState(
      enabled: enabled,
      dailyLimit: dailyLimit.clamp(0, 20),
      lastActivityAtMs: lastActivityAtMs < 0 ? 0 : lastActivityAtMs,
      nextSilenceAtMs: nextSilenceAtMs < 0 ? 0 : nextSilenceAtMs,
      lastProactiveAtMs: lastProactiveAtMs < 0 ? 0 : lastProactiveAtMs,
      lastUserMessageAtMs: lastUserMessageAtMs < 0 ? 0 : lastUserMessageAtMs,
      lastAssistantAtMs: lastAssistantAtMs < 0 ? 0 : lastAssistantAtMs,
      lastAssistantMessageId: lastAssistantMessageId.trim(),
      lastAssistantText: lastAssistantText.trim(),
      nudgedMessageId: nudgedMessageId.trim(),
      unansweredCount: unansweredCount < 0 ? 0 : unansweredCount,
      dailyDate: dailyDate.trim(),
      dailyCount: dailyCount < 0 ? 0 : dailyCount,
      firedSlots: List<String>.unmodifiable(slots),
    );
  }

  ProactiveMessageState copyWith({
    bool? enabled,
    int? dailyLimit,
    int? lastActivityAtMs,
    int? nextSilenceAtMs,
    int? lastProactiveAtMs,
    int? lastUserMessageAtMs,
    int? lastAssistantAtMs,
    String? lastAssistantMessageId,
    String? lastAssistantText,
    String? nudgedMessageId,
    int? unansweredCount,
    String? dailyDate,
    int? dailyCount,
    List<String>? firedSlots,
  }) {
    return ProactiveMessageState(
      enabled: enabled ?? this.enabled,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      lastActivityAtMs: lastActivityAtMs ?? this.lastActivityAtMs,
      nextSilenceAtMs: nextSilenceAtMs ?? this.nextSilenceAtMs,
      lastProactiveAtMs: lastProactiveAtMs ?? this.lastProactiveAtMs,
      lastUserMessageAtMs: lastUserMessageAtMs ?? this.lastUserMessageAtMs,
      lastAssistantAtMs: lastAssistantAtMs ?? this.lastAssistantAtMs,
      lastAssistantMessageId:
          lastAssistantMessageId ?? this.lastAssistantMessageId,
      lastAssistantText: lastAssistantText ?? this.lastAssistantText,
      nudgedMessageId: nudgedMessageId ?? this.nudgedMessageId,
      unansweredCount: unansweredCount ?? this.unansweredCount,
      dailyDate: dailyDate ?? this.dailyDate,
      dailyCount: dailyCount ?? this.dailyCount,
      firedSlots: firedSlots ?? this.firedSlots,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'dailyLimit': dailyLimit,
    'lastActivityAtMs': lastActivityAtMs,
    'nextSilenceAtMs': nextSilenceAtMs,
    'lastProactiveAtMs': lastProactiveAtMs,
    'lastUserMessageAtMs': lastUserMessageAtMs,
    'lastAssistantAtMs': lastAssistantAtMs,
    'lastAssistantMessageId': lastAssistantMessageId,
    'lastAssistantText': lastAssistantText,
    'nudgedMessageId': nudgedMessageId,
    'unansweredCount': unansweredCount,
    'dailyDate': dailyDate,
    'dailyCount': dailyCount,
    'firedSlots': firedSlots,
  };

  factory ProactiveMessageState.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    String readString(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    final rawSlots = json['firedSlots'];
    final slots = rawSlots is List
        ? [
            for (final item in rawSlots)
              if (item is String && item.trim().isNotEmpty) item.trim(),
          ]
        : const <String>[];

    return ProactiveMessageState(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      dailyLimit: readInt('dailyLimit'),
      lastActivityAtMs: readInt('lastActivityAtMs'),
      nextSilenceAtMs: readInt('nextSilenceAtMs'),
      lastProactiveAtMs: readInt('lastProactiveAtMs'),
      lastUserMessageAtMs: readInt('lastUserMessageAtMs'),
      lastAssistantAtMs: readInt('lastAssistantAtMs'),
      lastAssistantMessageId: readString('lastAssistantMessageId'),
      lastAssistantText: readString('lastAssistantText'),
      nudgedMessageId: readString('nudgedMessageId'),
      unansweredCount: readInt('unansweredCount'),
      dailyDate: json['dailyDate'] is String
          ? (json['dailyDate'] as String).trim()
          : '',
      dailyCount: readInt('dailyCount'),
      firedSlots: slots,
    ).normalized();
  }

  static DateTime? _toDateTime(int milliseconds) {
    if (milliseconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
