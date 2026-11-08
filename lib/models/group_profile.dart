import 'package:mori_ai/models/group_reply_mode.dart';

class GroupProfile {
  const GroupProfile({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdAt,
    this.avatar = '',
    this.replyMode = GroupReplyMode.sequential,
  });

  final String id;
  final String name;
  final String avatar;
  final List<String> memberIds;
  final DateTime createdAt;
  final GroupReplyMode replyMode;

  String get displayName => name.trim().isEmpty ? '群聊' : name.trim();

  GroupProfile copyWith({
    String? name,
    String? avatar,
    List<String>? memberIds,
    GroupReplyMode? replyMode,
  }) {
    return GroupProfile(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt,
      replyMode: replyMode ?? this.replyMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'memberIds': memberIds,
    'createdAt': createdAt.toIso8601String(),
    'replyMode': replyMode.name,
  };

  factory GroupProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final rawMembers = json['memberIds'];
    final rawCreatedAt = json['createdAt'];
    if (id is! String || name is! String || rawMembers is! List) {
      throw const FormatException('Invalid group profile');
    }

    final memberIds = <String>[];
    for (final member in rawMembers) {
      if (member is String && member.trim().isNotEmpty) {
        memberIds.add(member.trim());
      }
    }
    if (memberIds.isEmpty) {
      throw const FormatException('Invalid group members');
    }

    return GroupProfile(
      id: id,
      name: name.trim(),
      avatar: json['avatar'] is String ? (json['avatar'] as String).trim() : '',
      memberIds: List<String>.unmodifiable(memberIds),
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
          : DateTime.now(),
      replyMode: GroupReplyMode.fromName(
        json['replyMode'] is String ? json['replyMode'] as String : null,
      ),
    );
  }
}
