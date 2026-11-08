import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/pages/settings/diary_settings_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await DiaryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await DiaryStore.instance.load();
  });

  testWidgets('toggles daily diary and shows the scheduled time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: DiarySettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('启用每日日记'), findsOneWidget);
    expect(find.text('全局默认写作时间'), findsOneWidget);
    expect(find.textContaining('每天 22:30 左右'), findsOneWidget);
    expect(find.text('立即写一篇'), findsOneWidget);
    expect(find.text('角色单独设置'), findsOneWidget);
    expect(find.text('Mori'), findsOneWidget);

    await tester.tap(find.text('启用每日日记'));
    await tester.pumpAndSettle();

    expect(DiaryStore.instance.settings.value.enabled, isTrue);
    expect(find.text('只记录有意义的内容'), findsOneWidget);
  });
}
