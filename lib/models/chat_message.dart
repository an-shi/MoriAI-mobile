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
    this.createdAt,
    this.senderId = '',
    this.senderName = '',
  });

  final String id;
  final ChatRole role;
  final String content;
  final ChatImage? image;
  final DateTime? createdAt;
  final String senderId;
  final String senderName;

  bool get isUser => role == ChatRole.user;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    ChatImage? image,
    DateTime? createdAt,
    String? senderId,
    String? senderName,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      image: image ?? this.image,
      createdAt: createdAt ?? this.createdAt,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
    );
  }

  Map<String, dynamic> toApiJson() {
    final apiContent = senderName.trim().isEmpty
        ? content
        : '${senderName.trim()}：$content';

    if (image == null) {
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
