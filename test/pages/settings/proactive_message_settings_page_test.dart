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
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('22:30'), findsOneWidget);
    expect(ProactiveMessageStore.instance.settings.value.enabled, isFalse);

    await tester.tap(find.text('启用自动消息'));
    await tester.pumpAndSettle();

    expect(ProactiveMessageStore.instance.settings.value.enabled, isTrue);

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

    final rangeSlider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    rangeSlider.onChanged?.call(const RangeValues(30, 90));
    await tester.pumpAndSettle();
    rangeSlider.onChangeEnd?.call(const RangeValues(30, 90));
    await tester.pumpAndSettle();

    expect(ProactiveMessageStore.instance.settings.value.silenceMinMinutes, 30);
    expect(ProactiveMessageStore.instance.settings.value.silenceMaxMinutes, 90);
  });
}
