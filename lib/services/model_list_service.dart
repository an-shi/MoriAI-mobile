import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/model_option.dart';

class ModelListException implements Exception {
  const ModelListException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 通过供应商的 OpenAI 兼容 `/models` 接口获取可用模型列表。
class ModelListService {
  ModelListService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ModelOption>> fetchModels({
    required ModelProvider provider,
    required String apiKey,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw ModelListException('请先保存 ${provider.name} API Key，再获取模型列表。');
    }

    final http.Response response;
    try {
      response = await _client
          .get(
            provider.modelsUri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $key',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ModelListException('连接 ${provider.name} 超时，请检查网络后重试。');
    } on http.ClientException catch (error) {
      throw ModelListException('无法连接 ${provider.name}：${error.message}');
    }

    if (response.statusCode != 200) {
      throw ModelListException(
        _errorMessage(provider, response.statusCode, response.body),
      );
    }

    return _parseModels(provider, response.body);
  }

  List<ModelOption> _parseModels(ModelProvider provider, String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw ModelListException('${provider.name} 返回了无法解析的模型列表。');
    }

    dynamic rawModels;
    if (decoded is Map<String, dynamic>) {
      rawModels = decoded['data'] ?? decoded['models'];
    } else if (decoded is List) {
      rawModels = decoded;
    }

    if (rawModels is! List) {
      throw ModelListException('${provider.name} 返回的模型列表格式无法识别。');
    }

    final modelsById = <String, ModelOption>{};
    for (final item in rawModels) {
      final String? id = switch (item) {
        String value => value,
        Map<String, dynamic> value =>
          value['id'] is String ? value['id'] as String : null,
        _ => null,
      };
      final trimmedId = id?.trim() ?? '';
      if (trimmedId.isEmpty || modelsById.containsKey(trimmedId)) {
        continue;
      }

      String? name;
      var supportsVision = false;
      if (item is Map<String, dynamic>) {
        final rawName = item['name'];
        if (rawName is String && rawName.trim().isNotEmpty) {
          name = rawName.trim();
        }
        supportsVision = _supportsVision(item);
      }

      modelsById[trimmedId] = ModelOption(
        id: trimmedId,
        name: name ?? trimmedId,
        supportsVision: supportsVision,
      );
    }

    if (modelsById.isEmpty) {
      throw ModelListException('${provider.name} 没有返回可用模型，请检查账号权限后重试。');
    }

    final models = modelsById.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return List<ModelOption>.unmodifiable(models);
  }

  bool _supportsVision(Map<String, dynamic> model) {
    final modalities = model['input_modalities'];
    if (modalities is List) {
      for (final modality in modalities) {
        if (modality is String &&
            (modality.toLowerCase() == 'image' ||
                modality.toLowerCase() == 'vision')) {
          return true;
        }
      }
    }

    final architecture = model['architecture'];
    if (architecture is Map<String, dynamic>) {
      final nested = architecture['input_modalities'];
      if (nested is List) {
        for (final modality in nested) {
          if (modality is String &&
              (modality.toLowerCase() == 'image' ||
                  modality.toLowerCase() == 'vision')) {
            return true;
          }
        }
      }
    }

    return model['supports_vision'] == true;
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
      404 => '供应商未提供模型列表接口',
      429 => '请求太频繁，请稍后再试',
      500 || 503 => '${provider.name} 服务暂时不可用',
      _ => '${provider.name} 请求失败（HTTP $statusCode）',
    };

    return detail.isEmpty ? reason : '$reason：$detail';
  }

  void dispose() {
    _client.close();
  }
}
