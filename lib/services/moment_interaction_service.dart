import 'dart:async';
import 'dart:math';

import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/models/moment_interaction_settings.dart';
import 'package:mori_ai/services/character_activity_recorder.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/moment_generator.dart';
import 'package:mori_ai/services/moment_interaction_settings_store.dart';
import 'package:mori_ai/services/moment_store.dart';

abstract interface class MomentInteractions {
  Future<void> onMomentCreated(Moment moment);

  Future<void> onCommentCreated(Moment moment, MomentComment comment);
}

/// 负责角色之间的自动评论和回复。
///
/// 所有动作串行执行，避免用户快速发布动态时产生并发请求。自动回复层数和
/// 每轮互动人数由 `MomentInteractionSettings` 控制。
class MomentInteractionService implements MomentInteractions {
  MomentInteractionService({MomentGenerator? generator, Random? random})
    : _generator = generator ?? MomentService(),
      _random = random ?? Random();

  static final MomentInteractionService instance = MomentInteractionService();

  static const _maxUnlimitedReplyDepth = 50;

  final MomentGenerator _generator;
  final Random _random;

  Future<void> _queue = Future<void>.value();

  @override
  Future<void> onMomentCreated(Moment moment) {
    return _enqueue(() => _handleMoment(moment));
  }

