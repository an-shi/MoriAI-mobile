import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/chat_conversation_summary.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryAppendEvent {
  const ChatHistoryAppendEvent({
    required this.conversationId,
    required this.messages,
  });

  final String conversationId;
  final List<ChatMessage> messages;
}

/// 按角色卡保存聊天记录。
///
/// 聊天记录只保存本地会话内容，不会写入或读取记忆模块。
class ChatHistoryStore {
  ChatHistoryStore._();

  static final ChatHistoryStore instance = ChatHistoryStore._();

  static const _keyPrefix = 'chat_history_v1_';

  /// 会话聊天记录被整体删除时更新为对应会话 ID，供已打开的聊天页清空界面。
  final ValueNotifier<String> clearedConversation = ValueNotifier<String>('');

  /// 外部服务（如自动消息）向会话追加消息后发出事件。
  final ValueNotifier<ChatHistoryAppendEvent?> messageAppended =
      ValueNotifier<ChatHistoryAppendEvent?>(null);

  Directory? _imagesRoot;

  Future<List<ChatMessage>> loadFor(String cardId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_prefsKey(cardId));
      if (raw == null || raw.isEmpty) {
        return const [];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final result = <ChatMessage>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final roleValue = item['role'];
        final content = item['content'];
        if (roleValue is! String || content is! String) {
          continue;
        }
        final role = switch (roleValue) {
          'user' => ChatRole.user,
          'assistant' => ChatRole.assistant,
          _ => null,
        };
        if (role == null) {
          continue;
        }

        final id = item['id'] is String ? item['id'] as String : '';
        final createdAtValue = item['createdAt'];
        final createdAt = createdAtValue is String
            ? DateTime.tryParse(createdAtValue)
            : null;

        ChatImage? image;
        final imageValue = item['image'];
        if (imageValue is Map) {
          final fileName = imageValue['file'];
          final mimeType = imageValue['mimeType'];
          if (fileName is String && mimeType is String) {
            final file = await _imageFileFor(cardId, fileName);
            if (file != null && await file.exists()) {
              final bytes = await file.readAsBytes();
              if (bytes.isNotEmpty) {
                image = ChatImage(bytes: bytes, mimeType: mimeType);
              }
            }
          }
        }

        result.add(
          ChatMessage(
            id: id,
            role: role,
            content: content,
            image: image,
            createdAt: createdAt,
            senderId: item['senderId'] is String
                ? item['senderId'] as String
                : '',
            senderName: item['senderName'] is String
                ? item['senderName'] as String
                : '',
          ),
        );
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<ChatConversationSummary?> summaryFor(String cardId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_prefsKey(cardId));
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }

      for (var index = decoded.length - 1; index >= 0; index--) {
        final item = decoded[index];
        if (item is! Map) {
          continue;
        }

        final rawContent = item['content'];
        final content = rawContent is String ? rawContent.trim() : '';
        final hasImage = item['image'] is Map;
        if (content.isEmpty && !hasImage) {
          continue;
        }

        final preview = content.isEmpty
            ? '[图片]'
            : content.replaceAll(RegExp(r'\s+'), ' ');
        final rawCreatedAt = item['createdAt'];
        final createdAt = rawCreatedAt is String
            ? DateTime.tryParse(rawCreatedAt)
            : null;
        return ChatConversationSummary(preview: preview, createdAt: createdAt);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFor(String cardId, List<ChatMessage> messages) async {
    try {
      final serialized = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (var index = 0; index < messages.length; index++) {
        final message = messages[index];
        if (!message.isUser &&
            message.content.trim().isEmpty &&
            message.image == null) {
          continue;
        }

        final id = message.id.isNotEmpty
            ? message.id
            : '${(message.createdAt ?? now).microsecondsSinceEpoch}_$index';
        String? imageFile;
        if (message.image != null) {
          imageFile = await _saveImage(cardId, id, message.image!);
        }

        serialized.add({
          'id': id,
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.content,
          'createdAt': (message.createdAt ?? now).toIso8601String(),
          if (message.senderId.isNotEmpty) 'senderId': message.senderId,
          if (message.senderName.isNotEmpty) 'senderName': message.senderName,
          if (imageFile != null)
            'image': {'file': imageFile, 'mimeType': message.image!.mimeType},
        });
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_prefsKey(cardId), jsonEncode(serialized));
    } catch (_) {
      // 聊天记录保存失败不阻断当前会话。
    }
  }

  Future<void> deleteForCard(String cardId) => deleteConversation(cardId);

  /// 通知已打开的聊天页和会话列表：外部服务已经写入新消息。
  void notifyExternalMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) {
    if (messages.isEmpty) {
      return;
    }
    messageAppended.value = ChatHistoryAppendEvent(
      conversationId: conversationId,
      messages: List<ChatMessage>.unmodifiable(messages),
    );
  }

  /// 删除一个会话的全部聊天记录和聊天图片。
  Future<void> deleteConversation(String conversationId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_prefsKey(conversationId));
    } catch (_) {
      // 忽略本地存储清理失败。
    }

    // 先置空再赋值，确保连续删除同一个会话时也能通知监听者。
    clearedConversation.value = '';
    clearedConversation.value = conversationId;

    try {
      final directory = await _cardImageDirectory(
        conversationId,
        create: false,
      );
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {
      // 忽略聊天图片清理失败。
    }
  }

  /// 删除单条消息对应的聊天图片文件。
  Future<void> deleteImageFor(String conversationId, String messageId) async {
    if (messageId.isEmpty) {
      return;
    }
    try {
      final directory = await _cardImageDirectory(
        conversationId,
        create: false,
      );
      if (directory == null) {
        return;
      }
      final safeId = messageId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${directory.path}/$safeId.jpg');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 忽略聊天图片清理失败。
    }
  }

  String _prefsKey(String cardId) => '$_keyPrefix$cardId';

  Future<String?> _saveImage(
    String cardId,
    String messageId,
    ChatImage image,
  ) async {
    try {
      final directory = await _cardImageDirectory(cardId, create: true);
      if (directory == null) {
        return null;
      }

      final safeId = messageId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = '$safeId.jpg';
      final file = File('${directory.path}/$fileName');
      if (!await file.exists()) {
        await file.writeAsBytes(image.bytes, flush: true);
      }
      return fileName;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _imageFileFor(String cardId, String fileName) async {
    final directory = await _cardImageDirectory(cardId, create: false);
    if (directory == null) {
      return null;
    }
    return File('${directory.path}/$fileName');
  }

  Future<Directory?> _cardImageDirectory(
    String cardId, {
    required bool create,
  }) async {
    try {
      var root = _imagesRoot;
      if (root == null) {
        final supportDirectory = await getApplicationSupportDirectory();
        root = Directory('${supportDirectory.path}/chat_images');
        if (create) {
          await root.create(recursive: true);
        } else if (!await root.exists()) {
          return null;
        }
        _imagesRoot = root;
      }

      final cardDirectory = Directory('${root.path}/$cardId');
      if (create) {
        await cardDirectory.create(recursive: true);
      } else if (!await cardDirectory.exists()) {
        return null;
      }
      return cardDirectory;
    } catch (_) {
      return null;
    }
  }
}
