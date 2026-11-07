import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await UserProfileStore.instance.load();
  });

  test('loads default profile and persists user fields', () async {
    await UserProfileStore.instance.load();
    expect(UserProfileStore.instance.profile.value.displayName, '我');

    await UserProfileStore.instance.save(
      UserProfile(
        name: '小森',
        gender: UserGender.female,
        birthday: DateTime(1998, 5, 20),
        signature: '今天也要开心。',
      ),
    );

    expect(UserProfileStore.instance.profile.value.name, '小森');

    await UserProfileStore.instance.load();
    final profile = UserProfileStore.instance.profile.value;
    expect(profile.name, '小森');
    expect(profile.displayName, '小森');
    expect(profile.gender, UserGender.female);
    expect(profile.birthday, DateTime(1998, 5, 20));
    expect(profile.signature, '今天也要开心。');
  });
}
