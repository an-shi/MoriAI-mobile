import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/pages/memory/memory_dossier_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MemoryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MemoryStore.instance.load();
  });

  testWidgets('shows the profile and open topics of each character', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now().millisecondsSinceEpoch;
    await MemoryStore.instance.saveProfile(
      MemoryProfile(
        characterId: CharacterProfile.presetMoriId,
        summary: '用户是住在杭州的设计师，和 Mori 是熟悉的朋友。',
        preferences: '喜欢睡前喝热牛奶。',
        recentFocus: '最近在准备换工作。',
        importantDates: const ['12 月 24 日约好一起看电影'],
        updatedAtMs: now,
      ),
    );
    await MemoryStore.instance.saveOpenTopic(
      MemoryOpenTopic(
        id: 'topic_1',
        characterId: CharacterProfile.presetMoriId,
        text: '用户下周要去看牙医，还没告诉我结果。',
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: MemoryDossierPage()));
    await tester.pumpAndSettle();

    expect(find.text('人物档案'), findsOneWidget);
    expect(find.textContaining('设计师'), findsOneWidget);
    expect(find.textContaining('热牛奶'), findsOneWidget);
    expect(find.textContaining('换工作'), findsOneWidget);
    expect(find.textContaining('看电影'), findsOneWidget);
    expect(find.textContaining('牙医'), findsOneWidget);
    expect(find.textContaining('待跟进'), findsOneWidget);
  });

  testWidgets('adds a new open topic', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MemoryDossierPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '添加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '用户说周末要告诉我旅行的安排。');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    final topics = MemoryStore.instance.openTopicsFor(
      CharacterProfile.presetMoriId,
    );
    expect(topics, hasLength(1));
    expect(topics.single.text, contains('旅行'));
    expect(find.textContaining('旅行'), findsOneWidget);
  });

  testWidgets('resolves an open topic', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now().millisecondsSinceEpoch;
    await MemoryStore.instance.saveOpenTopic(
      MemoryOpenTopic(
        id: 'topic_1',
        characterId: CharacterProfile.presetMoriId,
        text: '用户说要告诉我面试结果。',
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: MemoryDossierPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('话题操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记为已解决'));
    await tester.pumpAndSettle();

    expect(
      MemoryStore.instance.openTopicsFor(CharacterProfile.presetMoriId),
      isEmpty,
    );
    final all = MemoryStore.instance.openTopicsFor(
      CharacterProfile.presetMoriId,
      includeResolved: true,
    );
    expect(all.single.status, MemoryOpenTopicStatus.resolved);
    expect(find.textContaining('已解决'), findsOneWidget);
  });
}
