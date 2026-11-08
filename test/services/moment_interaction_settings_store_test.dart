import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/moment_interaction_settings.dart';
import 'package:mori_ai/services/moment_interaction_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MomentInteractionSettingsStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await MomentInteractionSettingsStore.instance.load();
  });

  test('loads defaults and persists custom interaction settings', () async {
    final defaults = MomentInteractionSettingsStore.instance.settings.value;
    expect(defaults.autoCommentCount, 2);
    expect(defaults.autoReplyDepth, 1);

    await MomentInteractionSettingsStore.instance.save(
      const MomentInteractionSettings(autoCommentCount: 3, autoReplyDepth: 2),
    );

    await MomentInteractionSettingsStore.instance.load();
    final loaded = MomentInteractionSettingsStore.instance.settings.value;
    expect(loaded.autoCommentCount, 3);
    expect(loaded.autoReplyDepth, 2);
  });

  test('normalizes values outside the supported range', () async {
    final settings = const MomentInteractionSettings(
      autoCommentCount: 99,
      autoReplyDepth: -1,
    ).normalized();

    expect(settings.autoCommentCount, 5);
    expect(settings.autoReplyDepth, 0);
  });
}
