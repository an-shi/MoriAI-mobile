import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/pages/chat_detail_page.dart';
import 'package:mori_ai/pages/chat_list_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/pinned_conversation_store.dart';
import 'package:mori_ai/services/unread_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await PinnedConversationStore.instance.load();
    await UnreadStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await PinnedConversationStore.instance.load();
    await UnreadStore.instance.load();
  });

  testWidgets('lists conversations and opens the selected chat', (
    tester,
  ) async {
    final secondCard = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );

    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'mori_1',
        role: ChatRole.assistant,
        content: 'Mori 的历史消息',
        createdAt: DateTime(2026, 11, 8, 9),
      ),
    ]);
    await ChatHistoryStore.instance.saveFor(secondCard.id, [
      ChatMessage(
        id: 'xiaosen_1',
        role: ChatRole.user,
        content: '小森的最新消息',
        createdAt: DateTime(2026, 11, 8, 10),
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatListPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mori'), findsOneWidget);
    expect(find.text('小森'), findsOneWidget);
    expect(find.text('Mori 的历史消息'), findsOneWidget);
    expect(find.text('小森的最新消息'), findsOneWidget);

    await UnreadStore.instance.markUnread(
      CharacterProfile.presetMoriId,
      count: 2,
    );
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    final xiaosenTop = tester.getTopLeft(find.text('小森')).dy;
    final moriTop = tester.getTopLeft(find.text('Mori')).dy;
    expect(xiaosenTop, lessThan(moriTop));

    await tester.tap(find.text('Mori'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatDetailPage), findsOneWidget);
    expect(find.text('Mori 的历史消息'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ChatListPage), findsOneWidget);
  });

  testWidgets('pins conversations from the long-press menu', (tester) async {
    final secondCard = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final thirdCard = await CharacterStore.instance.addCard(
      name: '小夜',
      persona: '冷静、直接。',
    );

    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'mori_1',
        role: ChatRole.assistant,
        content: 'Mori 的历史消息',
        createdAt: DateTime(2026, 11, 8, 9),
      ),
    ]);
    await ChatHistoryStore.instance.saveFor(secondCard.id, [
      ChatMessage(
        id: 'xiaosen_1',
        role: ChatRole.user,
        content: '小森的最新消息',
        createdAt: DateTime(2026, 11, 8, 10),
      ),
    ]);
    await ChatHistoryStore.instance.saveFor(thirdCard.id, [
      ChatMessage(
        id: 'xiaoye_1',
        role: ChatRole.user,
        content: '小夜的最新消息',
        createdAt: DateTime(2026, 11, 8, 11),
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatListPage())),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('小夜')).dy,
      lessThan(tester.getTopLeft(find.text('小森')).dy),
    );

    await tester.longPress(find.text('Mori'));
    await tester.pumpAndSettle();
    expect(find.text('置顶'), findsOneWidget);
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('小森'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();

    expect(
      PinnedConversationStore.instance.isPinned(CharacterProfile.presetMoriId),
      isTrue,
    );
    expect(PinnedConversationStore.instance.isPinned(secondCard.id), isTrue);

    // 置顶会话排在最前，多个置顶之间仍按最新消息倒序。
    expect(
      tester.getTopLeft(find.text('小森')).dy,
      lessThan(tester.getTopLeft(find.text('Mori')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Mori')).dy,
      lessThan(tester.getTopLeft(find.text('小夜')).dy),
    );

    final moriTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Mori'), matching: find.byType(ListTile)),
    );
    final theme = Theme.of(tester.element(find.text('Mori')));
    expect(moriTile.tileColor, theme.colorScheme.surfaceContainerLow);

    await tester.longPress(find.text('Mori'));
    await tester.pumpAndSettle();
    expect(find.text('取消置顶'), findsOneWidget);
    await tester.tap(find.text('取消置顶'));
    await tester.pumpAndSettle();

    expect(
      PinnedConversationStore.instance.isPinned(CharacterProfile.presetMoriId),
      isFalse,
    );
  });
}
