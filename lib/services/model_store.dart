import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 管理当前模型选择以及用户保存的模型预设。
class ModelStore {
  ModelStore._();

  static final ModelStore instance = ModelStore._();

  static const _providerKey = 'llm_provider';
  static const _modelKey = 'llm_model';
  static const _presetsKey = 'llm_presets';
  static const _activePresetKey = 'llm_active_preset';
  static const _modelCatalogKey = 'llm_model_catalog';
  static const _legacyModelKey = 'deepseek_model';

  final ValueNotifier<ModelSelection> selection = ValueNotifier<ModelSelection>(
    ModelSelection.empty,
  );

  final ValueNotifier<List<ModelPreset>> presets =
      ValueNotifier<List<ModelPreset>>(const []);

  /// 当前正在使用的预设 id；手动修改供应商或模型后会被清空。
  final ValueNotifier<String?> activePresetId = ValueNotifier<String?>(null);

  /// 按供应商缓存的模型列表，包含模型是否支持图片识别等能力信息。
  final ValueNotifier<Map<String, List<ModelOption>>> modelCatalog =
      ValueNotifier<Map<String, List<ModelOption>>>(const {});

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final providerId = _validProviderId(preferences.getString(_providerKey));

      var modelId = preferences.getString(_modelKey)?.trim() ?? '';
      if (modelId.isEmpty &&
          providerId == ModelProviderCatalog.defaultProviderId) {
        // 兼容旧版本保存的 DeepSeek 模型选择。
        modelId = preferences.getString(_legacyModelKey)?.trim() ?? '';
      }

      selection.value = ModelSelection(
        providerId: providerId,
        modelId: modelId,
      );

      final loadedPresets = _decodePresets(preferences.getString(_presetsKey));
      presets.value = List<ModelPreset>.unmodifiable(loadedPresets);

      final storedActiveId = preferences.getString(_activePresetKey);
      activePresetId.value =
          storedActiveId != null &&
              loadedPresets.any((preset) => preset.id == storedActiveId)
          ? storedActiveId
          : null;

