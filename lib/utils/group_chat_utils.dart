import 'package:mori_ai/models/chat_message.dart';

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
