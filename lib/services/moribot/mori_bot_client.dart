import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mori_ai/models/moribot/mori_models.dart';

/// Error returned by MoriBot or by the transport layer while talking to it.
class MoriApiException implements Exception {
  const MoriApiException(this.message, {this.statusCode, this.data, this.code});

  final String message;
  final int? statusCode;
  final Object? data;
  final String? code;

  bool get isUnauthorized => statusCode == 401;

  bool get isNotFound => statusCode == 404;

  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// HTTP client for the MoriBot mobile protocol.
///
/// The client is configured by [MoriSessionStore] with the server origin and
/// the long-lived device token. It never talks to model providers directly.
class MoriBotClient {
  MoriBotClient({
    http.Client? client,
    this.defaultTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(minutes: 3),
  }) : _client = client ?? http.Client();

  static final MoriBotClient instance = MoriBotClient();

  final http.Client _client;
  final Duration defaultTimeout;
  final Duration sendTimeout;

  String _baseUrl = '';
  String _deviceToken = '';

  String get baseUrl => _baseUrl;

  String get deviceToken => _deviceToken;

  bool get isConfigured => _baseUrl.isNotEmpty && _deviceToken.isNotEmpty;

  void configure({required String baseUrl, required String deviceToken}) {
    _baseUrl = normalizeServerUrl(baseUrl);
    _deviceToken = deviceToken.trim();
  }

  void clear() {
    _baseUrl = '';
    _deviceToken = '';
  }

  /// Normalizes an origin typed by the user or read from a pairing link.
  static String normalizeServerUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      throw const MoriApiException('请填写 MoriBot 服务器地址');
    }
    if (!value.contains('://')) {
      final host = value.split('/').first;
      final isLocal =
          host.startsWith('localhost') ||
          host.startsWith('127.') ||
          host.startsWith('10.') ||
          host.startsWith('192.168.') ||
          host.startsWith('10.0.2.2') ||
          host.startsWith('[::1]') ||
          RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host);
      value = '${isLocal ? 'http' : 'https'}://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const MoriApiException('服务器地址格式不正确，需要 http:// 或 https://');
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  Map<String, String> get authHeaders => {
    'Accept': 'application/json',
    'Accept-Language': 'zh-CN',
    'Authorization': 'Bearer $_deviceToken',
  };

