import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/main.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
  });

  testWidgets('bottom navigation switches between pages', (tester) async {
    await tester.pumpWidget(const MoriApp());

    expect(find.text('嗨，我是 Mori'), findsOneWidget);

    await tester.tap(find.text('记忆与角色卡'));
    await tester.pumpAndSettle();
    expect(find.text('记忆'), findsOneWidget);
    expect(find.text('角色卡'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('模型'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('关于 Mori'), findsOneWidget);
  });

  testWidgets('assistant name follows the character card', (tester) async {
    await CharacterStore.instance.load();
    await CharacterStore.instance.save(
      CharacterProfile(
        id: CharacterStore.instance.activeCard.id,
        name: '小森',
        persona: '温柔、耐心',
      ),
    );

    await tester.pumpWidget(const MoriApp());

    expect(find.text('嗨，我是 小森'), findsOneWidget);
    expect(find.text('和 小森 说点什么…'), findsOneWidget);
  });

  testWidgets('memory categories open their own pages', (tester) async {
    await tester.pumpWidget(const MoriApp());

    await tester.tap(find.text('记忆与角色卡'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('记忆'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '记忆'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('角色卡'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '角色卡'), findsOneWidget);
  });

  testWidgets('settings categories open their own pages', (tester) async {
    await tester.pumpWidget(const MoriApp());

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('模型'));
    await tester.pumpAndSettle();
    expect(find.text('模型配置'), findsOneWidget);
    expect(find.text('模型供应商'), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('模型预设'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
  });
}
