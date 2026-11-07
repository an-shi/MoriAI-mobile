import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/main.dart';

void main() {
  testWidgets('bottom navigation switches between pages', (tester) async {
    await tester.pumpWidget(const MoriApp());

    expect(find.text('嗨，我是 Mori'), findsOneWidget);

    await tester.tap(find.text('记忆与人格卡'));
    await tester.pumpAndSettle();
    expect(find.text('还没有记忆'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('模型'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('关于 Mori'), findsOneWidget);
  });

  testWidgets('settings categories open their own pages', (tester) async {
    await tester.pumpWidget(const MoriApp());

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('模型'));
    await tester.pumpAndSettle();
    expect(find.text('模型配置'), findsOneWidget);
    expect(find.text('模型供应商'), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('模型预设'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
  });
}
