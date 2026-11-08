import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';
import 'package:mori_ai/models/proactive_message_state.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/proactive_message_service.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await ModelStore.instance.load();
    await ProactiveMessageStore.instance.load();
    await CharacterActivityStore.instance.load();
    await MemoryStore.instance.load();
    await ModelStore.instance.saveModels(
      ModelProviderCatalog.defaultProviderId,
      const [
        ModelOption(
          id: 'deepseek-chat',
          name: 'DeepSeek Chat',
          supportsVision: false,
        ),
      ],
    );
    await ModelStore.instance.saveSelection(
      const ModelSelection(
        providerId: ModelProviderCatalog.defaultProviderId,
        modelId: 'deepseek-chat',
      ),
    );
    ApiKeyStore.instance.keyFor(ModelProviderCatalog.defaultProviderId).value =
        'test-key';
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    ApiKeyStore.instance.keyFor(ModelProviderCatalog.defaultProviderId).value =
        null;
    await CharacterStore.instance.load();
    await ModelStore.instance.load();
    await ProactiveMessageStore.instance.load();
    await CharacterActivityStore.instance.load();
    await MemoryStore.instance.load();
  });

  test('manual trigger appends cleaned proactive bubbles', () async {
    late String requestBody;
    final client = MockClient.streaming((request, bodyStream) async {
      requestBody = utf8.decode(await bodyStream.toBytes());
      const sse =
          'data: {"choices":[{"delta":{"content":"Mori：晚上好呀"}}]}\n'
          'data: {"choices":[{"delta":{"content":"\\n今天也要早点睡"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: Random(1),
    );

    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_1',
        role: ChatRole.user,
        content: '今天好累。',
        createdAt: DateTime(2026, 11, 8, 21),
      ),
      ChatMessage(
        id: 'assistant_1',
        role: ChatRole.assistant,
        content: '那就早点休息。',
        createdAt: DateTime(2026, 11, 8, 21, 1),
      ),
    ]);

    await service.triggerNow(CharacterProfile.presetMoriId);

    final history = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(history, hasLength(4));
    expect(history[2].isUser, isFalse);
    expect(history[2].content, '晚上好呀');
    expect(history[3].content, '今天也要早点睡');
    expect(requestBody, contains('主动消息模式'));
    expect(requestBody, contains('内部提醒'));
    expect(requestBody, contains('今天好累。'));

    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.lastProactiveAtMs, greaterThan(0));
  });

  test('manual trigger injects relevant memories', () async {
    late String requestBody;
    final client = MockClient.streaming((request, bodyStream) async {
      requestBody = utf8.decode(await bodyStream.toBytes());
      const sse =
          'data: {"choices":[{"delta":{"content":"晚上好呀"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: Random(1),
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await MemoryStore.instance.saveEntry(
      MemoryEntry(
        id: 'milk',
        characterId: CharacterProfile.presetMoriId,
        text: '用户喜欢在睡前喝热牛奶',
        category: MemoryCategory.preference,
        importance: 0.8,
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_memory',
        role: ChatRole.user,
        content: '我最近喜欢喝热牛奶。',
        createdAt: DateTime(2026, 11, 8, 21),
      ),
    ]);

    await service.triggerNow(CharacterProfile.presetMoriId);

    expect(requestBody, contains('用户喜欢在睡前喝热牛奶'));
    expect(requestBody, contains('长期记得'));
  });

  test('manual trigger reports missing model configuration', () async {
    await ModelStore.instance.saveSelection(
      const ModelSelection(
        providerId: ModelProviderCatalog.defaultProviderId,
        modelId: '',
      ),
    );
    final chatService = ChatService(
      client: MockClient.streaming((_, _) async {
        return http.StreamedResponse(const Stream.empty(), 200);
      }),
    );
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: Random(1),
    );

    await expectLater(
      service.triggerNow(CharacterProfile.presetMoriId),
      throwsA(isA<ProactiveMessageException>()),
    );
  });

  test('silence marker does not append a message', () async {
    final client = MockClient.streaming((_, _) async {
      const sse =
          'data: {"choices":[{"delta":{"content":"[沉默]"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_silence',
        role: ChatRole.user,
        content: '今天好累。',
        createdAt: DateTime(2026, 11, 8, 21),
      ),
    ]);
    await service.triggerNow(CharacterProfile.presetMoriId);

    final history = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(history, hasLength(1));

    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.lastProactiveAtMs, 0);
    expect(state?.dailyCount, 0);
  });

  test('questions without replies trigger one gentle nudge', () async {
    final now = DateTime.now();
    final client = MockClient.streaming((request, bodyStream) async {
      final body = utf8.decode(await bodyStream.toBytes());
      expect(body, contains('没有回复'));
      const sse =
          'data: {"choices":[{"delta":{"content":"人呢？"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      const ProactiveMessageSettings(
        enabled: true,
        silenceEnabled: true,
        scheduledEnabled: false,
        nudgeEnabled: true,
      ),
    );
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_nudge',
        role: ChatRole.user,
        content: '我先去忙了。',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: 'assistant_question',
        role: ChatRole.assistant,
        content: '你今晚会早点睡吗？',
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
    ]);
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      ProactiveMessageState(
        lastActivityAtMs: now
            .subtract(const Duration(minutes: 20))
            .millisecondsSinceEpoch,
        nextSilenceAtMs: now
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        lastUserMessageAtMs: now
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch,
        lastAssistantAtMs: now
            .subtract(const Duration(minutes: 20))
            .millisecondsSinceEpoch,
        lastAssistantMessageId: 'assistant_question',
        lastAssistantText: '你今晚会早点睡吗？',
        dailyDate: _dateKey(now),
      ),
    );

    await service.runCheckForTest();

    final history = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(history, hasLength(3));
    expect(history.last.content, '人呢？');

    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.nudgedMessageId, 'assistant_question');
    expect(state?.dailyCount, 0);
    expect(state?.unansweredCount, 0);
  });

  test('per-character switch blocks automatic triggers', () async {
    final now = DateTime.now();
    final client = MockClient.streaming((_, _) async {
      fail('disabled character should not call the model');
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      const ProactiveMessageSettings(enabled: true),
    );
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_disabled',
        role: ChatRole.user,
        content: '先这样。',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      ProactiveMessageState(
        enabled: false,
        nextSilenceAtMs: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        lastActivityAtMs: now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        dailyDate: _dateKey(now),
      ),
    );

    await service.runCheckForTest();

    final history = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(history, hasLength(1));
  });

  test('scheduled greeting fires and marks the slot', () async {
    final now = DateTime.now();
    final scheduledTime = ProactiveMessageSettings.formatTimeOfDay(
      now.hour * 60 + now.minute,
    );
    final client = MockClient.streaming((_, _) async {
      const sse =
          'data: {"choices":[{"delta":{"content":"早上好。"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      ProactiveMessageSettings(
        enabled: true,
        silenceEnabled: false,
        scheduledEnabled: true,
        quietHoursEnabled: false,
        scheduledTimes: [scheduledTime],
      ),
    );
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_scheduled',
        role: ChatRole.user,
        content: '明天见。',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      ProactiveMessageState(
        lastActivityAtMs: now
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        nextSilenceAtMs: now
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        dailyDate: _dateKey(now),
      ),
    );

    await service.runCheckForTest();

    final history = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(history, hasLength(2));
    expect(history.last.content, '早上好。');

    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.firedSlots, contains('${_dateKey(now)}|$scheduledTime'));
  });

  test('scheduled greeting waits when the chat has no history', () async {
    final now = DateTime.now();
    final scheduledTime = ProactiveMessageSettings.formatTimeOfDay(
      now.hour * 60 + now.minute,
    );
    final client = MockClient.streaming((_, _) async {
      fail('a chat without history should not call the model');
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      ProactiveMessageSettings(
        enabled: true,
        silenceEnabled: false,
        scheduledEnabled: true,
        quietHoursEnabled: false,
        scheduledTimes: [scheduledTime],
      ),
    );
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      ProactiveMessageState(
        lastActivityAtMs: now
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        nextSilenceAtMs: now
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        dailyDate: _dateKey(now),
      ),
    );

    await service.runCheckForTest();

    expect(
      await ChatHistoryStore.instance.loadFor(CharacterProfile.presetMoriId),
      isEmpty,
    );
    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.firedSlots, isEmpty);
  });

  test('scheduled greeting bypasses the character cooldown', () async {
    final now = DateTime.now();
    final scheduledTime = ProactiveMessageSettings.formatTimeOfDay(
      now.hour * 60 + now.minute,
    );
    var calls = 0;
    final client = MockClient.streaming((_, _) async {
      calls++;
      const sse =
          'data: {"choices":[{"delta":{"content":"晚上好。"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      ProactiveMessageSettings(
        enabled: true,
        silenceEnabled: false,
        scheduledEnabled: true,
        quietHoursEnabled: false,
        scheduledTimes: [scheduledTime],
      ),
    );
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_scheduled_cooldown',
        role: ChatRole.user,
        content: '等会儿聊。',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      ProactiveMessageState(
        lastActivityAtMs: now
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        nextSilenceAtMs: now
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        dailyDate: _dateKey(now),
      ),
    );

    // 手动触发成功后，该角色进入 5 分钟冷却。
    await service.triggerNow(CharacterProfile.presetMoriId);
    expect(calls, 1);

    final diagnostics = await service.diagnose();
    expect(diagnostics.conversations.single.cooldownRemaining, isNotNull);
    expect(diagnostics.conversations.single.reason, contains('不受角色冷却限制'));

    await service.runCheckForTest();

    expect(calls, 2);
    final history = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(history.last.content, '晚上好。');
    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.firedSlots, contains('${_dateKey(now)}|$scheduledTime'));
  });

  test('silence trigger still respects the character cooldown', () async {
    final now = DateTime.now();
    var calls = 0;
    final client = MockClient.streaming((_, _) async {
      calls++;
      const sse =
          'data: {"choices":[{"delta":{"content":"晚上好。"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      const ProactiveMessageSettings(
        enabled: true,
        silenceEnabled: true,
        scheduledEnabled: false,
        nudgeEnabled: false,
        quietHoursEnabled: false,
      ),
    );
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_silence_cooldown',
        role: ChatRole.user,
        content: '先这样。',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      ProactiveMessageState(
        lastActivityAtMs: now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        nextSilenceAtMs: now
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        dailyDate: _dateKey(now),
      ),
    );

    await service.triggerNow(CharacterProfile.presetMoriId);
    expect(calls, 1);

    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      state!.copyWith(
        nextSilenceAtMs: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      ),
    );

    final diagnostics = await service.diagnose();
    expect(diagnostics.conversations.single.reason, '该角色刚触发过，冷却中');
    expect(diagnostics.conversations.single.cooldownRemaining, isNotNull);

    await service.runCheckForTest();

    expect(calls, 1);
    final history = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(history, hasLength(2));
  });

  test('nudge trigger still respects the character cooldown', () async {
    final now = DateTime.now();
    var calls = 0;
    final client = MockClient.streaming((_, _) async {
      calls++;
      const sse =
          'data: {"choices":[{"delta":{"content":"晚上好。"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      const ProactiveMessageSettings(
        enabled: true,
        silenceEnabled: false,
        scheduledEnabled: false,
        nudgeEnabled: true,
        quietHoursEnabled: false,
      ),
    );
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'user_nudge_cooldown',
        role: ChatRole.user,
        content: '我先去忙了。',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: 'assistant_question_cooldown',
        role: ChatRole.assistant,
        content: '你今晚会早点睡吗？',
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
    ]);
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      ProactiveMessageState(
        lastActivityAtMs: now
            .subtract(const Duration(minutes: 20))
            .millisecondsSinceEpoch,
        nextSilenceAtMs: now
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        lastUserMessageAtMs: now
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch,
        lastAssistantAtMs: now
            .subtract(const Duration(minutes: 20))
            .millisecondsSinceEpoch,
        lastAssistantMessageId: 'assistant_question_cooldown',
        lastAssistantText: '你今晚会早点睡吗？',
        dailyDate: _dateKey(now),
      ),
    );

    await service.triggerNow(CharacterProfile.presetMoriId);
    expect(calls, 1);

    await service.runCheckForTest();

    expect(calls, 1);
    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.nudgedMessageId, isEmpty);
  });

  test('one character cooldown does not block another character', () async {
    final now = DateTime.now();
    final second = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    var calls = 0;
    final client = MockClient.streaming((_, _) async {
      calls++;
      const sse =
          'data: {"choices":[{"delta":{"content":"晚上好。"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ProactiveMessageService.test(
      chatService: chatService,
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      const ProactiveMessageSettings(
        enabled: true,
        silenceEnabled: true,
        scheduledEnabled: false,
        nudgeEnabled: false,
        quietHoursEnabled: false,
      ),
    );
    for (final card in [CharacterProfile.presetMori, second]) {
      await ChatHistoryStore.instance.saveFor(card.id, [
        ChatMessage(
          id: 'user_${card.id}',
          role: ChatRole.user,
          content: '晚上好。',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ]);
    }
    await ProactiveMessageStore.instance.saveState(
      CharacterProfile.presetMoriId,
      ProactiveMessageState(
        nextSilenceAtMs: now
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        dailyDate: _dateKey(now),
      ),
    );
    await ProactiveMessageStore.instance.saveState(
      second.id,
      ProactiveMessageState(
        lastActivityAtMs: now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        nextSilenceAtMs: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        dailyDate: _dateKey(now),
      ),
    );

    await service.triggerNow(CharacterProfile.presetMoriId);
    expect(calls, 1);

    final diagnostics = await service.diagnose();
    final byName = {
      for (final item in diagnostics.conversations) item.characterName: item,
    };
    expect(byName['Mori']?.reason, '该角色刚触发过，冷却中');
    expect(byName['小森']?.reason, '条件已满足，可以触发');

    await service.runCheckForTest();

    expect(calls, 2);
    expect(await ChatHistoryStore.instance.loadFor(second.id), hasLength(2));
  });

  test('per-character negative daily limit is stored as unlimited', () async {
    final service = ProactiveMessageService.test(
      chatService: ChatService(
        client: MockClient.streaming((_, _) async {
          fail('config update should not call the model');
        }),
      ),
      random: _AlwaysZeroRandom(),
    );

    await service.updateConversationConfig(
      CharacterProfile.presetMoriId,
      dailyLimit: -3,
    );

    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.dailyLimit, ProactiveMessageSettings.unlimited);
  });

  test('diagnostics explains why a character is skipped', () async {
    final service = ProactiveMessageService.test(
      chatService: ChatService(
        client: MockClient.streaming((_, _) async {
          return http.StreamedResponse(const Stream.empty(), 200);
        }),
      ),
      random: _AlwaysZeroRandom(),
    );

    await ProactiveMessageStore.instance.saveSettings(
      const ProactiveMessageSettings(
        enabled: true,
        silenceEnabled: false,
        scheduledEnabled: false,
      ),
    );

    final diagnostics = await service.diagnose();
    expect(diagnostics.modelConfigured, isTrue);
    expect(diagnostics.conversations.single.reason, '该角色还没有聊天记录');
  });
}

String _dateKey(DateTime time) {
  return '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';
}

class _AlwaysZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
