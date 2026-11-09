import 'package:mori_ai/services/diary_store.dart';

/// 把角色最近写过的日记整理成一段聊天上下文。
///
/// 日记属于角色的私人记录，只注入单聊和主动消息；群聊、动态等公开场景
/// 不读取，避免把私事带到公开内容里。
class DiaryContextBuilder {
  DiaryContextBuilder._();

  static final DiaryContextBuilder instance = DiaryContextBuilder._();

  static const _maxContentLength = 180;
  static const _maxBlockLength = 700;

  String buildForPrivateChat(String characterId) {
    return _build(characterId);
  }

  /// 主动消息和单聊使用相同的日记范围。
  String buildForProactive(String characterId) {
    return _build(characterId);
  }

  /// 群聊不会注入角色的私人日记。
  String buildForGroupChat(String characterId) {
    return '';
  }

  String _build(String characterId) {
    final settings = DiaryStore.instance.settings.value;
    if (!settings.recallEnabled || settings.recallCount <= 0) {
      return '';
    }
    final entries = DiaryStore.instance
        .entriesFor(characterId)
        .where((entry) => entry.content.trim().isNotEmpty)
        .take(settings.recallCount);
    final now = DateTime.now();
    final lines = <String>[];
    var length = 0;
    for (final entry in entries) {
      var content = entry.content.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (content.length > _maxContentLength) {
        content = '${content.substring(0, _maxContentLength)}…';
      }
      final mood = entry.moodLabel.trim();
      final line =
          '- ${_whenText(entry.date ?? entry.createdAt, now)}'
          '${mood.isEmpty ? '' : ' · $mood'}：$content';
      if (lines.isNotEmpty && length + line.length > _maxBlockLength) {
        break;
      }
      lines.add(line);
      length += line.length + 1;
    }
    if (lines.isEmpty) {
      return '';
    }
    return '（以下是你最近写过的私人日记，不是用户刚说的。'
        '只有在自然相关时才提起你记下的心情或事情，可以顺口带一句，'
        '但不要逐字复述，也不要编造没有写过的事。）\n'
        '${lines.join('\n')}';
  }

  String _whenText(DateTime time, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final days = today.difference(day).inDays;
    if (days <= 0) {
      return '今天';
    }
    if (days == 1) {
      return '昨天';
    }
    if (days < 7) {
      return '$days 天前';
    }
    final month = time.month.toString().padLeft(2, '0');
    final date = time.day.toString().padLeft(2, '0');
    if (time.year == now.year) {
      return '$month-$date';
    }
    return '${time.year}-$month-$date';
  }
}
