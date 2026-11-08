import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/utils/chat_queue_utils.dart';

void main() {
  const userA = ChatMessage(id: 'user_a', role: ChatRole.user, content: '消息 A');
  const assistantA = ChatMessage(
    id: 'assistant_a',
    role: ChatRole.assistant,
    content: '回复 A',
  );
  const userB = ChatMessage(id: 'user_b', role: ChatRole.user, content: '消息 B');

  test('keeps only user messages without an assistant response', () {
    final pending = pendingQueueMessages(
      [userA, assistantA, userB],
      ['user_a', 'user_b', 'missing'],
    );

    expect(pending.map((message) => message.id), ['user_b']);
  });

  test('keeps a message when only an empty assistant placeholder exists', () {
    const emptyAssistant = ChatMessage(
      id: 'empty',
      role: ChatRole.assistant,
      content: '',
    );
    final pending = pendingQueueMessages([userA, emptyAssistant], ['user_a']);

    expect(pending.map((message) => message.id), ['user_a']);
  });

  test('excludes later queued messages from the active round history', () {
    final history = roundHistoryFor(
      [userA, userB, assistantA],
      [userA, userB],
      userA,
    );

    expect(history.map((message) => message.id), ['user_a', 'assistant_a']);
  });
}
