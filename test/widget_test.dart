import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/main.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await MomentStore.instance.load();
    await DiaryStore.instance.load();
    await MemoryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await MomentStore.instance.load();
    await DiaryStore.instance.load();
    await MemoryStore.instance.load();
  });

  testWidgets('bottom navigation switches between pages', (tester) async {
    await tester.pumpWidget(const MoriApp());
    await tester.pumpAndSettle();

    expect(find.text('Mori'), findsOneWidget);
    expect(find.text('暂无消息'), findsOneWidget);

    await tester.tap(find.text('记忆与角色卡'));
    await tester.pumpAndSettle();
    expect(find.text('记忆'), findsOneWidget);
    expect(find.text('日记'), findsOneWidget);
    expect(find.text('角色卡'), findsOneWidget);

    await tester.tap(find.text('动态'));
    await tester.pumpAndSettle();
    expect(find.text('最新动态'), findsOneWidget);
    expect(find.text('还没有动态'), findsOneWidget);
  });

  testWidgets('user profile is on the left and add menu is on the right', (
    tester,
  ) async {
    await tester.pumpWidget(const MoriApp());
    await tester.pumpAndSettle();

    final userX = tester.getCenter(find.byTooltip('个人资料')).dx;
    final addX = tester.getCenter(find.byTooltip('更多')).dx;
    expect(userX, lessThan(addX));
  });

  testWidgets('profile drawer opens personal settings', (tester) async {
    await tester.pumpWidget(const MoriApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('个人资料'));
    await tester.pumpAndSettle();
    expect(find.text('个人信息'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(Drawer)).dx, lessThan(1));

    await tester.tap(find.text('个人信息'));
    await tester.pumpAndSettle();
    expect(find.text('基本资料'), findsOneWidget);
  });

  testWidgets('plus menu creates a group chat', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await CharacterStore.instance.load();
    await CharacterStore.instance.addCard(name: '小森', persona: '安静、耐心。');

    await tester.pumpWidget(const MoriApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('新建群聊'), findsOneWidget);

    await tester.tap(find.text('新建群聊'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '新建群聊'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '测试群聊');
    final memberTiles = find.byType(CheckboxListTile);
    expect(memberTiles, findsNWidgets(2));
    await tester.tap(memberTiles.at(0));
    await tester.tap(memberTiles.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('测试群聊'), findsOneWidget);
    expect(GroupStore.instance.groups.value, hasLength(1));
  });

  testWidgets('memory categories open their own pages', (tester) async {
    await tester.pumpWidget(const MoriApp());

    await tester.tap(find.text('记忆与角色卡'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('记忆'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '记忆'), findsOneWidget);
    expect(find.text('添加记忆'), findsWidgets);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('人物档案'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '人物档案'), findsOneWidget);
    expect(find.text('未完成话题'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '日记'), findsOneWidget);
    expect(find.text('还没有日记'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('角色卡'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '角色卡'), findsOneWidget);
  });

  testWidgets('settings categories open their own pages', (tester) async {
    await tester.pumpWidget(const MoriApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('个人资料'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);

    await tester.tap(find.text('模型'));
    await tester.pumpAndSettle();
    expect(find.text('模型配置'), findsOneWidget);
    expect(find.text('模型供应商'), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('模型预设'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('动态互动'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动态互动'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '动态互动'), findsOneWidget);
    expect(find.text('自动评论人数'), findsOneWidget);
    expect(find.text('自动回复层数'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('自动消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自动消息'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '自动消息'), findsOneWidget);
    expect(find.text('启用自动消息'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '日记'), findsOneWidget);
    expect(find.text('启用每日日记'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('记忆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记忆'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '记忆设置'), findsOneWidget);
    expect(find.text('启用长期记忆'), findsOneWidget);
  });
}