  /// Resolves a relative media path into an absolute URL.
  Uri resolveMediaUri(String url) {
    final value = url.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.parse(value);
    }
    if (_baseUrl.isEmpty) {
      throw const MoriApiException('尚未连接 MoriBot 服务器');
    }
    return Uri.parse('$_baseUrl${value.startsWith('/') ? value : '/$value'}');
  }

  bool isServerMediaUrl(String url) {
    final value = url.trim();
    return !value.startsWith('http://') && !value.startsWith('https://');
  }

  /// WebSocket endpoint used for server events and heartbeats.
  Uri get webSocketUri {
    if (_baseUrl.isEmpty) {
      throw const MoriApiException('尚未连接 MoriBot 服务器');
    }
    final base = Uri.parse(_baseUrl);
    return base
        .replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '${base.path}/api/v1/mobile/ws'.replaceFirst(
            RegExp(r'^/+'),
            '/',
          ),
        )
        .removeFragment();
  }

  Future<MoriPairResult> pair({
    required String baseUrl,
    required String code,
    required String deviceName,
  }) async {
    final data = await _requestMap(
      'POST',
      '/api/v1/mobile/pair',
      baseUrlOverride: baseUrl,
      authenticated: false,
      body: {'code': code.trim(), 'device_name': deviceName.trim()},
    );
    return MoriPairResult.fromJson(data);
  }

  Future<MoriSelf> me() async {
    final data = await _requestMap('GET', '/api/v1/mobile/app/me');
    return MoriSelf.fromJson(data);
  }

  Future<List<MoriCharacter>> characters() async {
    final data = await _requestData('GET', '/api/v1/mobile/app/characters');
    if (data is! List) {
      throw const MoriApiException('服务器返回的角色卡格式不正确');
    }
    final result = <MoriCharacter>[];
    for (final item in data) {
      final map = readMoriObject(item);
      if (map != null) {
        result.add(MoriCharacter.fromJson(map));
      }
    }
    return result;
  }

  Future<MoriConversationPage> conversations({
    int? characterId,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _requestMap(
      'GET',
      '/api/v1/mobile/app/conversations',
      query: {
        if (characterId != null) 'character_id': '$characterId',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return MoriConversationPage.fromJson(data);
  }

  Future<MoriConversation> createConversation({
    required int characterId,
    String title = '',
  }) async {
    final data = await _requestMap(
      'POST',
      '/api/v1/mobile/app/conversations',
      body: {'character_id': characterId, 'title': title.trim()},
    );
    return MoriConversation.fromJson(data);
  }

  Future<MoriConversation> conversation(String conversationId) async {
    final data = await _requestMap(
      'GET',
      '/api/v1/mobile/app/conversations/${Uri.encodeComponent(conversationId)}',
    );
    return MoriConversation.fromJson(data);
  }

  Future<MoriConversation> renameConversation(
    String conversationId,
    String title,
  ) async {
    final data = await _requestMap(
      'PATCH',
      '/api/v1/mobile/app/conversations/${Uri.encodeComponent(conversationId)}',
      body: {'title': title.trim()},
    );
    return MoriConversation.fromJson(data);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _requestData(
      'DELETE',
      '/api/v1/mobile/app/conversations/${Uri.encodeComponent(conversationId)}',
    );
  }

  Future<MoriMessagePage> messages(
    String conversationId, {
    int limit = 50,
    int? beforeId,
    int? afterId,
  }) async {
    assert(beforeId == null || afterId == null);
    final data = await _requestMap(
      'GET',
      '/api/v1/mobile/app/conversations/${Uri.encodeComponent(conversationId)}/messages',
      query: {
        'limit': '$limit',
        if (beforeId != null) 'before_id': '$beforeId',
        if (afterId != null) 'after_id': '$afterId',
      },
    );
    return MoriMessagePage.fromJson(data);
  }

  Future<MoriSendResult> sendMessage(
    String conversationId, {
    required String content,
    required String clientMessageId,
    bool speech = false,
  }) async {
    final data = await _requestMap(
      'POST',
      '/api/v1/mobile/app/conversations/${Uri.encodeComponent(conversationId)}/messages',
      timeout: sendTimeout,
      body: {
        'content': content,
        'client_message_id': clientMessageId,
        if (speech) 'speech': true,
      },
    );
    return MoriSendResult.fromJson(data);
  }

  /// Downloads a media file. Server-relative URLs include the device token;
  /// remote provider URLs (for example image CDN links) are fetched directly.
  Future<List<int>> downloadMedia(String url) async {
    final uri = resolveMediaUri(url);
    final headers = <String, String>{'Accept-Language': 'zh-CN'};
    if (isServerMediaUrl(url)) {
      headers['Authorization'] = 'Bearer $_deviceToken';
    }
    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw MoriApiException(
        '媒体下载失败（HTTP ${response.statusCode}）',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> _requestMap(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? baseUrlOverride,
    bool authenticated = true,
    Duration? timeout,
  }) async {
    final data = await _requestData(
      method,
      path,
      query: query,
      body: body,
      baseUrlOverride: baseUrlOverride,
      authenticated: authenticated,
      timeout: timeout,
    );
    final map = readMoriObject(data);
    if (map == null) {
      throw const MoriApiException('服务器返回的数据格式不正确');
    }
    return map;
  }

  Future<Object?> _requestData(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? baseUrlOverride,
    bool authenticated = true,
    Duration? timeout,
  }) async {
    final base = baseUrlOverride == null
        ? _baseUrl
        : normalizeServerUrl(baseUrlOverride);
    if (base.isEmpty) {
      throw const MoriApiException('尚未连接 MoriBot 服务器');
    }
    if (authenticated && _deviceToken.isEmpty) {
      throw const MoriApiException('设备尚未配对', statusCode: 401);
    }

    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': 'zh-CN',
      if (authenticated) 'Authorization': 'Bearer $_deviceToken',
      if (body != null) 'Content-Type': 'application/json',
    };

    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _client
          .send(request)
          .timeout(timeout ?? defaultTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const MoriApiException('连接 MoriBot 超时，请检查网络后重试');
    } on http.ClientException catch (error) {
      throw MoriApiException('无法连接 MoriBot：${error.message}');
    }

    final decoded = _decodeEnvelope(response);
    final status = decoded['status'];
    if (response.statusCode >= 400 || status == 'error') {
      final message = readMoriString(decoded['message']).trim();
      throw MoriApiException(
        message.isEmpty ? _fallbackErrorMessage(response.statusCode) : message,
        statusCode: response.statusCode,
        data: decoded['data'],
        code: readMoriString(decoded['code']),
      );
    }
    return decoded['data'];
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    final text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (text.isEmpty) {
      if (response.statusCode >= 400) {
        throw MoriApiException(
          _fallbackErrorMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }
      return const {'status': 'ok', 'data': null};
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      // Fall through to the format error below.
    }

    if (response.statusCode >= 400) {
      throw MoriApiException(
        '服务器请求失败（HTTP ${response.statusCode}）',
        statusCode: response.statusCode,
      );
    }
    throw const MoriApiException('服务器返回了无法识别的响应');
  }

  String _fallbackErrorMessage(int statusCode) {
    return switch (statusCode) {
      400 => '请求内容不正确',
      401 => '设备未授权，请重新配对',
      404 => '请求的内容不存在',
      409 => '当前操作无法完成',
      422 => '请求参数不正确',
      429 => '请求太频繁，请稍后再试',
      500 => 'MoriBot 服务器内部错误',
      502 => 'MoriBot 生成回复失败',
      _ => 'MoriBot 请求失败（HTTP $statusCode）',
    };
  }

  void dispose() {
    _client.close();
  }
}
