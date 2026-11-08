import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/group_store.dart';

abstract final class CharacterActivityRecorder {
  static Future<void> recordChatMessages({
    required CharacterProfile character,
    required String conversationId,
    required bool isGroup,
    required Iterable<ChatMessage> messages,
  }) {
    final contextLabel = isGroup
        ? (GroupStore.instance.groupById(conversationId)?.displayName ?? '群聊')
        : '和用户单聊';
    return CharacterActivityStore.instance.recordAll([
      for (final message in messages)
        if (!message.isUser && message.id.trim().isNotEmpty)
          if (message.content.trim().isNotEmpty)
            CharacterActivity(
              id: message.id,
              characterId: character.id,
              kind: isGroup
                  ? CharacterActivityKind.groupMessage
                  : CharacterActivityKind.singleMessage,
              contextId: conversationId,
              contextLabel: contextLabel,
              content: message.content,
              createdAtMs:
                  (message.createdAt ?? DateTime.now()).millisecondsSinceEpoch,
            ),
    ]);
  }

  static Future<void> recordProactiveMessages({
    required CharacterProfile character,
    required Iterable<ChatMessage> messages,
  }) {
    return CharacterActivityStore.instance.recordAll([
      for (final message in messages)
        if (message.id.trim().isNotEmpty)
          if (message.content.trim().isNotEmpty)
            CharacterActivity(
              id: message.id,
              characterId: character.id,
              kind: CharacterActivityKind.proactiveMessage,
              contextId: character.id,
              contextLabel: '和用户单聊',
              content: message.content,
              createdAtMs:
                  (message.createdAt ?? DateTime.now()).millisecondsSinceEpoch,
            ),
    ]);
  }

  static Future<void> recordMoment({
    required CharacterProfile character,
    required Moment moment,
  }) {
    final content = moment.content.trim();
    return CharacterActivityStore.instance.record(
      CharacterActivity(
        id: moment.id,
        characterId: character.id,
        kind: CharacterActivityKind.moment,
        contextId: moment.id,
        contextLabel: '动态',
        content: content.isEmpty ? '发了一条图片动态' : content,
        createdAtMs: moment.createdAt.millisecondsSinceEpoch,
      ),
    );
  }

  static Future<void> recordMomentComment({
    required CharacterProfile character,
    required Moment moment,
    required MomentComment comment,
    required bool isReply,
  }) {
    return CharacterActivityStore.instance.record(
      CharacterActivity(
        id: comment.id,
        characterId: character.id,
        kind: isReply
            ? CharacterActivityKind.momentReply
            : CharacterActivityKind.momentComment,
        contextId: moment.id,
        contextLabel: '动态',
        content: comment.content,
        createdAtMs: comment.createdAt.millisecondsSinceEpoch,
      ),
    );
  }
}
