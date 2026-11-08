import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterActivityStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterActivityStore.instance.load();
  });

  CharacterActivity activity({
    required String id,
    required String characterId,
    required CharacterActivityKind kind,
    required String content,
    required int minutesAgo,
  }) {
    return CharacterActivity(
      id: id,
      characterId: characterId,
      kind: kind,
      contextId: 'context',
      contextLabel: '上下文',
      content: content,
      createdAtMs: DateTime.now()
          .subtract(Duration(minutes: minutesAgo))
          .millisecondsSinceEpoch,
    );
  }

  test('records, deduplicates and restores activities', () async {
    await CharacterActivityStore.instance.recordAll([
      activity(
        id: 'a1',
        characterId: 'mori',
        kind: CharacterActivityKind.groupMessage,
        content: '群聊内容',
        minutesAgo: 3,
      ),
      activity(
        id: 'a2',
        characterId: 'mori',
        kind: CharacterActivityKind.moment,
        content: '动态内容',
        minutesAgo: 2,
      ),
      activity(
        id: 'a1',
        characterId: 'mori',
        kind: CharacterActivityKind.groupMessage,
        content: '重复内容',
        minutesAgo: 1,
      ),
    ]);

    expect(CharacterActivityStore.instance.activitiesFor('mori'), hasLength(2));
    expect(
      CharacterActivityStore.instance.activitiesFor('mori').last.content,
      '动态内容',
    );

    await CharacterActivityStore.instance.load();
    final loaded = CharacterActivityStore.instance.activitiesFor('mori');
    expect(loaded, hasLength(2));
    expect(loaded.map((item) => item.id), ['a1', 'a2']);
  });

  test('trims the oldest activities beyond the per-character cap', () async {
    await CharacterActivityStore.instance.recordAll([
      for (
        var index = 0;
        index < CharacterActivityStore.maxActivitiesPerCharacter + 5;
        index++
      )
        activity(
          id: 'a$index',
          characterId: 'mori',
          kind: CharacterActivityKind.singleMessage,
          content: '内容 $index',
          minutesAgo: 1000 - index,
        ),
    ]);

    final activities = CharacterActivityStore.instance.activitiesFor('mori');
    expect(
      activities,
      hasLength(CharacterActivityStore.maxActivitiesPerCharacter),
    );
    expect(activities.first.content, '内容 5');
    expect(activities.last.content, '内容 304');
  });

  test('clears activities for one character only', () async {
    await CharacterActivityStore.instance.recordAll([
      activity(
        id: 'a1',
        characterId: 'mori',
        kind: CharacterActivityKind.moment,
        content: 'Mori 动态',
        minutesAgo: 2,
      ),
      activity(
        id: 'b1',
        characterId: 'other',
        kind: CharacterActivityKind.moment,
        content: '其他角色动态',
        minutesAgo: 1,
      ),
    ]);

    await CharacterActivityStore.instance.clearForCharacter('mori');

    expect(CharacterActivityStore.instance.activitiesFor('mori'), isEmpty);
    expect(
      CharacterActivityStore.instance.activitiesFor('other'),
      hasLength(1),
    );
  });
}
