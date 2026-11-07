import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/pages/chat_detail_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await ModelStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await ModelStore.instance.load();
  });

  testWidgets('opens the character card editor from chat settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ChatDetailPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('聊天设置'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '聊天设置'), findsOneWidget);
    expect(find.text('角色卡设置'), findsOneWidget);

    await tester.tap(find.text('角色卡设置'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '编辑角色卡'), findsOneWidget);
  });
}
