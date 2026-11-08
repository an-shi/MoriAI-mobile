class ProactiveMessageSettings {
  const ProactiveMessageSettings({
    this.enabled = false,
    this.silenceEnabled = true,
    this.scheduledEnabled = true,
    this.silenceMinMinutes = 60,
    this.silenceMaxMinutes = 180,
    this.dailyLimit = 6,
    this.maxUnanswered = 3,
    this.nudgeEnabled = true,
    this.quietHoursEnabled = true,
    this.quietStartMinutes = 23 * 60 + 30,
    this.quietEndMinutes = 7 * 60,
    this.scheduledTimes = const ['08:30', '22:30'],
  });

  static const defaults = ProactiveMessageSettings();

  static const minSilenceMinutes = 15;
  static const maxSilenceMinutes = 360;
  static const maxDailyLimit = 20;
  static const maxUnansweredLimit = 10;

  final bool enabled;
  final bool silenceEnabled;
  final bool scheduledEnabled;
  final int silenceMinMinutes;
  final int silenceMaxMinutes;
  final int dailyLimit;
  final int maxUnanswered;
  final bool nudgeEnabled;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final List<String> scheduledTimes;

  List<int> get scheduledMinuteValues {
    final values = <int>[];
    for (final raw in scheduledTimes) {
      final minute = parseTimeOfDay(raw);
      if (minute != null) {
        values.add(minute);
      }
    }
    values.sort();
    return values;
  }

  static int? parseTimeOfDay(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  static String formatTimeOfDay(int minuteOfDay) {
    final normalized = minuteOfDay.clamp(0, 24 * 60 - 1);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  bool isQuietTime(DateTime time) {
    if (!quietHoursEnabled || quietStartMinutes == quietEndMinutes) {
      return false;
    }
    final minute = time.hour * 60 + time.minute;
    if (quietStartMinutes < quietEndMinutes) {
      return minute >= quietStartMinutes && minute < quietEndMinutes;
    }
    return minute >= quietStartMinutes || minute < quietEndMinutes;
  }

  ProactiveMessageSettings normalized() {
    final safeMin = silenceMinMinutes.clamp(
      minSilenceMinutes,
      maxSilenceMinutes - minSilenceMinutes,
    );
    final safeMax = silenceMaxMinutes.clamp(
      safeMin + minSilenceMinutes,
      maxSilenceMinutes,
    );
    final times = <String>[];
    final seen = <int>{};
    for (final raw in scheduledTimes) {
      final minute = parseTimeOfDay(raw);
      if (minute != null && seen.add(minute)) {
        times.add(formatTimeOfDay(minute));
      }
    }
    times.sort();

    return ProactiveMessageSettings(
      enabled: enabled,
      silenceEnabled: silenceEnabled,
      scheduledEnabled: scheduledEnabled,
      silenceMinMinutes: safeMin,
      silenceMaxMinutes: safeMax,
      dailyLimit: dailyLimit.clamp(1, maxDailyLimit),
      maxUnanswered: maxUnanswered.clamp(1, maxUnansweredLimit),
      nudgeEnabled: nudgeEnabled,
      quietHoursEnabled: quietHoursEnabled,
      quietStartMinutes: quietStartMinutes.clamp(0, 24 * 60 - 1),
      quietEndMinutes: quietEndMinutes.clamp(0, 24 * 60 - 1),
      scheduledTimes: List<String>.unmodifiable(times),
    );
  }

  ProactiveMessageSettings copyWith({
    bool? enabled,
    bool? silenceEnabled,
    bool? scheduledEnabled,
    int? silenceMinMinutes,
    int? silenceMaxMinutes,
    int? dailyLimit,
    int? maxUnanswered,
    bool? nudgeEnabled,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    List<String>? scheduledTimes,
  }) {
    return ProactiveMessageSettings(
      enabled: enabled ?? this.enabled,
      silenceEnabled: silenceEnabled ?? this.silenceEnabled,
      scheduledEnabled: scheduledEnabled ?? this.scheduledEnabled,
      silenceMinMinutes: silenceMinMinutes ?? this.silenceMinMinutes,
      silenceMaxMinutes: silenceMaxMinutes ?? this.silenceMaxMinutes,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      maxUnanswered: maxUnanswered ?? this.maxUnanswered,
      nudgeEnabled: nudgeEnabled ?? this.nudgeEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'silenceEnabled': silenceEnabled,
    'scheduledEnabled': scheduledEnabled,
    'silenceMinMinutes': silenceMinMinutes,
    'silenceMaxMinutes': silenceMaxMinutes,
    'dailyLimit': dailyLimit,
    'maxUnanswered': maxUnanswered,
    'nudgeEnabled': nudgeEnabled,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
    'scheduledTimes': scheduledTimes,
  };

  factory ProactiveMessageSettings.fromJson(Map<String, dynamic> json) {
    bool readBool(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    int readInt(String key, int fallback) {
      final value = json[key];
      return value is int ? value : fallback;
    }

    final rawTimes = json['scheduledTimes'];
    final times = rawTimes is List
        ? [
            for (final item in rawTimes)
              if (item is String && item.trim().isNotEmpty) item.trim(),
          ]
        : defaults.scheduledTimes;

    return ProactiveMessageSettings(
      enabled: readBool('enabled', defaults.enabled),
      silenceEnabled: readBool('silenceEnabled', defaults.silenceEnabled),
      scheduledEnabled: readBool('scheduledEnabled', defaults.scheduledEnabled),
      silenceMinMinutes: readInt(
        'silenceMinMinutes',
        defaults.silenceMinMinutes,
      ),
      silenceMaxMinutes: readInt(
        'silenceMaxMinutes',
        defaults.silenceMaxMinutes,
      ),
      dailyLimit: readInt('dailyLimit', defaults.dailyLimit),
      maxUnanswered: readInt('maxUnanswered', defaults.maxUnanswered),
      nudgeEnabled: readBool('nudgeEnabled', defaults.nudgeEnabled),
      quietHoursEnabled: readBool(
        'quietHoursEnabled',
        defaults.quietHoursEnabled,
      ),
      quietStartMinutes: readInt(
        'quietStartMinutes',
        defaults.quietStartMinutes,
      ),
      quietEndMinutes: readInt('quietEndMinutes', defaults.quietEndMinutes),
      scheduledTimes: times,
    ).normalized();
  }
}
