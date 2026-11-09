import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/pages/settings/proactive_message_settings_page.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProactiveMessageStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ProactiveMessageStore.instance.load();
  });

  testWidgets('toggles proactive messages and restores defaults', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: ProactiveMessageSettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('自动消息'), findsOneWidget);
    expect(find.text('启用自动消息'), findsOneWidget);
    expect(find.text('本地通知'), findsOneWidget);
    expect(find.text('目的引擎（实验性）'), findsOneWidget);
    expect(find.text('运行诊断'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('22:30'), findsOneWidget);
    expect(ProactiveMessageStore.instance.settings.value.enabled, isFalse);

    await tester.tap(find.text('启用自动消息'));
    await tester.pumpAndSettle();

    expect(ProactiveMessageStore.instance.settings.value.enabled, isTrue);
    expect(
      ProactiveMessageStore.instance.settings.value.notificationsEnabled,
      isTrue,
    );

    await tester.tap(find.text('本地通知'));
    await tester.pumpAndSettle();
    expect(
      ProactiveMessageStore.instance.settings.value.notificationsEnabled,
      isFalse,
    );

    await tester.tap(find.text('目的引擎（实验性）'));
    await tester.pumpAndSettle();
    expect(
      ProactiveMessageStore.instance.settings.value.purposeEnabled,
      isTrue,
    );

    await tester.ensureVisible(find.text('恢复默认设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认设置'));
    await tester.pumpAndSettle();

    expect(ProactiveMessageStore.instance.settings.value.enabled, isFalse);
  });

  testWidgets('saves silence range changes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: ProactiveMessageSettingsPage()),
    );
    await tester.pumpAndSettle();

    final minField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '最短间隔（分钟）',
    );
    final maxField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '最长间隔（分钟）',
    );

    await tester.enterText(minField, '30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(maxField, '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(ProactiveMessageStore.instance.settings.value.silenceMinMinutes, 30);
    expect(ProactiveMessageStore.instance.settings.value.silenceMaxMinutes, 90);
  });

  testWidgets('accepts values above the previous limits', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: ProactiveMessageSettingsPage()),
    );
    await tester.pumpAndSettle();

    final minField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '最短间隔（分钟）',
    );
    final dailyField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '所有单聊每日总上限',
    );
    final unansweredField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '连续未回复上限',
    );

    await tester.enterText(minField, '500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(dailyField, '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(unansweredField, '42');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final settings = ProactiveMessageStore.instance.settings.value;
    expect(settings.silenceMinMinutes, 500);
    expect(settings.silenceMaxMinutes, 500);
    expect(settings.dailyLimit, 999);
    expect(settings.maxUnanswered, 42);
  });
}
