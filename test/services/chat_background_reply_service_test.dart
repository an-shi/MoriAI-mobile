import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/services/active_conversation_store.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/chat_background_reply_service.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_queue_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/unread_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ModelStore.instance.load();
    await UnreadStore.instance.load();
    await CharacterActivityStore.instance.load();
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
    ApiKeyStore.instance.keyFor(
      ModelProviderCatalog.defaultProviderId,
    ).value = 'test-key';
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    ApiKeyStore.instance.keyFor(
      ModelProviderCatalog.defaultProviderId,
    ).value = null;
    await ModelStore.instance.load();
    await UnreadStore.instance.load();
    await CharacterActivityStore.instance.load();
    ActiveConversationStore.instance.leave(CharacterProfile.presetMoriId);
  });

  test('appends the reply, clears the queue and marks the chat unread', () async {
    final conversationId = CharacterProfile.presetMoriId;
    final user = ChatMessage(
      id: 'user_1',
      role: ChatRole.user,
      content: '你好',
      createdAt: DateTime.now(),
    );
    await ChatHistoryStore.instance.saveFor(conversationId, [user]);
    await ChatQueueStore.instance.saveFor(conversationId, [user.id]);

    final client = MockClient.streaming((_, _) async {
      const sse =
          'data: {"choices":[{"delta":{"content":"第一句"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final chatService = ChatService(client: client);
    addTearDown(chatService.dispose);
    final service = ChatBackgroundReplyService.forTest(
      chatService: chatService,
    );
    final completed = Completer<ChatBackgroundTurnResult>();
    service.lastCompleted.addListener(() {
      final result = service.lastCompleted.value;
      if (result != null && !completed.isCompleted) {
        completed.complete(result);
      }
    });

    service.schedule(
      ChatBackgroundTurnRequest(
        conversationId: conversationId,
        isGroup: false,
        notificationTitle: 'Mori',
        batch: [user],
        roundHistory: [user],
        delay: Duration.zero,
        buildPrompts: () async => [
          ChatBackgroundSpeakerPrompt(
            conversationId: conversationId,
            responder: CharacterProfile.presetMori,
            showSender: false,
            forceBurst: false,
            burstTarget: 0,
            minimum: 0,
            allowAutoSplit: false,
            maxBubbles: 1,
            buildSystemPrompt:
                (
                  history, {
                  bool continuation = false,
                  int alreadySent = 0,
                  int continuationTarget = 0,
                }) => '你是测试助手。',
          ),
        ],
      ),
    );

    final result = await completed.future.timeout(const Duration(seconds: 5));
    expect(result.success, isTrue);
    expect(result.batchIds, [user.id]);

    final history = await ChatHistoryStore.instance.loadFor(conversationId);
    expect(
      history.map((message) => message.content).toList(),
      ['你好', '第一句'],
    );
    expect(await ChatQueueStore.instance.loadFor(conversationId), isEmpty);
    expect(UnreadStore.instance.countFor(conversationId), 1);
  });
}