  @override
  Future<void> onCommentCreated(Moment moment, MomentComment comment) {
    return _enqueue(() => _handleComment(moment.id, comment));
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action()).catchError((Object _) {});
    _queue = next;
    return next;
  }

  Future<void> _handleMoment(Moment moment) async {
    final current = MomentStore.instance.momentById(moment.id);
    if (current == null) {
      return;
    }

    final settings = MomentInteractionSettingsStore.instance.settings.value;
    final cards = CharacterStore.instance.cards.value;
    final candidates = [
      for (final card in cards)
        if (card.id != current.authorId) card,
    ];
    if (candidates.isEmpty) {
      return;
    }
    candidates.shuffle(_random);

    final latest = MomentStore.instance.momentById(current.id) ?? current;
    final existingCommenters = {
      for (final comment in latest.comments)
        if (!comment.isUser && comment.replyToCommentId.isEmpty)
          comment.authorId,
    };
    final commenters = [
      for (final card in candidates)
        if (!existingCommenters.contains(card.id)) card,
    ];
    final targetComments = settings.autoCommentCount < 0
        ? candidates.length
        : min(settings.autoCommentCount, candidates.length);
    final remainingComments = targetComments - existingCommenters.length;
    if (remainingComments <= 0 || commenters.isEmpty) {
      return;
    }

    final selected = commenters.take(remainingComments).toList(growable: false);
    for (final commenter in selected) {
      final currentMoment = MomentStore.instance.momentById(latest.id);
      if (currentMoment == null) {
        return;
      }
      final commentText = await _generateComment(commenter, currentMoment);
      if (commentText == null) {
        continue;
      }
      final comment = await _addComment(currentMoment, commenter, commentText);
      if (comment == null) {
        continue;
      }
      await _continueReplies(currentMoment, comment, settings);
    }
  }

  Future<void> _handleComment(String momentId, MomentComment comment) async {
    final current = MomentStore.instance.momentById(momentId);
    if (current == null) {
      return;
    }

    if (comment.isUser && comment.replyToCommentId.isNotEmpty) {
      final target = _findComment(current, comment.replyToCommentId);
      if (target != null && !target.isUser) {
        final character = CharacterStore.instance.cardById(target.authorId);
        if (character != null) {
          await _replyToUserReply(current, comment, character);
          return;
        }
      }
    }

    final settings = MomentInteractionSettingsStore.instance.settings.value;
    if (settings.autoReplyDepth == 0) {
      return;
    }

    await _continueReplies(current, comment, settings);
    await _addJoiners(current, comment, settings);
  }

  Future<void> _replyToUserReply(
    Moment moment,
    MomentComment userReply,
    CharacterProfile character,
  ) async {
    final latest = MomentStore.instance.momentById(moment.id);
    if (latest == null ||
        latest.comments.any(
          (item) =>
              item.replyToCommentId == userReply.id &&
              item.authorId == character.id,
        )) {
      return;
    }

    final replyText = await _generateReply(character, latest, userReply);
    if (replyText == null) {
      return;
    }
    await _addReply(latest, character, replyText, userReply);
  }

  MomentComment? _findComment(Moment moment, String commentId) {
    for (final comment in moment.comments) {
      if (comment.id == commentId) {
        return comment;
      }
    }
    return null;
  }

  Future<void> _addJoiners(
    Moment moment,
    MomentComment target,
    MomentInteractionSettings settings,
  ) async {
    final replyDepthLimit = _replyDepthLimit(settings);
    if (target.replyDepth >= replyDepthLimit) {
      return;
    }

    final latest = MomentStore.instance.momentById(moment.id);
    if (latest == null) {
      return;
    }
    final directReplyAuthors = {
      for (final comment in latest.comments)
        if (comment.replyToCommentId == target.id) comment.authorId,
    };
    final candidates = [
      for (final card in CharacterStore.instance.cards.value)
        if (card.id != target.authorId && !directReplyAuthors.contains(card.id))
          card,
    ]..shuffle(_random);
    if (candidates.isEmpty) {
      return;
    }

    final joinerCount = settings.autoCommentCount < 0
        ? candidates.length
        : settings.autoCommentCount - 1;
    if (joinerCount <= 0) {
      return;
    }
    final selected = candidates
        .take(min(joinerCount, candidates.length))
        .toList(growable: false);
    for (final joiner in selected) {
      final currentMoment = MomentStore.instance.momentById(moment.id);
      if (currentMoment == null) {
        return;
      }
      final replyText = await _generateReply(joiner, currentMoment, target);
      if (replyText == null) {
        continue;
      }
      await _addReply(currentMoment, joiner, replyText, target);
    }
  }

  Future<void> _continueReplies(
    Moment moment,
    MomentComment start,
    MomentInteractionSettings settings,
  ) async {
    final replyDepthLimit = _replyDepthLimit(settings);
    var replyTo = start;
    while (replyTo.replyDepth < replyDepthLimit) {
      final latest = MomentStore.instance.momentById(moment.id);
      if (latest == null ||
          latest.comments.any((item) => item.replyToCommentId == replyTo.id)) {
        return;
      }

      final responder = _pickResponder(latest, replyTo);
      if (responder == null) {
        return;
      }
      final replyText = await _generateReply(responder, latest, replyTo);
      if (replyText == null) {
        return;
      }
      final reply = await _addReply(latest, responder, replyText, replyTo);
      if (reply == null) {
        return;
      }
      replyTo = reply;
    }
  }

  int _replyDepthLimit(MomentInteractionSettings settings) {
    return settings.autoReplyDepth < 0
        ? _maxUnlimitedReplyDepth
        : settings.autoReplyDepth;
  }

  CharacterProfile? _pickResponder(Moment moment, MomentComment replyTo) {
    final cards = CharacterStore.instance.cards.value;
    final author = moment.isUser
        ? null
        : CharacterStore.instance.cardById(moment.authorId);
    if (author != null && author.id != replyTo.authorId) {
      return author;
    }

    final candidates = [
      for (final card in cards)
        if (card.id != replyTo.authorId) card,
    ];
    if (candidates.isEmpty) {
      return null;
    }
    return candidates[_random.nextInt(candidates.length)];
  }

  Future<String?> _generateComment(
    CharacterProfile character,
    Moment moment,
  ) async {
    try {
      return await _generator.generateCommentForCharacter(
        character: character,
        moment: moment,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _generateReply(
    CharacterProfile character,
    Moment moment,
    MomentComment replyTo,
  ) async {
    try {
      return await _generator.generateReplyForCharacter(
        character: character,
        moment: moment,
        replyTo: replyTo,
      );
    } catch (_) {
      return null;
    }
  }

  Future<MomentComment?> _addComment(
    Moment moment,
    CharacterProfile character,
    String content,
  ) async {
    try {
      final comment = await MomentStore.instance.addComment(
        moment.id,
        authorId: character.id,
        authorName: character.displayName,
        isUser: false,
        content: content,
      );
      unawaited(
        CharacterActivityRecorder.recordMomentComment(
          character: character,
          moment: moment,
          comment: comment,
          isReply: false,
        ),
      );
      return comment;
    } catch (_) {
      return null;
    }
  }

  Future<MomentComment?> _addReply(
    Moment moment,
    CharacterProfile character,
    String content,
    MomentComment replyTo,
  ) async {
    final latest = MomentStore.instance.momentById(moment.id) ?? moment;
    if (latest.comments.any(
      (item) =>
          item.replyToCommentId == replyTo.id && item.authorId == character.id,
    )) {
      return null;
    }

    try {
      final comment = await MomentStore.instance.addComment(
        latest.id,
        authorId: character.id,
        authorName: character.displayName,
        isUser: false,
        content: content,
        replyToCommentId: replyTo.id,
        replyToAuthorName: replyTo.authorName.isEmpty
            ? (replyTo.isUser ? '用户' : '角色')
            : replyTo.authorName,
        replyDepth: replyTo.replyDepth + 1,
      );
      unawaited(
        CharacterActivityRecorder.recordMomentComment(
          character: character,
          moment: latest,
          comment: comment,
          isReply: true,
        ),
      );
      return comment;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _generator.dispose();
  }
}
