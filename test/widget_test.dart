import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/main.dart';
import 'package:mori_ai/services/moribot/mori_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MoriSessionStore.instance.snapshot.value =
        const MoriSessionSnapshot.unpaired();
  });

  testWidgets('unpaired app shows the MoriBot pairing page', (tester) async {
    await tester.pumpWidget(const MoriApp());
    await tester.pumpAndSettle();

    expect(find.text('连接 MoriBot'), findsWidgets);
    expect(find.byKey(const Key('pairing-server-field')), findsOneWidget);
    expect(find.byKey(const Key('pairing-code-field')), findsOneWidget);
    expect(find.byKey(const Key('pairing-device-field')), findsOneWidget);
    expect(find.byKey(const Key('pairing-submit-button')), findsOneWidget);
  });

  testWidgets('pairing form validates the short code', (tester) async {
    await tester.pumpWidget(const MoriApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('pairing-server-field')),
      'http://127.0.0.1:6186',
    );
    await tester.enterText(find.byKey(const Key('pairing-code-field')), 'ABC');
    await tester.tap(find.byKey(const Key('pairing-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('配对码应为 8 位字母或数字'), findsOneWidget);
  });
}
