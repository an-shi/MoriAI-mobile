import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mori_ai/config/model_providers.dart';

/// 按供应商管理 API Key 的本地安全存储。
///
/// Key 保存在 Android Keystore / iOS Keychain 中，不写入代码或 Git。
/// 同一供应商下的所有模型和预设共用同一个 Key。
class ApiKeyStore {
  ApiKeyStore._();

  static final ApiKeyStore instance = ApiKeyStore._();

  static const _legacyDeepSeekKey = 'deepseek_api_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Map<String, ValueNotifier<String?>> _notifiers = {};

  /// 获取某个供应商的 Key 监听器。null 表示尚未配置。
  ValueNotifier<String?> keyFor(String providerId) {
    return _notifiers.putIfAbsent(
      providerId,
      () => ValueNotifier<String?>(null),
    );
  }

  Future<void> load() async {
    for (final provider in ModelProviderCatalog.all) {
      await loadProvider(provider.id);
    }
  }

  Future<void> loadProvider(String providerId) async {
    final notifier = keyFor(providerId);
    try {
      var stored = await _storage.read(key: _storageKey(providerId));

      if ((stored == null || stored.trim().isEmpty) &&
          providerId == ModelProviderCatalog.defaultProviderId) {
        // 兼容旧版本只保存 DeepSeek Key 的情况。
        stored = await _storage.read(key: _legacyDeepSeekKey);
        if (stored != null && stored.trim().isNotEmpty) {
          final legacyKey = stored.trim();
          stored = legacyKey;
          try {
            await _storage.write(
              key: _storageKey(providerId),
              value: legacyKey,
            );
          } catch (_) {
            // 迁移失败时仍继续使用旧 Key。
          }
        }
      }

      notifier.value = (stored == null || stored.trim().isEmpty)
          ? null
          : stored.trim();
    } catch (_) {
      notifier.value = null;
    }
  }

  Future<void> save(String providerId, String value) async {
    final key = value.trim();
    if (key.isEmpty) {
      await clear(providerId);
      return;
    }

    await _storage.write(key: _storageKey(providerId), value: key);
    keyFor(providerId).value = key;

    if (providerId == ModelProviderCatalog.defaultProviderId) {
      try {
        await _storage.delete(key: _legacyDeepSeekKey);
      } catch (_) {
        // 清理旧 Key 失败不影响新 Key 的使用。
      }
    }
  }

  Future<void> clear(String providerId) async {
    await _storage.delete(key: _storageKey(providerId));
    if (providerId == ModelProviderCatalog.defaultProviderId) {
      try {
        await _storage.delete(key: _legacyDeepSeekKey);
      } catch (_) {
        // 旧 Key 清理失败不影响当前 Key 的清除。
      }
    }
    keyFor(providerId).value = null;
  }

  String _storageKey(String providerId) => 'api_key_$providerId';
}
