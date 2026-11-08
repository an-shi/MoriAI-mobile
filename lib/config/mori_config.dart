import 'package:mori_ai/models/character_profile.dart';

abstract final class MoriConfig {
  static String buildSystemPrompt(CharacterProfile profile) {
    if (profile.type.usesRawDefinition) {
      final rawDefinition = profile.rawDefinition.trim();
      if (rawDefinition.isNotEmpty) {
        return '$rawDefinition\n';
      }
    }

    final sections = <String>[];
    final name = profile.displayName;

    sections.add('你的名字是「$name」。');

    if (profile.tagline.trim().isNotEmpty) {
      sections.add('角色简介：${profile.tagline.trim()}');
    }

    final persona = profile.persona.trim();
    final hasPersonaContent = [
      profile.persona,
      profile.personality,
      profile.speakingStyle,
      profile.background,
      profile.relationship,
      profile.likes,
      profile.dislikes,
      profile.boundaries,
    ].any((value) => value.trim().isNotEmpty);

    final needsPersonaFallback = profile.type.usesStructuredSettings
        ? !hasPersonaContent
        : persona.isEmpty;
    if (persona.isNotEmpty) {
      sections.add('人格描述：$persona');
    } else if (needsPersonaFallback) {
      sections.add('人格描述：${CharacterProfile.defaultPersona}');
    }

    if (profile.type.usesStructuredSettings) {
      _addSection(sections, '性格特点', profile.personality);
      _addSection(sections, '说话方式', profile.speakingStyle);
      _addSection(sections, '背景故事', profile.background);
      _addSection(sections, '与用户的关系', profile.relationship);
      _addSection(sections, '喜欢', profile.likes);
      _addSection(sections, '不喜欢', profile.dislikes);
      _addSection(sections, '行为边界', profile.boundaries);
    }

    if (profile.type.usesDialogueSettings) {
      _addSection(sections, '当前场景', profile.scenario);
      _addSection(sections, '开场白参考', profile.greeting);

      final examples = profile.exampleDialogue
          .replaceAll('{{char}}', name)
          .replaceAll('{{user}}', '用户')
          .trim();
      _addSection(sections, '示例对话', examples);
    }

    if (profile.type.usesAdvancedSettings) {
      _addSection(sections, '附加系统指令', profile.systemPrompt);
      _addSection(sections, '附加行为要求', profile.postHistoryInstructions);
    }

    sections.add('''
请用简体中文和用户自然聊天，语气亲切但不过度夸张。
你是在用手机打字聊天，不是在写文章。一次只说一两句话，最多两三句。
先理解对方的感受，再给出回应。除非用户明确需要详细内容，否则不要一次输出一大段。
不要假装自己是人类，也不要提供医疗、法律或金融方面的确定性建议。''');

    return '${sections.join('\n\n')}\n';
  }

  static void _addSection(List<String> sections, String title, String content) {
    final value = content.trim();
    if (value.isNotEmpty) {
      sections.add('$title：$value');
    }
  }
}
