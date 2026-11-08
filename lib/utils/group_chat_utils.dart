import 'dart:math';

import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/group_reply_mode.dart';

List<CharacterProfile> selectGroupSpeakers({
  required List<CharacterProfile> members,
  required GroupReplyMode mode,
  required String userMessage,
  Random? random,
}) {
  if (members.isEmpty) {
    return const [];
  }
  final rng = random ?? Random();
  switch (mode) {
    case GroupReplyMode.sequential:
      return List<CharacterProfile>.of(members);
    case GroupReplyMode.randomOrder:
      return [...members]..shuffle(rng);
    case GroupReplyMode.singleRandom:
      return [members[rng.nextInt(members.length)]];
    case GroupReplyMode.mentioned:
      final lowerText = userMessage.toLowerCase();
      final mentioned = [
        for (final member in members)
          if (lowerText.contains(member.displayName.trim().toLowerCase()))
            member,
      ];
      if (mentioned.isNotEmpty) {
        return mentioned;
      }
      return [members[rng.nextInt(members.length)]];
  }
}

/// Builds the history sent to one group member.
///
/// Other members' replies keep their sender-name prefix so the model can tell
/// speakers apart, while the responder's own past replies stay unprefixed so
/// the model does not learn to repeat its name at the start of a message.
List<ChatMessage> buildGroupRequestHistory(
  List<ChatMessage> messages, {
  required String responderId,
}) {
  return [
    for (final message in messages)
      if (!message.isUser &&
          responderId.isNotEmpty &&
          message.senderId == responderId)
        message.copyWith(senderName: '')
      else
        message,
  ];
}
