import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/pages/character/character_chat_settings_page.dart';
import 'package:mori_ai/pages/character/character_moments_page.dart';
import 'package:mori_ai/pages/chat_detail_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await ModelStore.instance.load();
    await MomentStore.instance.load();
    await ProactiveMessageStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await ModelStore.instance.load();
    await MomentStore.instance.load();
    await ProactiveMessageStore.instance.load();
  });

  testWidgets('opens the character card editor from the character page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatDetailPage(characterId: CharacterProfile.presetMoriId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('聊天设置'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Mori'), findsOneWidget);
    expect(find.text('动态'), findsOneWidget);
    expect(find.text('角色卡设置'), findsOneWidget);

    await tester.tap(find.text('角色卡设置'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '编辑角色卡'), findsOneWidget);
  });

  testWidgets('opens the character moments page from the character page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatDetailPage(characterId: CharacterProfile.presetMoriId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('聊天设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动态'));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterMomentsPage), findsOneWidget);
    expect(find.text('最新动态'), findsOneWidget);
    expect(find.text('还没有动态'), findsOneWidget);
  });

  testWidgets("character moments page only shows that character's moments", (
    tester,
  ) async {
    MomentStore.instance.moments.value = [
      Moment(
        id: 'mori_moment',
        authorId: CharacterProfile.presetMoriId,
        authorName: 'Mori',
        isUser: false,
        content: 'Mori 的动态',
        createdAt: DateTime(2026, 11, 8, 12),
      ),
      Moment(
        id: 'user_moment',
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '用户的动态',
        createdAt: DateTime(2026, 11, 8, 13),
      ),
    ];
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatDetailPage(characterId: CharacterProfile.presetMoriId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('聊天设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动态'));
    await tester.pumpAndSettle();

    expect(find.text('Mori 的动态'), findsOneWidget);
    expect(find.text('用户的动态'), findsNothing);
  });

  testWidgets('deletes the chat history from the character settings page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await ChatHistoryStore.instance.saveFor(CharacterProfile.presetMoriId, [
      ChatMessage(
        id: 'history_delete',
        role: ChatRole.user,
        content: '准备删除的聊天记录',
        createdAt: DateTime(2026, 11, 8, 10),
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatDetailPage(characterId: CharacterProfile.presetMoriId),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('准备删除的聊天记录'), findsOneWidget);

    await tester.tap(find.byTooltip('聊天设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('删除聊天记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除聊天记录'));
    await tester.pumpAndSettle();

    expect(find.text('确定删除该角色的全部聊天记录吗？删除后无法恢复。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(
      await ChatHistoryStore.instance.loadFor(CharacterProfile.presetMoriId),
      isEmpty,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('准备删除的聊天记录'), findsNothing);
  });

  testWidgets('toggles proactive messages for a single character', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: CharacterChatSettingsPage(
          characterId: CharacterProfile.presetMoriId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('允许主动消息'), findsOneWidget);
    await tester.ensureVisible(find.text('允许主动消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('允许主动消息'));
    await tester.pumpAndSettle();

    final state = await ProactiveMessageStore.instance.loadState(
      CharacterProfile.presetMoriId,
    );
    expect(state?.enabled, isFalse);
  });
}
