import 'package:mori_ai/models/system_context_settings.dart';
import 'package:mori_ai/services/system_context_settings_store.dart';

/// 把当前系统时间整理成模型可读的上下文。
///
/// 当前只提供时间感知；以后可以在这里扩展设备、网络等系统信息。
class SystemContextBuilder {
  SystemContextBuilder._();

  static final SystemContextBuilder instance = SystemContextBuilder._();

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  String build({
    DateTime? now,
    DateTime? previousMessageAt,
    SystemContextSettings? settings,
  }) {
    final effectiveSettings =
        settings ?? SystemContextSettingsStore.instance.settings.value;
    if (!effectiveSettings.timeAwarenessEnabled) {
      return '';
    }

    final current = now ?? DateTime.now();
    final hour = current.hour.toString().padLeft(2, '0');
    final minute = current.minute.toString().padLeft(2, '0');
    final weekday = _weekdays[current.weekday - 1];
    final zone = _timeZoneLabel(current);
    final lines = <String>[
      '当前日期：${current.year} 年 ${current.month} 月 ${current.day} 日，星期$weekday',
      '当前时间：$hour:$minute${zone.isEmpty ? '' : '（$zone）'}',
      '当前时段：${_timeOfDay(current.hour)}',
    ];
    if (previousMessageAt != null) {
      lines.add('距离上一条消息：${_relativeLabel(previousMessageAt, current)}');
    }
    lines.add(
      '当用户问现在几点、今天几号、星期几或某个日期时，按以上时间回答，不要编造日期。'
      '平时不用主动频繁报时。',
    );
    return '【系统上下文】\n${lines.join('\n')}';
  }

  String _timeZoneLabel(DateTime time) {
    final offset = time.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    final name = time.timeZoneName.trim();
    return ['UTC$sign$hours:$minutes', if (name.isNotEmpty) name].join('，');
  }

  String _timeOfDay(int hour) {
    if (hour < 5) {
      return '凌晨';
    }
    if (hour < 8) {
      return '清晨';
    }
    if (hour < 11) {
      return '上午';
    }
    if (hour < 13) {
      return '中午';
    }
    if (hour < 17) {
      return '下午';
    }
    if (hour < 19) {
      return '傍晚';
    }
    if (hour < 23) {
      return '晚上';
    }
    return '深夜';
  }

  String _relativeLabel(DateTime previous, DateTime now) {
    final difference = now.difference(previous);
    if (difference.isNegative || difference.inMinutes < 1) {
      return '刚刚';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} 分钟前';
    }
    if (difference.inHours < 24) {
      final minutes = difference.inMinutes % 60;
      return minutes == 0
          ? '${difference.inHours} 小时前'
          : '${difference.inHours} 小时 $minutes 分钟前';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    }
    return '很久以前';
  }
}
