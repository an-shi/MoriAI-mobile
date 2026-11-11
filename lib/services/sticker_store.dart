import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/sticker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户自己添加的表情包，按本地文件保存。
class StickerStore {
  StickerStore._();

  static final StickerStore instance = StickerStore._();

  static const _key = 'user_stickers_v1';
  static const maxStickers = 60;

  final ValueNotifier<List<Sticker>> stickers = ValueNotifier<List<Sticker>>(
    const [],
  );

  Directory? _directory;

  @visibleForTesting
  void useDirectoryForTest(Directory directory) {
    _directory = directory;
  }

  @visibleForTesting
  void useStickersForTest(List<Sticker> items) {
    stickers.value = List<Sticker>.unmodifiable(items);
  }

  Future<void> load() async {
    final loaded = <Sticker>[];
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null || raw.isEmpty) {
        stickers.value = const [];
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        stickers.value = const [];
        return;
      }
      final seen = <String>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        try {
          final sticker = Sticker.fromJson(Map<String, dynamic>.from(item));
          if (sticker.id.isEmpty ||
              sticker.fileName.isEmpty ||
              sticker.mimeType.isEmpty ||
              !seen.add(sticker.id)) {
            continue;
          }
          final file = await _fileFor(sticker.fileName, create: false);
          if (file == null || !await file.exists()) {
            continue;
          }
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) {
            continue;
          }
          loaded.add(sticker.copyWith(bytes: bytes));
        } catch (_) {
          // 跳过损坏的表情包记录。
        }
      }
    } catch (_) {
      loaded.clear();
    }
    loaded.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    stickers.value = List<Sticker>.unmodifiable(loaded);
  }

  Future<Sticker?> addSticker(Uint8List bytes, String mimeType) async {
    if (bytes.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final id = 'sticker_${now.microsecondsSinceEpoch}';
    final extension = _extensionFor(mimeType);
    final fileName = '$id.$extension';
    final file = await _fileFor(fileName, create: true);
    if (file == null) {
      return null;
    }
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      return null;
    }
    final sticker = Sticker(
      id: id,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
      createdAtMs: now.millisecondsSinceEpoch,
    );
    final next = [sticker, ...stickers.value];
    stickers.value = List<Sticker>.unmodifiable(next);
    await _trim();
    await _persist();
    return sticker;
  }

  Future<void> deleteSticker(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return;
    }
    Sticker? removed;
    final next = <Sticker>[];
    for (final sticker in stickers.value) {
      if (sticker.id == trimmed) {
        removed = sticker;
      } else {
        next.add(sticker);
      }
    }
    if (removed == null) {
      return;
    }
    stickers.value = List<Sticker>.unmodifiable(next);
    if (removed.fileName.isNotEmpty) {
      try {
        final file = await _fileFor(removed.fileName, create: false);
        if (file != null && await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // 忽略文件删除失败。
      }
    }
    await _persist();
  }

  Future<void> _trim() async {
    if (stickers.value.length <= maxStickers) {
      return;
    }
    final keep = stickers.value.take(maxStickers).toList(growable: false);
    final removed = stickers.value.skip(maxStickers).toList(growable: false);
    stickers.value = List<Sticker>.unmodifiable(keep);
    for (final sticker in removed) {
      try {
        final file = await _fileFor(sticker.fileName, create: false);
        if (file != null && await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // 忽略清理失败。
      }
    }
  }

  Future<void> _persist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _key,
        jsonEncode([for (final sticker in stickers.value) sticker.toJson()]),
      );
    } catch (_) {
      // 表情包保存失败不阻断聊天。
    }
  }

  Future<File?> _fileFor(String fileName, {required bool create}) async {
    final directory = await _ensureDirectory(create: create);
    if (directory == null) {
      return null;
    }
    return File('${directory.path}/$fileName');
  }

  Future<Directory?> _ensureDirectory({required bool create}) async {
    if (_directory != null) {
      return _directory;
    }
    try {
      final root = await getApplicationSupportDirectory();
      final directory = Directory('${root.path}/user_stickers');
      if (!await directory.exists()) {
        if (!create) {
          return null;
        }
        await directory.create(recursive: true);
      }
      _directory = directory;
      return directory;
    } catch (_) {
      return null;
    }
  }

  String _extensionFor(String mimeType) {
    return switch (mimeType.toLowerCase()) {
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }
}
