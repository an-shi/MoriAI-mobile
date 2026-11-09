import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/mood.dart';
import 'package:mori_ai/pages/settings/mood_settings_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MoodStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MoodStore.instance.load();
  });

  testWidgets('toggles mood and changes the base', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MoodSettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('启用心情'), findsOneWidget);
    expect(find.text('角色心情'), findsOneWidget);
    expect(find.text('心情基线'), findsOneWidget);
    expect(find.text('使用模型判断心情'), findsOneWidget);

    await tester.tap(find.text('使用模型判断心情'));
    await tester.pumpAndSettle();
    expect(MoodStore.instance.settings.value.modelJudgeEnabled, isTrue);

    await tester.tap(find.text('启用心情'));
    await tester.pumpAndSettle();
    expect(MoodStore.instance.settings.value.enabled, isFalse);

    final baseField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '心情基线',
    );
    await tester.enterText(baseField, '70');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(MoodStore.instance.settings.value.base, 70);
    expect(
      MoodStore.instance.settings.value.halfLifeHours,
      MoodSettings.defaults.halfLifeHours,
    );
  });
}
