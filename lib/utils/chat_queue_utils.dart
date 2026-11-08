import 'package:mori_ai/models/chat_message.dart';

/// Returns queued user messages that still have no assistant response.
///
/// A user message counts as answered when at least one non-empty assistant
/// message appears after it and before the next user message.
List<ChatMessage> pendingQueueMessages(
  List<ChatMessage> messages,
  List<String> queuedIds,
) {
  final indices = <String, int>{
    for (var index = 0; index < messages.length; index++)
      if (messages[index].isUser) messages[index].id: index,
  };
  final result = <ChatMessage>[];
  final seen = <String>{};
  for (final id in queuedIds) {
    if (!seen.add(id)) {
      continue;
    }
    final index = indices[id];
    if (index == null) {
      continue;
    }
    var answered = false;
    for (var next = index + 1; next < messages.length; next++) {
      final message = messages[next];
      if (message.isUser) {
        break;
      }
      if (!message.isUser &&
          (message.content.trim().isNotEmpty || message.image != null)) {
        answered = true;
        break;
      }
    }
    if (!answered) {
      result.add(messages[index]);
    }
  }
  return result;
}

/// Builds the history for one reply round.
///
/// Later queued user messages are excluded, while the active message and all
/// assistant replies are included.
List<ChatMessage> roundHistoryFor(
  List<ChatMessage> messages,
  List<ChatMessage> queuedMessages,
  ChatMessage activeMessage,
) {
  final queuedIds = {
    for (final message in queuedMessages)
      if (message.id != activeMessage.id) message.id,
  };
  return [
    for (final message in messages)
      if (!(message.isUser && queuedIds.contains(message.id))) message,
  ];
}
