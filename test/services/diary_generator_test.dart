import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/diary_generator.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await CharacterActivityStore.instance.load();
    await MoodStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await CharacterActivityStore.instance.load();
    await MoodStore.instance.load();
  });

  test('builds a diary from meaningful messages and own activities', () async {
    final character = CharacterStore.instance.cardById(
      CharacterProfile.presetMoriId,
    )!;
    final day = DateTime(2026, 11, 8);
    await ChatHistoryStore.instance.saveFor(character.id, [
      ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        content: '今天面试通过了，特别开心',
        createdAt: day.add(const Duration(hours: 9)),
      ),
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        content: '太好了，我就知道你可以',
        createdAt: day.add(const Duration(hours: 9, minutes: 1)),
      ),
      ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        content: '嗯',
        createdAt: day.add(const Duration(hours: 9, minutes: 2)),
      ),
      ChatMessage(
        id: 'u3',
        role: ChatRole.user,
        content: '哈哈',
        createdAt: day.add(const Duration(hours: 9, minutes: 3)),
      ),
      ChatMessage(
        id: 'u4',
        role: ChatRole.user,
        content: '明天想一起去吃火锅吗',
        createdAt: day.add(const Duration(hours: 20)),
      ),
      ChatMessage(
        id: 'a2',
        role: ChatRole.assistant,
        content: '好呀，明天晚上见',
        createdAt: day.add(const Duration(hours: 20, minutes: 1)),
      ),
    ]);
    await CharacterActivityStore.instance.record(
      CharacterActivity(
        id: 'moment_1',
        characterId: character.id,
        kind: CharacterActivityKind.moment,
        contextId: 'moment_1',
        contextLabel: '动态',
        content: '今天发了一条关于秋天的动态',
        createdAtMs: day.add(const Duration(hours: 18)).millisecondsSinceEpoch,
      ),
    );
    await CharacterActivityStore.instance.record(
      CharacterActivity(
        id: 'group_1',
        characterId: character.id,
        kind: CharacterActivityKind.groupMessage,
        contextId: 'group_1',
        contextLabel: '测试群',
        content: '晚上一起打游戏吗',
        createdAtMs: day.add(const Duration(hours: 19)).millisecondsSinceEpoch,
      ),
    );
    await MoodStore.instance.nudge(character.id, 20, '被夸了');

    String? capturedSystem;
    String? capturedUser;
    final generator = DiaryGenerator(
      complete: ({required systemPrompt, required userPrompt}) async {
        capturedSystem = systemPrompt;
        capturedUser = userPrompt;
        return 'Mori：「今天面试通过了，我很开心。晚上还一起去吃了火锅。」';
      },
    );

    final entry = await generator.generateForDay(
      character,
      day,
      now: day.add(const Duration(hours: 22, minutes: 30)),
    );

    expect(entry, isNotNull);
    expect(entry!.dateKey, '2026-11-08');
    expect(entry.content, '今天面试通过了，我很开心。晚上还一起去吃了火锅。');
    expect(entry.moodValue, inInclusiveRange(0, 100));
    expect(entry.moodLabel, isNotEmpty);
    expect(entry.messageCount, 6);
    expect(capturedSystem, contains('【日记模式】'));
    expect(capturedUser, contains('今天面试通过了'));
    expect(capturedUser, contains('明天想一起去吃火锅吗'));
    expect(capturedUser, contains('我发了动态'));
    expect(capturedUser, contains('今天发了一条关于秋天的动态'));
    expect(capturedUser, contains('我在群聊「测试群」说'));
    expect(capturedUser, contains('晚上一起打游戏吗'));
    expect(capturedUser, contains('不要逐条复述聊天记录'));
    expect(capturedUser, isNot(contains('对方：嗯')));
    expect(capturedUser, isNot(contains('对方：哈哈')));
  });

  test('handles a quiet day without inventing material', () async {
    final character = CharacterStore.instance.cardById(
      CharacterProfile.presetMoriId,
    )!;
    final day = DateTime(2026, 11, 9);
    String? capturedUser;
    final generator = DiaryGenerator(
      complete: ({required systemPrompt, required userPrompt}) async {
        capturedUser = userPrompt;
        return '今天很安静，没发生什么特别的事，但心里挺平静的。';
      },
    );

    final entry = await generator.generateForDay(
      character,
      day,
      now: day.add(const Duration(hours: 22, minutes: 30)),
    );

    expect(entry, isNotNull);
    expect(capturedUser, contains('今天没有聊天，也没有发布动态。'));
    expect(entry!.messageCount, 0);
  });

  test('returns null when the model chooses to skip', () async {
    final character = CharacterStore.instance.cardById(
      CharacterProfile.presetMoriId,
    )!;
    final day = DateTime(2026, 11, 10);
    final generator = DiaryGenerator(
      complete: ({required systemPrompt, required userPrompt}) async => '[跳过]',
    );

    final entry = await generator.generateForDay(
      character,
      day,
      now: day.add(const Duration(hours: 22, minutes: 30)),
    );

    expect(entry, isNull);
  });
}
