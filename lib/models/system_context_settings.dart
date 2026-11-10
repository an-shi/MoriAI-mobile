class SystemContextSettings {
  const SystemContextSettings({this.timeAwarenessEnabled = true});

  static const defaults = SystemContextSettings();

  /// 是否让模型知道当前日期、时间、星期和时区。
  final bool timeAwarenessEnabled;

  SystemContextSettings normalized() {
    return SystemContextSettings(timeAwarenessEnabled: timeAwarenessEnabled);
  }

  SystemContextSettings copyWith({bool? timeAwarenessEnabled}) {
    return SystemContextSettings(
      timeAwarenessEnabled: timeAwarenessEnabled ?? this.timeAwarenessEnabled,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'timeAwarenessEnabled': timeAwarenessEnabled,
  };

  factory SystemContextSettings.fromJson(Map<String, dynamic> json) {
    final value = json['timeAwarenessEnabled'];
    return SystemContextSettings(
      timeAwarenessEnabled: value is bool
          ? value
          : defaults.timeAwarenessEnabled,
    ).normalized();
  }
}
