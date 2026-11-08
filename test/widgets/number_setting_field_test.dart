import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/widgets/number_setting_field.dart';

void main() {
  testWidgets('does not duplicate the unlimited hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumberSettingField(
            label: '每日上限',
            value: 1,
            allowUnlimited: true,
            helperText: '负数表示无上限。',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('负数表示无上限。'), findsOneWidget);

    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) {
        continue;
      }
      expect(
        data,
        isNot(contains('负数表示无上限。负数表示无上限。')),
        reason: '辅助文本不应重复追加无上限提示',
      );
    }
  });
}
