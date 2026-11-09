import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';

/// 本地通知：角色主动消息到达时提醒用户。
///
/// 只在 Android/iOS/macOS 上初始化；桌面和其他平台直接跳过。
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 用户点击通知后要打开的会话 ID。
  final ValueNotifier<String?> pendingConversationId = ValueNotifier<String?>(
    null,
  );

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized || kIsWeb) {
      return;
    }
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android &&
        platform != TargetPlatform.iOS &&
        platform != TargetPlatform.macOS) {
      return;
    }
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleResponse,
      );
      _initialized = true;

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final payload = launch?.notificationResponse?.payload;
        if (payload != null && payload.trim().isNotEmpty) {
          pendingConversationId.value = payload.trim();
        }
      }

      if (platform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (platform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (platform == TargetPlatform.macOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (_) {
      _initialized = false;
    }
  }

  void _handleResponse(NotificationResponse response) {
    final payload = response.payload?.trim() ?? '';
    if (payload.isNotEmpty) {
      pendingConversationId.value = payload;
    }
  }

  Future<void> showProactive({
    required String conversationId,
    required String characterName,
    required String body,
    ProactiveMessageSettings settings = ProactiveMessageSettings.defaults,
  }) async {
    if (!_initialized || !settings.notificationsEnabled) {
      return;
    }
    final id = conversationId.trim();
    if (id.isEmpty || body.trim().isEmpty) {
      return;
    }
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'mori_proactive',
          '角色主动消息',
          channelDescription: '角色主动发来的聊天消息',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      );
      await _plugin.show(
        id: _notificationId(id),
        title: characterName.trim().isEmpty ? 'Mori' : characterName.trim(),
        body: body.trim().length > 120
            ? '${body.trim().substring(0, 120)}…'
            : body.trim(),
        notificationDetails: details,
        payload: id,
      );
    } catch (_) {
      // 通知失败不影响聊天。
    }
  }

  int _notificationId(String conversationId) {
    return conversationId.hashCode & 0x7fffffff;
  }
}
