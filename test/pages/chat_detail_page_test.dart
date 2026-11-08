import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_burst_settings.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/pages/character/character_chat_settings_page.dart';
import 'package:mori_ai/pages/character/character_moments_page.dart';
import 'package:mori_ai/pages/chat_detail_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_burst_settings_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/mood_store.dart';
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
    await ChatBurstSettingsStore.instance.load();
    await MoodStore.instance.load();
    await DiaryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await ModelStore.instance.load();
    await MomentStore.instance.load();
    await ProactiveMessageStore.instance.load();
    await ChatBurstSettingsStore.instance.load();
    await MoodStore.instance.load();
    await DiaryStore.instance.load();
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

  testWidgets('sets the per-character burst tendency', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: CharacterChatSettingsPage(
          characterId: CharacterProfile.presetMoriId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('聊天连发倾向'), findsOneWidget);
    await tester.ensureVisible(find.text('积极'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('积极'));
    await tester.pumpAndSettle();

    expect(
      ChatBurstSettingsStore.instance.settings.value.tendencyFor(
        CharacterProfile.presetMoriId,
      ),
      ChatBurstTendency.active,
    );

    await tester.tap(find.text('跟随全局'));
    await tester.pumpAndSettle();
    expect(
      ChatBurstSettingsStore.instance.settings.value.characterTendencies,
      isEmpty,
    );
  });

  testWidgets('shows and resets the character mood', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await MoodStore.instance.nudge(CharacterProfile.presetMoriId, 30, '被夸了');

    await tester.pumpWidget(
      const MaterialApp(
        home: CharacterChatSettingsPage(
          characterId: CharacterProfile.presetMoriId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('心情'), findsOneWidget);
    expect(find.text('超开心'), findsOneWidget);
    expect(find.text('90/100'), findsOneWidget);
    expect(find.textContaining('被夸了'), findsOneWidget);

    await tester.tap(find.byTooltip('重置心情'));
    await tester.pumpAndSettle();

    expect(
      MoodStore.instance.snapshotFor(CharacterProfile.presetMoriId).value,
      60,
    );
    expect(find.text('平平常常'), findsOneWidget);
    expect(find.text('60/100'), findsOneWidget);
  });

  testWidgets('sets per-character diary settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: CharacterChatSettingsPage(
          characterId: CharacterProfile.presetMoriId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日记'), findsOneWidget);
    await tester.ensureVisible(find.text('日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();

    expect(find.text('Mori的日记'), findsOneWidget);
    final followGlobal = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('跟随全局'),
    );
    expect(followGlobal, findsOneWidget);
    expect(find.text('单独设置'), findsOneWidget);

    await tester.tap(find.text('单独设置'));
    await tester.pumpAndSettle();
    expect(
      DiaryStore.instance.settings.value.hasOverride(
        CharacterProfile.presetMoriId,
      ),
      isTrue,
    );
    expect(find.text('每天写日记'), findsOneWidget);

    await tester.tap(find.text('每天写日记'));
    await tester.pumpAndSettle();
    expect(
      DiaryStore.instance.settings.value
          .settingsFor(CharacterProfile.presetMoriId)
          ?.enabled,
      isTrue,
    );

    await tester.tap(followGlobal);
    await tester.pumpAndSettle();
    expect(
      DiaryStore.instance.settings.value.hasOverride(
        CharacterProfile.presetMoriId,
      ),
      isFalse,
    );
  });
}
