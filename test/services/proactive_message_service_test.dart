import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';
import 'package:mori_ai/models/proactive_message_state.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_service.dart';
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
