import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/mood_judge_service.dart';

void main() {
  test('parses a model mood judgment', () async {
    String? capturedSystem;
    String? capturedUser;
    final service = MoodJudgeService(
      complete: ({required systemPrompt, required userPrompt}) async {
        capturedSystem = systemPrompt;
        capturedUser = userPrompt;
        return '{"delta":8,"reason":"用户说喜欢你"}';
      },
    );

    final result = await service.judge(
      characterName: 'Mori',
      currentMood: 60,
      userText: '我喜欢你，今天也很可爱',
      recentMessages: [
        ChatMessage(
          id: 'u1',
          role: ChatRole.user,
          content: '我喜欢你，今天也很可爱',
          createdAt: DateTime(2026, 11, 9, 10),
        ),
      ],
    );

    expect(result, isNotNull);
    expect(result!.delta, 8);
    expect(result.reason, '用户说喜欢你');
    expect(capturedSystem, contains('心情判断器'));
    expect(capturedSystem, contains('Mori'));
    expect(capturedUser, contains('我喜欢你'));
  });

  test('clamps the delta and rejects invalid output', () async {
    var raw = '{"delta":99,"reason":"用户夸了角色"}';
    final service = MoodJudgeService(
      complete: ({required systemPrompt, required userPrompt}) async => raw,
    );

    final result = await service.judge(
      characterName: 'Mori',
      currentMood: 50,
      userText: '你真棒',
      recentMessages: const [],
    );
    expect(result!.delta, 20);

    raw = '不是 JSON';
    expect(
      await service.judge(
        characterName: 'Mori',
        currentMood: 50,
        userText: '你好',
        recentMessages: const [],
      ),
      isNull,
    );

    raw = '{"delta":3,"reason":""}';
    expect(
      await service.judge(
        characterName: 'Mori',
        currentMood: 50,
        userText: '你好',
        recentMessages: const [],
      ),
      isNull,
    );
  });
}
