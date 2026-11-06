import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 管理 DeepSeek API Key 的本地安全存储。
///
/// Key 保存在 Android Keystore / iOS Keychain 中，不写入代码或 Git。
class ApiKeyStore {
  ApiKeyStore._();

  static final ApiKeyStore instance = ApiKeyStore._();

  static const _storageKey = 'deepseek_api_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// 当前 Key。null 表示尚未配置。
  final ValueNotifier<String?> apiKey = ValueNotifier<String?>(null);

  Future<void> load() async {
    try {
      final key = await _storage.read(key: _storageKey);
      apiKey.value = (key == null || key.trim().isEmpty) ? null : key.trim();
    } catch (_) {
      apiKey.value = null;
    }
  }

  Future<void> save(String value) async {
    final key = value.trim();
    if (key.isEmpty) {
      await clear();
      return;
    }

    await _storage.write(key: _storageKey, value: key);
    apiKey.value = key;
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
    apiKey.value = null;
  }
}
