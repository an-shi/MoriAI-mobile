import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';
import 'package:mori_ai/models/proactive_message_state.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProactiveMessageStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ProactiveMessageStore.instance.load();
  });

  test('loads disabled defaults and persists settings', () async {
    expect(ProactiveMessageStore.instance.settings.value.enabled, isFalse);
    expect(ProactiveMessageStore.instance.settings.value.nudgeEnabled, isTrue);
    expect(
      ProactiveMessageStore.instance.settings.value.notificationsEnabled,
      isTrue,
    );
    expect(
      ProactiveMessageStore.instance.settings.value.purposeEnabled,
      isFalse,
    );
    expect(ProactiveMessageStore.instance.settings.value.scheduledTimes, [
      '08:30',
      '22:30',
    ]);

    await ProactiveMessageStore.instance.saveSettings(
      const ProactiveMessageSettings(
        enabled: true,
        silenceMinMinutes: 45,
        silenceMaxMinutes: 120,
        nudgeEnabled: false,
        notificationsEnabled: false,
        purposeEnabled: true,
        scheduledTimes: ['09:15', '23:00'],
      ),
    );

    await ProactiveMessageStore.instance.load();
    final loaded = ProactiveMessageStore.instance.settings.value;
    expect(loaded.enabled, isTrue);
    expect(loaded.silenceMinMinutes, 45);
    expect(loaded.silenceMaxMinutes, 120);
    expect(loaded.nudgeEnabled, isFalse);
    expect(loaded.notificationsEnabled, isFalse);
    expect(loaded.purposeEnabled, isTrue);
    expect(loaded.scheduledTimes, ['09:15', '23:00']);
  });

  test('normalizes invalid ranges and scheduled times', () async {
    final settings = const ProactiveMessageSettings(
      silenceMinMinutes: 500,
      silenceMaxMinutes: 1200,
      dailyLimit: 99,
      maxUnanswered: 42,
      quietStartMinutes: -10,
      quietEndMinutes: 2000,
      scheduledTimes: ['25:00', '08:30', '08:30', 'bad', '7:05'],
    ).normalized();

    expect(settings.silenceMinMinutes, 500);
    expect(settings.silenceMaxMinutes, 1200);
    expect(settings.dailyLimit, 99);
    expect(settings.maxUnanswered, 42);
    expect(settings.quietStartMinutes, 0);
    expect(settings.quietEndMinutes, 24 * 60 - 1);
    expect(settings.scheduledTimes, ['07:05', '08:30']);
  });

  test('keeps silence minimum at one minute and orders the range', () {
    final settings = const ProactiveMessageSettings(
      silenceMinMinutes: 0,
      silenceMaxMinutes: -5,
    ).normalized();

    expect(settings.silenceMinMinutes, 1);
    expect(settings.silenceMaxMinutes, 1);
  });

  test('keeps negative limits as unlimited', () {
    final settings = const ProactiveMessageSettings(
      dailyLimit: -3,
      maxUnanswered: -2,
    ).normalized();

    expect(settings.dailyLimit, ProactiveMessageSettings.unlimited);
    expect(settings.maxUnanswered, ProactiveMessageSettings.unlimited);

    const state = ProactiveMessageState(
      dailyLimit: -5,
      firedSlots: ['not-a-slot'],
    );
    expect(state.normalized().dailyLimit, -1);
    expect(state.normalized().firedSlots, isEmpty);
  });

  test('detects quiet hours across midnight', () {
    const settings = ProactiveMessageSettings(
      quietStartMinutes: 23 * 60 + 30,
      quietEndMinutes: 7 * 60,
    );

    expect(settings.isQuietTime(DateTime(2026, 11, 8, 23, 40)), isTrue);
    expect(settings.isQuietTime(DateTime(2026, 11, 8, 2)), isTrue);
    expect(settings.isQuietTime(DateTime(2026, 11, 8, 12)), isFalse);
    expect(settings.isQuietTime(DateTime(2026, 11, 8, 7)), isFalse);
  });

  test('persists and deletes proactive state', () async {
    const state = ProactiveMessageState(
      enabled: false,
      dailyLimit: 4,
      lastActivityAtMs: 1000,
      nextSilenceAtMs: 2000,
      lastProactiveAtMs: 1500,
      lastUserMessageAtMs: 900,
      lastAssistantAtMs: 1400,
      lastAssistantMessageId: 'assistant_1',
      lastAssistantText: '那你早点睡？',
      nudgedMessageId: 'assistant_0',
      unansweredCount: 2,
      dailyDate: '2026-11-08',
      dailyCount: 3,
      firedSlots: ['2026-11-08|08:30', '2026-11-08|Closure: broken slot'],
    );
    await ProactiveMessageStore.instance.saveState('mori', state);

    await ProactiveMessageStore.instance.load();
    final loaded = await ProactiveMessageStore.instance.loadState('mori');
    expect(loaded?.enabled, isFalse);
    expect(loaded?.dailyLimit, 4);
    expect(loaded?.lastUserMessageAtMs, 900);
    expect(loaded?.lastAssistantMessageId, 'assistant_1');
    expect(loaded?.lastAssistantText, '那你早点睡？');
    expect(loaded?.nudgedMessageId, 'assistant_0');
    expect(loaded?.unansweredCount, 2);
    expect(loaded?.firedSlots, ['2026-11-08|08:30']);

    await ProactiveMessageStore.instance.deleteState('mori');
    expect(await ProactiveMessageStore.instance.loadState('mori'), isNull);
  });
}
