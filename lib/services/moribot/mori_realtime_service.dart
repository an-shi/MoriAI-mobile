import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/services/moribot/mori_bot_client.dart';
import 'package:mori_ai/services/moribot/mori_session_store.dart';

enum MoriRealtimeStatus { stopped, connecting, connected, disconnected }

/// Maintains the outbound authenticated WebSocket used for server events and
/// heartbeats. Regular CRUD stays on the HTTPS API.
class MoriRealtimeService {
  MoriRealtimeService._();

  static final MoriRealtimeService instance = MoriRealtimeService._();

  final ValueNotifier<MoriRealtimeStatus> status =
      ValueNotifier<MoriRealtimeStatus>(MoriRealtimeStatus.stopped);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  /// Last server event other than heartbeat frames. Kept for future event
  /// driven UI such as dashboard messages or server-side push.
  final ValueNotifier<Map<String, dynamic>?> lastEvent =
      ValueNotifier<Map<String, dynamic>?>(null);

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _shouldRun = false;

  bool get isConnected => status.value == MoriRealtimeStatus.connected;

  Future<void> start() async {
    _shouldRun = true;
    if (status.value == MoriRealtimeStatus.connected ||
        status.value == MoriRealtimeStatus.connecting) {
      return;
    }
    await _connect();
  }

  Future<void> stop() async {
    _shouldRun = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
    status.value = MoriRealtimeStatus.stopped;
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> _connect() async {
    if (kIsWeb || !_shouldRun) {
      status.value = MoriRealtimeStatus.stopped;
      return;
    }

    final client = MoriBotClient.instance;
    if (!client.isConfigured) {
      status.value = MoriRealtimeStatus.stopped;
      return;
    }

    status.value = MoriRealtimeStatus.connecting;
    lastError.value = null;
    try {
      final socket = await WebSocket.connect(
        client.webSocketUri.toString(),
        headers: client.authHeaders,
      ).timeout(const Duration(seconds: 20));
      if (!_shouldRun) {
        await socket.close();
        return;
      }

      _socket = socket;
      _attempt = 0;
      status.value = MoriRealtimeStatus.connected;
      _subscription = socket.listen(
        _handleFrame,
        onDone: _handleClosed,
        onError: (Object error, StackTrace stackTrace) {
          lastError.value = '实时连接出错：$error';
          _handleClosed();
        },
        cancelOnError: false,
      );
    } catch (error) {
      if (!_shouldRun) {
        return;
      }
      lastError.value = '无法连接实时通道：$error';
      status.value = MoriRealtimeStatus.disconnected;
      _scheduleReconnect();
    }
  }

  void _handleFrame(dynamic raw) {
    if (raw is! String) {
      return;
    }
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return;
    }
    if (data == null) {
      return;
    }

    switch ('${data['type'] ?? ''}') {
      case 'hello':
        return;
      case 'ping':
        _send({'type': 'pong'});
        return;
      case 'pong':
        return;
      case 'revoked':
        unawaited(
          MoriSessionStore.instance.invalidate(notice: '设备已被服务器撤销，请重新配对'),
        );
        return;
      case 'error':
        lastError.value = '${data['message'] ?? '实时通道返回错误'}';
        return;
      default:
        lastEvent.value = data;
    }
  }

  void _handleClosed() {
    _subscription?.cancel();
    _subscription = null;
    _socket = null;
    if (status.value != MoriRealtimeStatus.stopped) {
      status.value = MoriRealtimeStatus.disconnected;
    }
    if (_shouldRun) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_shouldRun) {
      return;
    }
    _attempt++;
    final seconds = switch (_attempt) {
      1 => 1,
      2 => 2,
      3 => 4,
      4 => 8,
      5 => 16,
      _ => 30,
    };
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (_shouldRun) {
        unawaited(_connect());
      }
    });

    // A revoked token keeps failing handshakes. Revalidate periodically and
    // clear the pairing if the HTTP API also reports 401.
    if (_attempt == 3 || _attempt % 6 == 0) {
      unawaited(
        MoriSessionStore.instance.refreshMe(silent: true).catchError((_) {
          return null;
        }),
      );
    }
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _socket?.add(jsonEncode(payload));
    } catch (_) {
      // The socket listener will schedule a reconnect if it has closed.
    }
  }
}
