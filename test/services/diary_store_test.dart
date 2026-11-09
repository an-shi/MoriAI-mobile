import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DiaryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await DiaryStore.instance.load();
  });

  test('defaults and settings normalization', () async {
    final defaults = DiaryStore.instance.settings.value;
    expect(defaults.enabled, isFalse);
    expect(defaults.timeLabel, '22:30');
    expect(defaults.recallEnabled, isTrue);
    expect(defaults.recallCount, 2);

    final normalized = const DiarySettings(timeMinutes: 3000).normalized();
    expect(normalized.timeMinutes, 24 * 60 - 1);
    expect(const DiarySettings(timeMinutes: -20).normalized().timeMinutes, 0);
    expect(const DiarySettings(recallCount: 99).normalized().recallCount, 5);
    expect(const DiarySettings(recallCount: -3).normalized().recallCount, 0);

    await DiaryStore.instance.saveSettings(
      const DiarySettings(
        enabled: true,
        timeMinutes: 8 * 60 + 5,
        recallEnabled: false,
        recallCount: 4,
      ),
    );
    await DiaryStore.instance.load();
    expect(DiaryStore.instance.settings.value.enabled, isTrue);
    expect(DiaryStore.instance.settings.value.timeLabel, '08:05');
    expect(DiaryStore.instance.settings.value.recallEnabled, isFalse);
    expect(DiaryStore.instance.settings.value.recallCount, 4);
  });

  test('reads old settings without recall fields', () {
    final restored = DiarySettings.fromJson({
      'enabled': true,
      'timeMinutes': 9 * 60,
    });
    expect(restored.enabled, isTrue);
    expect(restored.recallEnabled, isTrue);
    expect(restored.recallCount, 2);
  });

  test('supports per-character diary overrides', () async {
    final settings =
        const DiarySettings(
          enabled: false,
          timeMinutes: 22 * 60 + 30,
        ).setCharacterSettings(
          'mori',
          const DiaryCharacterSettings(enabled: true, timeMinutes: 8 * 60),
        );
    expect(settings.hasOverride('mori'), isTrue);
    expect(settings.isEnabledFor('mori'), isTrue);
    expect(settings.timeLabelFor('mori'), '08:00');
    expect(settings.isEnabledFor('other'), isFalse);
    expect(settings.timeLabelFor('other'), '22:30');

    final restored = DiarySettings.fromJson(settings.toJson());
    expect(restored.hasOverride('mori'), isTrue);
    expect(restored.isEnabledFor('mori'), isTrue);
    expect(restored.timeLabelFor('mori'), '08:00');

    await DiaryStore.instance.saveSettings(settings);
    await DiaryStore.instance.load();
    expect(DiaryStore.instance.settings.value.isEnabledFor('mori'), isTrue);
    expect(DiaryStore.instance.settings.value.timeLabelFor('mori'), '08:00');

    final cleared = DiaryStore.instance.settings.value.clearCharacterSettings(
      'mori',
    );
    await DiaryStore.instance.saveSettings(cleared);
    await DiaryStore.instance.load();
    expect(DiaryStore.instance.settings.value.hasOverride('mori'), isFalse);
    expect(DiaryStore.instance.settings.value.isEnabledFor('mori'), isFalse);
    expect(DiaryStore.instance.settings.value.timeLabelFor('mori'), '22:30');
  });

  test('saves, replaces and deletes one diary per character per day', () async {
    final first = DiaryEntry(
      id: 'diary_mori_2026-11-08',
      characterId: 'mori',
      dateKey: '2026-11-08',
      content: '今天面试通过了，很开心。',
      createdAtMs: DateTime(2026, 11, 8, 22, 30).millisecondsSinceEpoch,
      moodValue: 80,
      moodLabel: '心情不错',
      messageCount: 12,
    );
    await DiaryStore.instance.saveEntry(first);

    expect(DiaryStore.instance.entriesFor('mori'), hasLength(1));
    expect(
      DiaryStore.instance.entryFor('mori', '2026-11-08')?.content,
      contains('面试'),
    );

    await DiaryStore.instance.saveEntry(
      DiaryEntry(
        id: first.id,
        characterId: first.characterId,
        dateKey: first.dateKey,
        content: '今天面试通过了，晚上一起去吃了火锅。',
        createdAtMs: first.createdAtMs + 1000,
        moodValue: 90,
        moodLabel: '超开心',
        messageCount: 18,
      ),
    );
    expect(DiaryStore.instance.entriesFor('mori'), hasLength(1));
    expect(
      DiaryStore.instance.entryFor('mori', '2026-11-08')?.content,
      contains('火锅'),
    );

    await DiaryStore.instance.load();
    expect(DiaryStore.instance.entriesFor('mori'), hasLength(1));
    expect(
      DiaryStore.instance.entryFor('mori', '2026-11-08')?.moodLabel,
      '超开心',
    );

    await DiaryStore.instance.deleteEntry(first.id);
    expect(DiaryStore.instance.entriesFor('mori'), isEmpty);
  });

  test('persists generation state and clears a character', () async {
    await DiaryStore.instance.saveState(
      'mori',
      const DiaryState(
        lastAttemptDate: '2026-11-08',
        lastSuccessDate: '2026-11-07',
        lastAttemptAtMs: 1000,
        nextRetryAtMs: 2000,
        lastError: '网络错误',
      ),
    );
    await DiaryStore.instance.saveEntry(
      DiaryEntry(
        id: 'diary_mori_2026-11-08',
        characterId: 'mori',
        dateKey: '2026-11-08',
        content: '今天的日记。',
        createdAtMs: DateTime(2026, 11, 8, 22, 30).millisecondsSinceEpoch,
      ),
    );
    await DiaryStore.instance.saveSettings(
      const DiarySettings().setCharacterSettings(
        'mori',
        const DiaryCharacterSettings(enabled: true, timeMinutes: 8 * 60),
      ),
    );

    await DiaryStore.instance.load();
    final state = DiaryStore.instance.stateFor('mori');
    expect(state.lastAttemptDate, '2026-11-08');
    expect(state.lastSuccessDate, '2026-11-07');
    expect(state.lastError, '网络错误');

    await DiaryStore.instance.clearForCharacter('mori');
    expect(DiaryStore.instance.entriesFor('mori'), isEmpty);
    expect(DiaryStore.instance.stateFor('mori').lastSuccessDate, isEmpty);
    expect(DiaryStore.instance.settings.value.hasOverride('mori'), isFalse);
  });

  test('keeps diary entries when settings json is corrupted', () async {
    final entry = DiaryEntry(
      id: 'diary_mori_2026-11-08',
      characterId: 'mori',
      dateKey: '2026-11-08',
      content: '就算设置坏了，日记也要保留。',
      createdAtMs: DateTime(2026, 11, 8, 22, 30).millisecondsSinceEpoch,
    );
    SharedPreferences.setMockInitialValues({
      'diary_settings_v1': 'not-json',
      'character_diary_v1': jsonEncode([entry.toJson()]),
    });
    await DiaryStore.instance.load();

    expect(DiaryStore.instance.settings.value, const DiarySettings());
    expect(DiaryStore.instance.entriesFor('mori'), hasLength(1));
  });

  test('trims old entries beyond the per-character capacity', () async {
    final entries = <Map<String, dynamic>>[];
    final start = DateTime(2025, 1, 1, 22, 30);
    for (var index = 0; index < 370; index++) {
      final date = start.add(Duration(days: index));
      entries.add(
        DiaryEntry(
          id: 'diary_mori_${diaryDateKey(date)}',
          characterId: 'mori',
          dateKey: diaryDateKey(date),
          content: '第 $index 天的日记。',
          createdAtMs: date.millisecondsSinceEpoch,
        ).toJson(),
      );
    }
    SharedPreferences.setMockInitialValues({
      'character_diary_v1': jsonEncode(entries),
    });
    await DiaryStore.instance.load();

    final stored = DiaryStore.instance.entriesFor('mori');
    expect(stored, hasLength(DiaryStore.maxEntriesPerCharacter));
    expect(stored.last.content, '第 5 天的日记。');
    expect(stored.any((entry) => entry.content == '第 0 天的日记。'), isFalse);
  });
}
