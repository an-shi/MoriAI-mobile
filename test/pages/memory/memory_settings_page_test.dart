import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/pages/memory/memory_settings_page.dart';
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

  testWidgets('toggles memory and changes recall count', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MemorySettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('启用长期记忆'), findsOneWidget);
    expect(find.text('自动整理记忆'), findsOneWidget);
    expect(find.text('启用群聊公共记忆'), findsOneWidget);
    expect(find.text('每次召回条数'), findsOneWidget);
    expect(find.text('立即整理记忆'), findsOneWidget);

    await tester.tap(find.text('启用群聊公共记忆'));
    await tester.pumpAndSettle();
    expect(MemoryStore.instance.settings.value.groupMemoryEnabled, isFalse);

    await tester.tap(find.text('自动整理记忆'));
    await tester.pumpAndSettle();
    expect(MemoryStore.instance.settings.value.autoExtract, isFalse);

    final recallField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '每次召回条数',
    );
    await tester.enterText(recallField, '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(MemoryStore.instance.settings.value.recallCount, 4);

    await tester.tap(find.text('启用长期记忆'));
    await tester.pumpAndSettle();
    expect(MemoryStore.instance.settings.value.enabled, isFalse);
  });

  testWidgets('clears all memories for a character', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now().millisecondsSinceEpoch;
    await MemoryStore.instance.saveEntry(
      MemoryEntry(
        id: 'm1',
        characterId: CharacterProfile.presetMoriId,
        text: '用户喜欢热牛奶',
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: MemorySettingsPage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('清空某个角色的记忆'));
    await tester.tap(find.text('清空某个角色的记忆'));
    await tester.pumpAndSettle();
    expect(find.textContaining('全部 1 条记忆'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();
    expect(
      MemoryStore.instance.entriesFor(CharacterProfile.presetMoriId),
      isEmpty,
    );
  });
}
