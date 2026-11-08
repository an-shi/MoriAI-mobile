import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/pages/memory/memory_library_page.dart';
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

  Future<void> seed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MemoryStore.instance.saveEntry(
      MemoryEntry(
        id: 'm1',
        characterId: CharacterProfile.presetMoriId,
        text: '用户喜欢在晚上喝热牛奶',
        category: MemoryCategory.preference,
        importance: 0.7,
        tags: const ['牛奶'],
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
  }

  testWidgets('shows, searches and deletes memories', (tester) async {
    await seed();
    await tester.pumpWidget(const MaterialApp(home: MemoryLibraryPage()));
    await tester.pumpAndSettle();

    expect(find.text('用户喜欢在晚上喝热牛奶'), findsOneWidget);
    expect(find.text('Mori'), findsWidgets);
    expect(find.text('喜好'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '牛奶');
    await tester.pumpAndSettle();
    expect(find.text('用户喜欢在晚上喝热牛奶'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '完全无关');
    await tester.pumpAndSettle();
    expect(find.text('没有找到相关记忆'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('记忆操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('确定删除这条记忆吗？删除后无法恢复。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('还没有记忆'), findsOneWidget);
    expect(
      MemoryStore.instance.entriesFor(CharacterProfile.presetMoriId),
      isEmpty,
    );
  });

  testWidgets('adds a manual memory', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryLibraryPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('添加记忆'), findsWidgets);

    final contentField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '记忆内容',
    );
    await tester.enterText(contentField, '用户下个月准备去旅行');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    final entries = MemoryStore.instance.entriesFor(
      CharacterProfile.presetMoriId,
    );
    expect(entries, hasLength(1));
    expect(entries.single.text, contains('旅行'));
    expect(entries.single.source, MemorySource.manual);
  });

  testWidgets('shows an empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryLibraryPage()));
    await tester.pumpAndSettle();
    expect(find.text('还没有记忆'), findsOneWidget);
  });
}
