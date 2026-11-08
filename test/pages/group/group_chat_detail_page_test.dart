import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/pages/group/group_chat_detail_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
  });

  testWidgets('renders group history with the speaking member name', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final second = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final group = await GroupStore.instance.createGroup(
      name: '测试群聊',
      memberIds: ['mori', second.id],
    );
    await ChatHistoryStore.instance.saveFor(group.id, [
      ChatMessage(
        id: 'group_1',
        role: ChatRole.assistant,
        content: 'Mori：大家好，我是 Mori。',
        senderId: 'mori',
        senderName: 'Mori',
        createdAt: DateTime(2026, 11, 8, 10),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: GroupChatDetailPage(group: group)),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试群聊'), findsOneWidget);
    expect(find.text('2 位成员'), findsOneWidget);
    expect(find.text('大家好，我是 Mori。'), findsOneWidget);
    expect(find.text('Mori：大家好，我是 Mori。'), findsNothing);
    expect(find.text('Mori'), findsOneWidget);

    await tester.tap(find.byTooltip('群聊设置'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '群聊设置'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '新的群聊名称');
    await tester.tap(find.text('保存群聊设置'));
    await tester.pumpAndSettle();

    expect(find.text('新的群聊名称'), findsOneWidget);
    expect(GroupStore.instance.groupById(group.id)?.name, '新的群聊名称');
  });

  testWidgets('deletes the group chat history from the settings page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final second = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final group = await GroupStore.instance.createGroup(
      name: '测试群聊',
      memberIds: ['mori', second.id],
    );
    await ChatHistoryStore.instance.saveFor(group.id, [
      ChatMessage(
        id: 'group_delete',
        role: ChatRole.user,
        content: '准备删除的群聊记录',
        senderId: 'user',
        createdAt: DateTime(2026, 11, 8, 10),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: GroupChatDetailPage(group: group)),
    );
    await tester.pumpAndSettle();
    expect(find.text('准备删除的群聊记录'), findsOneWidget);

    await tester.tap(find.byTooltip('群聊设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('删除聊天记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除聊天记录'));
    await tester.pumpAndSettle();

    expect(find.text('确定删除该群聊的全部聊天记录吗？删除后无法恢复。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(await ChatHistoryStore.instance.loadFor(group.id), isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('准备删除的群聊记录'), findsNothing);
  });
}
