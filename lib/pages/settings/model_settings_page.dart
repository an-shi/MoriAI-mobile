import 'package:flutter/material.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/model_list_service.dart';
import 'package:mori_ai/services/model_store.dart';

class ModelSettingsPage extends StatefulWidget {
  const ModelSettingsPage({super.key});

  @override
  State<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends State<ModelSettingsPage> {
  final _apiKeyController = TextEditingController();
  final _modelListService = ModelListService();

  late String _providerId;
  late String _modelId;
  List<ModelOption> _models = const [];
  String? _modelsError;
  bool _loadingModels = false;
  bool _savingKey = false;
  bool _obscureKey = true;
  int _modelRequestId = 0;

  ModelProvider get _provider =>
      ModelProviderCatalog.byId(_providerId) ??
      ModelProviderCatalog.defaultProvider;

  List<ModelOption> get _modelOptions {
    final options = [..._models];
    if (_modelId.isNotEmpty && !options.any((model) => model.id == _modelId)) {
      options.insert(
        0,
        ModelOption(id: _modelId, name: _modelId, supportsVision: false),
      );
    }
    return options;
  }

  ModelOption? get _selectedModelOption {
    for (final model in _modelOptions) {
      if (model.id == _modelId) {
        return model;
      }
    }
    return null;
  }

  bool get _hasSelectedModelMetadata {
    return _models.any((model) => model.id == _modelId);
  }

  String get _modelHelperText {
    if (_modelsError != null) {
      return _modelsError!;
    }

    if (_models.isEmpty) {
      if (_loadingModels) {
        return '正在从 ${_provider.name} 获取模型列表…';
      }
      return '保存下方 API Key 后会自动获取模型列表，也可以点击刷新。';
    }

    if (_modelId.isNotEmpty && !_hasSelectedModelMetadata) {
      return '当前模型不在返回列表中，无法确认图片能力，请刷新或重新选择模型。';
    }

    final selected = _selectedModelOption;
    if (selected != null) {
      return selected.supportsVision
          ? '支持图片识别，可在对话页发送图片。'
          : '该模型暂不支持图片输入，只能发送文本。';
    }

    return '已获取 ${_models.length} 个模型，列表来自 ${_provider.name} 官方接口。';
  }

  bool get _hasSavedKey =>
      (ApiKeyStore.instance.keyFor(_providerId).value ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    final selection = ModelStore.instance.selection.value;
    _providerId = ModelProviderCatalog.byId(selection.providerId) != null
        ? selection.providerId
        : ModelProviderCatalog.defaultProviderId;
    _modelId = selection.modelId;
    _models = ModelStore.instance.modelsFor(_providerId);
    _apiKeyController.text =
        ApiKeyStore.instance.keyFor(_providerId).value ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _apiKeyController.text.trim().isNotEmpty) {
        _loadModels();
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelListService.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    if (_loadingModels) {
      return;
    }

    final savedKey = (ApiKeyStore.instance.keyFor(_providerId).value ?? '')
        .trim();
    final typedKey = _apiKeyController.text.trim();
    if (savedKey.isEmpty) {
      setState(() {
        _modelsError = '请先保存 ${_provider.name} API Key，再获取模型列表。';
      });
      _showSnackBar('请先保存 API Key');
      return;
    }
    if (typedKey != savedKey) {
      setState(() {
        _modelsError = 'API Key 有改动，请先保存后再获取模型列表。';
      });
      _showSnackBar('请先保存修改后的 API Key');
      return;
    }
    final apiKey = savedKey;

    final requestId = ++_modelRequestId;
    final provider = _provider;

    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });

    try {
      final models = await _modelListService.fetchModels(
        provider: provider,
        apiKey: apiKey,
      );
      await ModelStore.instance.saveModels(provider.id, models);
      if (!mounted || requestId != _modelRequestId) {
        return;
      }
      setState(() {
        _models = models;
      });
    } on ModelListException catch (error) {
      if (!mounted || requestId != _modelRequestId) {
        return;
      }
      setState(() {
        _modelsError = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _modelRequestId) {
        return;
      }
      setState(() {
        _modelsError = '获取模型列表失败，请稍后重试。';
      });
    } finally {
      if (mounted && requestId == _modelRequestId) {
        setState(() => _loadingModels = false);
      }
    }
  }

