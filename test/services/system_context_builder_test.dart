import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/system_context_settings.dart';
import 'package:mori_ai/services/system_context_builder.dart';

void main() {
  test('builds current date, time and timezone', () {
    final now = DateTime(2026, 11, 10, 14, 32);
    final context = SystemContextBuilder.instance.build(
      now: now,
      settings: const SystemContextSettings(),
    );

    expect(context, contains('【系统上下文】'));
    expect(context, contains('2026 年 11 月 10 日，星期二'));
    expect(context, contains('当前时间：14:32'));
    expect(context, contains('当前时段：下午'));
    expect(context, contains('UTC'));
    expect(context, contains('不要编造日期'));
  });

  test('includes relative time from the previous message', () {
    final now = DateTime(2026, 11, 10, 14, 32);
    final context = SystemContextBuilder.instance.build(
      now: now,
      previousMessageAt: DateTime(2026, 11, 10, 12, 27),
      settings: const SystemContextSettings(),
    );
    expect(context, contains('距离上一条消息：2 小时 5 分钟前'));
  });

  test('returns empty when time awareness is disabled', () {
    expect(
      SystemContextBuilder.instance.build(
        now: DateTime(2026, 11, 10, 14, 32),
        settings: const SystemContextSettings(timeAwarenessEnabled: false),
      ),
      isEmpty,
    );
  });
}
