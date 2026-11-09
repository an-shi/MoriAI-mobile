import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/group_memory_extractor.dart';
import 'package:mori_ai/services/group_memory_service.dart';
import 'package:mori_ai/services/group_memory_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await GroupMemoryStore.instance.load();
    await MemoryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await GroupMemoryStore.instance.load();
    await MemoryStore.instance.load();
  });

  Future<void> seedGroupMessages(String groupId, DateTime now) {
    return ChatHistoryStore.instance.saveFor(groupId, [
      for (var index = 0; index < 10; index++)
        ChatMessage(
          id: 'gmsg_$index',
          role: index.isEven ? ChatRole.user : ChatRole.assistant,
          content: index.isEven
              ? '这是第 $index 条群聊内容，大家约好一起去看展。'
              : '我记住了第 $index 条群聊内容。',
          senderId: index.isEven ? 'user' : CharacterProfile.presetMoriId,
          senderName: index.isEven ? '用户' : 'Mori',
          createdAt: now.subtract(Duration(minutes: 30 - index)),
        ),
    ]);
  }

  test('extracts group memories after the group has been idle', () async {
    final second = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final group = await GroupStore.instance.createGroup(
      name: '测试群聊',
      memberIds: [CharacterProfile.presetMoriId, second.id],
    );
    final now = DateTime(2026, 11, 8, 22);
    await seedGroupMessages(group.id, now);
    await MemoryStore.instance.saveSettings(
      const MemorySettings(
        enabled: true,
        groupMemoryEnabled: true,
        autoExtract: true,
        extractIdleMinutes: 10,
        extractMinMessages: 8,
      ),
    );
    var calls = 0;
    final service = GroupMemoryService.test(
      extractor: GroupMemoryExtractor(
        complete: ({required systemPrompt, required userPrompt}) async {
          calls++;
          return '''
{
  "memories": [
    {"text":"大家约好下个月一起去看展","category":"plan","importance":0.8,"tags":["看展"]}
  ],
  "profile": {
    "summary": "大家像朋友一样熟。",
    "sharedHabits": "经常一起聊周末安排。",
    "recentFocus": "最近在约看展。",
    "importantDates": ["下个月第一个周末去看展"]
  }
}
''';
        },
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();

    expect(calls, 1);
    final entries = GroupMemoryStore.instance.entriesFor(group.id);
    expect(entries, hasLength(1));
    expect(entries.single.text, contains('看展'));
    expect(
      GroupMemoryStore.instance.profileFor(group.id).summary,
      contains('朋友'),
    );
    expect(
      GroupMemoryStore.instance.stateFor(group.id).lastProcessedMessageId,
      'gmsg_9',
    );

    await service.runCheckForTest();
    expect(calls, 1);
  });

  test('does not extract group memories when disabled', () async {
    final second = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final group = await GroupStore.instance.createGroup(
      name: '测试群聊',
      memberIds: [CharacterProfile.presetMoriId, second.id],
    );
    final now = DateTime(2026, 11, 8, 22);
    await seedGroupMessages(group.id, now);
    await MemoryStore.instance.saveSettings(
      const MemorySettings(
        enabled: true,
        groupMemoryEnabled: false,
        autoExtract: true,
        extractIdleMinutes: 10,
        extractMinMessages: 8,
      ),
    );
    var calls = 0;
    final service = GroupMemoryService.test(
      extractor: GroupMemoryExtractor(
        complete: ({required systemPrompt, required userPrompt}) async {
          calls++;
          return '[]';
        },
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();
    expect(calls, 0);
    expect(GroupMemoryStore.instance.entriesFor(group.id), isEmpty);
  });

  test('manual extraction ignores idle time', () async {
    final second = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final group = await GroupStore.instance.createGroup(
      name: '测试群聊',
      memberIds: [CharacterProfile.presetMoriId, second.id],
    );
    final now = DateTime(2026, 11, 8, 22);
    await ChatHistoryStore.instance.saveFor(group.id, [
      ChatMessage(
        id: 'manual_g1',
        role: ChatRole.user,
        content: '大家周末一起吃饭吧。',
        senderId: 'user',
        senderName: '用户',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      ChatMessage(
        id: 'manual_g2',
        role: ChatRole.assistant,
        content: '好呀，我来订位置。',
        senderId: CharacterProfile.presetMoriId,
        senderName: 'Mori',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
    final service = GroupMemoryService.test(
      extractor: GroupMemoryExtractor(
        complete: ({required systemPrompt, required userPrompt}) async =>
            '[{"text":"大家约好周末一起吃饭","category":"plan","importance":0.7}]',
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    final count = await service.extractNow(group.id);
    expect(count, 1);
    expect(GroupMemoryStore.instance.entriesFor(group.id), hasLength(1));
  });
}
