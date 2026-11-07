import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/config/mori_config.dart';
import 'package:mori_ai/models/character_profile.dart';

void main() {
  test('builds the system prompt from the active character card', () {
    const profile = CharacterProfile(
      id: 'custom',
      name: '小森',
      persona: '冷静、简洁，喜欢倾听。',
    );

    final prompt = MoriConfig.buildSystemPrompt(profile);

    expect(prompt, contains('小森'));
    expect(prompt, contains('冷静、简洁，喜欢倾听。'));
    expect(prompt, isNot(contains('Mori')));
  });

  test('uses generic fallback values for an unnamed character card', () {
    const profile = CharacterProfile(id: 'custom', name: '', persona: '');

    final prompt = MoriConfig.buildSystemPrompt(profile);

    expect(prompt, contains(CharacterProfile.fallbackDisplayName));
    expect(prompt, contains(CharacterProfile.defaultPersona));
    expect(prompt, isNot(contains('Mori')));
  });

  test('uses the preset Mori character when it is active', () {
    final prompt = MoriConfig.buildSystemPrompt(CharacterProfile.presetMori);

    expect(prompt, contains('Mori'));
    expect(prompt, contains(CharacterProfile.defaultPersona));
    expect(prompt, contains('性格特点'));
  });

  test('only includes fields enabled by the selected card type', () {
    const simple = CharacterProfile(
      id: 'simple',
      name: '小森',
      persona: '简单人格描述。',
      scenario: '不应该生效的场景。',
      systemPrompt: '不应该生效的系统指令。',
    );
    final simplePrompt = MoriConfig.buildSystemPrompt(simple);
    expect(simplePrompt, contains('简单人格描述。'));
    expect(simplePrompt, isNot(contains('不应该生效的场景。')));
    expect(simplePrompt, isNot(contains('不应该生效的系统指令。')));

    const advanced = CharacterProfile(
      id: 'advanced',
      type: CharacterCardType.advanced,
      name: '小森',
      persona: '简单人格描述。',
      scenario: '安静的夜晚。',
      systemPrompt: '保持简洁。',
    );
    final advancedPrompt = MoriConfig.buildSystemPrompt(advanced);
    expect(advancedPrompt, contains('安静的夜晚。'));
    expect(advancedPrompt, contains('保持简洁。'));
  });

  test('uses pasted raw definition directly without rebuilding fields', () {
    const raw = '''你是小森，一个安静、耐心、喜欢倾听的伙伴。
说话简洁自然，每次回复不超过三句话。
当用户难过时，先回应情绪，再给出建议。''';
    const profile = CharacterProfile(
      id: 'pasted',
      type: CharacterCardType.paste,
      name: '小森',
      persona: '这段人格不应该被使用。',
      rawDefinition: raw,
    );

    final prompt = MoriConfig.buildSystemPrompt(profile);

    expect(prompt.trim(), raw);
    expect(prompt, isNot(contains('这段人格不应该被使用。')));
    expect(prompt, isNot(contains('请用简体中文和用户自然聊天')));
  });
}
