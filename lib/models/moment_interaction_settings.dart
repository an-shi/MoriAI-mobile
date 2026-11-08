class MomentInteractionSettings {
  const MomentInteractionSettings({
    this.autoCommentCount = 2,
    this.autoReplyDepth = 1,
  });

  static const defaults = MomentInteractionSettings();

  static const maxCommentCount = 5;
  static const maxReplyDepth = 3;

  final int autoCommentCount;
  final int autoReplyDepth;

  MomentInteractionSettings normalized() {
    return MomentInteractionSettings(
      autoCommentCount: autoCommentCount.clamp(0, maxCommentCount).toInt(),
      autoReplyDepth: autoReplyDepth.clamp(0, maxReplyDepth).toInt(),
    );
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
