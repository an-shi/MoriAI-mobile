import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/services/diary_context_builder.dart';
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

  DiaryEntry entry(String dateKey, String content, {String mood = ''}) {
    final date = diaryDateFromKey(dateKey)!;
    return DiaryEntry(
      id: 'diary_${dateKey}_$content',
      characterId: 'mori',
      dateKey: dateKey,
      content: content,
      createdAtMs: DateTime(
        date.year,
        date.month,
        date.day,
        22,
        30,
      ).millisecondsSinceEpoch,
      moodLabel: mood,
    );
  }

  test(
    'injects the most recent diaries and respects the recall count',
    () async {
      await DiaryStore.instance.saveEntry(entry('2026-11-05', '三天前的日记内容。'));
      await DiaryStore.instance.saveEntry(
        entry('2026-11-08', '昨天和朋友去看了电影。', mood: '心情不错'),
      );
      await DiaryStore.instance.saveEntry(entry('2026-11-09', '今天把房间收拾干净了。'));

      final context = DiaryContextBuilder.instance.buildForPrivateChat('mori');

      expect(context, contains('你最近写过的私人日记'));
      expect(context, contains('今天把房间收拾干净了。'));
      expect(context, contains('昨天和朋友去看了电影。'));
      expect(context, contains('心情不错'));
      expect(context, isNot(contains('三天前的日记内容。')));
    },
  );

  test(
    'returns nothing when recall is disabled or the count is zero',
    () async {
      await DiaryStore.instance.saveEntry(entry('2026-11-08', '昨天的日记。'));

      await DiaryStore.instance.saveSettings(
        DiaryStore.instance.settings.value.copyWith(recallEnabled: false),
      );
      expect(DiaryContextBuilder.instance.buildForPrivateChat('mori'), isEmpty);

      await DiaryStore.instance.saveSettings(
        DiaryStore.instance.settings.value.copyWith(
          recallEnabled: true,
          recallCount: 0,
        ),
      );
      expect(DiaryContextBuilder.instance.buildForProactive('mori'), isEmpty);
    },
  );

  test(
    'keeps diaries private to the character and out of group chats',
    () async {
      await DiaryStore.instance.saveEntry(entry('2026-11-08', '只属于 Mori 的日记。'));
      await DiaryStore.instance.saveEntry(
        DiaryEntry(
          id: 'diary_other_2026-11-08',
          characterId: 'other',
          dateKey: '2026-11-08',
          content: '这是其他角色的日记。',
          createdAtMs: DateTime(2026, 11, 8, 22, 30).millisecondsSinceEpoch,
        ),
      );

      final context = DiaryContextBuilder.instance.buildForPrivateChat('mori');
      expect(context, contains('只属于 Mori 的日记。'));
      expect(context, isNot(contains('这是其他角色的日记。')));
      expect(DiaryContextBuilder.instance.buildForGroupChat('mori'), isEmpty);
    },
  );

  test('clips very long diary entries before injecting them', () async {
    await DiaryStore.instance.saveEntry(entry('2026-11-08', '很长的日记。' * 80));

    final context = DiaryContextBuilder.instance.buildForPrivateChat('mori');
    expect(context, contains('…'));
    expect(context.length, lessThan(1000));
  });
}
