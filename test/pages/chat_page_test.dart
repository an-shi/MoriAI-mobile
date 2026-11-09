import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_burst_settings.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/pages/chat_page.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/chat_burst_settings_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ModelStore.instance.load();
    await ChatBurstSettingsStore.instance.load();
    await CharacterActivityStore.instance.load();
    await MoodStore.instance.load();
    await DiaryStore.instance.load();
    await MemoryStore.instance.load();
    ApiKeyStore.instance.keyFor(ModelProviderCatalog.defaultProviderId).value =
        'test-key';
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    ApiKeyStore.instance.keyFor(ModelProviderCatalog.defaultProviderId).value =
        null;
    await ModelStore.instance.load();
    await ChatBurstSettingsStore.instance.load();
    await CharacterActivityStore.instance.load();
    await MoodStore.instance.load();
    await DiaryStore.instance.load();
    await MemoryStore.instance.load();
  });

  testWidgets('shows the image button only for vision-capable models', (
    tester,
  ) async {
    await ModelStore.instance.saveModels('deepseek', const [
      ModelOption(
        id: 'vision-model',
        name: 'Vision Model',
        supportsVision: true,
      ),
      ModelOption(id: 'text-model', name: 'Text Model', supportsVision: false),
    ]);
    await ModelStore.instance.saveSelection(
      const ModelSelection(providerId: 'deepseek', modelId: 'vision-model'),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatPage(characterId: CharacterProfile.presetMoriId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('发送图片'), findsOneWidget);

    await tester.tap(find.byTooltip('发送图片'));
    await tester.pumpAndSettle();
    expect(find.text('照片'), findsOneWidget);
    expect(find.text('拍摄'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await ModelStore.instance.saveSelection(
      const ModelSelection(providerId: 'deepseek', modelId: 'text-model'),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('发送图片'), findsNothing);
  });

  testWidgets('restores persisted chat history for the active character', (
    tester,
  ) async {
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'history_1',
        role: ChatRole.user,
        content: '这是上次的聊天记录',
        createdAt: DateTime(2026, 11, 8, 10, 30),
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatPage(characterId: CharacterProfile.presetMoriId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('这是上次的聊天记录'), findsOneWidget);
    expect(find.text('发消息…'), findsOneWidget);
  });

  testWidgets('appends externally generated messages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatPage(characterId: CharacterProfile.presetMoriId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final message = ChatMessage(
      id: 'external_1',
      role: ChatRole.assistant,
      content: '主动发来的消息',
      createdAt: DateTime(2026, 11, 8, 22),
    );
    ChatHistoryStore.instance.notifyExternalMessages(
      CharacterProfile.presetMoriId,
      [message],
    );
    await tester.pumpAndSettle();

    expect(find.text('主动发来的消息'), findsOneWidget);

    ChatHistoryStore.instance.notifyExternalMessages(
      CharacterProfile.presetMoriId,
      [message],
    );
    await tester.pumpAndSettle();
    expect(find.text('主动发来的消息'), findsOneWidget);
  });

  testWidgets('deletes a single message from the long-press menu', (
    tester,
  ) async {
    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'message_delete',
        role: ChatRole.user,
        content: '准备删除的消息',
        createdAt: DateTime(2026, 11, 8, 10, 30),
      ),
      ChatMessage(
        id: 'message_keep',
        role: ChatRole.assistant,
        content: '保留的消息',
        createdAt: DateTime(2026, 11, 8, 10, 31),
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatPage(characterId: CharacterProfile.presetMoriId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('chat-message-message_delete')),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除消息'), findsOneWidget);

    await tester.tap(find.text('删除消息'));
    await tester.pumpAndSettle();

    expect(find.text('准备删除的消息'), findsNothing);
    expect(find.text('保留的消息'), findsOneWidget);

    final stored = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(stored.map((message) => message.id), ['message_keep']);
  });

  testWidgets('splits a burst reply into multiple bubbles', (tester) async {
    await _prepareBurstTest(tester, '第一句|||第二句|||第三句');
    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsOneWidget);
    expect(find.text('第三句'), findsOneWidget);
    expect(find.textContaining('|||'), findsNothing);

    final stored = await ChatHistoryStore.instance.loadFor(
      CharacterProfile.presetMoriId,
    );
    expect(
      stored
          .where((message) => !message.isUser)
          .map((message) => message.content),
      ['第一句', '第二句', '第三句'],
    );
  });

  testWidgets('splits newline replies into multiple bubbles', (tester) async {
    await _prepareBurstTest(tester, '第一句\n第二句\n第三句');
    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsOneWidget);
    expect(find.text('第三句'), findsOneWidget);
  });

  testWidgets('splits sentence punctuation into multiple bubbles', (
    tester,
  ) async {
    await _prepareBurstTest(tester, '第一句。第二句！第三句？');
    expect(find.text('第一句。'), findsOneWidget);
    expect(find.text('第二句！'), findsOneWidget);
    expect(find.text('第三句？'), findsOneWidget);
  });

  testWidgets('renders streamed burst chunks incrementally', (tester) async {
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

    final client = MockClient.streaming((_, _) async {
      const sse =
          'data: {"choices":[{"delta":{"content":"第一句|||"}}]}\n'
          'data: {"choices":[{"delta":{"content":"第二句|||"}}]}\n'
          'data: {"choices":[{"delta":{"content":"第三句"}}]}\n'
          'data: [DONE]\n';
      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final service = ChatService(client: client);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatPage(
            characterId: CharacterProfile.presetMoriId,
            chatService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '你好');
    await tester.pump();
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsOneWidget);
    expect(find.text('第三句'), findsOneWidget);
    expect(find.textContaining('|||'), findsNothing);
  });

  testWidgets('splits newlines inside a burst segment', (tester) async {
    await _prepareBurstTest(tester, '第一句|||第二句\n第三句');
    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsOneWidget);
    expect(find.text('第三句'), findsOneWidget);
    expect(find.textContaining('第二句\n第三句'), findsNothing);
  });

  testWidgets('injects cross-context activities into private chat prompt', (
    tester,
  ) async {
    final now = DateTime.now();
    await CharacterActivityStore.instance.recordAll([
      CharacterActivity(
        id: 'group_activity',
        characterId: CharacterProfile.presetMoriId,
        kind: CharacterActivityKind.groupMessage,
        contextId: 'group_1',
        contextLabel: '摸鱼群',
        content: '老板，饭吃完没',
        createdAtMs: now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      ),
      CharacterActivity(
        id: 'moment_activity',
        characterId: CharacterProfile.presetMoriId,
        kind: CharacterActivityKind.moment,
        contextId: 'moment_1',
        contextLabel: '动态',
        content: '糖吃完了，嘴里还留着甜味儿',
        createdAtMs: now
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      ),
      CharacterActivity(
        id: 'private_activity',
        characterId: CharacterProfile.presetMoriId,
        kind: CharacterActivityKind.singleMessage,
        contextId: CharacterProfile.presetMoriId,
        contextLabel: '和用户单聊',
        content: '只在单聊里说的话',
        createdAtMs: now
            .subtract(const Duration(hours: 3))
            .millisecondsSinceEpoch,
      ),
    ]);
    final requestBodies = <String>[];
    await _prepareBurstTest(tester, '第一句', requestBodies: requestBodies);

    expect(requestBodies.single, contains('群「摸鱼群」'));
    expect(requestBodies.single, contains('糖吃完了，嘴里还留着甜味儿'));
    expect(requestBodies.single, isNot(contains('只在单聊里说的话')));
  });

  testWidgets('off tendency keeps punctuation text in one bubble', (
    tester,
  ) async {
    await ChatBurstSettingsStore.instance.setGlobalTendency(
      ChatBurstTendency.off,
    );
    await _prepareBurstTest(tester, '第一句。第二句。第三句。');
    expect(find.text('第一句。第二句。第三句。'), findsOneWidget);
  });

  testWidgets('off tendency flattens newlines instead of keeping them', (
    tester,
  ) async {
    await ChatBurstSettingsStore.instance.setGlobalTendency(
      ChatBurstTendency.off,
    );
    await _prepareBurstTest(tester, '第一句\n第二句\n第三句');
    expect(find.text('第一句，第二句，第三句'), findsOneWidget);
    expect(find.textContaining('第一句\n第二句'), findsNothing);
  });

  testWidgets('active tendency adds the positive burst instruction', (
    tester,
  ) async {
    await ChatBurstSettingsStore.instance.setGlobalTendency(
      ChatBurstTendency.active,
    );
    final requestBodies = <String>[];
    await _prepareBurstTest(tester, '第一句|||第二句', requestBodies: requestBodies);
    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsOneWidget);
    expect(requestBodies.single, contains('连发倾向：积极'));
  });

  testWidgets('injects mood context into chat prompt', (tester) async {
    await MoodStore.instance.nudge(CharacterProfile.presetMoriId, 30, '被用户夸了');
    final requestBodies = <String>[];
    await _prepareBurstTest(tester, '第一句', requestBodies: requestBodies);

    expect(requestBodies.single, contains('你现在超开心'));
    expect(requestBodies.single, contains('被用户夸了'));
  });

  testWidgets('injects relevant long-term memories into chat prompt', (
    tester,
  ) async {
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
    final requestBodies = <String>[];
    await _prepareBurstTest(
      tester,
      '第一句',
      userText: '我想喝点热牛奶',
      requestBodies: requestBodies,
    );

    expect(requestBodies.single, contains('用户喜欢在睡前喝热牛奶'));
    expect(requestBodies.single, contains('长期记得'));
  });

  testWidgets('injects recent diary context into chat prompt', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await DiaryStore.instance.saveEntry(
      DiaryEntry(
        id: 'diary_mori_${diaryDateKey(yesterday)}',
        characterId: CharacterProfile.presetMoriId,
        dateKey: diaryDateKey(yesterday),
        content: '昨天和用户一起看了很晚的电影。',
        createdAtMs: yesterday.millisecondsSinceEpoch,
        moodLabel: '心情不错',
      ),
    );
    final requestBodies = <String>[];
    await _prepareBurstTest(tester, '第一句', requestBodies: requestBodies);

    expect(requestBodies.single, contains('最近写过的私人日记'));
    expect(requestBodies.single, contains('昨天和用户一起看了很晚的电影。'));
    expect(requestBodies.single, contains('心情不错'));
  });

  testWidgets('observes mood changes from the user message', (tester) async {
    await _prepareBurstTest(tester, '第一句', userText: '喜欢你，真棒，厉害，可爱');

    final mood = MoodStore.instance.snapshotFor(CharacterProfile.presetMoriId);
    expect(mood.value, greaterThan(70));
    expect(mood.label, anyOf('心情不错', '超开心'));
  });

  testWidgets('forces comma split when the user asks for multiple messages', (
    tester,
  ) async {
    final requestBodies = <String>[];
    await _prepareBurstTest(
      tester,
      '第一句，第二句，第三句',
      userText: '多发几条',
      requestBodies: requestBodies,
    );
    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsOneWidget);
    expect(find.text('第三句'), findsOneWidget);
    expect(requestBodies, hasLength(1));
    expect(requestBodies.single, contains('本轮连发要求'));
    expect(requestBodies.single, contains('3 条'));
  });

  testWidgets('parses a JSON burst reply', (tester) async {
    final requestBodies = <String>[];
    await _prepareBurstTest(
      tester,
      jsonEncode(['第一句', '第二句', '第三句']),
      userText: '发三条',
      requestBodies: requestBodies,
    );
    expect(find.text('第一句'), findsOneWidget);
    expect(find.text('第二句'), findsOneWidget);
    expect(find.text('第三句'), findsOneWidget);
    expect(requestBodies.single, contains('JSON 字符串数组'));
  });

  testWidgets(
    'continues when the model returns fewer messages than requested',
    (tester) async {
      await _prepareBurstTest(
        tester,
        '',
        userText: '发三条',
        contents: [
          jsonEncode(['第一句', '第二句']),
          '第三句',
        ],
        waitRounds: 4,
      );
      expect(find.text('第一句'), findsOneWidget);
      expect(find.text('第二句'), findsOneWidget);
      expect(find.text('第三句'), findsOneWidget);
    },
  );

  testWidgets('uses the requested burst count in the system prompt', (
    tester,
  ) async {
    final requestBodies = <String>[];
    await _prepareBurstTest(
      tester,
      '第一句|||第二句',
      userText: '你要发两条给我',
      requestBodies: requestBodies,
    );
    expect(requestBodies.single, contains('2 条消息'));
  });

  testWidgets('treats 一条条说 as a burst request', (tester) async {
    final requestBodies = <String>[];
    await _prepareBurstTest(
      tester,
      '第一句|||第二句|||第三句',
      userText: '一条条说',
      requestBodies: requestBodies,
    );
    expect(requestBodies.single, contains('3 条消息'));
  });
}

Future<void> _prepareBurstTest(
  WidgetTester tester,
  String content, {
  String userText = '你好',
  List<String>? requestBodies,
  List<String>? contents,
  int waitRounds = 1,
}) async {
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

  var requestIndex = 0;
  final client = MockClient.streaming((request, bodyStream) async {
    requestBodies?.add(utf8.decode(await bodyStream.toBytes()));
    final responseContent = contents != null && requestIndex < contents.length
        ? contents[requestIndex]
        : content;
    requestIndex++;
    final sse =
        'data: {"choices":[{"delta":{"content":${jsonEncode(responseContent)}}}]}\n'
        'data: [DONE]\n';
    return http.StreamedResponse(
      Stream.value(utf8.encode(sse)),
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  });
  final service = ChatService(client: client);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatPage(
          characterId: CharacterProfile.presetMoriId,
          chatService: service,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), userText);
  await tester.pump();
  await tester.tap(find.byTooltip('发送'));
  await tester.pump();
  for (var round = 0; round < waitRounds; round++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    for (var index = 0; index < 50; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}
