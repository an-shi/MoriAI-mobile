import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/models/moment_interaction_settings.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/moment_generator.dart';
import 'package:mori_ai/services/moment_interaction_service.dart';
import 'package:mori_ai/services/moment_interaction_settings_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMomentGenerator implements MomentGenerator {
  int commentCalls = 0;
  int replyCalls = 0;

  @override
  Future<String> generateForCharacter(CharacterProfile character) async {
    return '测试动态';
  }

  @override
  Future<String> generateCommentForCharacter({
    required CharacterProfile character,
    required Moment moment,
  }) async {
    commentCalls++;
    return '这条动态很有意思。';
  }

  @override
  Future<String> generateReplyForCharacter({
    required CharacterProfile character,
    required Moment moment,
    required MomentComment replyTo,
  }) async {
    replyCalls++;
    return '谢谢你的评论。';
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MomentStore.instance.load();
    await MomentInteractionSettingsStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MomentStore.instance.load();
    await MomentInteractionSettingsStore.instance.load();
  });

  test('automatically comments on a character moment', () async {
    final secondCard = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    final moment = await MomentStore.instance.add(
      authorId: CharacterProfile.presetMoriId,
      authorName: 'Mori',
      isUser: false,
      content: '今天出去散步了。',
    );
    final generator = _FakeMomentGenerator();
    final service = MomentInteractionService(
      generator: generator,
      random: Random(1),
    );
    addTearDown(service.dispose);

    await service.onMomentCreated(moment);

    final updated = MomentStore.instance.momentById(moment.id);
    expect(updated, isNotNull);
    expect(updated!.comments, hasLength(2));
    expect(updated.comments.first.authorId, secondCard.id);
    expect(updated.comments.first.isUser, isFalse);
    expect(updated.comments.last.authorId, CharacterProfile.presetMoriId);
    expect(updated.comments.last.replyToCommentId, updated.comments.first.id);
    expect(generator.commentCalls, 1);
    expect(generator.replyCalls, 1);
  });

  test(
    'automatically replies between characters under a user moment',
    () async {
      await CharacterStore.instance.addCard(name: '小森', persona: '安静、耐心。');
      await MomentInteractionSettingsStore.instance.save(
        const MomentInteractionSettings(autoCommentCount: 1),
      );
      final moment = await MomentStore.instance.add(
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '今天出去散步了。',
      );
      final generator = _FakeMomentGenerator();
      final service = MomentInteractionService(
        generator: generator,
        random: Random(1),
      );
      addTearDown(service.dispose);

      await service.onMomentCreated(moment);

      final updated = MomentStore.instance.momentById(moment.id);
      expect(updated, isNotNull);
      expect(updated!.comments, hasLength(2));
      expect(updated.comments.every((comment) => !comment.isUser), isTrue);
      expect(
        updated.comments.first.authorId,
        isNot(updated.comments.last.authorId),
      );
      expect(updated.comments.last.replyToCommentId, updated.comments.first.id);
      expect(generator.commentCalls, 1);
      expect(generator.replyCalls, 1);
    },
  );

  test('uses configurable interaction counts', () async {
    await CharacterStore.instance.addCard(name: '角色 A', persona: 'A');
    await CharacterStore.instance.addCard(name: '角色 B', persona: 'B');
    await CharacterStore.instance.addCard(name: '角色 C', persona: 'C');
    await MomentInteractionSettingsStore.instance.save(
      const MomentInteractionSettings(autoCommentCount: 2, autoReplyDepth: 2),
    );
    final moment = await MomentStore.instance.add(
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '今天出去散步了。',
    );
    final generator = _FakeMomentGenerator();
    final service = MomentInteractionService(
      generator: generator,
      random: Random(1),
    );
    addTearDown(service.dispose);

    await service.onMomentCreated(moment);

    final updated = MomentStore.instance.momentById(moment.id);
    expect(updated, isNotNull);

    final topLevelComments = updated!.comments
        .where((comment) => comment.replyToCommentId.isEmpty)
        .toList();
    expect(topLevelComments, hasLength(2));
    expect(updated.comments.any((comment) => comment.replyDepth == 2), isTrue);
    expect(generator.commentCalls, 2);
    expect(generator.replyCalls, greaterThanOrEqualTo(2));
  });

  test('can disable automatic interactions', () async {
    await MomentInteractionSettingsStore.instance.save(
      const MomentInteractionSettings(autoCommentCount: 0, autoReplyDepth: 0),
    );
    final moment = await MomentStore.instance.add(
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '今天出去散步了。',
    );
    final generator = _FakeMomentGenerator();
    final service = MomentInteractionService(
      generator: generator,
      random: Random(1),
    );
    addTearDown(service.dispose);

    await service.onMomentCreated(moment);

    final updated = MomentStore.instance.momentById(moment.id);
    expect(updated!.comments, isEmpty);
    expect(generator.commentCalls, 0);
    expect(generator.replyCalls, 0);
  });

  test('automatically replies to a user comment', () async {
    final moment = await MomentStore.instance.add(
      authorId: CharacterProfile.presetMoriId,
      authorName: 'Mori',
      isUser: false,
      content: '今天出去散步了。',
    );
    final comment = await MomentStore.instance.addComment(
      moment.id,
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '散步确实很舒服。',
    );
    final generator = _FakeMomentGenerator();
    final service = MomentInteractionService(
      generator: generator,
      random: Random(1),
    );
    addTearDown(service.dispose);

    await service.onCommentCreated(moment, comment);

    final updated = MomentStore.instance.momentById(moment.id);
    expect(updated, isNotNull);
    expect(updated!.comments, hasLength(2));
    final reply = updated.comments.last;
    expect(reply.isUser, isFalse);
    expect(reply.authorId, CharacterProfile.presetMoriId);
    expect(reply.replyToCommentId, comment.id);
    expect(reply.replyToAuthorName, '我');
    expect(generator.replyCalls, 1);
  });

  test('lets another character join a user comment thread', () async {
    final secondCard = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '安静、耐心。',
    );
    await MomentInteractionSettingsStore.instance.save(
      const MomentInteractionSettings(autoCommentCount: 2, autoReplyDepth: 1),
    );
    final moment = await MomentStore.instance.add(
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '今天出去散步了。',
    );
    final comment = await MomentStore.instance.addComment(
      moment.id,
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '散步确实很舒服。',
    );
    final generator = _FakeMomentGenerator();
    final service = MomentInteractionService(
      generator: generator,
      random: Random(1),
    );
    addTearDown(service.dispose);

    await service.onCommentCreated(moment, comment);

    final updated = MomentStore.instance.momentById(moment.id);
    expect(updated, isNotNull);
    expect(updated!.comments, hasLength(3));
    final replies = updated.comments
        .where((item) => item.replyToCommentId == comment.id)
        .toList();
    expect(replies, hasLength(2));
    expect(replies.map((item) => item.authorId).toSet(), {
      CharacterProfile.presetMoriId,
      secondCard.id,
    });
    expect(replies.every((item) => item.replyDepth == 1), isTrue);
  });

  test(
    'replies to a user reply even when auto reply depth is disabled',
    () async {
      await MomentInteractionSettingsStore.instance.save(
        const MomentInteractionSettings(autoCommentCount: 0, autoReplyDepth: 0),
      );
      final moment = await MomentStore.instance.add(
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '今天出去散步了。',
      );
      final characterComment = await MomentStore.instance.addComment(
        moment.id,
        authorId: CharacterProfile.presetMoriId,
        authorName: 'Mori',
        isUser: false,
        content: '散步确实很舒服。',
      );
      final userReply = await MomentStore.instance.addComment(
        moment.id,
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '你也一起去吧。',
        replyToCommentId: characterComment.id,
        replyToAuthorName: 'Mori',
        replyDepth: 1,
      );
      final generator = _FakeMomentGenerator();
      final service = MomentInteractionService(
        generator: generator,
        random: Random(1),
      );
      addTearDown(service.dispose);

      await service.onCommentCreated(moment, userReply);

      final updated = MomentStore.instance.momentById(moment.id);
      expect(updated, isNotNull);
      expect(updated!.comments, hasLength(3));
      final reply = updated.comments.last;
      expect(reply.isUser, isFalse);
      expect(reply.authorId, CharacterProfile.presetMoriId);
      expect(reply.replyToCommentId, userReply.id);
      expect(reply.replyDepth, 2);
      expect(generator.replyCalls, 1);
    },
  );

  test('does not reply to an automatic reply again', () async {
    final moment = await MomentStore.instance.add(
      authorId: CharacterProfile.presetMoriId,
      authorName: 'Mori',
      isUser: false,
      content: '今天出去散步了。',
    );
    final comment = await MomentStore.instance.addComment(
      moment.id,
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '散步确实很舒服。',
    );
    final reply = await MomentStore.instance.addComment(
      moment.id,
      authorId: CharacterProfile.presetMoriId,
      authorName: 'Mori',
      isUser: false,
      content: '谢谢你的评论。',
      replyToCommentId: comment.id,
      replyToAuthorName: '用户',
    );
    final generator = _FakeMomentGenerator();
    final service = MomentInteractionService(
      generator: generator,
      random: Random(1),
    );
    addTearDown(service.dispose);

    await service.onCommentCreated(moment, reply);

    final updated = MomentStore.instance.momentById(moment.id);
    expect(updated!.comments, hasLength(2));
    expect(generator.replyCalls, 0);
  });
}
