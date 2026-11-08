import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/moment_interaction_settings.dart';
import 'package:mori_ai/pages/settings/moment_interaction_settings_page.dart';
import 'package:mori_ai/services/moment_interaction_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MomentInteractionSettingsStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await MomentInteractionSettingsStore.instance.load();
  });

  testWidgets('renders settings and restores defaults', (tester) async {
    await MomentInteractionSettingsStore.instance.save(
      const MomentInteractionSettings(autoCommentCount: 3, autoReplyDepth: 2),
    );

    await tester.pumpWidget(
      const MaterialApp(home: MomentInteractionSettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '动态互动'), findsOneWidget);
    expect(find.textContaining('当前 3 人'), findsOneWidget);
    expect(find.textContaining('当前 2 层'), findsOneWidget);

    await tester.ensureVisible(find.text('恢复默认设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认设置'));
    await tester.pumpAndSettle();

    final settings = MomentInteractionSettingsStore.instance.settings.value;
    expect(settings.autoCommentCount, 2);
    expect(settings.autoReplyDepth, 1);
  });

  testWidgets('accepts values above the previous limits', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MomentInteractionSettingsPage()),
    );
    await tester.pumpAndSettle();

    final countField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '人数',
    );
    final depthField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '层数',
    );

    await tester.enterText(countField, '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(depthField, '42');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final settings = MomentInteractionSettingsStore.instance.settings.value;
    expect(settings.autoCommentCount, 99);
    expect(settings.autoReplyDepth, 42);
  });
}
