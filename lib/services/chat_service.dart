import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/chat_message.dart';

class ChatServiceException implements Exception {
  const ChatServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 基于 OpenAI 兼容协议的大模型流式对话服务。
class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Stream<String> streamChat(
    List<ChatMessage> messages, {
    required ModelProvider provider,
    required String apiKey,
    required String model,
    required String systemPrompt,
    double? temperature,
  }) async* {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw ChatServiceException(
        '尚未配置 ${provider.name} API Key，请先在「设置 > 模型」中填写。',
      );
    }

    final modelId = model.trim();
    if (modelId.isEmpty) {
      throw const ChatServiceException('尚未选择模型，请先在「设置 > 模型」中选择。');
    }

    final request = http.Request('POST', provider.chatUri)
      ..headers.addAll({
        'Accept': 'text/event-stream',
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'model': modelId,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          ...messages.map((message) => message.toApiJson()),
        ],
        'stream': true,
        'temperature': ?temperature,
        if (provider.supportsThinkingToggle)
          // 关闭深度思考，缩短首字延迟，适合日常陪伴聊天。
          'thinking': {'type': 'disabled'},
      });

    final http.StreamedResponse response;
    try {
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ChatServiceException('连接 ${provider.name} 超时，请检查网络后重试。');
    } on http.ClientException catch (error) {
      throw ChatServiceException('无法连接 ${provider.name}：${error.message}');
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw ChatServiceException(
        _errorMessage(provider, response.statusCode, body),
      );
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(const Duration(seconds: 60));

    try {
      await for (final line in lines) {
        final data = _extractData(line);
        if (data == null) {
          continue;
        }
        if (data == '[DONE]') {
          break;
        }

        final content = _extractContent(data);
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      }
    } on TimeoutException {
      throw ChatServiceException('${provider.name} 响应超时，请稍后重试。');
    }
  }

  void dispose() {
    _client.close();
  }

  String? _extractData(String line) {
    if (!line.startsWith('data:')) {
      return null;
    }
    final data = line.substring(5).trim();
    return data.isEmpty ? null : data;
  }

  String? _extractContent(String data) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        return null;
      }

      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }

      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      final delta = first['delta'];
      if (delta is! Map<String, dynamic>) {
        return null;
      }

      final content = delta['content'];
      return content is String ? content : null;
    } on FormatException {
      return null;
    }
  }

  String _errorMessage(ModelProvider provider, int statusCode, String body) {
    var detail = '';
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final error = json['error'];
        if (error is Map<String, dynamic>) {
          detail = (error['message'] as String?) ?? '';
        }
      }
    } on FormatException {
      // 忽略非 JSON 错误响应。
    }

    final reason = switch (statusCode) {
      400 => '请求格式不正确',
      401 => 'API Key 无效，请检查设置中的 Key',
      402 => '账户余额不足',
      403 => '没有访问权限',
      422 => '请求参数错误',
      429 => '请求太频繁，请稍后再试',
      500 || 503 => '${provider.name} 服务暂时不可用',
      _ => '${provider.name} 请求失败（HTTP $statusCode）',
    };

    return detail.isEmpty ? reason : '$reason：$detail';
  }
}
