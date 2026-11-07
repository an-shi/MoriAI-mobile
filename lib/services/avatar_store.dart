import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 管理角色卡头像文件的本地存储。
///
/// 角色卡只保存相对文件名，避免应用目录变化后绝对路径失效。
class AvatarStore {
  AvatarStore._();

  static final AvatarStore instance = AvatarStore._();

  static const _folderName = 'character_avatars';

  Directory? _directory;

  Future<void> load() async {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final directory = Directory('${supportDirectory.path}/$_folderName');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _directory = directory;
    } catch (_) {
      _directory = null;
    }
  }

  File? fileFor(String fileName) {
    final name = fileName.trim();
    final directory = _directory;
    if (name.isEmpty || directory == null) {
      return null;
    }

    final file = File('${directory.path}/$name');
    return file.existsSync() ? file : null;
  }

  Future<String> saveAvatar(String cardId, Uint8List bytes) async {
    final directory = await _ensureDirectory();
    final fileName = '${cardId}_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return fileName;
  }

  Future<void> deleteAvatar(String fileName) async {
    if (fileName.trim().startsWith('assets/')) {
      return;
    }

    final file = fileFor(fileName);
    if (file == null) {
      return;
    }

    try {
      await file.delete();
    } catch (_) {
      // 头像清理失败不应影响角色卡本身的保存或删除。
    }
  }

  Future<Directory> _ensureDirectory() async {
    final existing = _directory;
    if (existing != null) {
      return existing;
    }

    await load();
    final directory = _directory;
    if (directory == null) {
      throw StateError('Avatar directory is unavailable');
    }
    return directory;
  }
}
