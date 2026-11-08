import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CharacterActivityBackfill {
  CharacterActivityBackfill._();

  static final CharacterActivityBackfill instance =
      CharacterActivityBackfill._();

  static const _doneKey = 'character_activity_backfill_v1_done';

  Future<void> ensureBackfilled() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_doneKey) == true) {
      return;
    }

    try {
      final activities = <CharacterActivity>[];
      for (final character in CharacterStore.instance.cards.value) {
        final history = await ChatHistoryStore.instance.loadFor(character.id);
        for (final message in history) {
          if (message.isUser ||
              message.id.trim().isEmpty ||
              message.content.trim().isEmpty) {
            continue;
          }
          activities.add(
            CharacterActivity(
              id: message.id,
              characterId: character.id,
              kind: CharacterActivityKind.singleMessage,
              contextId: character.id,
              contextLabel: '和用户单聊',
              content: message.content,
              createdAtMs:
                  (message.createdAt ?? DateTime.now()).millisecondsSinceEpoch,
            ),
          );
        }
      }

      for (final group in GroupStore.instance.groups.value) {
        final history = await ChatHistoryStore.instance.loadFor(group.id);
        for (final message in history) {
          if (message.isUser ||
              message.id.trim().isEmpty ||
              message.senderId.trim().isEmpty ||
              message.content.trim().isEmpty) {
            continue;
          }
          if (CharacterStore.instance.cardById(message.senderId) == null) {
            continue;
          }
          activities.add(
            CharacterActivity(
              id: message.id,
              characterId: message.senderId,
              kind: CharacterActivityKind.groupMessage,
              contextId: group.id,
              contextLabel: group.name,
              content: message.content,
              createdAtMs:
                  (message.createdAt ?? DateTime.now()).millisecondsSinceEpoch,
            ),
          );
        }
      }

      for (final moment in MomentStore.instance.moments.value) {
        if (!moment.isUser && moment.authorId.trim().isNotEmpty) {
          final content = moment.content.trim();
          activities.add(
            CharacterActivity(
              id: moment.id,
              characterId: moment.authorId,
              kind: CharacterActivityKind.moment,
              contextId: moment.id,
              contextLabel: '动态',
              content: content.isEmpty ? '发了一条图片动态' : content,
              createdAtMs: moment.createdAt.millisecondsSinceEpoch,
            ),
          );
        }
        for (final comment in moment.comments) {
          if (comment.isUser ||
              comment.authorId.trim().isEmpty ||
              comment.content.trim().isEmpty) {
            continue;
          }
          activities.add(
            CharacterActivity(
              id: comment.id,
              characterId: comment.authorId,
              kind: comment.replyToCommentId.isEmpty
                  ? CharacterActivityKind.momentComment
                  : CharacterActivityKind.momentReply,
              contextId: moment.id,
              contextLabel: '动态',
              content: comment.content,
              createdAtMs: comment.createdAt.millisecondsSinceEpoch,
            ),
          );
        }
      }

      await CharacterActivityStore.instance.recordAll(activities);
      await preferences.setBool(_doneKey, true);
    } catch (_) {
      // 回填失败不影响启动，下次启动会继续尝试。
    }
  }
}
