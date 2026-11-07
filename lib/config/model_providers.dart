/// 一个大模型供应商的接入信息。
///
/// 目前所有供应商都按 OpenAI 兼容协议接入：通过 `/models` 获取模型列表，
/// 通过 `/chat/completions` 发起流式对话。
class ModelProvider {
  const ModelProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKeyHint,
    required this.description,
    this.modelsPath = '/models',
    this.chatPath = '/chat/completions',
    this.supportsThinkingToggle = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String apiKeyHint;
  final String description;
  final String modelsPath;
  final String chatPath;

  /// 是否支持 DeepSeek 的 `thinking` 开关。
  final bool supportsThinkingToggle;

  Uri get modelsUri => Uri.parse('$baseUrl$modelsPath');

  Uri get chatUri => Uri.parse('$baseUrl$chatPath');
}

/// 已支持的模型供应商列表。
///
/// 后续接入 GLM、Qwen 等供应商时，只需在这里补充配置。
abstract final class ModelProviderCatalog {
  static const String defaultProviderId = 'deepseek';

  static const ModelProvider deepSeek = ModelProvider(
    id: defaultProviderId,
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    apiKeyHint: 'sk-...',
    description: '官方 API，兼容 OpenAI 协议',
    supportsThinkingToggle: true,
  );

  static const List<ModelProvider> all = [deepSeek];

  static ModelProvider? byId(String id) {
    for (final provider in all) {
      if (provider.id == id) {
        return provider;
      }
    }
    return null;
  }

  static ModelProvider get defaultProvider => deepSeek;
}
