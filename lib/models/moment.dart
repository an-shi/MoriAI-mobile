import 'dart:typed_data';

class MomentImage {
  const MomentImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class MomentComment {
  const MomentComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.isUser,
    required this.content,
    required this.createdAt,
    this.replyToCommentId = '',
    this.replyToAuthorName = '',
    this.replyDepth = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final bool isUser;
  final String content;
  final DateTime createdAt;
  final String replyToCommentId;
  final String replyToAuthorName;
  final int replyDepth;

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'isUser': isUser,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    if (replyToCommentId.isNotEmpty) 'replyToCommentId': replyToCommentId,
    if (replyToAuthorName.isNotEmpty) 'replyToAuthorName': replyToAuthorName,
    if (replyDepth > 0) 'replyDepth': replyDepth,
  };

  factory MomentComment.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final authorId = json['authorId'];
    final content = json['content'];
    if (id is! String ||
        id.trim().isEmpty ||
        authorId is! String ||
        authorId.trim().isEmpty ||
        content is! String ||
        content.trim().isEmpty) {
      throw const FormatException('Invalid moment comment');
    }

    final createdAt = json['createdAt'];
    return MomentComment(
      id: id.trim(),
      authorId: authorId.trim(),
      authorName: json['authorName'] is String
          ? (json['authorName'] as String).trim()
          : '',
      isUser: json['isUser'] == true,
      content: content.trim(),
      createdAt: createdAt is String
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now(),
      replyToCommentId: json['replyToCommentId'] is String
          ? (json['replyToCommentId'] as String).trim()
          : '',
      replyToAuthorName: json['replyToAuthorName'] is String
          ? (json['replyToAuthorName'] as String).trim()
          : '',
      replyDepth: json['replyDepth'] is int && (json['replyDepth'] as int) > 0
          ? json['replyDepth'] as int
          : 0,
    );
  }
}

class Moment {
  const Moment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.isUser,
    required this.content,
    required this.createdAt,
    this.imageFile = '',
    this.imageMimeType = '',
    this.image,
    this.comments = const [],
  });

  final String id;
  final String authorId;
  final String authorName;
  final bool isUser;
  final String content;
  final DateTime createdAt;
  final String imageFile;
  final String imageMimeType;
  final MomentImage? image;
  final List<MomentComment> comments;

  Moment copyWith({
    String? content,
    String? imageFile,
    String? imageMimeType,
    MomentImage? image,
    List<MomentComment>? comments,
  }) {
    return Moment(
      id: id,
      authorId: authorId,
      authorName: authorName,
      isUser: isUser,
      content: content ?? this.content,
      createdAt: createdAt,
      imageFile: imageFile ?? this.imageFile,
      imageMimeType: imageMimeType ?? this.imageMimeType,
      image: image ?? this.image,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'isUser': isUser,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    if (imageFile.isNotEmpty)
      'image': {
        'file': imageFile,
        'mimeType': image?.mimeType ?? imageMimeType,
      },
    'comments': [for (final comment in comments) comment.toJson()],
  };

  factory Moment.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final authorId = json['authorId'];
    final content = json['content'];
    if (id is! String ||
        id.trim().isEmpty ||
        authorId is! String ||
        authorId.trim().isEmpty ||
        content is! String) {
      throw const FormatException('Invalid moment');
    }

    var imageFile = '';
    var imageMimeType = '';
    final rawImage = json['image'];
    if (rawImage is Map) {
      final fileName = rawImage['file'];
      final mimeType = rawImage['mimeType'];
      if (fileName is String && fileName.trim().isNotEmpty) {
        imageFile = fileName.trim();
      }
      if (mimeType is String && mimeType.trim().isNotEmpty) {
        imageMimeType = mimeType.trim();
      }
    }

    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty && imageFile.isEmpty) {
      throw const FormatException('Moment has no content');
    }

    final comments = <MomentComment>[];
    final rawComments = json['comments'];
    if (rawComments is List) {
      final ids = <String>{};
      for (final item in rawComments) {
        if (item is! Map) {
          continue;
        }
        try {
          final comment = MomentComment.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (ids.add(comment.id)) {
            comments.add(comment);
          }
        } on FormatException {
          // 跳过损坏的评论。
        }
      }
    }

    final createdAt = json['createdAt'];
    return Moment(
      id: id.trim(),
      authorId: authorId.trim(),
      authorName: json['authorName'] is String
          ? (json['authorName'] as String).trim()
          : '',
      isUser: json['isUser'] == true,
      content: normalizedContent,
      createdAt: createdAt is String
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now(),
      imageFile: imageFile,
      imageMimeType: imageMimeType,
      comments: List<MomentComment>.unmodifiable(comments),
    );
  }
}
