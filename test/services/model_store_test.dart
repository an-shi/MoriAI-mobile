import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ModelStore.instance.load();
  });

  test('defaults to DeepSeek without a model', () async {
    await ModelStore.instance.load();

    expect(
      ModelStore.instance.selection.value.providerId,
      ModelProviderCatalog.defaultProviderId,
    );
    expect(ModelStore.instance.selection.value.modelId, isEmpty);
  });

  test('persists and reloads the selected provider and model', () async {
    await ModelStore.instance.load();

    await ModelStore.instance.saveSelection(
      const ModelSelection(providerId: 'deepseek', modelId: 'deepseek-chat'),
    );
    expect(
      ModelStore.instance.selection.value,
      const ModelSelection(providerId: 'deepseek', modelId: 'deepseek-chat'),
    );

    await ModelStore.instance.load();
    expect(
      ModelStore.instance.selection.value,
      const ModelSelection(providerId: 'deepseek', modelId: 'deepseek-chat'),
    );
  });

  test('saves, applies, and deletes model presets', () async {
    await ModelStore.instance.load();
    await ModelStore.instance.saveSelection(
      const ModelSelection(providerId: 'deepseek', modelId: 'deepseek-chat'),
    );

    final preset = await ModelStore.instance.savePreset(name: '日常聊天');
    expect(ModelStore.instance.presets.value, hasLength(1));
    expect(ModelStore.instance.activePresetId.value, preset.id);

    await ModelStore.instance.saveSelection(
      const ModelSelection(
        providerId: 'deepseek',
        modelId: 'deepseek-reasoner',
      ),
    );
    expect(ModelStore.instance.activePresetId.value, isNull);

    await ModelStore.instance.applyPreset(preset.id);
    expect(ModelStore.instance.selection.value.modelId, 'deepseek-chat');
    expect(ModelStore.instance.activePresetId.value, preset.id);

    await ModelStore.instance.load();
    expect(ModelStore.instance.presets.value, hasLength(1));
    expect(ModelStore.instance.activePresetId.value, preset.id);
    expect(ModelStore.instance.selection.value.modelId, 'deepseek-chat');

    await ModelStore.instance.deletePreset(preset.id);
    expect(ModelStore.instance.presets.value, isEmpty);
    expect(ModelStore.instance.activePresetId.value, isNull);
    expect(ModelStore.instance.selection.value.modelId, 'deepseek-chat');
  });

  test('migrates the legacy DeepSeek model selection', () async {
    SharedPreferences.setMockInitialValues({
      'deepseek_model': 'deepseek-reasoner',
    });

    await ModelStore.instance.load();

    expect(
      ModelStore.instance.selection.value.providerId,
      ModelProviderCatalog.defaultProviderId,
    );
    expect(ModelStore.instance.selection.value.modelId, 'deepseek-reasoner');
  });

  test('caches model lists and detects vision capability', () async {
    await ModelStore.instance.load();
    await ModelStore.instance.saveModels('deepseek', const [
      ModelOption(
        id: 'vision-model',
        name: 'Vision Model',
        supportsVision: true,
      ),
      ModelOption(id: 'text-model', name: 'Text Model', supportsVision: false),
    ]);

    const visionSelection = ModelSelection(
      providerId: 'deepseek',
      modelId: 'vision-model',
    );
    const textSelection = ModelSelection(
      providerId: 'deepseek',
      modelId: 'text-model',
    );
    expect(ModelStore.instance.modelsFor('deepseek'), hasLength(2));
    expect(ModelStore.instance.supportsVision(visionSelection), isTrue);
    expect(ModelStore.instance.supportsVision(textSelection), isFalse);

    await ModelStore.instance.load();
    expect(
      ModelStore.instance
          .modelsFor('deepseek')
          .firstWhere((model) => model.id == 'vision-model')
          .name,
      'Vision Model',
    );
    expect(ModelStore.instance.supportsVision(visionSelection), isTrue);
  });

  test('rejects an unsupported provider', () async {
    await expectLater(
      ModelStore.instance.saveSelection(
        const ModelSelection(providerId: 'unknown', modelId: 'some-model'),
      ),
      throwsArgumentError,
    );
  });
}
