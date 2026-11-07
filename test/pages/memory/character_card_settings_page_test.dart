import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/pages/memory/character_card_settings_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
  });

  Finder fieldWithLabel(String label) {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
  }

  Future<void> openMoriEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CharacterCardSettingsPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mori'));
    await tester.pumpAndSettle();
    expect(find.text('编辑角色卡'), findsOneWidget);
  }

  testWidgets('opens the edit page from a card and saves changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await openMoriEditor(tester);

    await tester.enterText(fieldWithLabel('名称'), '小森');
    await tester.enterText(fieldWithLabel('人格描述'), '温柔、耐心，喜欢倾听。');
    await tester.enterText(fieldWithLabel('性格特点'), '安静、细心、有一点幽默感。');
    await tester.tap(find.text('保存角色卡'));
    await tester.pumpAndSettle();

    expect(CharacterStore.instance.activeCard.name, '小森');
    expect(CharacterStore.instance.activeCard.persona, '温柔、耐心，喜欢倾听。');
    expect(CharacterStore.instance.activeCard.personality, '安静、细心、有一点幽默感。');
    expect(find.text('小森'), findsOneWidget);
    expect(find.text('角色卡已保存'), findsOneWidget);
  });

  testWidgets('switches card type and exposes the matching fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await openMoriEditor(tester);
    expect(fieldWithLabel('性格特点'), findsOneWidget);
    expect(fieldWithLabel('场景'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('character-card-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色扮演').last);
    await tester.pumpAndSettle();

    expect(fieldWithLabel('场景'), findsOneWidget);
    expect(fieldWithLabel('开场白'), findsOneWidget);
    expect(fieldWithLabel('示例对话'), findsOneWidget);

    await tester.enterText(fieldWithLabel('场景'), '一个安静的夜晚。');
    await tester.tap(find.text('保存角色卡'));
    await tester.pumpAndSettle();

    expect(CharacterStore.instance.activeCard.type, CharacterCardType.roleplay);
    expect(CharacterStore.instance.activeCard.scenario, '一个安静的夜晚。');
  });

  testWidgets('pasted card type uses a single raw definition field', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await openMoriEditor(tester);
    await tester.tap(find.byKey(const ValueKey('character-card-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('粘贴设定').last);
    await tester.pumpAndSettle();

    expect(fieldWithLabel('角色卡设定'), findsOneWidget);
    expect(fieldWithLabel('一句话简介'), findsNothing);
    expect(fieldWithLabel('人格描述'), findsNothing);
    expect(fieldWithLabel('性格特点'), findsNothing);

    const raw = '你是小森，一个安静、耐心的伙伴。\n说话简洁自然。';
    await tester.enterText(fieldWithLabel('名称'), '小森');
    await tester.enterText(fieldWithLabel('角色卡设定'), raw);
    await tester.tap(find.text('保存角色卡'));
    await tester.pumpAndSettle();

    expect(CharacterStore.instance.activeCard.type, CharacterCardType.paste);
    expect(CharacterStore.instance.activeCard.name, '小森');
    expect(CharacterStore.instance.activeCard.rawDefinition, raw);
  });

  testWidgets('cannot delete the only card, but can delete after adding one', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: CharacterCardSettingsPage()),
    );
    await tester.pumpAndSettle();

    final disabledDelete = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(disabledDelete.onPressed, isNull);

    await tester.tap(find.text('新建角色卡'));
    await tester.pumpAndSettle();
    expect(find.text('编辑角色卡'), findsOneWidget);
    expect(CharacterStore.instance.cards.value, hasLength(2));

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));

    await tester.tap(find.byTooltip('使用这张角色卡'));
    await tester.pumpAndSettle();
    expect(
      CharacterStore.instance.activeCard.id,
      CharacterProfile.presetMoriId,
    );

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('删除角色卡'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(CharacterStore.instance.cards.value, hasLength(1));
    expect(
      CharacterStore.instance.activeCard.id,
      CharacterProfile.presetMoriId,
    );
    expect(find.byTooltip('至少保留一张角色卡'), findsOneWidget);
  });
}
