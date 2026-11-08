class MomentInteractionSettings {
  const MomentInteractionSettings({
    this.autoCommentCount = 2,
    this.autoReplyDepth = 1,
  });

  static const defaults = MomentInteractionSettings();

  static const unlimited = -1;

  final int autoCommentCount;
  final int autoReplyDepth;

  MomentInteractionSettings normalized() {
    return MomentInteractionSettings(
      autoCommentCount: _normalize(autoCommentCount),
      autoReplyDepth: _normalize(autoReplyDepth),
    );
  }

  static int _normalize(int value) {
    if (value < 0) {
      return unlimited;
    }
    return value;
  }

  MomentInteractionSettings copyWith({
    int? autoCommentCount,
    int? autoReplyDepth,
  }) {
    return MomentInteractionSettings(
      autoCommentCount: autoCommentCount ?? this.autoCommentCount,
      autoReplyDepth: autoReplyDepth ?? this.autoReplyDepth,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'autoCommentCount': autoCommentCount,
    'autoReplyDepth': autoReplyDepth,
  };

  factory MomentInteractionSettings.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      return value is int ? value : fallback;
    }

    return MomentInteractionSettings(
      autoCommentCount: readInt('autoCommentCount', defaults.autoCommentCount),
      autoReplyDepth: readInt('autoReplyDepth', defaults.autoReplyDepth),
    ).normalized();
  }
}
