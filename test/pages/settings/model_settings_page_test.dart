import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/pages/settings/model_settings_page.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preset dialog handles clearing and closing its input', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    await ModelStore.instance.load();
    await ModelStore.instance.saveSelection(
      const ModelSelection(providerId: 'deepseek', modelId: 'deepseek-chat'),
    );

    await tester.pumpWidget(const MaterialApp(home: ModelSettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存当前配置为预设'));
    await tester.pumpAndSettle();
    expect(find.text('保存为预设'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('保存为预设'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
    );
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('保存当前配置为预设'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(ModelStore.instance.presets.value, hasLength(1));
  });
}
