import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/services/character_activity_store.dart';

class CharacterActivityContextBuilder {
  CharacterActivityContextBuilder._();

  static final CharacterActivityContextBuilder instance =
      CharacterActivityContextBuilder._();

  static const _limit = 8;
  static const _maxContentLength = 90;
  static const _maxBlockLength = 900;

  /// 单聊/主动消息：可以知道自己所有群聊和公开动态。
  String buildForPrivateChat(String characterId) {
    return _build(
      characterId,
      header: '（以下是你自己最近在群聊和动态里做过的事，不是用户刚说的。聊到了可以自然带出，但不要逐条复述，不要编造。）',
      filter: (activity) => activity.isGroup || activity.isPublic,
    );
  }

  /// 群聊：只带公开的动态/评论，不带其他群和单聊内容。
  String buildForGroupChat(String characterId) {
    return _build(
      characterId,
      header: '（以下是你自己最近发过的动态或评论，不是当前群聊里刚发生的事。可以自然带出，但不要逐条复述，不要编造。）',
      filter: (activity) => activity.isPublic,
    );
  }

  /// 主动消息：和单聊一致。
  String buildForProactive(String characterId) {
    return _build(
      characterId,
      header: '（以下是你自己最近在群聊和动态里做过的事，不是用户刚说的。聊到了可以自然带出，但不要逐条复述，不要编造。）',
      filter: (activity) => activity.isGroup || activity.isPublic,
    );
  }

  /// 发动态、评论动态：只看自己的公开动态/评论。
  String buildForMoment(String characterId) {
    return _build(
      characterId,
      header: '（以下是你自己最近发过的动态或评论。可以参考，但不要重复已经说过的话。）',
      filter: (activity) => activity.isPublic,
    );
  }

  String _build(
    String characterId, {
    required String header,
    required bool Function(CharacterActivity activity) filter,
  }) {
    final activities =
        CharacterActivityStore.instance.activitiesFor(characterId).where((
          activity,
        ) {
          return activity.content.trim().isNotEmpty && filter(activity);
        }).toList()..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    if (activities.isEmpty) {
      return '';
    }

    final now = DateTime.now();
    final lines = <String>[];
    var length = 0;
    for (final activity in activities) {
      var content = activity.content.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (content.length > _maxContentLength) {
        content = '${content.substring(0, _maxContentLength)}…';
      }
      final line =
          '- ${_formatTime(activity.createdAt, now)} '
          '${_contextLabel(activity)}：$content';
      if (length + line.length > _maxBlockLength && lines.isNotEmpty) {
        break;
      }
      lines.add(line);
      length += line.length + 1;
      if (lines.length >= _limit) {
        break;
      }
    }
    if (lines.isEmpty) {
      return '';
    }
    return '$header\n${lines.join('\n')}';
  }

  String _contextLabel(CharacterActivity activity) {
    return switch (activity.kind) {
      CharacterActivityKind.groupMessage =>
        '群「${activity.contextLabel.isEmpty ? '群聊' : activity.contextLabel}」',
      CharacterActivityKind.moment => '动态',
      CharacterActivityKind.momentComment => '动态评论',
      CharacterActivityKind.momentReply => '动态回复',
      CharacterActivityKind.singleMessage => '单聊',
      CharacterActivityKind.proactiveMessage => '主动消息',
    };
  }

  String _formatTime(DateTime time, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final days = today.difference(day).inDays;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    if (days == 0) {
      return '今天 $hh:$mm';
    }
    if (days == 1) {
      return '昨天 $hh:$mm';
    }
    final month = time.month.toString().padLeft(2, '0');
    final date = time.day.toString().padLeft(2, '0');
    if (time.year == now.year) {
      return '$month-$date $hh:$mm';
    }
    return '${time.year}-$month-$date $hh:$mm';
  }
}
