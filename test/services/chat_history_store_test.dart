import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists chat messages separately for each character card', () async {
    final timestamp = DateTime(2026, 11, 8, 10, 30);
    await ChatHistoryStore.instance.saveFor('card_a', [
      ChatMessage(
        id: '1',
        role: ChatRole.user,
        content: '早上好',
        createdAt: timestamp,
      ),
      ChatMessage(
        id: '2',
        role: ChatRole.assistant,
        content: '早上好，今天想做什么？',
        createdAt: timestamp.add(const Duration(seconds: 3)),
      ),
    ]);
    await ChatHistoryStore.instance.saveFor('card_b', [
      ChatMessage(
        id: '3',
        role: ChatRole.user,
        content: '另一个角色的聊天',
        createdAt: timestamp,
      ),
    ]);

    final cardAMessages = await ChatHistoryStore.instance.loadFor('card_a');
    final cardBMessages = await ChatHistoryStore.instance.loadFor('card_b');

    expect(cardAMessages, hasLength(2));
    expect(cardAMessages.first.content, '早上好');
    expect(cardAMessages.last.content, '早上好，今天想做什么？');
    expect(cardAMessages.first.createdAt, timestamp);
    expect(cardBMessages, hasLength(1));
    expect(cardBMessages.single.content, '另一个角色的聊天');
  });

  test(
    'returns the latest message summary for the conversation list',
    () async {
      final latestTime = DateTime(2026, 11, 8, 11, 0);
      await ChatHistoryStore.instance.saveFor('card_a', [
        ChatMessage(
          id: '1',
          role: ChatRole.user,
          content: '较早的消息',
          createdAt: latestTime.subtract(const Duration(minutes: 10)),
        ),
        ChatMessage(
          id: '2',
          role: ChatRole.assistant,
          content: '最新一条消息\n第二行',
          createdAt: latestTime,
        ),
      ]);

      final summary = await ChatHistoryStore.instance.summaryFor('card_a');

      expect(summary, isNotNull);
      expect(summary!.preview, '最新一条消息 第二行');
      expect(summary.createdAt, latestTime);
      expect(await ChatHistoryStore.instance.summaryFor('card_b'), isNull);
    },
  );

  test('does not persist an empty assistant placeholder', () async {
    await ChatHistoryStore.instance.saveFor('card_a', [
      const ChatMessage(id: '1', role: ChatRole.user, content: '你好'),
      const ChatMessage(id: '2', role: ChatRole.assistant, content: ''),
    ]);

    final messages = await ChatHistoryStore.instance.loadFor('card_a');

    expect(messages, hasLength(1));
    expect(messages.single.role, ChatRole.user);
  });
}
