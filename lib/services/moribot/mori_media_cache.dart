import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mori_ai/services/moribot/mori_bot_client.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads speech and image files into a disposable local cache.
///
/// The server still owns the media. If a file is missing or corrupted it is
/// downloaded again on demand.
class MoriMediaCache {
  MoriMediaCache._();

  static final MoriMediaCache instance = MoriMediaCache._();

  static const _directoryName = 'moribot_media';

  Directory? _directory;
  final Map<String, Future<File?>> _inFlight = {};

  Future<File?> fileFor(String url) {
    final value = url.trim();
    if (value.isEmpty) {
      return Future.value(null);
    }
    final existing = _inFlight[value];
    if (existing != null) {
      return existing;
    }

    late final Future<File?> future;
    future = _download(value).whenComplete(() {
      if (identical(_inFlight[value], future)) {
        _inFlight.remove(value);
      }
    });
    _inFlight[value] = future;
    return future;
  }

  Future<File?> _download(String url) async {
    try {
      final directory = await _cacheDirectory();
      if (directory == null) {
        return null;
      }
      final file = File('${directory.path}/${_fileName(url)}');
      if (await file.exists() && await file.length() > 0) {
        return file;
      }

      final bytes = await MoriBotClient.instance.downloadMedia(url);
      if (bytes.isEmpty) {
        return null;
      }
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final directory = _directory ?? await _cacheDirectory();
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {
      // Cache cleanup is best effort.
    }
    _directory = null;
    _inFlight.clear();
  }

  Future<Directory?> _cacheDirectory() async {
    try {
      final existing = _directory;
      if (existing != null) {
        if (!await existing.exists()) {
          await existing.create(recursive: true);
        }
        return existing;
      }
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/$_directoryName');
      await directory.create(recursive: true);
      _directory = directory;
      return directory;
    } catch (_) {
      return null;
    }
  }

  String _fileName(String url) {
    final digest = sha256.convert(url.codeUnits).toString();
    final extension = _extensionFor(url);
    return '$digest$extension';
  }

  String _extensionFor(String url) {
    try {
      final uri = Uri.tryParse(url);
      final path = uri?.path ?? url;
      final name = path.split('/').last;
      final dot = name.lastIndexOf('.');
      if (dot >= 0 && dot < name.length - 1) {
        final extension = name.substring(dot).toLowerCase();
        if (extension.length <= 8 &&
            RegExp(r'^\.[a-z0-9]+$').hasMatch(extension)) {
          return extension;
        }
      }
    } catch (_) {
      // Fall through to the generic extension.
    }
    return '.bin';
  }
}
