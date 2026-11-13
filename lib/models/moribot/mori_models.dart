/// Data models for the MoriBot mobile protocol.
///
/// The server is the source of truth. Every model can be serialized back to the
/// same snake_case shape used by the HTTP API, which also lets the local cache
/// reuse the exact payloads received from MoriBot.
library;

String readMoriString(Object? value) => value is String ? value : '';

int readMoriInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}') ?? 0;
}

bool readMoriBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    if (value == 'true' || value == '1') {
      return true;
    }
    if (value == 'false' || value == '0') {
      return false;
    }
  }
  return fallback;
}

/// MoriBot stores timestamps as naive UTC. Parse them as UTC so the phone can
/// convert them to the device timezone before rendering.
DateTime? parseMoriDate(Object? value) {
  final raw = value is String ? value.trim() : '';
  if (raw.isEmpty) {
    return null;
  }
  final hasTimeZone =
      raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
  final normalized = hasTimeZone ? raw : '${raw}Z';
  return DateTime.tryParse(normalized)?.toLocal();
}

Map<String, dynamic>? readMoriObject(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

class MoriDevice {
  const MoriDevice({
    required this.id,
    required this.name,
    this.online = false,
    this.createdAt,
    this.lastSeenAt,
    this.revokedAt,
  });

  final String id;
  final String name;
  final bool online;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;

  factory MoriDevice.fromJson(Map<String, dynamic> json) {
    return MoriDevice(
      id: readMoriString(json['id']),
      name: readMoriString(json['name']),
      online: readMoriBool(json['online']),
      createdAt: parseMoriDate(json['created_at']),
      lastSeenAt: parseMoriDate(json['last_seen_at']),
      revokedAt: parseMoriDate(json['revoked_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'online': online,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
    'revoked_at': revokedAt?.toUtc().toIso8601String(),
  };
}

class MoriUser {
  const MoriUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
  });

  final int id;
  final String username;
  final String displayName;
  final String role;

  String get effectiveDisplayName =>
      displayName.trim().isNotEmpty ? displayName.trim() : username;

  factory MoriUser.fromJson(Map<String, dynamic> json) {
    return MoriUser(
      id: readMoriInt(json['id']),
      username: readMoriString(json['username']),
      displayName: readMoriString(json['display_name']),
      role: readMoriString(json['role']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'role': role,
  };
}

class MoriSelf {
  const MoriSelf({
    required this.device,
    required this.user,
    required this.serverVersion,
    required this.protocol,
  });

  final MoriDevice device;
  final MoriUser user;
  final String serverVersion;
  final int protocol;

  factory MoriSelf.fromJson(Map<String, dynamic> json) {
    final device = readMoriObject(json['device']);
    final user = readMoriObject(json['user']);
    return MoriSelf(
      device: device == null
          ? const MoriDevice(id: '', name: '')
          : MoriDevice.fromJson(device),
      user: user == null
          ? const MoriUser(id: 0, username: '', displayName: '', role: '')
          : MoriUser.fromJson(user),
      serverVersion: readMoriString(json['server_version']),
      protocol: readMoriInt(json['protocol']),
    );
  }
}

class MoriPairResult {
  const MoriPairResult({required this.deviceToken, required this.device});

  final String deviceToken;
  final MoriDevice device;

  factory MoriPairResult.fromJson(Map<String, dynamic> json) {
    final device = readMoriObject(json['device']);
    return MoriPairResult(
      deviceToken: readMoriString(json['device_token']),
      device: device == null
          ? const MoriDevice(id: '', name: '')
          : MoriDevice.fromJson(device),
    );
  }
}

class MoriCharacter {
  const MoriCharacter({
    required this.id,
    required this.name,
    this.avatar = '',
    this.description = '',
    this.chatAvailable = true,
    this.speechAvailable = false,
    this.imageAvailable = false,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String avatar;
  final String description;
  final bool chatAvailable;
  final bool speechAvailable;
  final bool imageAvailable;
  final DateTime? updatedAt;

  String get displayName => name.trim().isEmpty ? '角色 $id' : name.trim();

  String get summary {
    final text = description.trim();
    if (text.isNotEmpty) {
      return text;
    }
    return chatAvailable ? '可以开始聊天' : '暂时不可用';
  }

  factory MoriCharacter.fromJson(Map<String, dynamic> json) {
    return MoriCharacter(
      id: readMoriInt(json['id']),
      name: readMoriString(json['name']),
      avatar: readMoriString(json['avatar']),
      description: readMoriString(json['description']),
      chatAvailable: readMoriBool(json['chat_available'], fallback: true),
      speechAvailable: readMoriBool(json['speech_available']),
      imageAvailable: readMoriBool(json['image_available']),
      updatedAt: parseMoriDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'description': description,
    'chat_available': chatAvailable,
    'speech_available': speechAvailable,
    'image_available': imageAvailable,
    'updated_at': updatedAt?.toUtc().toIso8601String(),
  };
}

class MoriConversation {
  const MoriConversation({
    required this.id,
    required this.characterId,
    required this.characterName,
    this.characterAvatar = '',
    this.characterAvailable = true,
    this.title = '',
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.messageCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int characterId;
  final String characterName;
  final String characterAvatar;
  final bool characterAvailable;
  final String title;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final int messageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName =>
      characterName.trim().isEmpty ? '对话' : characterName.trim();

  String get displayTitle => title.trim().isEmpty ? displayName : title.trim();

  String get preview {
    final text = lastMessagePreview.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? '暂无消息' : text;
  }

  DateTime? get activityAt => lastMessageAt ?? updatedAt ?? createdAt;

  factory MoriConversation.fromJson(Map<String, dynamic> json) {
    return MoriConversation(
      id: readMoriString(json['id']),
      characterId: readMoriInt(json['character_id']),
      characterName: readMoriString(json['character_name']),
      characterAvatar: readMoriString(json['character_avatar']),
      characterAvailable: readMoriBool(
        json['character_available'],
        fallback: true,
      ),
      title: readMoriString(json['title']),
      lastMessagePreview: readMoriString(json['last_message_preview']),
      lastMessageAt: parseMoriDate(json['last_message_at']),
      messageCount: readMoriInt(json['message_count']),
      createdAt: parseMoriDate(json['created_at']),
      updatedAt: parseMoriDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'character_id': characterId,
    'character_name': characterName,
    'character_avatar': characterAvatar,
    'character_available': characterAvailable,
    'title': title,
    'last_message_preview': lastMessagePreview,
    'last_message_at': lastMessageAt?.toUtc().toIso8601String(),
    'message_count': messageCount,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
  };
}

class MoriConversationPage {
  const MoriConversationPage({
    required this.conversations,
    required this.hasMore,
  });

  final List<MoriConversation> conversations;
  final bool hasMore;

  factory MoriConversationPage.fromJson(Map<String, dynamic> json) {
    final raw = json['conversations'];
    final conversations = <MoriConversation>[];
    if (raw is List) {
      for (final item in raw) {
        final map = readMoriObject(item);
        if (map != null) {
          conversations.add(MoriConversation.fromJson(map));
        }
      }
    }
    return MoriConversationPage(
      conversations: conversations,
      hasMore: readMoriBool(json['has_more']),
    );
  }
}

class MoriSpeech {
  const MoriSpeech({
    required this.url,
    this.mimeType = 'audio/mpeg',
    this.format = 'mp3',
    this.byteLength = 0,
  });

  final String url;
  final String mimeType;
  final String format;
  final int byteLength;

  factory MoriSpeech.fromJson(Map<String, dynamic> json) {
    return MoriSpeech(
      url: readMoriString(json['url']),
      mimeType: readMoriString(json['mime_type']).isEmpty
          ? 'audio/mpeg'
          : readMoriString(json['mime_type']),
      format: readMoriString(json['format']).isEmpty
          ? 'mp3'
          : readMoriString(json['format']),
      byteLength: readMoriInt(json['byte_length']),
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'mime_type': mimeType,
    'format': format,
    'byte_length': byteLength,
  };
}

class MoriImage {
  const MoriImage({required this.url, this.mimeType = 'image/png'});

  final String url;
  final String mimeType;

  factory MoriImage.fromJson(Map<String, dynamic> json) {
    return MoriImage(
      url: readMoriString(json['url']),
      mimeType: readMoriString(json['mime_type']).isEmpty
          ? 'image/png'
          : readMoriString(json['mime_type']),
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'mime_type': mimeType};
}

enum MoriMessageStatus { sent, pending, failed }

class MoriMessage {
  const MoriMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    this.content = '',
    this.speech,
    this.images = const [],
    this.clientMessageId = '',
    this.providerId = '',
    this.model = '',
    this.createdAt,
    this.status = MoriMessageStatus.sent,
  });

  /// Server message IDs are positive. Optimistic local messages use negative
  /// IDs until the server response replaces them.
  final int id;
  final String conversationId;
  final String role;
  final String content;
  final MoriSpeech? speech;
  final List<MoriImage> images;
  final String clientMessageId;
  final String providerId;
  final String model;
  final DateTime? createdAt;
  final MoriMessageStatus status;

  bool get isUser => role == 'user';

  bool get isAssistant => role == 'assistant';

  bool get hasMedia => speech != null || images.isNotEmpty;

  bool get isEmpty => content.trim().isEmpty && !hasMedia;

  MoriMessage copyWith({
    int? id,
    String? conversationId,
    String? role,
    String? content,
    MoriSpeech? speech,
    List<MoriImage>? images,
    String? clientMessageId,
    String? providerId,
    String? model,
    DateTime? createdAt,
    MoriMessageStatus? status,
  }) {
    return MoriMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      speech: speech ?? this.speech,
      images: images ?? this.images,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  factory MoriMessage.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final speech = readMoriObject(json['speech']);
    final images = <MoriImage>[];
    if (rawImages is List) {
      for (final item in rawImages) {
        final map = readMoriObject(item);
        if (map != null) {
          images.add(MoriImage.fromJson(map));
        }
      }
    }
    return MoriMessage(
      id: readMoriInt(json['id']),
      conversationId: readMoriString(json['conversation_id']),
      role: readMoriString(json['role']),
      content: readMoriString(json['content']),
      speech: speech == null ? null : MoriSpeech.fromJson(speech),
      images: images,
      clientMessageId: readMoriString(json['client_message_id']),
      providerId: readMoriString(json['provider_id']),
      model: readMoriString(json['model']),
      createdAt: parseMoriDate(json['created_at']),
      status: MoriMessageStatus.sent,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'role': role,
    'content': content,
    'speech': speech?.toJson(),
    'images': [for (final image in images) image.toJson()],
    'client_message_id': clientMessageId,
    'provider_id': providerId,
    'model': model,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

class MoriMessagePage {
  const MoriMessagePage({
    required this.messages,
    required this.hasMore,
    this.earliestId,
    this.latestId,
  });

  final List<MoriMessage> messages;
  final bool hasMore;
  final int? earliestId;
  final int? latestId;

  factory MoriMessagePage.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final messages = <MoriMessage>[];
    if (raw is List) {
      for (final item in raw) {
        final map = readMoriObject(item);
        if (map != null) {
          messages.add(MoriMessage.fromJson(map));
        }
      }
    }
    return MoriMessagePage(
      messages: messages,
      hasMore: readMoriBool(json['has_more']),
      earliestId: json['earliest_id'] == null
          ? null
          : readMoriInt(json['earliest_id']),
      latestId: json['latest_id'] == null
          ? null
          : readMoriInt(json['latest_id']),
    );
  }
}

class MoriSendResult {
  const MoriSendResult({
    required this.conversation,
    required this.userMessage,
    required this.assistantMessage,
  });

  final MoriConversation conversation;
  final MoriMessage userMessage;
  final MoriMessage assistantMessage;

  factory MoriSendResult.fromJson(Map<String, dynamic> json) {
    final conversation = readMoriObject(json['conversation']);
    final userMessage = readMoriObject(json['user_message']);
    final assistantMessage = readMoriObject(json['assistant_message']);
    if (conversation == null ||
        userMessage == null ||
        assistantMessage == null) {
      throw const FormatException('Invalid send message response');
    }
    return MoriSendResult(
      conversation: MoriConversation.fromJson(conversation),
      userMessage: MoriMessage.fromJson(userMessage),
      assistantMessage: MoriMessage.fromJson(assistantMessage),
    );
  }
}

/// Parses a `morimobile://pair?server=...&code=...` link.
class MoriPairingLink {
  const MoriPairingLink({required this.serverUrl, required this.code});

  final String serverUrl;
  final String code;

  static MoriPairingLink? tryParse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.toLowerCase() != 'morimobile') {
      return null;
    }
    if (uri.host.toLowerCase() != 'pair') {
      return null;
    }
    final server = uri.queryParameters['server']?.trim() ?? '';
    final code = uri.queryParameters['code']?.trim() ?? '';
    if (server.isEmpty || code.isEmpty) {
      return null;
    }
    return MoriPairingLink(serverUrl: server, code: code);
  }
}
