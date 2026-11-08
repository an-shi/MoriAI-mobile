import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/memory_extractor.dart';
import 'package:mori_ai/services/memory_service.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MemoryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MemoryStore.instance.load();
    await ChatHistoryStore.instance.deleteForCard(
      CharacterProfile.presetMoriId,
    );
  });

  Future<void> seedMessages(DateTime now, {int count = 10}) {
    return ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      for (var index = 0; index < count; index++)
        ChatMessage(
          id: 'msg_$index',
          role: index.isEven ? ChatRole.user : ChatRole.assistant,
          content: index.isEven ? '这是第 $index 条值得记住的聊天内容' : '我记住了第 $index 条内容',
          createdAt: now.subtract(Duration(minutes: 30 - index)),
        ),
    ]);
  }

  test('extracts memories after the conversation has been idle', () async {
    final now = DateTime(2026, 11, 8, 22);
    await seedMessages(now);
    await MemoryStore.instance.saveSettings(
      const MemorySettings(
        enabled: true,
        autoExtract: true,
        extractIdleMinutes: 10,
        extractMinMessages: 8,
      ),
    );
    var calls = 0;
    final service = MemoryService.test(
      extractor: MemoryExtractor(
        complete: ({required systemPrompt, required userPrompt}) async {
          calls++;
          return '[{"text":"用户喜欢在晚上喝热牛奶","category":"preference","importance":0.7,"tags":["牛奶"]}]';
        },
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();
    expect(calls, 1);
    final entries = MemoryStore.instance.entriesFor(
      CharacterProfile.presetMoriId,
    );
    expect(entries, hasLength(1));
    expect(entries.single.text, contains('热牛奶'));
    expect(
      MemoryStore.instance
          .stateFor(CharacterProfile.presetMoriId)
          .lastProcessedMessageId,
      'msg_9',
    );

    await service.runCheckForTest();
    expect(calls, 1);
  });

  test('waits for idle time and enough messages', () async {
    final now = DateTime(2026, 11, 8, 22);
    await seedMessages(now, count: 3);
    await MemoryStore.instance.saveSettings(
      const MemorySettings(
        enabled: true,
        autoExtract: true,
        extractIdleMinutes: 10,
        extractMinMessages: 8,
      ),
    );
    var calls = 0;
    final service = MemoryService.test(
      extractor: MemoryExtractor(
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

    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      for (var index = 0; index < 10; index++)
        ChatMessage(
          id: 'recent_$index',
          role: index.isEven ? ChatRole.user : ChatRole.assistant,
          content: '最近的聊天 $index',
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
    ]);
    await service.runCheckForTest();
    expect(calls, 0);
  });

  test('manual extraction ignores idle time', () async {
    final now = DateTime(2026, 11, 8, 22);
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'manual_u',
        role: ChatRole.user,
        content: '我下个月准备去旅行',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      ChatMessage(
        id: 'manual_a',
        role: ChatRole.assistant,
        content: '听起来不错，想去哪里',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
    final service = MemoryService.test(
      extractor: MemoryExtractor(
        complete: ({required systemPrompt, required userPrompt}) async => '[{"text":"用户下个月准备去旅行","category":"plan","importance":0.8,"tags":["旅行"]}]',
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    final count = await service.extractNow(CharacterProfile.presetMoriId);
    expect(count, 1);
    expect(
      MemoryStore.instance
          .entriesFor(CharacterProfile.presetMoriId)
          .single
          .category,
      MemoryCategory.plan,
    );
  });

  test('merges a similar existing memory instead of duplicating it', () async {
    final now = DateTime(2026, 11, 8, 22);
    await MemoryStore.instance.saveEntry(
      MemoryEntry(
        id: 'old',
        characterId: CharacterProfile.presetMoriId,
        text: '用户喜欢在晚上喝热牛奶',
        importance: 0.5,
        tags: const ['牛奶'],
        createdAtMs: now.millisecondsSinceEpoch - 1000,
        updatedAtMs: now.millisecondsSinceEpoch - 1000,
      ),
    );
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'merge_u',
        role: ChatRole.user,
        content: '我每天晚上都要喝热牛奶',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      ChatMessage(
        id: 'merge_a',
        role: ChatRole.assistant,
        content: '睡前喝牛奶挺好',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
    final service = MemoryService.test(
      extractor: MemoryExtractor(
        complete: ({required systemPrompt, required userPrompt}) async => '[{"text":"用户喜欢晚上喝热牛奶","category":"preference","importance":0.9,"tags":["睡前"]}]',
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.extractNow(CharacterProfile.presetMoriId);
    final entries = MemoryStore.instance.entriesFor(
      CharacterProfile.presetMoriId,
    );
    expect(entries, hasLength(1));
    expect(entries.single.id, 'old');
    expect(entries.single.importance, 0.9);
    expect(entries.single.tags, containsAll(['牛奶', '睡前']));
  });

  test('retries after a failed extraction', () async {
    var now = DateTime(2026, 11, 8, 22);
    await seedMessages(now);
    await MemoryStore.instance.saveSettings(
      const MemorySettings(
        enabled: true,
        autoExtract: true,
        extractIdleMinutes: 10,
        extractMinMessages: 8,
      ),
    );
    var shouldFail = true;
    var calls = 0;
    final service = MemoryService.test(
      extractor: MemoryExtractor(
        complete: ({required systemPrompt, required userPrompt}) async {
          calls++;
          if (shouldFail) {
            throw const MemoryException('模型暂时不可用');
          }
          return '[{"text":"用户喜欢热牛奶","category":"preference","importance":0.7}]';
        },
      ),
      now: () => now,
    );
    addTearDown(service.stop);

    await service.runCheckForTest();
    expect(calls, 1);
    final failedState = MemoryStore.instance.stateFor(
      CharacterProfile.presetMoriId,
    );
    expect(failedState.lastError, '模型暂时不可用');
    expect(failedState.lastProcessedMessageId, isEmpty);
    expect(failedState.nextRetryAtMs, greaterThan(now.millisecondsSinceEpoch));

    shouldFail = false;
    await service.runCheckForTest();
    expect(calls, 1);

    now = now.add(const Duration(minutes: 31));
    await service.runCheckForTest();
    expect(calls, 2);
    expect(
      MemoryStore.instance.entriesFor(CharacterProfile.presetMoriId),
      hasLength(1),
    );
  });
}
