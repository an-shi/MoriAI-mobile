import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/group_memory.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/group_memory_store.dart';
import 'package:mori_ai/services/memory_context_builder.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MemoryStore.instance.load();
    await GroupMemoryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await MemoryStore.instance.load();
    await GroupMemoryStore.instance.load();
  });

  Future<void> save(String id, String text, {double importance = 0.6}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MemoryStore.instance.saveEntry(
      MemoryEntry(
        id: id,
        characterId: 'mori',
        text: text,
        importance: importance,
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
  }

  test('recalls relevant private memories', () async {
    await save('milk', '用户喜欢睡前喝热牛奶', importance: 0.8);
    await save('city', '用户住在杭州', importance: 0.4);

    final context = MemoryContextBuilder.instance.buildForPrivateChat(
      'mori',
      query: '牛奶',
    );
    expect(context, contains('热牛奶'));
    expect(context, contains('长期记得'));
  });

  test('injects the profile and open topics', () async {
    await save('milk', '用户喜欢睡前喝热牛奶');
    await MemoryStore.instance.saveProfile(
      MemoryProfile(
        characterId: 'mori',
        summary: '用户是住在杭州的设计师，和 Mori 是朋友。',
        preferences: '喜欢安静的音乐。',
        recentFocus: '最近在准备换工作。',
        importantDates: const ['12 月 24 日约好一起看电影'],
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await MemoryStore.instance.saveOpenTopic(
      MemoryOpenTopic(
        id: 'topic_1',
        characterId: 'mori',
        text: '用户下周要去看牙医，还没告诉我结果。',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    final context = MemoryContextBuilder.instance.buildForPrivateChat('mori');
    expect(context, contains('人物小档案'));
    expect(context, contains('设计师'));
    expect(context, contains('安静的音乐'));
    expect(context, contains('换工作'));
    expect(context, contains('看电影'));
    expect(context, contains('还没结果的事'));
    expect(context, contains('牙医'));
  });

  test('does not inject the profile into group chat', () async {
    await MemoryStore.instance.saveProfile(
      MemoryProfile(
        characterId: 'mori',
        summary: '用户是住在杭州的设计师。',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    expect(MemoryContextBuilder.instance.buildForGroupChat('mori'), isEmpty);
  });

  test('does not inject private memories into group chat', () async {
    await save('milk', '用户喜欢睡前喝热牛奶');
    expect(
      MemoryContextBuilder.instance.buildForGroupChat('mori', query: '牛奶'),
      isEmpty,
    );
  });

  test(
    'injects only the matching group public memory and impression',
    () async {
      await save('milk', '用户喜欢睡前喝热牛奶');
      final now = DateTime.now().millisecondsSinceEpoch;
      await GroupMemoryStore.instance.saveProfile(
        GroupMemoryProfile(
          groupId: 'group_a',
          summary: '大家像宿舍室友一样熟。',
          sharedHabits: '经常互相发梗图。',
          recentFocus: '最近在约看展。',
          updatedAtMs: now,
        ),
      );
      await GroupMemoryStore.instance.saveEntry(
        GroupMemoryEntry(
          id: 'gmem_a',
          groupId: 'group_a',
          text: '大家约好下个月一起去看展。',
          category: MemoryCategory.plan,
          importance: 0.8,
          createdAtMs: now,
          updatedAtMs: now,
        ),
      );
      await GroupMemoryStore.instance.saveEntry(
        GroupMemoryEntry(
          id: 'gmem_b',
          groupId: 'group_b',
          text: '另一个群一起去看了电影。',
          createdAtMs: now,
          updatedAtMs: now,
        ),
      );

      final context = MemoryContextBuilder.instance.buildForGroupChat(
        'group_a',
        query: '看展',
      );
      expect(context, contains('群印象'));
      expect(context, contains('宿舍室友'));
      expect(context, contains('梗图'));
      expect(context, contains('一起去看展'));
      expect(context, isNot(contains('热牛奶')));
      expect(context, isNot(contains('另一个群')));
    },
  );

  test('returns empty group context when group memory is disabled', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await GroupMemoryStore.instance.saveEntry(
      GroupMemoryEntry(
        id: 'gmem_a',
        groupId: 'group_a',
        text: '大家约好一起去看展。',
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    await MemoryStore.instance.saveSettings(
      const MemorySettings(groupMemoryEnabled: false),
    );
    expect(MemoryContextBuilder.instance.buildForGroupChat('group_a'), isEmpty);
  });

  test('returns empty when memory or recall is disabled', () async {
    await save('milk', '用户喜欢睡前喝热牛奶');
    await MemoryStore.instance.saveSettings(
      const MemorySettings(enabled: false),
    );
    expect(
      MemoryContextBuilder.instance.buildForPrivateChat('mori', query: '牛奶'),
      isEmpty,
    );

    await MemoryStore.instance.saveSettings(
      const MemorySettings(enabled: true, recallCount: 0),
    );
    expect(
      MemoryContextBuilder.instance.buildForPrivateChat('mori', query: '牛奶'),
      isEmpty,
    );
  });

  test('falls back to important memories for an empty query', () async {
    await save('low', '用户偶尔看电影', importance: 0.2);
    await save('high', '用户非常重视家人', importance: 0.95);
    final context = MemoryContextBuilder.instance.buildForPrivateChat('mori');
    expect(context, contains('非常重视家人'));
  });
}
