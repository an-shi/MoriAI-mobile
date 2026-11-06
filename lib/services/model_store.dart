import 'package:flutter/foundation.dart';
import 'package:mori_ai/config/deepseek_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 管理当前选择的 DeepSeek 模型。
class ModelStore {
  ModelStore._();

  static final ModelStore instance = ModelStore._();

  static const _prefsKey = 'deepseek_model';

  final ValueNotifier<String> model = ValueNotifier<String>(
    DeepSeekConfig.defaultModel,
  );

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_prefsKey);
      model.value = stored != null && DeepSeekConfig.isSupportedModel(stored)
          ? stored
          : DeepSeekConfig.defaultModel;
    } catch (_) {
      model.value = DeepSeekConfig.defaultModel;
    }
  }

  Future<void> save(String id) async {
    if (!DeepSeekConfig.isSupportedModel(id)) {
      throw ArgumentError.value(id, 'id', 'Unsupported DeepSeek model');
    }

    final previous = model.value;
    model.value = id;

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(_prefsKey, id);
      if (!saved) {
        throw StateError('Failed to save model selection');
      }
    } catch (_) {
      model.value = previous;
      rethrow;
    }
  }
}
