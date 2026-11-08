import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/pages/memory/diary_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await DiaryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await DiaryStore.instance.load();
  });

  testWidgets('shows diary entries and deletes one', (tester) async {
    final now = DateTime.now();
    await DiaryStore.instance.saveEntry(
      DiaryEntry(
        id: 'diary_mori_today',
        characterId: CharacterProfile.presetMoriId,
        dateKey: diaryDateKey(now),
        content: '今天和用户聊了面试的事，也一起约好晚上吃火锅。',
        createdAtMs: now.millisecondsSinceEpoch,
        moodValue: 90,
        moodLabel: '超开心',
        messageCount: 18,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: DiaryPage()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '日记'), findsOneWidget);
    expect(find.text('Mori'), findsOneWidget);
    expect(find.text('今天和用户聊了面试的事，也一起约好晚上吃火锅。'), findsOneWidget);
    expect(find.textContaining('心情 超开心'), findsOneWidget);

    await tester.tap(find.byTooltip('日记操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除日记'));
    await tester.pumpAndSettle();
    expect(find.text('确定删除这篇日记吗？删除后无法恢复。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('还没有日记'), findsOneWidget);
    expect(DiaryStore.instance.allEntries(), isEmpty);
  });

  testWidgets('shows an empty state with a settings shortcut', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DiaryPage()));
    await tester.pumpAndSettle();

    expect(find.text('还没有日记'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
  });
}
