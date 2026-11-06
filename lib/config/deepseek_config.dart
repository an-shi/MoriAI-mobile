class DeepSeekModelOption {
  const DeepSeekModelOption({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

abstract final class DeepSeekConfig {
  static const String baseUrl = 'https://api.deepseek.com';

  static const String defaultModel = 'deepseek-flash';

  /// 官方文档当前提供的模型。
  static const List<DeepSeekModelOption> models = [
    DeepSeekModelOption(
      id: 'deepseek-flash',
      name: 'DeepSeek Flash',
      description: '响应更快，适合日常陪伴聊天',
    ),
    DeepSeekModelOption(
      id: 'deepseek-v4-pro',
      name: 'DeepSeek V4 Pro',
      description: '能力更强，适合复杂问题，价格更高',
    ),
  ];

  static bool isSupportedModel(String id) =>
      models.any((model) => model.id == id);

  static DeepSeekModelOption modelOption(String id) =>
      models.firstWhere((model) => model.id == id, orElse: () => models.first);

  static const String systemPrompt = '''
你叫 Mori，是一个温柔、真诚、带一点幽默感的 AI 陪伴助手。
请用简体中文和用户自然聊天，语气亲切但不过度夸张。
先理解对方的感受，再给出回应；回答通常控制在 2-5 句话，除非用户明确需要更详细的内容。
不要假装自己是人类，也不要提供医疗、法律或金融方面的确定性建议。
''';
}
