enum ChatBurstTendency { followGlobal, off, natural, active }

extension ChatBurstTendencyLabel on ChatBurstTendency {
  String get label => switch (this) {
    ChatBurstTendency.followGlobal => '跟随全局',
    ChatBurstTendency.off => '关闭',
    ChatBurstTendency.natural => '自然',
    ChatBurstTendency.active => '积极',
  };

  String get description => switch (this) {
    ChatBurstTendency.followGlobal => '使用全局连发倾向。',
    ChatBurstTendency.off => '不主动鼓励连发；模型自己使用分隔符时仍会分条。',
    ChatBurstTendency.natural => '像真人一样，想说的多就拆成几条短消息。',
    ChatBurstTendency.active => '默认优先拆成多条短消息，适合话多的角色。',
  };
}

class ChatBurstRange {
  const ChatBurstRange({
    required this.minMessages,
    required this.maxMessages,
    required this.minChars,
    required this.maxChars,
  });

  static const natural = ChatBurstRange(
    minMessages: 1,
    maxMessages: 3,
    minChars: 10,
    maxChars: 60,
  );

  static const active = ChatBurstRange(
    minMessages: 2,
    maxMessages: 5,
    minChars: 15,
    maxChars: 100,
  );

  final int minMessages;
  final int maxMessages;
  final int minChars;
  final int maxChars;

  ChatBurstRange normalized() {
    final safeMinMessages = minMessages < 1 ? 1 : minMessages;
    final safeMaxMessages = maxMessages < safeMinMessages
        ? safeMinMessages
        : maxMessages;
    final safeMinChars = minChars < 1 ? 1 : minChars;
    final safeMaxChars = maxChars < safeMinChars ? safeMinChars : maxChars;
    return ChatBurstRange(
      minMessages: safeMinMessages,
      maxMessages: safeMaxMessages,
      minChars: safeMinChars,
      maxChars: safeMaxChars,
    );
  }

  ChatBurstRange copyWith({
    int? minMessages,
    int? maxMessages,
    int? minChars,
    int? maxChars,
  }) {
    return ChatBurstRange(
      minMessages: minMessages ?? this.minMessages,
      maxMessages: maxMessages ?? this.maxMessages,
      minChars: minChars ?? this.minChars,
      maxChars: maxChars ?? this.maxChars,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'minMessages': minMessages,
    'maxMessages': maxMessages,
    'minChars': minChars,
    'maxChars': maxChars,
  };

  factory ChatBurstRange.fromJson(
    Map<String, dynamic> json,
    ChatBurstRange fallback,
  ) {
    int read(String key, int fallbackValue) {
      final value = json[key];
      return value is int ? value : fallbackValue;
    }

    return ChatBurstRange(
      minMessages: read('minMessages', fallback.minMessages),
      maxMessages: read('maxMessages', fallback.maxMessages),
      minChars: read('minChars', fallback.minChars),
      maxChars: read('maxChars', fallback.maxChars),
    ).normalized();
  }
}

class ChatBurstSettings {
  const ChatBurstSettings({
    this.globalTendency = ChatBurstTendency.natural,
    this.characterTendencies = const {},
    this.tendencyRanges = const {
      ChatBurstTendency.natural: ChatBurstRange.natural,
      ChatBurstTendency.active: ChatBurstRange.active,
    },
  });

  static const defaults = ChatBurstSettings();

  final ChatBurstTendency globalTendency;
  final Map<String, ChatBurstTendency> characterTendencies;
  final Map<ChatBurstTendency, ChatBurstRange> tendencyRanges;

  ChatBurstTendency tendencyFor(String characterId) {
    final value = characterTendencies[characterId];
    if (value == null || value == ChatBurstTendency.followGlobal) {
      return globalTendency;
    }
    return value;
  }

