enum CharacterActivityKind {
  singleMessage,
  groupMessage,
  proactiveMessage,
  moment,
  momentComment,
  momentReply,
}

enum CharacterActivityPrivacy { private, group, public }

extension CharacterActivityKindLabel on CharacterActivityKind {
  String get label => switch (this) {
    CharacterActivityKind.singleMessage => '单聊',
    CharacterActivityKind.groupMessage => '群聊',
    CharacterActivityKind.proactiveMessage => '主动消息',
    CharacterActivityKind.moment => '动态',
    CharacterActivityKind.momentComment => '动态评论',
    CharacterActivityKind.momentReply => '动态回复',
  };
}

class CharacterActivity {
  const CharacterActivity({
    required this.id,
    required this.characterId,
    required this.kind,
    required this.contextId,
    required this.contextLabel,
    required this.content,
    required this.createdAtMs,
  });

  final String id;
  final String characterId;
  final CharacterActivityKind kind;
  final String contextId;
  final String contextLabel;
  final String content;
  final int createdAtMs;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  CharacterActivityPrivacy get privacy => switch (kind) {
    CharacterActivityKind.singleMessage ||
    CharacterActivityKind.proactiveMessage => CharacterActivityPrivacy.private,
    CharacterActivityKind.groupMessage => CharacterActivityPrivacy.group,
    CharacterActivityKind.moment ||
    CharacterActivityKind.momentComment ||
    CharacterActivityKind.momentReply => CharacterActivityPrivacy.public,
  };

  bool get isPublic => privacy == CharacterActivityPrivacy.public;

  bool get isGroup => privacy == CharacterActivityPrivacy.group;

  bool get isPrivate => privacy == CharacterActivityPrivacy.private;

  CharacterActivity normalized() {
    final trimmedId = id.trim();
    final trimmedCharacterId = characterId.trim();
    final trimmedContextId = contextId.trim();
    final trimmedLabel = contextLabel.trim();
    var trimmedContent = content.trim();
    if (trimmedContent.length > 500) {
      trimmedContent = trimmedContent.substring(0, 500);
    }
    return CharacterActivity(
      id: trimmedId,
      characterId: trimmedCharacterId,
      kind: kind,
      contextId: trimmedContextId,
      contextLabel: trimmedLabel,
      content: trimmedContent,
      createdAtMs: createdAtMs < 0 ? 0 : createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'characterId': characterId,
    'kind': kind.name,
    'contextId': contextId,
    'contextLabel': contextLabel,
    'content': content,
    'createdAtMs': createdAtMs,
  };

  factory CharacterActivity.fromJson(Map<String, dynamic> json) {
    CharacterActivityKind readKind(Object? raw) {
      for (final value in CharacterActivityKind.values) {
        if (value.name == raw) {
          return value;
        }
      }
      return CharacterActivityKind.singleMessage;
    }

    String readString(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    final createdAt = json['createdAtMs'];
    return CharacterActivity(
      id: readString('id'),
      characterId: readString('characterId'),
      kind: readKind(json['kind']),
      contextId: readString('contextId'),
      contextLabel: readString('contextLabel'),
      content: readString('content'),
      createdAtMs: createdAt is int && createdAt > 0 ? createdAt : 0,
    ).normalized();
  }
}
