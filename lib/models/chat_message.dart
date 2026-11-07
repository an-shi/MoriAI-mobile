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
  const ChatMessage({required this.role, required this.content, this.image});

  final ChatRole role;
  final String content;
  final ChatImage? image;

  bool get isUser => role == ChatRole.user;

  Map<String, dynamic> toApiJson() {
    if (image == null) {
      return {'role': isUser ? 'user' : 'assistant', 'content': content};
    }

    return {
      'role': isUser ? 'user' : 'assistant',
      'content': [
        if (content.trim().isNotEmpty) {'type': 'text', 'text': content},
        {
          'type': 'image_url',
          'image_url': {'url': image!.dataUrl},
        },
      ],
    };
  }
}
