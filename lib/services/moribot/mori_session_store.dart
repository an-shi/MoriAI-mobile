import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mori_ai/models/moribot/mori_models.dart';
import 'package:mori_ai/services/moribot/mori_bot_client.dart';
import 'package:mori_ai/services/moribot/mori_cache_store.dart';
import 'package:mori_ai/services/moribot/mori_media_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MoriSessionStatus { unpaired, connecting, ready, error }

class MoriSessionSnapshot {
  const MoriSessionSnapshot({
    required this.status,
    this.serverUrl,
    this.device,
    this.user,
    this.serverVersion,
    this.protocol,
    this.notice,
    this.error,
  });

  const MoriSessionSnapshot.unpaired({this.serverUrl, this.notice})
    : status = MoriSessionStatus.unpaired,
      device = null,
      user = null,
      serverVersion = null,
      protocol = null,
      error = null;

  final MoriSessionStatus status;
  final String? serverUrl;
  final MoriDevice? device;
  final MoriUser? user;
  final String? serverVersion;
  final int? protocol;

  /// User-facing information such as "设备已被撤销，请重新配对".
  final String? notice;

  /// Transport/server error shown by the connection screen.
  final String? error;

  bool get isReady => status == MoriSessionStatus.ready;

  bool get hasCachedAccount => user != null;

