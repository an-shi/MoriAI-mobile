import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/utils/group_chat_utils.dart';

void main() {
  test('removes the responder name from its own history but keeps others', () {
    const messages = [
      ChatMessage(
        role: ChatRole.user,
        content: '你们好。',
        senderId: 'user',
        senderName: '小森',
      ),
      ChatMessage(
        role: ChatRole.assistant,
        content: '你好。',
        senderId: 'mori',
        senderName: 'Mori',
      ),
      ChatMessage(
        role: ChatRole.assistant,
        content: '晚上好。',
        senderId: 'card_2',
        senderName: '小夜',
      ),
    ];

    final history = buildGroupRequestHistory(messages, responderId: 'card_2');

    expect(history[0].senderName, '小森');
    expect(history[1].senderName, 'Mori');
    expect(history[2].senderName, '');
    expect(history[2].content, '晚上好。');
  });
}
