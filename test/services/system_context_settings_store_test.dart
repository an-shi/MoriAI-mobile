import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/system_context_settings.dart';
import 'package:mori_ai/services/system_context_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SystemContextSettingsStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await SystemContextSettingsStore.instance.load();
  });

  test('loads defaults and persists', () async {
    expect(
      SystemContextSettingsStore.instance.settings.value.timeAwarenessEnabled,
      isTrue,
    );

    await SystemContextSettingsStore.instance.save(
      const SystemContextSettings(timeAwarenessEnabled: false),
    );
    await SystemContextSettingsStore.instance.load();
    expect(
      SystemContextSettingsStore.instance.settings.value.timeAwarenessEnabled,
      isFalse,
    );
  });

  test('falls back to defaults for corrupted data', () async {
    SharedPreferences.setMockInitialValues({
      'system_context_settings_v1': 'not-json',
    });
    await SystemContextSettingsStore.instance.load();
    expect(
      SystemContextSettingsStore.instance.settings.value.timeAwarenessEnabled,
      isTrue,
    );
  });
}
