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
    expect(find.textContaining('3 个角色评论'), findsOneWidget);
    expect(find.textContaining('嵌套 2 层'), findsOneWidget);

    await tester.ensureVisible(find.text('恢复默认设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认设置'));
    await tester.pumpAndSettle();

    final settings = MomentInteractionSettingsStore.instance.settings.value;
    expect(settings.autoCommentCount, 2);
    expect(settings.autoReplyDepth, 1);
  });
}
