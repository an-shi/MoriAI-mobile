import 'package:flutter/material.dart';
import 'package:mori_ai/services/api_key_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiKeyController;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: ApiKeyStore.instance.apiKey.value ?? '',
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _showSnackBar('请先输入 API Key');
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiKeyStore.instance.save(key);
      if (!mounted) {
        return;
      }
      _apiKeyController.text = key;
      _showSnackBar('API Key 已保存');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('保存失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _clearApiKey() async {
    setState(() => _saving = true);
    try {
      await ApiKeyStore.instance.clear();
      if (!mounted) {
        return;
      }
      _apiKeyController.clear();
      _showSnackBar('API Key 已清除');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('清除失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
    final hasKey = ApiKeyStore.instance.apiKey.value?.isNotEmpty ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
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
                    Icon(Icons.key_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DeepSeek API',
                        style: theme.textTheme.titleMedium?.copyWith(
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
                        color: hasKey
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasKey ? '已配置' : '未配置',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasKey
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'API Key 仅保存在本机安全存储中，用于直连 DeepSeek 官方 API。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_saving) {
                      _saveApiKey();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
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
                        onPressed: _saving ? null : _saveApiKey,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('保存'),
                      ),
                    ),
                    if (hasKey) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _saving ? null : _clearApiKey,
                        child: const Text('清除'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '修改后下一条消息立即生效',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.palette_outlined),
                title: Text('外观'),
                subtitle: Text('跟随系统'),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('关于 Mori'),
                subtitle: Text('版本 1.0.0'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
