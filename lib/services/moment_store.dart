import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MomentStore {
  MomentStore._();

  static final MomentStore instance = MomentStore._();

  static const _momentsKey = 'moments_v1';

  final ValueNotifier<List<Moment>> moments = ValueNotifier<List<Moment>>(
    const [],
  );

  Directory? _imagesRoot;
  int _sequence = 0;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_momentsKey);
      if (raw == null || raw.isEmpty) {
        moments.value = const [];
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        moments.value = const [];
        return;
      }

      final result = <Moment>[];
      final ids = <String>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        try {
          final moment = Moment.fromJson(Map<String, dynamic>.from(item));
          if (!ids.add(moment.id)) {
            continue;
          }
          final hydrated = await _hydrateImage(moment);
          if (hydrated != null) {
            result.add(hydrated);
          }
        } on FormatException {
          // 跳过损坏的动态记录。
        }
      }
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      moments.value = List<Moment>.unmodifiable(result);
    } catch (_) {
      moments.value = const [];
    }
  }

  Future<Moment> add({
    required String authorId,
    required String authorName,
    required bool isUser,
    required String content,
    MomentImage? image,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty && image == null) {
      throw ArgumentError.value(
        content,
        'content',
        'A moment needs text or an image',
      );
    }

    final momentId = _newMomentId();
    var imageFile = '';
    if (image != null) {
      imageFile = await _saveImage(momentId, image) ?? '';
      if (imageFile.isEmpty) {
        throw StateError('Failed to save moment image');
      }
    }

    final moment = Moment(
      id: momentId,
      authorId: authorId.trim(),
      authorName: authorName.trim(),
      isUser: isUser,
      content: normalized,
      createdAt: DateTime.now(),
      imageFile: imageFile,
      imageMimeType: image?.mimeType ?? '',
      image: image,
    );
    final previous = moments.value;
    final next = List<Moment>.unmodifiable([moment, ...previous]);
    await _persist(previous, next);
    return moment;
  }

  Moment? momentById(String momentId) {
    for (final moment in moments.value) {
      if (moment.id == momentId) {
        return moment;
      }
    }
    return null;
  }

  Future<MomentComment> addComment(
    String momentId, {
    required String authorId,
    required String authorName,
    required bool isUser,
    required String content,
    String replyToCommentId = '',
    String replyToAuthorName = '',
    int replyDepth = 0,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(content, 'content', 'Content cannot be empty');
    }

    final previous = moments.value;
    final index = previous.indexWhere((moment) => moment.id == momentId);
    if (index < 0) {
      throw StateError('Moment not found');
    }

    final comment = MomentComment(
      id: _newCommentId(),
      authorId: authorId.trim(),
      authorName: authorName.trim(),
      isUser: isUser,
      content: normalized,
      createdAt: DateTime.now(),
      replyToCommentId: replyToCommentId.trim(),
      replyToAuthorName: replyToAuthorName.trim(),
      replyDepth: replyDepth < 0 ? 0 : replyDepth,
    );
    final moment = previous[index];
    final updated = moment.copyWith(
      comments: List<MomentComment>.unmodifiable([...moment.comments, comment]),
    );
    final next = List<Moment>.unmodifiable([...previous]..[index] = updated);
    await _persist(previous, next);
    return comment;
  }

  Future<void> delete(String momentId) async {
    final previous = moments.value;
    final index = previous.indexWhere((moment) => moment.id == momentId);
    if (index < 0) {
      return;
    }

    final moment = previous[index];
    final next = List<Moment>.unmodifiable([...previous]..removeAt(index));
    await _persist(previous, next);
    await _deleteImage(moment.imageFile);
  }

  /// 删除一条评论，并连同其下的所有回复一起删除。
  Future<void> deleteComment(String momentId, String commentId) async {
    final previous = moments.value;
    final index = previous.indexWhere((moment) => moment.id == momentId);
    if (index < 0) {
      return;
    }

    final moment = previous[index];
    final removedIds = <String>{commentId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final comment in moment.comments) {
        if (comment.replyToCommentId.isNotEmpty &&
            removedIds.contains(comment.replyToCommentId) &&
            removedIds.add(comment.id)) {
          changed = true;
        }
      }
    }

    final comments = [
      for (final comment in moment.comments)
        if (!removedIds.contains(comment.id)) comment,
    ];
    if (comments.length == moment.comments.length) {
      return;
    }

    final updated = moment.copyWith(
      comments: List<MomentComment>.unmodifiable(comments),
    );
    final next = List<Moment>.unmodifiable([...previous]..[index] = updated);
    await _persist(previous, next);
  }

  /// 删除某个角色发布的全部动态，以及该角色在其他动态下的评论。
  Future<void> deleteForCharacter(String characterId) async {
    final previous = moments.value;
    final removedImages = <String>[];
    final next = <Moment>[];
    var changed = false;

    for (final moment in previous) {
      if (moment.authorId == characterId) {
        changed = true;
        if (moment.imageFile.isNotEmpty) {
          removedImages.add(moment.imageFile);
        }
        continue;
      }

      final comments = [
        for (final comment in moment.comments)
          if (comment.authorId != characterId) comment,
      ];
      if (comments.length != moment.comments.length) {
        changed = true;
        next.add(
          moment.copyWith(comments: List<MomentComment>.unmodifiable(comments)),
        );
      } else {
        next.add(moment);
      }
    }

    if (!changed) {
      return;
    }

    await _persist(previous, List<Moment>.unmodifiable(next));
    for (final imageFile in removedImages) {
      await _deleteImage(imageFile);
    }
  }

  Future<void> _persist(List<Moment> previous, List<Moment> next) async {
    moments.value = next;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _momentsKey,
        jsonEncode([for (final item in next) item.toJson()]),
      );
      if (!saved) {
        throw StateError('Failed to save moments');
      }
    } catch (_) {
      moments.value = previous;
      rethrow;
    }
  }

  Future<Moment?> _hydrateImage(Moment moment) async {
    if (moment.imageFile.isEmpty) {
      return moment;
    }

    final image = await _loadImage(moment.imageFile, moment.imageMimeType);
    if (image != null) {
      return moment.copyWith(image: image);
    }
    if (moment.content.isEmpty) {
      return null;
    }
    return moment.copyWith(imageFile: '', imageMimeType: '');
  }

  Future<String?> _saveImage(String momentId, MomentImage image) async {
    try {
      final directory = await _imageDirectory(create: true);
      if (directory == null) {
        return null;
      }

      final safeId = momentId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = '$safeId.jpg';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(image.bytes, flush: true);
      return fileName;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteImage(String fileName) async {
    if (fileName.isEmpty) {
      return;
    }
    try {
      final directory = await _imageDirectory(create: false);
      if (directory == null) {
        return;
      }
      final file = File('${directory.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 忽略图片清理失败。
    }
  }

  Future<MomentImage?> _loadImage(String fileName, String mimeType) async {
    try {
      final directory = await _imageDirectory(create: false);
      if (directory == null) {
        return null;
      }
      final file = File('${directory.path}/$fileName');
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return MomentImage(
        bytes: bytes,
        mimeType: mimeType.isEmpty ? 'image/jpeg' : mimeType,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _imageDirectory({required bool create}) async {
    try {
      var root = _imagesRoot;
      if (root == null) {
        final supportDirectory = await getApplicationSupportDirectory();
        root = Directory('${supportDirectory.path}/moment_images');
        if (create) {
          await root.create(recursive: true);
        } else if (!await root.exists()) {
          return null;
        }
        _imagesRoot = root;
      }
      return root;
    } catch (_) {
      return null;
    }
  }

  String _newMomentId() {
    _sequence++;
    return 'moment_${DateTime.now().microsecondsSinceEpoch}_$_sequence';
  }

  String _newCommentId() {
    _sequence++;
    return 'comment_${DateTime.now().microsecondsSinceEpoch}_$_sequence';
  }
}
