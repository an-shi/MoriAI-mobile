import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/group_memory.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/group_memory_extractor.dart';

void main() {
  test('parses group memories and the group impression', () async {
    String? capturedSystem;
    String? capturedUser;
    final extractor = GroupMemoryExtractor(
      complete: ({required systemPrompt, required userPrompt}) async {
        capturedSystem = systemPrompt;
        capturedUser = userPrompt;
        return '''
{
  "memories": [
    {"text":"大家约好下个月一起去看展","category":"plan","importance":0.8,"tags":["看展"]},
    {"text":"群里的密码是 123456","category":"fact","importance":0.9}
  ],
  "profile": {
    "summary": "大家像大学宿舍室友一样熟。",
    "sharedHabits": "经常互相发梗图和深夜吐槽。",
    "recentFocus": "最近在约一起看展。",
    "importantDates": ["下个月第一个周末去看展"]
  }
}
''';
      },
    );

    final group = GroupProfile(
      id: 'group_1',
      name: '深夜聊天室',
      memberIds: const ['mori', 'sen'],
      createdAt: DateTime(2026, 11, 1),
    );
    final result = await extractor.extract(
      group: group,
      members: const [
        CharacterProfile.presetMori,
        CharacterProfile(id: 'sen', name: '小森', persona: '安静、耐心。'),
      ],
      messages: [
        ChatMessage(
          id: 'g1',
          role: ChatRole.user,
          content: '大家下个月一起去看展吧。',
          senderId: 'user',
          senderName: '我',
          createdAt: DateTime(2026, 11, 8, 21),
        ),
        ChatMessage(
          id: 'g2',
          role: ChatRole.assistant,
          content: '好啊，我来订票。',
          senderId: 'sen',
          senderName: '小森',
          createdAt: DateTime(2026, 11, 8, 21, 1),
        ),
      ],
      existing: [
        GroupMemoryEntry(
          id: 'old',
          groupId: 'group_1',
          text: '大家经常一起吐槽工作。',
          createdAtMs: 1000,
          updatedAtMs: 1000,
        ),
      ],
      profile: const GroupMemoryProfile(groupId: 'group_1', summary: '大家是朋友。'),
    );

    expect(result.candidates, hasLength(1));
    expect(result.candidates.single.category, MemoryCategory.plan);
    expect(result.candidates.single.importance, 0.8);
    expect(result.profile.groupId, 'group_1');
    expect(result.profile.summary, contains('宿舍室友'));
    expect(result.profile.sharedHabits, contains('梗图'));
    expect(result.profile.recentFocus, contains('看展'));
    expect(result.profile.importantDates.single, contains('第一个周末'));
    expect(capturedSystem, contains('深夜聊天室'));
    expect(capturedSystem, contains('小森'));
    expect(capturedUser, contains('大家经常一起吐槽工作'));
    expect(capturedUser, contains('21:00 用户：大家下个月一起去看展吧'));
    expect(capturedUser, contains('21:01 小森：好啊，我来订票'));
  });

  test('accepts a plain memory array for compatibility', () async {
    final extractor = GroupMemoryExtractor(
      complete: ({required systemPrompt, required userPrompt}) async =>
          '[{"text":"大家经常一起打游戏","category":"event","importance":0.6}]',
    );
    final group = GroupProfile(
      id: 'group_1',
      name: '群聊',
      memberIds: const ['mori', 'sen'],
      createdAt: DateTime(2026, 11, 1),
    );
    final result = await extractor.extract(
      group: group,
      members: const [],
      messages: const [],
      existing: const [],
    );
    expect(result.candidates, hasLength(1));
    expect(result.profile.isEmpty, isTrue);
  });

  test('throws on invalid JSON', () async {
    final extractor = GroupMemoryExtractor(
      complete: ({required systemPrompt, required userPrompt}) async =>
          '不是 JSON',
    );
    final group = GroupProfile(
      id: 'group_1',
      name: '群聊',
      memberIds: const ['mori', 'sen'],
      createdAt: DateTime(2026, 11, 1),
    );
    expect(
      () => extractor.extract(
        group: group,
        members: const [],
        messages: const [],
        existing: const [],
      ),
      throwsA(isA<MemoryException>()),
    );
  });
}
