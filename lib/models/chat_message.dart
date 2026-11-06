enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final ChatRole role;
  final String content;

  bool get isUser => role == ChatRole.user;

  Map<String, String> toApiJson() => {
    'role': isUser ? 'user' : 'assistant',
    'content': content,
  };
}