  ChatBurstRange rangeFor(ChatBurstTendency tendency) {
    if (tendency == ChatBurstTendency.active) {
      return tendencyRanges[ChatBurstTendency.active] ?? ChatBurstRange.active;
    }
    return tendencyRanges[ChatBurstTendency.natural] ?? ChatBurstRange.natural;
  }

  ChatBurstRange rangeForCharacter(String characterId) {
    return rangeFor(tendencyFor(characterId));
  }

  ChatBurstSettings normalized() {
    final global = globalTendency == ChatBurstTendency.followGlobal
        ? ChatBurstTendency.natural
        : globalTendency;
    final overrides = <String, ChatBurstTendency>{};
    for (final entry in characterTendencies.entries) {
      final id = entry.key.trim();
      if (id.isEmpty || entry.value == ChatBurstTendency.followGlobal) {
        continue;
      }
      overrides[id] = entry.value;
    }
    final ranges = <ChatBurstTendency, ChatBurstRange>{
      ChatBurstTendency.natural:
          (tendencyRanges[ChatBurstTendency.natural] ?? ChatBurstRange.natural)
              .normalized(),
      ChatBurstTendency.active:
          (tendencyRanges[ChatBurstTendency.active] ?? ChatBurstRange.active)
              .normalized(),
    };
    return ChatBurstSettings(
      globalTendency: global,
      characterTendencies: Map<String, ChatBurstTendency>.unmodifiable(
        overrides,
      ),
      tendencyRanges: Map<ChatBurstTendency, ChatBurstRange>.unmodifiable(
        ranges,
      ),
    );
  }

  ChatBurstSettings copyWith({
    ChatBurstTendency? globalTendency,
    Map<String, ChatBurstTendency>? characterTendencies,
    Map<ChatBurstTendency, ChatBurstRange>? tendencyRanges,
  }) {
    return ChatBurstSettings(
      globalTendency: globalTendency ?? this.globalTendency,
      characterTendencies: characterTendencies ?? this.characterTendencies,
      tendencyRanges: tendencyRanges ?? this.tendencyRanges,
    ).normalized();
  }

  Map<String, dynamic> toJson() => {
    'globalTendency': globalTendency.name,
    'characterTendencies': {
      for (final entry in characterTendencies.entries)
        entry.key: entry.value.name,
    },
    'tendencyRanges': {
      for (final entry in tendencyRanges.entries)
        entry.key.name: entry.value.toJson(),
    },
  };

  factory ChatBurstSettings.fromJson(Map<String, dynamic> json) {
    ChatBurstTendency readTendency(String? raw, ChatBurstTendency fallback) {
      for (final value in ChatBurstTendency.values) {
        if (value.name == raw) {
          return value;
        }
      }
      return fallback;
    }

    final rawOverrides = json['characterTendencies'];
    final overrides = <String, ChatBurstTendency>{};
    if (rawOverrides is Map) {
      rawOverrides.forEach((key, value) {
        if (key is String && value is String) {
          overrides[key] = readTendency(value, ChatBurstTendency.followGlobal);
        }
      });
    }

    final ranges = <ChatBurstTendency, ChatBurstRange>{
      ChatBurstTendency.natural: ChatBurstRange.natural,
      ChatBurstTendency.active: ChatBurstRange.active,
    };
    final rawRanges = json['tendencyRanges'];
    if (rawRanges is Map) {
      for (final tendency in [
        ChatBurstTendency.natural,
        ChatBurstTendency.active,
      ]) {
        final raw = rawRanges[tendency.name];
        if (raw is Map) {
          ranges[tendency] = ChatBurstRange.fromJson(
            Map<String, dynamic>.from(raw),
            ranges[tendency]!,
          );
        }
      }
    }

    final rawGlobal = json['globalTendency'];
    return ChatBurstSettings(
      globalTendency: readTendency(
        rawGlobal is String ? rawGlobal : null,
        ChatBurstTendency.natural,
      ),
      characterTendencies: overrides,
      tendencyRanges: ranges,
    ).normalized();
  }
}
