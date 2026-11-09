import 'package:flutter/foundation.dart';

/// 记录当前正在查看的会话，用于判断主动消息是否需要计为未读或发通知。
class ActiveConversationStore {
  ActiveConversationStore._();

  static final ActiveConversationStore instance = ActiveConversationStore._();

  final ValueNotifier<String?> activeConversationId = ValueNotifier<String?>(
    null,
  );

  String? get activeId => activeConversationId.value;

  bool isActive(String conversationId) {
    return activeConversationId.value == conversationId.trim();
  }

  void enter(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    activeConversationId.value = id;
  }

  void leave(String conversationId) {
    if (activeConversationId.value == conversationId.trim()) {
      activeConversationId.value = null;
    }
  }
}
