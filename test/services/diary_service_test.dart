import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/diary_generator.dart';
import 'package:mori_ai/services/diary_service.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await CharacterActivityStore.instance.load();
    await MoodStore.instance.load();
    await DiaryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await CharacterActivityStore.instance.load();
    await MoodStore.instance.load();
    await DiaryStore.instance.load();
  });

  test('writes once per day when the scheduled time has passed', () async {
    final now = DateTime(2026, 11, 8, 23);
    await DiaryStore.instance.saveSettings(
      const DiarySettings(enabled: true, timeMinutes: 22 * 60 + 30),
    );
    var calls = 0;
    final service = DiaryService.test(
      generator: DiaryGenerator(
        complete: ({required systemPrompt, required userPrompt}) async {
          calls++;
          return '今天的日记。';
        },
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();
    expect(calls, 1);
    final entries = DiaryStore.instance.entriesFor(
      CharacterProfile.presetMoriId,
    );
    expect(entries, hasLength(1));
    expect(entries.single.dateKey, '2026-11-08');
    expect(entries.single.content, '今天的日记。');
    expect(
      DiaryStore.instance
          .stateFor(CharacterProfile.presetMoriId)
          .lastSuccessDate,
      '2026-11-08',
    );

    await service.runCheckForTest();
    expect(calls, 1);
  });

  test('does nothing when disabled or before the scheduled time', () async {
    final now = DateTime(2026, 11, 8, 10);
    var calls = 0;
    final service = DiaryService.test(
      generator: DiaryGenerator(
        complete: ({required systemPrompt, required userPrompt}) async {
          calls++;
          return '不应该生成。';
        },
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await DiaryStore.instance.saveSettings(
      const DiarySettings(enabled: false, timeMinutes: 22 * 60 + 30),
    );
    await service.runCheckForTest();
    expect(calls, 0);

    await DiaryStore.instance.saveSettings(
      const DiarySettings(enabled: true, timeMinutes: 22 * 60 + 30),
    );
    await service.runCheckForTest();
    expect(calls, 0);
    expect(
      DiaryStore.instance.entriesFor(CharacterProfile.presetMoriId),
      isEmpty,
    );
  });

  test('skips automatic writing when no model is configured', () async {
    final now = DateTime(2026, 11, 8, 23);
    await DiaryStore.instance.saveSettings(
      const DiarySettings(enabled: true, timeMinutes: 22 * 60 + 30),
    );
    final service = DiaryService.test(now: () => now);
    addTearDown(service.stop);

    await service.runCheckForTest();
    expect(
      DiaryStore.instance.entriesFor(CharacterProfile.presetMoriId),
      isEmpty,
    );
  });

  test(
    'writes for a character override even when the global switch is off',
    () async {
      final now = DateTime(2026, 11, 8, 10);
      await DiaryStore.instance.saveSettings(
        const DiarySettings(
          enabled: false,
          timeMinutes: 22 * 60 + 30,
        ).setCharacterSettings(
          CharacterProfile.presetMoriId,
          const DiaryCharacterSettings(enabled: true, timeMinutes: 8 * 60),
        ),
      );
      final service = DiaryService.test(
        generator: DiaryGenerator(
          complete: ({required systemPrompt, required userPrompt}) async =>
              '单独设置的日记。',
        ),
        now: () => now,
      );
      addTearDown(service.stop);

      await service.runCheckForTest();
      expect(
        DiaryStore.instance
            .entryFor(CharacterProfile.presetMoriId, '2026-11-08')
            ?.content,
        '单独设置的日记。',
      );
    },
  );

  test('a disabled character override blocks automatic writing', () async {
    final now = DateTime(2026, 11, 8, 23);
    await DiaryStore.instance.saveSettings(
      const DiarySettings(
        enabled: true,
        timeMinutes: 22 * 60 + 30,
      ).setCharacterSettings(
        CharacterProfile.presetMoriId,
        const DiaryCharacterSettings(enabled: false),
      ),
    );
    var calls = 0;
    final service = DiaryService.test(
      generator: DiaryGenerator(
        complete: ({required systemPrompt, required userPrompt}) async {
          calls++;
          return '不应该生成。';
        },
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();
    expect(calls, 0);
    expect(
      DiaryStore.instance.entriesFor(CharacterProfile.presetMoriId),
      isEmpty,
    );
  });

  test('catches up yesterday during the early morning window', () async {
    final now = DateTime(2026, 11, 8, 3);
    await DiaryStore.instance.saveSettings(
      const DiarySettings(enabled: true, timeMinutes: 22 * 60 + 30),
    );
    final service = DiaryService.test(
      generator: DiaryGenerator(
        complete: ({required systemPrompt, required userPrompt}) async =>
            '补写的日记。',
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();
    final entries = DiaryStore.instance.entriesFor(
      CharacterProfile.presetMoriId,
    );
    expect(entries, hasLength(1));
    expect(entries.single.dateKey, '2026-11-07');
  });

  test('manual writing replaces today diary', () async {
    final now = DateTime(2026, 11, 8, 23);
    await DiaryStore.instance.saveSettings(
      const DiarySettings(enabled: true, timeMinutes: 22 * 60 + 30),
    );
    var version = 1;
    final service = DiaryService.test(
      generator: DiaryGenerator(
        complete: ({required systemPrompt, required userPrompt}) async =>
            '第 $version 版日记。',
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();
    version = 2;
    final entry = await service.writeNow(CharacterProfile.presetMoriId);

    expect(entry.content, '第 2 版日记。');
    final entries = DiaryStore.instance.entriesFor(
      CharacterProfile.presetMoriId,
    );
    expect(entries, hasLength(1));
    expect(entries.single.content, '第 2 版日记。');
  });

  test('retries after a failed generation', () async {
    var now = DateTime(2026, 11, 8, 23);
    await DiaryStore.instance.saveSettings(
      const DiarySettings(enabled: true, timeMinutes: 22 * 60 + 30),
    );
    var calls = 0;
    var shouldFail = true;
    final service = DiaryService.test(
      generator: DiaryGenerator(
        complete: ({required systemPrompt, required userPrompt}) async {
          calls++;
          if (shouldFail) {
            throw const DiaryException('模型暂时不可用');
          }
          return '重试成功的日记。';
        },
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();
    expect(calls, 1);
    expect(
      DiaryStore.instance.entriesFor(CharacterProfile.presetMoriId),
      isEmpty,
    );
    final failedState = DiaryStore.instance.stateFor(
      CharacterProfile.presetMoriId,
    );
    expect(failedState.lastError, '模型暂时不可用');
    expect(failedState.nextRetryAtMs, greaterThan(now.millisecondsSinceEpoch));

    shouldFail = false;
    await service.runCheckForTest();
    expect(calls, 1);

    now = now.add(const Duration(minutes: 31));
    await service.runCheckForTest();
    expect(calls, 2);
    expect(
      DiaryStore.instance
          .entryFor(CharacterProfile.presetMoriId, '2026-11-08')
          ?.content,
      '重试成功的日记。',
    );
  });
}
