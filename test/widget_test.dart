import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/main.dart';

void main() {
  testWidgets('bottom navigation switches between pages', (tester) async {
    await tester.pumpWidget(const MoriApp());

    expect(find.text('嗨，我是 Mori'), findsOneWidget);

    await tester.tap(find.text('记忆'));
    await tester.pumpAndSettle();
    expect(find.text('还没有记忆'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('DeepSeek API'), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('对话模型'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('关于 Mori'), findsOneWidget);
  });
}
