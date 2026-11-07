import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';

void main() {
  test('serializes and restores avatar and extended card fields', () {
    const profile = CharacterProfile(
      id: 'card_1',
      type: CharacterCardType.roleplay,
      avatar: 'card_1_avatar.jpg',
      name: '小森',
      tagline: '安静的陪伴者',
      persona: '温柔、耐心。',
      personality: '细心，有一点幽默感。',
      speakingStyle: '回复简洁自然。',
      background: '来自一个安静的小镇。',
      relationship: '熟悉的朋友。',
      likes: '植物和音乐。',
      dislikes: '过度客套。',
      boundaries: '不假装人类。',
      scenario: '雨夜的书店。',
      greeting: '你来了。',
      exampleDialogue: '<START>\n{{user}}: 嗨\n{{char}}: 欢迎。',
      systemPrompt: '保持简洁。',
      postHistoryInstructions: '先回应情绪。',
      rawDefinition: '完整粘贴的角色卡设定。',
    );

    final restored = CharacterProfile.fromJson(profile.toJson());

    expect(restored.id, profile.id);
    expect(restored.type, CharacterCardType.roleplay);
    expect(restored.avatar, 'card_1_avatar.jpg');
    expect(restored.name, '小森');
    expect(restored.tagline, '安静的陪伴者');
    expect(restored.persona, '温柔、耐心。');
    expect(restored.personality, '细心，有一点幽默感。');
    expect(restored.speakingStyle, '回复简洁自然。');
    expect(restored.background, '来自一个安静的小镇。');
    expect(restored.relationship, '熟悉的朋友。');
    expect(restored.likes, '植物和音乐。');
    expect(restored.dislikes, '过度客套。');
    expect(restored.boundaries, '不假装人类。');
    expect(restored.scenario, '雨夜的书店。');
    expect(restored.greeting, '你来了。');
    expect(restored.exampleDialogue, '<START>\n{{user}}: 嗨\n{{char}}: 欢迎。');
    expect(restored.systemPrompt, '保持简洁。');
    expect(restored.postHistoryInstructions, '先回应情绪。');
    expect(restored.rawDefinition, '完整粘贴的角色卡设定。');
  });

  test('reads old cards without type or avatar as simple cards', () {
    final restored = CharacterProfile.fromJson({
      'id': 'old',
      'name': '旧角色',
      'persona': '旧的人格设定。',
    });

    expect(restored.type, CharacterCardType.simple);
    expect(restored.avatar, isEmpty);
    expect(restored.persona, '旧的人格设定。');
  });
}