  Future<void> _changeProvider(String? providerId) async {
    if (providerId == null || providerId == _providerId) {
      return;
    }
    if (ModelProviderCatalog.byId(providerId) == null) {
      return;
    }

    final previousProviderId = _providerId;
    final previousModelId = _modelId;
    final previousKey = _apiKeyController.text;
    final previousModels = _models;
    _modelRequestId++;
    setState(() {
      _providerId = providerId;
      _modelId = '';
      _models = ModelStore.instance.modelsFor(providerId);
      _modelsError = null;
      _loadingModels = false;
      _apiKeyController.text =
          ApiKeyStore.instance.keyFor(providerId).value ?? '';
    });

    try {
      await ModelStore.instance.saveSelection(
        ModelSelection(providerId: providerId, modelId: ''),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _providerId = previousProviderId;
        _modelId = previousModelId;
        _models = previousModels;
        _apiKeyController.text = previousKey;
      });
      _showSnackBar('切换供应商失败，请重试');
      return;
    }

    if (!mounted) {
      return;
    }
    if (_apiKeyController.text.trim().isNotEmpty) {
      await _loadModels();
    }
  }

  Future<void> _changeModel(String? modelId) async {
    if (modelId == null || modelId == _modelId) {
      return;
    }

    final previousModelId = _modelId;
    setState(() => _modelId = modelId);

    try {
      await ModelStore.instance.saveSelection(
        ModelSelection(providerId: _providerId, modelId: modelId),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _modelId = previousModelId);
      _showSnackBar('模型设置保存失败，请重试');
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _showSnackBar('请先输入 API Key');
      return;
    }

    setState(() => _savingKey = true);
    var saved = false;
    try {
      await ApiKeyStore.instance.save(_providerId, key);
      if (!mounted) {
        return;
      }
      _apiKeyController.text = key;
      saved = true;
      _showSnackBar('API Key 已保存');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('保存失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _savingKey = false);
      }
    }

    if (saved && mounted) {
      await _loadModels();
    }
  }

  Future<void> _clearApiKey() async {
    setState(() => _savingKey = true);
    _modelRequestId++;
    try {
      await ApiKeyStore.instance.clear(_providerId);
      if (!mounted) {
        return;
      }
      _apiKeyController.clear();
      setState(() {
        _models = const [];
        _modelsError = null;
        _loadingModels = false;
      });
      _showSnackBar('API Key 已清除');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('清除失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _savingKey = false);
      }
    }
  }

  Future<void> _savePreset() async {
    if (_modelId.trim().isEmpty) {
      _showSnackBar('请先选择一个模型');
      return;
    }

    final name = await _promptPresetName(
      suggested: '${_provider.name} · $_modelId',
    );
    if (name == null || !mounted) {
      return;
    }

    try {
      await ModelStore.instance.savePreset(name: name);
      if (!mounted) {
        return;
      }
      _showSnackBar('预设「$name」已保存');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('保存预设失败，请重试');
    }
  }

  Future<String?> _promptPresetName({required String suggested}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PresetNameDialog(initialName: suggested),
    );
  }

  Future<void> _applyPreset(ModelPreset preset) async {
    final provider = ModelProviderCatalog.byId(preset.selection.providerId);
    if (provider == null) {
      _showSnackBar('该预设的模型供应商已不再支持');
      return;
    }

    try {
      await ModelStore.instance.applyPreset(preset.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('切换预设失败，请重试');
      return;
    }

    if (!mounted) {
      return;
    }

    _modelRequestId++;
    setState(() {
      _providerId = preset.selection.providerId;
      _modelId = preset.selection.modelId;
      _models = ModelStore.instance.modelsFor(_providerId);
      _modelsError = null;
      _loadingModels = false;
      _apiKeyController.text =
          ApiKeyStore.instance.keyFor(_providerId).value ?? '';
    });

    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar('已切换到「${preset.name}」，请配置 ${provider.name} API Key');
    } else {
      _showSnackBar('已切换到「${preset.name}」');
      await _loadModels();
    }
  }

  Future<void> _deletePreset(ModelPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除预设'),
          content: Text('确定删除「${preset.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ModelStore.instance.deletePreset(preset.id);
      if (!mounted) {
        return;
      }
      _showSnackBar('预设已删除');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('删除预设失败，请重试');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('模型')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          ModelStore.instance.presets,
          ModelStore.instance.activePresetId,
        ]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.memory_rounded, color: colors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '模型配置',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const _ActivePresetBadge(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '选择供应商和模型。模型列表会通过供应商官方接口获取。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        key: ValueKey('provider-$_providerId'),
                        initialValue: _providerId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: '模型供应商',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          for (final provider in ModelProviderCatalog.all)
                            DropdownMenuItem<String>(
                              value: provider.id,
                              child: Text(provider.name),
                            ),
                        ],
                        onChanged: _changeProvider,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _provider.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('model-$_providerId-$_modelId'),
                              initialValue: _modelId.isEmpty ? null : _modelId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: '模型',
                                hintText: _loadingModels
                                    ? '正在获取模型列表…'
                                    : '请选择模型',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                for (final model in _modelOptions)
                                  DropdownMenuItem<String>(
                                    value: model.id,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            model.displayName,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (model.supportsVision) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.image_outlined,
                                            size: 16,
                                            color: colors.primary,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: _modelOptions.isEmpty
                                  ? null
                                  : _changeModel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _loadingModels ? null : _loadModels,
                            tooltip: '刷新模型列表',
                            icon: _loadingModels
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _modelHelperText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _modelsError != null
                              ? colors.error
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      Divider(height: 32, color: colors.outlineVariant),
                      Row(
                        children: [
                          Icon(
                            Icons.key_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_provider.name} API Key',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _hasSavedKey
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _hasSavedKey ? '已配置' : '未配置',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _hasSavedKey
                                    ? colors.onPrimaryContainer
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'API Key 仅保存在本机安全存储中。每个供应商的 Key 分开保存，切换模型或预设时无需重新填写。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureKey,
                        autocorrect: false,
                        enableSuggestions: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_savingKey) {
                            _saveApiKey();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText: _provider.apiKeyHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _obscureKey = !_obscureKey);
                            },
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscureKey ? '显示' : '隐藏',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _savingKey ? null : _saveApiKey,
                              child: _savingKey
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('保存 API Key'),
                            ),
                          ),
                          if (_hasSavedKey) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _savingKey ? null : _clearApiKey,
                              child: const Text('清除'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildPresetCard(theme, colors),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetCard(ThemeData theme, ColorScheme colors) {
    final presets = ModelStore.instance.presets.value;
    final activeId = ModelStore.instance.activePresetId.value;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.bookmarks_rounded, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '模型预设',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '把常用的供应商和模型组合保存下来，切换时无需重新填写。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (presets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Center(
                child: Text(
                  '还没有预设',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final preset in presets) ...[
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Icon(
                  preset.id == activeId
                      ? Icons.check_circle_rounded
                      : Icons.bookmark_border_rounded,
                  color: preset.id == activeId
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(preset.name)),
                    if (preset.id == activeId) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '使用中',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${ModelProviderCatalog.byId(preset.selection.providerId)?.name ?? preset.selection.providerId} · ${preset.selection.modelId}',
                ),
                trailing: IconButton(
                  onPressed: () => _deletePreset(preset),
                  tooltip: '删除预设',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                onTap: () => _applyPreset(preset),
              ),
            ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _savePreset,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('保存当前配置为预设'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存为预设'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: '预设名称',
          hintText: '例如：日常聊天',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            return FilledButton(
              onPressed: value.text.trim().isEmpty ? null : _submit,
              child: const Text('保存'),
            );
          },
        ),
      ],
    );
  }
}

class _ActivePresetBadge extends StatelessWidget {
  const _ActivePresetBadge();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ModelStore.instance.presets,
        ModelStore.instance.activePresetId,
      ]),
      builder: (context, _) {
        final activeId = ModelStore.instance.activePresetId.value;
        if (activeId == null) {
          return const SizedBox.shrink();
        }

        ModelPreset? active;
        for (final preset in ModelStore.instance.presets.value) {
          if (preset.id == activeId) {
            active = preset;
            break;
          }
        }
        if (active == null) {
          return const SizedBox.shrink();
        }

        final colors = Theme.of(context).colorScheme;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              active.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.onPrimaryContainer),
            ),
          ),
        );
      },
    );
  }
}
