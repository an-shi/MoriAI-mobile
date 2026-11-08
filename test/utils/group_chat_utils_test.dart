import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/group_reply_mode.dart';
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

  test('selects group speakers according to the reply mode', () {
    const members = [
      CharacterProfile(id: 'mori', name: 'Mori'),
      CharacterProfile(id: 'card_2', name: '小森'),
      CharacterProfile(id: 'card_3', name: '小夜'),
    ];

    final sequential = selectGroupSpeakers(
      members: members,
      mode: GroupReplyMode.sequential,
      userMessage: '大家好',
      random: Random(1),
    );
    expect(sequential.map((member) => member.id), ['mori', 'card_2', 'card_3']);

    final randomOrder = selectGroupSpeakers(
      members: members,
      mode: GroupReplyMode.randomOrder,
      userMessage: '大家好',
      random: Random(1),
    );
    expect(randomOrder, hasLength(3));
    expect(randomOrder.map((member) => member.id).toSet(), {
      'mori',
      'card_2',
      'card_3',
    });

    final single = selectGroupSpeakers(
      members: members,
      mode: GroupReplyMode.singleRandom,
      userMessage: '大家好',
      random: Random(1),
    );
    expect(single, hasLength(1));

    final mentioned = selectGroupSpeakers(
      members: members,
      mode: GroupReplyMode.mentioned,
      userMessage: 'Mori，你怎么看？',
      random: Random(1),
    );
    expect(mentioned.map((member) => member.id), ['mori']);

    final fallback = selectGroupSpeakers(
      members: members,
      mode: GroupReplyMode.mentioned,
      userMessage: '大家好',
      random: Random(1),
    );
    expect(fallback, hasLength(1));
  });
}