  MoriSessionSnapshot copyWith({
    MoriSessionStatus? status,
    String? serverUrl,
    MoriDevice? device,
    MoriUser? user,
    String? serverVersion,
    int? protocol,
    String? notice,
    String? error,
    bool clearError = false,
  }) {
    return MoriSessionSnapshot(
      status: status ?? this.status,
      serverUrl: serverUrl ?? this.serverUrl,
      device: device ?? this.device,
      user: user ?? this.user,
      serverVersion: serverVersion ?? this.serverVersion,
      protocol: protocol ?? this.protocol,
      notice: notice ?? this.notice,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns pairing credentials and the validated server session.
///
/// Only the long-lived device token is written to secure storage. Everything
/// else in the local cache can be discarded and fetched again from MoriBot.
class MoriSessionStore {
  MoriSessionStore._();

  static final MoriSessionStore instance = MoriSessionStore._();

  static const _serverUrlKey = 'moribot_server_url';
  static const _deviceKey = 'moribot_device_json';
  static const _userKey = 'moribot_user_json';
  static const _serverVersionKey = 'moribot_server_version';
  static const _protocolKey = 'moribot_protocol';
  static const _lastDeviceNameKey = 'moribot_last_device_name';
  static const _noticeKey = 'moribot_notice';
  static const _tokenKey = 'moribot_device_token';

  final ValueNotifier<MoriSessionSnapshot> snapshot =
      ValueNotifier<MoriSessionSnapshot>(const MoriSessionSnapshot.unpaired());

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  MoriBotClient get client => MoriBotClient.instance;

  String? _lastDeviceName;

  String get lastDeviceName {
    final value = _lastDeviceName?.trim() ?? '';
    return value.isEmpty ? defaultDeviceName : value;
  }

  static String get defaultDeviceName {
    try {
      final host = Platform.localHostname.trim();
      if (host.isNotEmpty && host.toLowerCase() != 'localhost') {
        return host.length > 64 ? host.substring(0, 64) : host;
      }
    } catch (_) {
      // Platform information is only used to prefill a friendly device name.
    }
    return '${defaultTargetPlatform.name} MoriMobile';
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final cachedServerUrl = preferences.getString(_serverUrlKey)?.trim() ?? '';
    _lastDeviceName = preferences.getString(_lastDeviceNameKey);
    final notice = preferences.getString(_noticeKey)?.trim();

    String? token;
    try {
      token = (await _secureStorage.read(key: _tokenKey))?.trim();
    } catch (_) {
      token = null;
    }

    if (cachedServerUrl.isEmpty || token == null || token.isEmpty) {
      snapshot.value = MoriSessionSnapshot.unpaired(
        serverUrl: cachedServerUrl.isEmpty ? null : cachedServerUrl,
        notice: notice?.isEmpty ?? true ? null : notice,
      );
      return;
    }

    client.configure(baseUrl: cachedServerUrl, deviceToken: token);
    final cachedDevice = _decodeMap(preferences.getString(_deviceKey));
    final cachedUser = _decodeMap(preferences.getString(_userKey));
    final device = cachedDevice == null
        ? null
        : MoriDevice.fromJson(cachedDevice);
    final user = cachedUser == null ? null : MoriUser.fromJson(cachedUser);
    final serverVersion = preferences.getString(_serverVersionKey);
    final protocol = preferences.getInt(_protocolKey);

    if (user != null) {
      snapshot.value = MoriSessionSnapshot(
        status: MoriSessionStatus.ready,
        serverUrl: cachedServerUrl,
        device: device,
        user: user,
        serverVersion: serverVersion,
        protocol: protocol,
        notice: notice?.isEmpty ?? true ? null : notice,
      );
      unawaited(refreshMe(silent: true));
      return;
    }

    snapshot.value = MoriSessionSnapshot(
      status: MoriSessionStatus.connecting,
      serverUrl: cachedServerUrl,
      device: device,
    );
    try {
      await refreshMe();
    } catch (_) {
      // refreshMe already converted the failure into a snapshot.
    }
  }

  /// Redeems a one-time pairing code and stores the device token.
  Future<MoriSelf?> pair({
    required String serverUrl,
    required String code,
    required String deviceName,
  }) async {
    final normalizedUrl = MoriBotClient.normalizeServerUrl(serverUrl);
    final normalizedCode = code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (normalizedCode.length != 8) {
      throw const MoriApiException('配对码应为 8 位字母或数字');
    }
    final name = deviceName.trim();
    if (name.isEmpty) {
      throw const MoriApiException('请填写设备名称');
    }

    snapshot.value = MoriSessionSnapshot(
      status: MoriSessionStatus.connecting,
      serverUrl: normalizedUrl,
    );

    final MoriPairResult result;
    try {
      result = await client.pair(
        baseUrl: normalizedUrl,
        code: normalizedCode,
        deviceName: name,
      );
    } on MoriApiException catch (error) {
      snapshot.value = MoriSessionSnapshot.unpaired(
        serverUrl: normalizedUrl,
        notice: error.message,
      );
      rethrow;
    } catch (error) {
      snapshot.value = MoriSessionSnapshot.unpaired(
        serverUrl: normalizedUrl,
        notice: '$error',
      );
      rethrow;
    }

    if (result.deviceToken.isEmpty) {
      snapshot.value = MoriSessionSnapshot.unpaired(
        serverUrl: normalizedUrl,
        notice: '服务器没有返回设备令牌',
      );
      throw const MoriApiException('服务器没有返回设备令牌');
    }

    client.configure(baseUrl: normalizedUrl, deviceToken: result.deviceToken);
    await _writeToken(result.deviceToken);
    await _writeBasePreferences(
      serverUrl: normalizedUrl,
      device: result.device,
      user: null,
      serverVersion: null,
      protocol: null,
      notice: null,
    );
    await _writeLastDeviceName(name);
    await MoriCacheStore.instance.clearAll();

    try {
      final self = await client.me();
      await _applySelf(self);
      return self;
    } on MoriApiException catch (error) {
      if (error.isUnauthorized) {
        await invalidate(notice: '设备配对已失效，请重新生成配对码');
        rethrow;
      }
      // Pairing itself succeeded. The token can still be used; the next
      // /me, conversation or WebSocket request will validate it again.
      snapshot.value = MoriSessionSnapshot(
        status: MoriSessionStatus.ready,
        serverUrl: normalizedUrl,
        device: result.device,
        error: error.message,
      );
      return null;
    } catch (error) {
      snapshot.value = MoriSessionSnapshot(
        status: MoriSessionStatus.ready,
        serverUrl: normalizedUrl,
        device: result.device,
        error: '$error',
      );
      return null;
    }
  }

  /// Validates the device token against MoriBot.
  Future<MoriSelf?> refreshMe({bool silent = false}) async {
    if (!client.isConfigured) {
      snapshot.value = const MoriSessionSnapshot.unpaired();
      return null;
    }

    try {
      final self = await client.me();
      await _applySelf(self);
      return self;
    } on MoriApiException catch (error) {
      if (error.isUnauthorized) {
        await invalidate(notice: '设备已被撤销或授权已失效，请重新配对');
        return null;
      }
      if (!silent) {
        final current = snapshot.value;
        if (current.status == MoriSessionStatus.connecting ||
            current.user == null) {
          snapshot.value = MoriSessionSnapshot(
            status: MoriSessionStatus.error,
            serverUrl: client.baseUrl,
            device: current.device,
            error: error.message,
          );
        } else {
          snapshot.value = current.copyWith(error: error.message);
        }
      }
      rethrow;
    } catch (error) {
      if (!silent) {
        final current = snapshot.value;
        if (current.status == MoriSessionStatus.connecting ||
            current.user == null) {
          snapshot.value = MoriSessionSnapshot(
            status: MoriSessionStatus.error,
            serverUrl: client.baseUrl,
            device: current.device,
            error: '$error',
          );
        } else {
          snapshot.value = current.copyWith(error: '$error');
        }
      }
      rethrow;
    }
  }

  /// Called when any HTTP or WebSocket request detects a revoked device.
  Future<void> invalidate({String? notice}) async {
    final serverUrl = client.baseUrl.isEmpty
        ? snapshot.value.serverUrl
        : client.baseUrl;
    client.clear();
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {
      // The in-memory token is already gone.
    }
    await _clearAccountPreferences(notice: notice);
    await _clearLocalData();
    snapshot.value = MoriSessionSnapshot.unpaired(
      serverUrl: serverUrl,
      notice: notice,
    );
  }

  /// Removes the device token while keeping the server URL for the next pair.
  Future<void> unpair() async {
    final serverUrl = client.baseUrl.isEmpty
        ? snapshot.value.serverUrl
        : client.baseUrl;
    client.clear();
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {
      // Ignore secure-storage cleanup failures.
    }
    await _clearAccountPreferences(notice: null);
    await _clearLocalData();
    snapshot.value = MoriSessionSnapshot.unpaired(serverUrl: serverUrl);
  }

  Future<void> clearLocalCache() async {
    await _clearLocalData();
  }

  Future<void> _applySelf(MoriSelf self) async {
    await _writeBasePreferences(
      serverUrl: client.baseUrl,
      device: self.device,
      user: self.user,
      serverVersion: self.serverVersion,
      protocol: self.protocol,
      notice: null,
    );
    snapshot.value = MoriSessionSnapshot(
      status: MoriSessionStatus.ready,
      serverUrl: client.baseUrl,
      device: self.device,
      user: self.user,
      serverVersion: self.serverVersion,
      protocol: self.protocol,
    );
  }

  Future<void> _writeBasePreferences({
    required String serverUrl,
    required MoriDevice? device,
    required MoriUser? user,
    required String? serverVersion,
    required int? protocol,
    required String? notice,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_serverUrlKey, serverUrl);
      if (device != null) {
        await preferences.setString(_deviceKey, jsonEncode(device.toJson()));
      } else {
        await preferences.remove(_deviceKey);
      }
      if (user != null) {
        await preferences.setString(_userKey, jsonEncode(user.toJson()));
      } else {
        await preferences.remove(_userKey);
      }
      if (serverVersion != null) {
        await preferences.setString(_serverVersionKey, serverVersion);
      } else {
        await preferences.remove(_serverVersionKey);
      }
      if (protocol != null) {
        await preferences.setInt(_protocolKey, protocol);
      } else {
        await preferences.remove(_protocolKey);
      }
      if (notice != null && notice.trim().isNotEmpty) {
        await preferences.setString(_noticeKey, notice);
      } else {
        await preferences.remove(_noticeKey);
      }
    } catch (_) {
      // Account metadata is only a startup cache; secure storage has the token.
    }
  }

  Future<void> _clearAccountPreferences({String? notice}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_deviceKey);
      await preferences.remove(_userKey);
      await preferences.remove(_serverVersionKey);
      await preferences.remove(_protocolKey);
      if (notice != null && notice.trim().isNotEmpty) {
        await preferences.setString(_noticeKey, notice);
      } else {
        await preferences.remove(_noticeKey);
      }
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> _clearLocalData() async {
    await MoriCacheStore.instance.clearAll();
    await MoriMediaCache.instance.clear();
  }

  Future<void> _writeToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Pairing still works for this process even if secure storage fails.
    }
  }

  Future<void> _writeLastDeviceName(String name) async {
    _lastDeviceName = name;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_lastDeviceNameKey, name);
    } catch (_) {
      // Only a form prefill.
    }
  }

  Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore corrupt startup cache.
    }
    return null;
  }
}
