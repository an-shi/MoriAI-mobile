import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:mori_ai/services/moribot/mori_media_cache.dart';

/// Plays generated speech files downloaded through the authenticated media
/// endpoint. Only one clip plays at a time.
class MoriAudioPlayer {
  MoriAudioPlayer._() {
    _player.onPlayerComplete.listen((_) {
      playingKey.value = null;
    });
  }

  static final MoriAudioPlayer instance = MoriAudioPlayer._();

  final AudioPlayer _player = AudioPlayer();

  /// Identifies the message whose speech is currently playing.
  final ValueNotifier<String?> playingKey = ValueNotifier<String?>(null);
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  Future<void> toggle({required String key, required String url}) async {
    if (playingKey.value == key) {
      await stop();
      return;
    }

    await stop();
    loading.value = true;
    try {
      final file = await MoriMediaCache.instance.fileFor(url);
      if (file == null) {
        throw StateError('语音文件下载失败');
      }
      playingKey.value = key;
      await _player.play(DeviceFileSource(file.path));
    } catch (_) {
      playingKey.value = null;
      rethrow;
    } finally {
      loading.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } finally {
      playingKey.value = null;
    }
  }
}
