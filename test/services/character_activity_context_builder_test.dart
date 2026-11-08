import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/services/character_activity_context_builder.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterActivityStore.instance.load();
    await CharacterActivityStore.instance.recordAll([
      CharacterActivity(
        id: 'group1',
        characterId: 'mori',
        kind: CharacterActivityKind.groupMessage,
        contextId: 'group_1',
        contextLabel: '摸鱼群',
        content: '老板，饭吃完没',
        createdAtMs: DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      ),
      CharacterActivity(
        id: 'moment1',
        characterId: 'mori',
        kind: CharacterActivityKind.moment,
        contextId: 'moment_1',
        contextLabel: '动态',
        content: '糖吃完了，嘴里还留着甜味儿',
        createdAtMs: DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      ),
      CharacterActivity(
        id: 'private1',
        characterId: 'mori',
        kind: CharacterActivityKind.singleMessage,
        contextId: 'mori',
        contextLabel: '和用户单聊',
        content: '只在单聊里说的话',
        createdAtMs: DateTime.now()
            .subtract(const Duration(hours: 3))
            .millisecondsSinceEpoch,
      ),
      CharacterActivity(
        id: 'other1',
        characterId: 'other',
        kind: CharacterActivityKind.groupMessage,
        contextId: 'group_2',
        contextLabel: '别的群',
        content: '其他角色的群聊',
        createdAtMs: DateTime.now()
            .subtract(const Duration(hours: 4))
            .millisecondsSinceEpoch,
      ),
    ]);
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterActivityStore.instance.load();
  });

  test('private chat can see groups and public moments', () {
    final text = CharacterActivityContextBuilder.instance.buildForPrivateChat(
      'mori',
    );

    expect(text, contains('群「摸鱼群」'));
    expect(text, contains('老板，饭吃完没'));
    expect(text, contains('动态'));
    expect(text, contains('糖吃完了'));
    expect(text, isNot(contains('只在单聊里说的话')));
    expect(text, isNot(contains('其他角色的群聊')));
  });

  test('group chat only sees public moments', () {
    final text = CharacterActivityContextBuilder.instance.buildForGroupChat(
      'mori',
    );

    expect(text, contains('糖吃完了'));
    expect(text, isNot(contains('老板，饭吃完没')));
    expect(text, isNot(contains('只在单聊里说的话')));
    expect(text, isNot(contains('其他角色的群聊')));
  });

  test('proactive messages see groups and public moments', () {
    final text = CharacterActivityContextBuilder.instance.buildForProactive(
      'mori',
    );

    expect(text, contains('摸鱼群'));
    expect(text, contains('糖吃完了'));
    expect(text, isNot(contains('只在单聊里说的话')));
  });

  test('moment generation only sees public activities', () {
    final text = CharacterActivityContextBuilder.instance.buildForMoment(
      'mori',
    );

    expect(text, contains('糖吃完了'));
    expect(text, isNot(contains('摸鱼群')));
    expect(text, isNot(contains('只在单聊里说的话')));
  });
}
