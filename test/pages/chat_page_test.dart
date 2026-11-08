import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/pages/chat_page.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ModelStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ModelStore.instance.load();
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
}
