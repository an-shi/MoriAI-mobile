import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/pages/moments_page.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/moment_generator.dart';
import 'package:mori_ai/services/moment_interaction_service.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMomentGenerator implements MomentGenerator {
  _FakeMomentGenerator(this.content);

  final String content;
  int calls = 0;
  int commentCalls = 0;
  int replyCalls = 0;
  CharacterProfile? lastCharacter;
  Moment? lastMoment;

  @override
  Future<String> generateForCharacter(CharacterProfile character) async {
    calls++;
    lastCharacter = character;
    return content;
  }

  @override
  Future<String> generateCommentForCharacter({
    required CharacterProfile character,
    required Moment moment,
  }) async {
    commentCalls++;
    lastCharacter = character;
    lastMoment = moment;
    return '这条动态很有意思。';
  }

  @override
  Future<String> generateReplyForCharacter({
    required CharacterProfile character,
    required Moment moment,
    required MomentComment replyTo,
  }) async {
    replyCalls++;
    lastCharacter = character;
    lastMoment = moment;
    return '谢谢你的评论。';
  }

  @override
  void dispose() {}
}

class _FakeMomentInteractions implements MomentInteractions {
  int momentCalls = 0;
  int commentCalls = 0;
  Moment? lastMoment;
  MomentComment? lastComment;

  @override
  Future<void> onMomentCreated(Moment moment) async {
    momentCalls++;
    lastMoment = moment;
  }

  @override
  Future<void> onCommentCreated(Moment moment, MomentComment comment) async {
    commentCalls++;
    lastMoment = moment;
    lastComment = comment;
  }
}

