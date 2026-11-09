import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/group_memory.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/pages/group/group_memory_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/group_memory_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await GroupMemoryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await GroupMemoryStore.instance.load();
  });

  Future<String> createGroup() async {
    final second = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final group = await GroupStore.instance.createGroup(
      name: '深夜聊天室',
      memberIds: [CharacterProfile.presetMoriId, second.id],
    );
    return group.id;
  }

  testWidgets('shows group impression and public memories', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final groupId = await createGroup();
    final now = DateTime.now().millisecondsSinceEpoch;
    await GroupMemoryStore.instance.saveProfile(
      GroupMemoryProfile(
        groupId: groupId,
        summary: '大家像宿舍室友一样熟。',
        sharedHabits: '经常互相发梗图。',
        recentFocus: '最近在约看展。',
        importantDates: const ['下个月第一个周末去看展'],
        updatedAtMs: now,
      ),
    );
    await GroupMemoryStore.instance.saveEntry(
      GroupMemoryEntry(
        id: 'gmem_1',
        groupId: groupId,
        text: '大家约好下个月一起去看展。',
        category: MemoryCategory.plan,
        importance: 0.8,
        tags: const ['看展'],
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: GroupMemoryPage(groupId: groupId)),
    );
    await tester.pumpAndSettle();

    expect(find.text('群公共记忆'), findsOneWidget);
    expect(find.text('群印象'), findsOneWidget);
    expect(find.textContaining('宿舍室友'), findsOneWidget);
    expect(find.textContaining('梗图'), findsOneWidget);
    expect(find.textContaining('一起去看展'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);
  });

  testWidgets('adds a manual group memory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final groupId = await createGroup();
    await tester.pumpWidget(
      MaterialApp(home: GroupMemoryPage(groupId: groupId)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加共同记忆'));
    await tester.pumpAndSettle();
    final memoryField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '共同记忆',
    );
    await tester.enterText(memoryField, '大家约好周末一起吃饭。');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    final entries = GroupMemoryStore.instance.entriesFor(groupId);
    expect(entries, hasLength(1));
    expect(entries.single.text, contains('吃饭'));
    expect(find.textContaining('吃饭'), findsOneWidget);
  });
}
