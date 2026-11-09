import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/group_memory.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/group_memory_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GroupMemoryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await GroupMemoryStore.instance.load();
  });

  test('saves and restores group memories, impressions and state', () async {
    await GroupMemoryStore.instance.saveProfile(
      GroupMemoryProfile(
        groupId: 'group_1',
        summary: '大家像大学宿舍室友一样熟。',
        sharedHabits: '经常互相发梗图和深夜吐槽。',
        recentFocus: '最近在约一起看展。',
        importantDates: const ['下个月第一个周末去看展'],
        updatedAtMs: 3000,
      ),
    );
    await GroupMemoryStore.instance.saveEntry(
      GroupMemoryEntry(
        id: 'gmem_1',
        groupId: 'group_1',
        text: '大家约好下个月一起去看展。',
        category: MemoryCategory.plan,
        importance: 0.8,
        tags: const ['看展'],
        createdAtMs: 1000,
        updatedAtMs: 2000,
      ),
    );
    await GroupMemoryStore.instance.saveState(
      'group_1',
      const MemoryExtractionState(
        lastProcessedMessageId: 'msg_10',
        lastProcessedAtMs: 2500,
      ),
    );

    await GroupMemoryStore.instance.load();

    final profile = GroupMemoryStore.instance.profileFor('group_1');
    expect(profile.summary, contains('宿舍室友'));
    expect(profile.sharedHabits, contains('梗图'));
    expect(profile.recentFocus, contains('看展'));
    expect(profile.importantDates.single, contains('第一个周末'));

    final entries = GroupMemoryStore.instance.entriesFor('group_1');
    expect(entries, hasLength(1));
    expect(entries.single.text, contains('看展'));
    expect(entries.single.category, MemoryCategory.plan);
    expect(
      GroupMemoryStore.instance.stateFor('group_1').lastProcessedMessageId,
      'msg_10',
    );
  });

  test('scopes memories by group and clears one group', () async {
    await GroupMemoryStore.instance.saveEntry(
      GroupMemoryEntry(
        id: 'gmem_a',
        groupId: 'group_a',
        text: 'A 群一起吃过火锅。',
        createdAtMs: 1000,
        updatedAtMs: 1000,
      ),
    );
    await GroupMemoryStore.instance.saveEntry(
      GroupMemoryEntry(
        id: 'gmem_b',
        groupId: 'group_b',
        text: 'B 群一起看过电影。',
        createdAtMs: 1000,
        updatedAtMs: 1000,
      ),
    );

    expect(GroupMemoryStore.instance.entriesFor('group_a'), hasLength(1));
    expect(GroupMemoryStore.instance.entriesFor('group_b'), hasLength(1));

    await GroupMemoryStore.instance.clearForGroup('group_a');
    expect(GroupMemoryStore.instance.entriesFor('group_a'), isEmpty);
    expect(GroupMemoryStore.instance.entriesFor('group_b'), hasLength(1));
  });

  test('archives and touches group memories', () async {
    await GroupMemoryStore.instance.saveEntry(
      GroupMemoryEntry(
        id: 'gmem_1',
        groupId: 'group_1',
        text: '大家约好周末一起吃饭。',
        createdAtMs: 1000,
        updatedAtMs: 1000,
      ),
    );

    await GroupMemoryStore.instance.touch(['gmem_1']);
    final touched = GroupMemoryStore.instance.entriesFor('group_1').single;
    expect(touched.accessCount, 1);
    expect(touched.lastAccessedAtMs, greaterThan(0));

    await GroupMemoryStore.instance.archiveEntry('gmem_1', archivedAtMs: 2000);
    expect(GroupMemoryStore.instance.entriesFor('group_1'), isEmpty);
    expect(
      GroupMemoryStore.instance
          .entriesFor('group_1', includeArchived: true)
          .single
          .isActive,
      isFalse,
    );
  });

  test('skips corrupted group memory data', () async {
    SharedPreferences.setMockInitialValues({
      'group_memory_v1': jsonEncode([
        {
          'id': 'good',
          'groupId': 'group_1',
          'text': '有效记忆',
          'createdAtMs': 1000,
        },
        {'id': 'bad', 'groupId': 'group_1', 'text': '', 'createdAtMs': 1000},
      ]),
      'group_memory_profile_v1': 'not-json',
    });
    await GroupMemoryStore.instance.load();

    expect(GroupMemoryStore.instance.entriesFor('group_1'), hasLength(1));
    expect(GroupMemoryStore.instance.profileFor('group_1').isEmpty, isTrue);
  });
}
