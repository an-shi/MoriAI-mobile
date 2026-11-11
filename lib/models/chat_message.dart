import 'dart:convert';
import 'dart:typed_data';

enum ChatRole { user, assistant }

class ChatImage {
  const ChatImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;

  String get dataUrl => 'data:$mimeType;base64,${base64Encode(bytes)}';
}

class ChatMessage {
  const ChatMessage({
    this.id = '',
    required this.role,
    required this.content,
    this.image,
    this.isSticker = false,
    this.createdAt,
    this.senderId = '',
    this.senderName = '',
  });

  final String id;
  final ChatRole role;
  final String content;
  final ChatImage? image;

  /// 是否是一张表情包。表情包仍然复用图片字节，但界面会以无气泡方式展示。
  final bool isSticker;
  final DateTime? createdAt;
  final String senderId;
  final String senderName;

  bool get isUser => role == ChatRole.user;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    ChatImage? image,
    bool? isSticker,
    DateTime? createdAt,
    String? senderId,
    String? senderName,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      image: image ?? this.image,
      isSticker: isSticker ?? this.isSticker,
      createdAt: createdAt ?? this.createdAt,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
    );
  }

  Map<String, dynamic> toApiJson({bool includeImage = true}) {
    final text = isSticker && content.trim().isEmpty ? '[表情包]' : content;
    final apiContent = senderName.trim().isEmpty
        ? text
        : '${senderName.trim()}：$text';

    if (image == null || !includeImage) {
      return {'role': isUser ? 'user' : 'assistant', 'content': apiContent};
    }

    return {
      'role': isUser ? 'user' : 'assistant',
      'content': [
        if (apiContent.trim().isNotEmpty) {'type': 'text', 'text': apiContent},
        {
          'type': 'image_url',
          'image_url': {'url': image!.dataUrl},
        },
      ],
    };
  }
}
