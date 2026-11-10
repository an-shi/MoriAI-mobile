import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_burst_settings.dart';
import 'package:mori_ai/pages/settings/chat_settings_page.dart';
import 'package:mori_ai/services/chat_burst_settings_store.dart';
import 'package:mori_ai/services/system_context_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatBurstSettingsStore.instance.load();
    await SystemContextSettingsStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatBurstSettingsStore.instance.load();
    await SystemContextSettingsStore.instance.load();
  });

  testWidgets('changes the global burst tendency and range', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ChatSettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('连发倾向'), findsOneWidget);
    expect(find.text('条数与字数范围'), findsOneWidget);
    expect(find.text('让角色知道当前时间'), findsOneWidget);
    expect(
      SystemContextSettingsStore.instance.settings.value.timeAwarenessEnabled,
      isTrue,
    );

    await tester.tap(find.text('让角色知道当前时间'));
    await tester.pumpAndSettle();
    expect(
      SystemContextSettingsStore.instance.settings.value.timeAwarenessEnabled,
      isFalse,
    );
    expect(
      ChatBurstSettingsStore.instance.settings.value.globalTendency,
      ChatBurstTendency.natural,
    );

    await tester.tap(find.text('积极'));
    await tester.pumpAndSettle();

    expect(
      ChatBurstSettingsStore.instance.settings.value.globalTendency,
      ChatBurstTendency.active,
    );

    final maxMessagesField = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == '最多条数',
        )
        .last;
    await tester.ensureVisible(maxMessagesField);
    await tester.pumpAndSettle();
    await tester.enterText(maxMessagesField, '6');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final range = ChatBurstSettingsStore.instance.settings.value.rangeFor(
      ChatBurstTendency.active,
    );
    expect(range.maxMessages, 6);
  });
}
