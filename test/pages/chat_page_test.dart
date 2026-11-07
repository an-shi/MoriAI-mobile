import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/pages/chat_page.dart';
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
      const MaterialApp(home: Scaffold(body: ChatPage())),
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
}
