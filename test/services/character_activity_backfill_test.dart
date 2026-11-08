import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/character_activity_backfill.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await MomentStore.instance.load();
    await CharacterActivityStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await MomentStore.instance.load();
    await CharacterActivityStore.instance.load();
  });

  test('backfills own single, group, moment and comment activities', () async {
    final second = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final now = DateTime.now();

    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'single_user',
        role: ChatRole.user,
        content: '单聊用户消息',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      ChatMessage(
        id: 'single_assistant',
        role: ChatRole.assistant,
        content: '单聊回复',
        createdAt: now.subtract(const Duration(hours: 3, minutes: 59)),
      ),
    ]);

    final group = await GroupStore.instance.createGroup(
      name: '摸鱼群',
      memberIds: [CharacterProfile.presetMoriId, second.id],
    );
    await ChatHistoryStore.instance.saveFor(group.id, [
      ChatMessage(
        id: 'group_user',
        role: ChatRole.user,
        content: '群里用户消息',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ChatMessage(
        id: 'group_assistant',
        role: ChatRole.assistant,
        senderId: CharacterProfile.presetMoriId,
        senderName: 'Mori',
        content: '群里回复',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 59)),
      ),
    ]);

    final moment = await MomentStore.instance.add(
      authorId: CharacterProfile.presetMoriId,
      authorName: 'Mori',
      isUser: false,
      content: '动态内容',
    );
    await MomentStore.instance.addComment(
      moment.id,
      authorId: CharacterProfile.presetMoriId,
      authorName: 'Mori',
      isUser: false,
      content: '评论内容',
    );

    await CharacterActivityBackfill.instance.ensureBackfilled();

    final activities = CharacterActivityStore.instance.activitiesFor(
      CharacterProfile.presetMoriId,
    );
    expect(activities, hasLength(4));
    expect(
      activities.map((activity) => activity.kind),
      containsAll([
        CharacterActivityKind.singleMessage,
        CharacterActivityKind.groupMessage,
        CharacterActivityKind.moment,
        CharacterActivityKind.momentComment,
      ]),
    );
    expect(
      activities.map((activity) => activity.content),
      containsAll(['单聊回复', '群里回复', '动态内容', '评论内容']),
    );
    expect(
      activities
          .firstWhere(
            (activity) => activity.kind == CharacterActivityKind.groupMessage,
          )
          .contextLabel,
      '摸鱼群',
    );

    await CharacterActivityBackfill.instance.ensureBackfilled();
    expect(
      CharacterActivityStore.instance.activitiesFor(
        CharacterProfile.presetMoriId,
      ),
      hasLength(4),
    );
  });
}
