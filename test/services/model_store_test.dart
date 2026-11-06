import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/config/deepseek_config.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists and reloads the selected model', () async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() async {
      SharedPreferences.setMockInitialValues({});
      await ModelStore.instance.load();
    });

    await ModelStore.instance.load();
    expect(ModelStore.instance.model.value, DeepSeekConfig.defaultModel);

    await ModelStore.instance.save('deepseek-v4-pro');
    expect(ModelStore.instance.model.value, 'deepseek-v4-pro');

    await ModelStore.instance.load();
    expect(ModelStore.instance.model.value, 'deepseek-v4-pro');
  });

  test('rejects an unsupported model id', () async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() async {
      SharedPreferences.setMockInitialValues({});
      await ModelStore.instance.load();
    });

    await expectLater(
      ModelStore.instance.save('unknown-model'),
      throwsArgumentError,
    );
  });
}