      modelCatalog.value = _decodeModelCatalog(
        preferences.getString(_modelCatalogKey),
      );
    } catch (_) {
      selection.value = ModelSelection.empty;
      presets.value = const [];
      activePresetId.value = null;
      modelCatalog.value = const {};
    }
  }

  List<ModelOption> modelsFor(String providerId) {
    return modelCatalog.value[providerId] ?? const [];
  }

  ModelOption? modelFor(ModelSelection selection) {
    for (final model in modelsFor(selection.providerId)) {
      if (model.id == selection.modelId) {
        return model;
      }
    }
    return null;
  }

  bool supportsVision(ModelSelection selection) {
    return modelFor(selection)?.supportsVision ?? false;
  }

  /// 缓存某个供应商的模型列表。缓存失败不影响本次会话使用。
  Future<void> saveModels(String providerId, List<ModelOption> models) async {
    if (ModelProviderCatalog.byId(providerId) == null) {
      throw ArgumentError.value(
        providerId,
        'providerId',
        'Unsupported model provider',
      );
    }

    final nextCatalog = Map<String, List<ModelOption>>.unmodifiable({
      ...modelCatalog.value,
      providerId: List<ModelOption>.unmodifiable(models),
    });
    modelCatalog.value = nextCatalog;

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _modelCatalogKey,
        jsonEncode({
          for (final entry in nextCatalog.entries)
            entry.key: [for (final model in entry.value) model.toJson()],
        }),
      );
    } catch (_) {
      // 仅作为能力缓存，持久化失败时保留内存中的数据。
    }
  }

  /// 保存当前选择。`activePresetId` 为空时表示用户进行了手动配置。
  Future<void> saveSelection(
    ModelSelection next, {
    String? activePresetId,
  }) async {
    final normalized = ModelSelection(
      providerId: next.providerId,
      modelId: next.modelId.trim(),
    );
    if (ModelProviderCatalog.byId(normalized.providerId) == null) {
      throw ArgumentError.value(
        normalized.providerId,
        'providerId',
        'Unsupported model provider',
      );
    }

    await _persistSelection(normalized, activePresetId: activePresetId);
  }

  Future<void> applyPreset(String presetId) async {
    ModelPreset? preset;
    for (final item in presets.value) {
      if (item.id == presetId) {
        preset = item;
        break;
      }
    }

    if (preset == null) {
      throw StateError('Preset not found');
    }
    if (ModelProviderCatalog.byId(preset.selection.providerId) == null) {
      throw StateError('Preset provider is no longer supported');
    }

    await _persistSelection(preset.selection, activePresetId: preset.id);
  }

  Future<ModelPreset> savePreset({required String name}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Preset name cannot be empty');
    }

    final current = selection.value;
    if (!current.hasModel) {
      throw StateError('Select a model before saving a preset');
    }
    if (ModelProviderCatalog.byId(current.providerId) == null) {
      throw StateError('Unsupported model provider');
    }

    final preset = ModelPreset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmedName,
      selection: current,
    );
    final nextPresets = [
      ...presets.value.where((item) => item.name != trimmedName),
      preset,
    ];

    await _persistPresets(nextPresets, activePresetId: preset.id);
    return preset;
  }

  Future<void> deletePreset(String presetId) async {
    final nextPresets = presets.value
        .where((preset) => preset.id != presetId)
        .toList(growable: false);
    if (nextPresets.length == presets.value.length) {
      return;
    }

    final nextActiveId = activePresetId.value == presetId
        ? null
        : activePresetId.value;
    await _persistPresets(nextPresets, activePresetId: nextActiveId);
  }

  Future<void> _persistSelection(
    ModelSelection next, {
    required String? activePresetId,
  }) async {
    final previousSelection = selection.value;
    final previousActiveId = this.activePresetId.value;

    selection.value = next;
    this.activePresetId.value = activePresetId;

    try {
      final preferences = await SharedPreferences.getInstance();
      var saved = await preferences.setString(_providerKey, next.providerId);
      saved = await preferences.setString(_modelKey, next.modelId) && saved;

      if (activePresetId == null) {
        saved = await preferences.remove(_activePresetKey) && saved;
      } else {
        saved =
            await preferences.setString(_activePresetKey, activePresetId) &&
            saved;
      }

      if (!saved) {
        throw StateError('Failed to save model selection');
      }
    } catch (_) {
      selection.value = previousSelection;
      this.activePresetId.value = previousActiveId;
      rethrow;
    }
  }

  Future<void> _persistPresets(
    List<ModelPreset> nextPresets, {
    required String? activePresetId,
  }) async {
    final previousPresets = presets.value;
    final previousActiveId = this.activePresetId.value;
    final immutablePresets = List<ModelPreset>.unmodifiable(nextPresets);

    presets.value = immutablePresets;
    this.activePresetId.value = activePresetId;

    try {
      final preferences = await SharedPreferences.getInstance();
      var saved = await preferences.setString(
        _presetsKey,
        jsonEncode([for (final preset in immutablePresets) preset.toJson()]),
      );

      if (activePresetId == null) {
        saved = await preferences.remove(_activePresetKey) && saved;
      } else {
        saved =
            await preferences.setString(_activePresetKey, activePresetId) &&
            saved;
      }

      if (!saved) {
        throw StateError('Failed to save model presets');
      }
    } catch (_) {
      presets.value = previousPresets;
      this.activePresetId.value = previousActiveId;
      rethrow;
    }
  }

  List<ModelPreset> _decodePresets(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final result = <ModelPreset>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        try {
          final preset = ModelPreset.fromJson(Map<String, dynamic>.from(item));
          if (ModelProviderCatalog.byId(preset.selection.providerId) != null &&
              preset.selection.hasModel) {
            result.add(preset);
          }
        } on FormatException {
          // 跳过损坏的预设，不影响其他数据。
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  Map<String, List<ModelOption>> _decodeModelCatalog(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const {};
      }

      final result = <String, List<ModelOption>>{};
      for (final entry in decoded.entries) {
        final providerId = entry.key;
        if (providerId is! String ||
            ModelProviderCatalog.byId(providerId) == null ||
            entry.value is! List) {
          continue;
        }

        final modelsById = <String, ModelOption>{};
        for (final item in entry.value as List) {
          if (item is! Map) {
            continue;
          }

          try {
            final model = ModelOption.fromJson(Map<String, dynamic>.from(item));
            modelsById[model.id] = model;
          } on FormatException {
            // 跳过损坏的模型缓存。
          }
        }

        if (modelsById.isNotEmpty) {
          final models = modelsById.values.toList()
            ..sort((a, b) => a.id.compareTo(b.id));
          result[providerId] = List<ModelOption>.unmodifiable(models);
        }
      }
      return Map<String, List<ModelOption>>.unmodifiable(result);
    } catch (_) {
      return const {};
    }
  }

  String _validProviderId(String? stored) {
    if (stored != null && ModelProviderCatalog.byId(stored) != null) {
      return stored;
    }
    return ModelProviderCatalog.defaultProviderId;
  }
}
