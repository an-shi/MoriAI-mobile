class ChatReplySettings {
  const ChatReplySettings({
    this.sendDelaySeconds = 2,
    this.focusLeaveDelaySeconds = 1,
  });

  static const defaults = ChatReplySettings();
  static const maxDelaySeconds = 30;

  /// 发出消息后，用户没有继续输入时，等待多久再让角色回复。
  final int sendDelaySeconds;

  /// 用户在发送后继续输入过，焦点离开输入框后再等待多久回复。
  final int focusLeaveDelaySeconds;

  ChatReplySettings normalized() {
    return ChatReplySettings(
      sendDelaySeconds: sendDelaySeconds.clamp(0, maxDelaySeconds).toInt(),
      focusLeaveDelaySeconds: focusLeaveDelaySeconds
          .clamp(0, maxDelaySeconds)
          .toInt(),
    );
  }

  ChatReplySettings copyWith({
    int? sendDelaySeconds,
    int? focusLeaveDelaySeconds,
  }) {
    return ChatReplySettings(
      sendDelaySeconds: sendDelaySeconds ?? this.sendDelaySeconds,
      focusLeaveDelaySeconds:
          focusLeaveDelaySeconds ?? this.focusLeaveDelaySeconds,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'sendDelaySeconds': sendDelaySeconds,
    'focusLeaveDelaySeconds': focusLeaveDelaySeconds,
  };

  factory ChatReplySettings.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      return value is int ? value : fallback;
    }

    return ChatReplySettings(
      sendDelaySeconds: readInt('sendDelaySeconds', defaults.sendDelaySeconds),
      focusLeaveDelaySeconds: readInt(
        'focusLeaveDelaySeconds',
        defaults.focusLeaveDelaySeconds,
      ),
    ).normalized();
  }
}
