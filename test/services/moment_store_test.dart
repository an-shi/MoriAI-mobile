import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MomentStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await MomentStore.instance.load();
  });

  test('adds and persists a moment', () async {
    final moment = await MomentStore.instance.add(
      authorId: 'mori',
      authorName: 'Mori',
      isUser: false,
      content: '今天天气很好。',
    );

    expect(moment.authorId, 'mori');
    expect(MomentStore.instance.moments.value, hasLength(1));

    await MomentStore.instance.load();
    final loaded = MomentStore.instance.moments.value.single;
    expect(loaded.id, moment.id);
    expect(loaded.authorName, 'Mori');
    expect(loaded.content, '今天天气很好。');
    expect(loaded.isUser, isFalse);
  });

  test('persists comments', () async {
    final moment = await MomentStore.instance.add(
      authorId: 'mori',
      authorName: 'Mori',
      isUser: false,
      content: '今天天气很好。',
    );

    await MomentStore.instance.addComment(
      moment.id,
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '确实不错。',
    );

    await MomentStore.instance.load();
    final loaded = MomentStore.instance.moments.value.single;
    expect(loaded.comments, hasLength(1));
    expect(loaded.comments.single.content, '确实不错。');
    expect(loaded.comments.single.isUser, isTrue);
  });

  test('deletes a moment', () async {
    final moment = await MomentStore.instance.add(
      authorId: 'mori',
      authorName: 'Mori',
      isUser: false,
      content: '准备删除的动态。',
    );

    await MomentStore.instance.delete(moment.id);

    expect(MomentStore.instance.moments.value, isEmpty);

    await MomentStore.instance.load();
    expect(MomentStore.instance.moments.value, isEmpty);
  });

  test('deletes a comment together with its replies', () async {
    final moment = await MomentStore.instance.add(
      authorId: 'mori',
      authorName: 'Mori',
      isUser: false,
      content: '今天天气很好。',
    );
    final parent = await MomentStore.instance.addComment(
      moment.id,
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '确实不错。',
    );
    await MomentStore.instance.addComment(
      moment.id,
      authorId: 'mori',
      authorName: 'Mori',
      isUser: false,
      content: '谢谢。',
      replyToCommentId: parent.id,
      replyToAuthorName: '我',
      replyDepth: 1,
    );
    await MomentStore.instance.addComment(
      moment.id,
      authorId: 'card_2',
      authorName: '小森',
      isUser: false,
      content: '我也觉得。',
    );

    await MomentStore.instance.deleteComment(moment.id, parent.id);

    final comments = MomentStore.instance.moments.value.single.comments;
    expect(comments.map((comment) => comment.content), ['我也觉得。']);

    await MomentStore.instance.load();
    expect(MomentStore.instance.moments.value.single.comments, hasLength(1));
  });

  test('deletes a character moments and comments', () async {
    final ownMoment = await MomentStore.instance.add(
      authorId: 'card_2',
      authorName: '小森',
      isUser: false,
      content: '准备删除的动态。',
    );
    final otherMoment = await MomentStore.instance.add(
      authorId: 'mori',
      authorName: 'Mori',
      isUser: false,
      content: '保留的动态。',
    );
    await MomentStore.instance.addComment(
      otherMoment.id,
      authorId: 'card_2',
      authorName: '小森',
      isUser: false,
      content: '小森的评论。',
    );
    await MomentStore.instance.addComment(
      otherMoment.id,
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '用户的评论。',
    );

    await MomentStore.instance.deleteForCharacter('card_2');

    expect(MomentStore.instance.momentById(ownMoment.id), isNull);
    final remaining = MomentStore.instance.momentById(otherMoment.id);
    expect(remaining, isNotNull);
    expect(remaining!.comments.map((comment) => comment.authorId), ['user']);
  });

  test(
    'loads moments from newest to oldest and skips invalid entries',
    () async {
      final raw = jsonEncode([
        {
          'id': 'old',
          'authorId': 'mori',
          'authorName': 'Mori',
          'isUser': false,
          'content': '较早的动态',
          'createdAt': '2026-11-07T10:00:00.000',
        },
        {'id': 'broken'},
        {
          'id': 'new',
          'authorId': 'user',
          'authorName': '小森',
          'isUser': true,
          'content': '较新的动态',
          'createdAt': '2026-11-08T10:00:00.000',
        },
      ]);
      SharedPreferences.setMockInitialValues({'moments_v1': raw});

      await MomentStore.instance.load();

      final moments = MomentStore.instance.moments.value;
      expect(moments, hasLength(2));
      expect(moments.first.content, '较新的动态');
      expect(moments.last.content, '较早的动态');
    },
  );
}