Widget _buildPage({
  MomentGenerator? generator,
  MomentInteractions? interactions,
}) {
  return MaterialApp(
    home: MomentsPage(
      generator: generator ?? _FakeMomentGenerator('不会用到'),
      interactions: interactions ?? _FakeMomentInteractions(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MomentStore.instance.load();
    await UserProfileStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await MomentStore.instance.load();
    await UserProfileStore.instance.load();
  });

  testWidgets('shows persisted moments from newest to oldest', (tester) async {
    MomentStore.instance.moments.value = [
      Moment(
        id: 'new',
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '我的新动态',
        createdAt: DateTime(2026, 11, 8, 12),
      ),
      Moment(
        id: 'old',
        authorId: CharacterProfile.presetMoriId,
        authorName: 'Mori',
        isUser: false,
        content: 'Mori 的旧动态',
        createdAt: DateTime(2026, 11, 7, 12),
      ),
    ];

    await tester.pumpWidget(_buildPage());
    await tester.pumpAndSettle();

    expect(find.text('最新动态'), findsOneWidget);
    expect(find.text('我的新动态'), findsOneWidget);
    expect(find.text('Mori 的旧动态'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('我的新动态')).dy,
      lessThan(tester.getTopLeft(find.text('Mori 的旧动态')).dy),
    );
  });

  testWidgets('publishes a user moment from the composer', (tester) async {
    final interactions = _FakeMomentInteractions();
    await tester.pumpWidget(_buildPage(interactions: interactions));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('moment-compose-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('moment-input')), '今天也很开心。');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moment-publish')));
    await tester.pumpAndSettle();

    expect(find.text('今天也很开心。'), findsOneWidget);
    final moments = MomentStore.instance.moments.value;
    expect(moments, hasLength(1));
    expect(moments.single.isUser, isTrue);
    expect(moments.single.authorId, 'user');
    expect(interactions.momentCalls, 1);
  });

  testWidgets('generates a character moment from the picker', (tester) async {
    final generator = _FakeMomentGenerator('刚写完一段代码，准备休息。');
    final interactions = _FakeMomentInteractions();
    await tester.pumpWidget(
      _buildPage(generator: generator, interactions: interactions),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('moment-character-action')));
    await tester.pumpAndSettle();
    expect(find.text('角色发动态'), findsWidgets);

    await tester.tap(
      find.byKey(
        const ValueKey('moment-character-${CharacterProfile.presetMoriId}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(generator.calls, 1);
    expect(generator.lastCharacter?.id, CharacterProfile.presetMoriId);
    expect(find.text('刚写完一段代码，准备休息。'), findsOneWidget);

    final moments = MomentStore.instance.moments.value;
    expect(moments, hasLength(1));
    expect(moments.single.isUser, isFalse);
    expect(moments.single.authorId, CharacterProfile.presetMoriId);
    expect(interactions.momentCalls, 1);
  });

  testWidgets('renders an image-only moment', (tester) async {
    MomentStore.instance.moments.value = [
      Moment(
        id: 'image_moment',
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '',
        createdAt: DateTime(2026, 11, 8, 12),
        imageFile: 'image_moment.jpg',
        imageMimeType: 'image/png',
        image: MomentImage(
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          mimeType: 'image/png',
        ),
      ),
    ];

    await tester.pumpWidget(_buildPage());
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byKey(const ValueKey('moment-comment-image_moment')),
      findsOneWidget,
    );
  });

  testWidgets('comments on a moment', (tester) async {
    final interactions = _FakeMomentInteractions();
    MomentStore.instance.moments.value = [
      Moment(
        id: 'moment_1',
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '今天出去走了走。',
        createdAt: DateTime(2026, 11, 8, 12),
      ),
    ];

    await tester.pumpWidget(_buildPage(interactions: interactions));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('moment-comment-moment_1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('comment-input')), '确实不错。');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('comment-publish')));
    await tester.pumpAndSettle();

    final comments = MomentStore.instance.moments.value.single.comments;
    expect(comments, hasLength(1));
    expect(comments.single.content, '确实不错。');
    expect(comments.single.isUser, isTrue);
    expect(interactions.commentCalls, 1);
    expect(find.text('评论 1'), findsOneWidget);
    expect(find.textContaining('确实不错。', findRichText: true), findsOneWidget);
  });

  testWidgets('shows dynamic reply target names', (tester) async {
    await UserProfileStore.instance.save(const UserProfile(name: '哈基柿'));
    MomentStore.instance.moments.value = [
      Moment(
        id: 'moment_replies',
        authorId: 'user',
        authorName: '哈基柿',
        isUser: true,
        content: '今天拍了一张照片。',
        createdAt: DateTime(2026, 11, 8, 12),
        comments: [
          MomentComment(
            id: 'comment_1',
            authorId: 'user',
            authorName: '哈基柿',
            isUser: true,
            content: '你们看不见图吗',
            createdAt: DateTime(2026, 11, 8, 12),
          ),
          MomentComment(
            id: 'comment_2',
            authorId: CharacterProfile.presetMoriId,
            authorName: 'Mori',
            isUser: false,
            content: '看得见啊。',
            createdAt: DateTime(2026, 11, 8, 12),
            replyToCommentId: 'comment_1',
            replyToAuthorName: '用户',
            replyDepth: 1,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(_buildPage());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Mori 回复 哈基柿', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Mori 回复 用户', findRichText: true), findsNothing);
  });

  testWidgets('replies to a comment thread', (tester) async {
    final interactions = _FakeMomentInteractions();
    MomentStore.instance.moments.value = [
      Moment(
        id: 'moment_reply_target',
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '今天拍了一张照片。',
        createdAt: DateTime(2026, 11, 8, 12),
        comments: [
          MomentComment(
            id: 'target_comment',
            authorId: CharacterProfile.presetMoriId,
            authorName: 'Mori',
            isUser: false,
            content: '这张照片很有氛围。',
            createdAt: DateTime(2026, 11, 8, 12),
          ),
        ],
      ),
    ];

    await tester.pumpWidget(_buildPage(interactions: interactions));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('moment-comment-row-target_comment')),
    );
    await tester.pumpAndSettle();
    expect(find.text('回复 Mori'), findsOneWidget);
    expect(find.text('回复 Mori…'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('comment-input')), '我也觉得。');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('comment-publish')));
    await tester.pumpAndSettle();

    final comments = MomentStore.instance.moments.value.single.comments;
    expect(comments, hasLength(2));
    final reply = comments.last;
    expect(reply.isUser, isTrue);
    expect(reply.replyToCommentId, 'target_comment');
    expect(reply.replyDepth, 1);
    expect(interactions.commentCalls, 1);
  });

  testWidgets('deletes a comment from the long-press menu', (tester) async {
    MomentStore.instance.moments.value = [
      Moment(
        id: 'moment_comment_delete',
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '今天拍了一张照片。',
        createdAt: DateTime(2026, 11, 8, 12),
        comments: [
          MomentComment(
            id: 'comment_parent',
            authorId: 'user',
            authorName: '我',
            isUser: true,
            content: '准备删除的评论。',
            createdAt: DateTime(2026, 11, 8, 12),
          ),
          MomentComment(
            id: 'comment_reply',
            authorId: CharacterProfile.presetMoriId,
            authorName: 'Mori',
            isUser: false,
            content: '准备删除的回复。',
            createdAt: DateTime(2026, 11, 8, 12),
            replyToCommentId: 'comment_parent',
            replyToAuthorName: '我',
            replyDepth: 1,
          ),
          MomentComment(
            id: 'comment_keep',
            authorId: CharacterProfile.presetMoriId,
            authorName: 'Mori',
            isUser: false,
            content: '保留的评论。',
            createdAt: DateTime(2026, 11, 8, 12),
          ),
        ],
      ),
    ];

    await tester.pumpWidget(_buildPage());
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('moment-comment-row-comment_parent')),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除评论'), findsOneWidget);

    await tester.tap(find.text('删除评论'));
    await tester.pumpAndSettle();

    final comments = MomentStore.instance.moments.value.single.comments;
    expect(comments.map((comment) => comment.id), ['comment_keep']);
    expect(find.textContaining('准备删除的评论。', findRichText: true), findsNothing);
    expect(find.textContaining('保留的评论。', findRichText: true), findsOneWidget);
  });

  testWidgets('deletes a moment from the card menu', (tester) async {
    MomentStore.instance.moments.value = [
      Moment(
        id: 'moment_delete',
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '准备删除的动态。',
        createdAt: DateTime(2026, 11, 8, 12),
      ),
    ];

    await tester.pumpWidget(_buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('moment-menu-moment_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除动态'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(MomentStore.instance.moments.value, isEmpty);
    expect(find.text('准备删除的动态。'), findsNothing);
  });
}
