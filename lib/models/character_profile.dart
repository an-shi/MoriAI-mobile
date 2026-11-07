enum CharacterCardType {
  simple,
  structured,
  roleplay,
  advanced,
  paste;

  String get label => switch (this) {
    CharacterCardType.simple => '简单陪伴',
    CharacterCardType.structured => '结构化设定',
    CharacterCardType.roleplay => '角色扮演',
    CharacterCardType.advanced => '高级自定义',
    CharacterCardType.paste => '粘贴设定',
  };

  String get description => switch (this) {
    CharacterCardType.simple => '只填写名称和一段人格描述，适合快速创建。',
    CharacterCardType.structured => '拆分性格、说话方式、背景、关系、喜好和边界，角色表现更稳定。',
    CharacterCardType.roleplay => '在结构化设定上增加场景、开场白和示例对话，适合角色扮演。',
    CharacterCardType.advanced => '在角色扮演基础上增加自定义系统指令，适合精细控制模型行为。',
    CharacterCardType.paste => '直接粘贴完整的角色卡设定，原文会作为系统提示词使用，不再逐项拆分。',
  };

  bool get usesStructuredSettings =>
      this == CharacterCardType.structured ||
      this == CharacterCardType.roleplay ||
      this == CharacterCardType.advanced;

  bool get usesDialogueSettings =>
      this == CharacterCardType.roleplay || this == CharacterCardType.advanced;

  bool get usesAdvancedSettings => this == CharacterCardType.advanced;

  bool get usesRawDefinition => this == CharacterCardType.paste;

  static CharacterCardType fromName(String? name) {
    for (final type in values) {
      if (type.name == name) {
        return type;
      }
    }
    return CharacterCardType.simple;
  }
}

class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    this.type = CharacterCardType.simple,
    this.avatar = '',
    this.tagline = '',
    this.persona = '',
    this.personality = '',
    this.speakingStyle = '',
    this.background = '',
    this.relationship = '',
    this.likes = '',
    this.dislikes = '',
    this.boundaries = '',
    this.scenario = '',
    this.greeting = '',
    this.exampleDialogue = '',
    this.systemPrompt = '',
    this.postHistoryInstructions = '',
    this.rawDefinition = '',
  });

  static const String presetMoriId = 'mori';
  static const String presetMoriAvatar = 'assets/icon/app_icon.png';
  static const String fallbackDisplayName = 'AI 伙伴';
  static const String defaultPersona = '温柔、真诚，带一点幽默感，善于倾听和陪伴用户。';

  static const CharacterProfile presetMori = CharacterProfile(
    id: presetMoriId,
    type: CharacterCardType.structured,
    avatar: presetMoriAvatar,
    name: 'Mori',
    tagline: '温柔、真诚，带一点幽默感的 AI 伙伴',
    persona: defaultPersona,
    personality: '温柔、真诚、耐心，偶尔有一点轻松的幽默感。',
    speakingStyle: '先回应对方的感受，再给出回应；回复通常 2-5 句话，语气自然，不过度夸张。',
    background: '来自安静虚拟空间的 AI 陪伴助手，喜欢观察和记住日常里的小事。',
    relationship: '逐渐熟悉、值得信任的朋友。',
    likes: '安静的音乐、植物、深夜的闲聊。',
    dislikes: '被强迫做决定、过度客套。',
    boundaries: '不假装自己是人类，不提供医疗、法律或金融方面的确定性建议。',
  );

  final String id;
  final CharacterCardType type;

  /// 本地头像文件名，实际文件由 AvatarStore 管理。
  final String avatar;
  final String name;
  final String tagline;
  final String persona;
  final String personality;
  final String speakingStyle;
  final String background;
  final String relationship;
  final String likes;
  final String dislikes;
  final String boundaries;
  final String scenario;
  final String greeting;
  final String exampleDialogue;
  final String systemPrompt;
  final String postHistoryInstructions;
  final String rawDefinition;

  bool get isPreset => id == presetMoriId;

  bool get hasName => name.trim().isNotEmpty;

  String get displayName => hasName ? name.trim() : fallbackDisplayName;

  String get effectivePersona {
    if (persona.trim().isNotEmpty) {
      return persona.trim();
    }
    if (personality.trim().isNotEmpty) {
      return personality.trim();
    }
    return defaultPersona;
  }

  String get summaryText {
    if (tagline.trim().isNotEmpty) {
      return tagline.trim();
    }
    if (type.usesRawDefinition && rawDefinition.trim().isNotEmpty) {
      return rawDefinition.trim();
    }
    return effectivePersona;
  }

  CharacterProfile withAvatar(String value) {
    return CharacterProfile(
      id: id,
      type: type,
      avatar: value,
      name: name,
      tagline: tagline,
      persona: persona,
      personality: personality,
      speakingStyle: speakingStyle,
      background: background,
      relationship: relationship,
      likes: likes,
      dislikes: dislikes,
      boundaries: boundaries,
      scenario: scenario,
      greeting: greeting,
      exampleDialogue: exampleDialogue,
      systemPrompt: systemPrompt,
      postHistoryInstructions: postHistoryInstructions,
      rawDefinition: rawDefinition,
    );
  }

  CharacterProfile normalized() {
    return CharacterProfile(
      id: id,
      type: type,
      avatar: avatar.trim(),
      name: name.trim(),
      tagline: tagline.trim(),
      persona: persona.trim(),
      personality: personality.trim(),
      speakingStyle: speakingStyle.trim(),
      background: background.trim(),
      relationship: relationship.trim(),
      likes: likes.trim(),
      dislikes: dislikes.trim(),
      boundaries: boundaries.trim(),
      scenario: scenario.trim(),
      greeting: greeting.trim(),
      exampleDialogue: exampleDialogue.trim(),
      systemPrompt: systemPrompt.trim(),
      postHistoryInstructions: postHistoryInstructions.trim(),
      rawDefinition: rawDefinition.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'avatar': avatar,
    'name': name,
    'tagline': tagline,
    'persona': persona,
    'personality': personality,
    'speakingStyle': speakingStyle,
    'background': background,
    'relationship': relationship,
    'likes': likes,
    'dislikes': dislikes,
    'boundaries': boundaries,
    'scenario': scenario,
    'greeting': greeting,
    'exampleDialogue': exampleDialogue,
    'systemPrompt': systemPrompt,
    'postHistoryInstructions': postHistoryInstructions,
    'rawDefinition': rawDefinition,
  };

  factory CharacterProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.trim().isEmpty || name is! String) {
      throw const FormatException('Invalid character profile');
    }

    final rawType = json['type'];
    return CharacterProfile(
      id: id.trim(),
      type: CharacterCardType.fromName(rawType is String ? rawType : null),
      avatar: _readString(json['avatar']),
      name: name.trim(),
      tagline: _readString(json['tagline']),
      persona: _readString(json['persona']),
      personality: _readString(json['personality']),
      speakingStyle: _readString(json['speakingStyle']),
      background: _readString(json['background']),
      relationship: _readString(json['relationship']),
      likes: _readString(json['likes']),
      dislikes: _readString(json['dislikes']),
      boundaries: _readString(json['boundaries']),
      scenario: _readString(json['scenario']),
      greeting: _readString(json['greeting']),
      exampleDialogue: _readString(json['exampleDialogue']),
      systemPrompt: _readString(json['systemPrompt']),
      postHistoryInstructions: _readString(json['postHistoryInstructions']),
      rawDefinition: _readString(json['rawDefinition']),
    );
  }

  static String _readString(Object? value) {
    return value is String ? value.trim() : '';
  }
}
