import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/pages/profile/personal_settings_page.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserProfileStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await UserProfileStore.instance.load();
  });

  Finder fieldWithLabel(String label) {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
  }

  testWidgets('updates name, gender and signature', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: PersonalSettingsPage()));
    await tester.pumpAndSettle();

    await tester.enterText(fieldWithLabel('名称'), '小森');
    await tester.enterText(fieldWithLabel('个性签名'), '今天也要开心。');
    await tester.tap(find.byType(DropdownButtonFormField<UserGender>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('女').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存个人信息'));
    await tester.pumpAndSettle();

    final profile = UserProfileStore.instance.profile.value;
    expect(profile.name, '小森');
    expect(profile.gender, UserGender.female);
    expect(profile.signature, '今天也要开心。');
    expect(find.text('个人信息已保存'), findsOneWidget);
  });
}
