import 'dart:math';

import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/config/mori_config.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_activity_context_builder.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/utils/chat_text_utils.dart';

abstract interface class MomentGenerator {
  Future<String> generateForCharacter(CharacterProfile character);

  Future<String> generateCommentForCharacter({
    required CharacterProfile character,
    required Moment moment,
  });

  Future<String> generateReplyForCharacter({
    required CharacterProfile character,
    required Moment moment,
    required MomentComment replyTo,
  });

  void dispose();
}

class MomentGenerationException implements Exception {
  const MomentGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MomentService implements MomentGenerator {
  MomentService({ChatService? chatService, Random? random})
    : _chatService = chatService ?? ChatService(),
      _random = random ?? Random();

  static const _maxMomentLength = 500;
  static const _maxCommentLength = 200;

  static const _momentAngles = [
    '最近发生的一件小事',
    '一个突然冒出来的想法',
    '对某件事的轻微吐槽',
    '一段和过去有关的回忆',
    '最近在期待的事情',
    '观察到的一个生活细节',
    '自己的一个小习惯或小缺点',
    '和用户或朋友的一次互动',
    '当下时间带来的心情变化',
    '一个和角色核心设定有关、但角度新鲜的日常片段',
  ];

  final ChatService _chatService;
  final Random _random;

  @override
  Future<String> generateForCharacter(CharacterProfile character) {
    final now = DateTime.now();
    final recentMoments = MomentStore.instance.moments.value
        .where(
          (moment) =>
              moment.authorId == character.id &&
              (moment.content.trim().isNotEmpty || moment.image != null),
        )
        .take(5)
        .toList();
    final recentSummary = recentMoments.isEmpty
        ? '暂无'
        : recentMoments
              .map((moment) {
                final content = moment.content.trim().isEmpty
                    ? '[图片动态]'
                    : moment.content.trim();
                final short = content.length > 80
                    ? '${content.substring(0, 80)}…'
                    : content;
                return '- $short';
              })
              .join('\n');
    final angle = _momentAngles[_random.nextInt(_momentAngles.length)];
    final moodContext = MoodStore.instance.contextLine(character.id);
    final systemPrompt =
        '''
${MoriConfig.buildSystemPrompt(character)}

请以「${character.displayName}」的身份，写一条适合发布在社交动态里的短内容。
当前时间：${now.month}月${now.day}日 ${_timeOfDay(now.hour)}
本次创作方向：$angle
最近发布过的动态（不要重复这些内容、开头、主题和句式）：
$recentSummary
${moodContext.isEmpty ? '' : '\n$moodContext\n'}
要求：
- 使用第一人称，符合角色的性格和说话方式。
- 1-3 句话，简短自然，适合直接展示在动态列表。
- 写一个具体、有当下感的片段，可以包含时间、动作、地点或感受。
- 不要总围绕同一个爱好、食物或口头禅；如果最近动态集中出现某个主题，这次必须换一个生活切面。
- 不要反复使用「今天」开头，也不要照抄最近动态中的句子。
- 不要添加标题、角色名前缀、引号、括号说明或 Markdown。
- 只输出动态正文。''';
    return _generate(
      systemPrompt: systemPrompt,
      userPrompt: '写一条动态。',
      characterName: character.displayName,
      maxLength: _maxMomentLength,
      temperature: 1.0,
    );
  }

  @override
  Future<String> generateCommentForCharacter({
    required CharacterProfile character,
    required Moment moment,
  }) {
    final authorName = _momentAuthorName(moment);
    final content = moment.content.isEmpty ? '（图片动态）' : moment.content;
    final imageHint = moment.image != null ? '这条动态包含一张图片。\n' : '';
    final existingComments = _formatExistingComments(moment, character);
    final activityContext = CharacterActivityContextBuilder.instance
        .buildForMoment(character.id);
    final moodContext = MoodStore.instance.contextLine(character.id);

    final systemPrompt =
        '''
${MoriConfig.buildSystemPrompt(character)}

你正在浏览一条社交动态，请以「${character.displayName}」的身份写一条评论。
动态作者：$authorName
动态内容：$content
$imageHint已有评论（标记为「你自己」的是你之前发表的内容）：
$existingComments
${activityContext.isEmpty ? '' : '\n$activityContext\n'}
${moodContext.isEmpty ? '' : '\n$moodContext\n'}
身份规则：
- 你是「${character.displayName}」。
- 标记为「你自己」的评论是你之前写的。
- 其他名称的评论来自用户或其他角色，不要当成你自己的发言。
- 不要把其他角色的评论误认为自己的评论，也不要把自己的评论误认为别人的。

要求：
- 使用第一人称，符合角色的性格和说话方式。
- 1-2 句话，简短自然。
- 直接输出评论正文。
- 不要添加角色名前缀、引号、标题或 Markdown。
- 不要重复已有评论。''';
    return _generate(
      systemPrompt: systemPrompt,
      userPrompt: '写一条评论。',
      characterName: character.displayName,
      maxLength: _maxCommentLength,
      temperature: 0.95,
      imageMoment: moment,
    );
  }

  @override
  Future<String> generateReplyForCharacter({
    required CharacterProfile character,
    required Moment moment,
    required MomentComment replyTo,
  }) {
    final momentAuthor = _momentAuthorName(moment);
    final content = moment.content.isEmpty ? '（图片动态）' : moment.content;
    final imageHint = moment.image != null ? '这条动态包含一张图片。\n' : '';
    final replyAuthor = _commentAuthorName(moment, replyTo);
    final existingComments = _formatExistingComments(moment, character);
    final activityContext = CharacterActivityContextBuilder.instance
        .buildForMoment(character.id);
    final moodContext = MoodStore.instance.contextLine(character.id);

    final systemPrompt =
        '''
${MoriConfig.buildSystemPrompt(character)}

你正在浏览一条社交动态，并准备回复其中一条评论。
你是「${character.displayName}」。
动态作者：$momentAuthor
动态内容：$content
$imageHint你要回复的评论：
$replyAuthor：${replyTo.content}

已有评论（标记为「你自己」的是你之前发表的内容）：
$existingComments
${activityContext.isEmpty ? '' : '\n$activityContext\n'}
${moodContext.isEmpty ? '' : '\n$moodContext\n'}
身份规则：
- 标记为「你自己」的评论是你之前写的。
- 其他名称的评论来自用户或其他角色，不要当成你自己的发言。
- 不要把自己的评论误认为别人的评论，也不要假装自己是其他角色。

要求：
- 使用第一人称，符合角色的性格和说话方式。
- 直接回应这条评论，1-2 句话，简短自然。
- 直接输出回复正文。
- 不要添加角色名前缀、@、引号、标题或 Markdown。
- 不要重复已有评论。''';
    return _generate(
      systemPrompt: systemPrompt,
      userPrompt: '回复这条评论。',
      characterName: character.displayName,
      maxLength: _maxCommentLength,
      temperature: 0.95,
      imageMoment: moment,
    );
  }

  String _momentAuthorName(Moment moment) {
    if (moment.isUser) {
      final name = UserProfileStore.instance.profile.value.displayName.trim();
      return name.isEmpty ? '用户' : '用户（$name）';
    }
    final card = CharacterStore.instance.cardById(moment.authorId);
    final name = card?.displayName ?? moment.authorName.trim();
    return name.isEmpty ? '角色' : name;
  }

  String _commentAuthorName(Moment moment, MomentComment comment) {
    if (comment.isUser) {
      final name = UserProfileStore.instance.profile.value.displayName.trim();
      return name.isEmpty ? '用户' : '用户（$name）';
    }
    final card = CharacterStore.instance.cardById(comment.authorId);
    final name = card?.displayName ?? comment.authorName.trim();
    return name.isEmpty ? '角色' : name;
  }

  MomentComment? _commentById(Moment moment, String commentId) {
    if (commentId.isEmpty) {
      return null;
    }
    for (final comment in moment.comments) {
      if (comment.id == commentId) {
        return comment;
      }
    }
    return null;
  }

  String _formatExistingComments(
    Moment moment,
    CharacterProfile character, {
    int limit = 10,
  }) {
    if (moment.comments.isEmpty) {
      return '暂无评论。';
    }
    return moment.comments
        .take(limit)
        .map((comment) {
          final isSelf = comment.authorId == character.id;
          final author = isSelf ? '你自己' : _commentAuthorName(moment, comment);
          final target = _commentById(moment, comment.replyToCommentId);
          final replyLabel = target == null
              ? ''
              : ' 回复 ${_commentAuthorName(moment, target)}';
          return '- $author$replyLabel：${comment.content}';
        })
        .join('\n');
  }

  String _timeOfDay(int hour) {
    if (hour < 6) {
      return '深夜';
    }
    if (hour < 9) {
      return '早晨';
    }
    if (hour < 12) {
      return '上午';
    }
    if (hour < 14) {
      return '中午';
    }
    if (hour < 18) {
      return '下午';
    }
    if (hour < 22) {
      return '晚上';
    }
    return '深夜';
  }

  Future<String> _generate({
    required String systemPrompt,
    required String userPrompt,
    required String characterName,
    required int maxLength,
    required double temperature,
    Moment? imageMoment,
  }) async {
    final selection = ModelStore.instance.selection.value;
    final provider =
        ModelProviderCatalog.byId(selection.providerId) ??
        ModelProviderCatalog.defaultProvider;
    final apiKey = ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw MomentGenerationException(
        '请先在「设置 > 模型」中填写 ${provider.name} API Key。',
      );
    }
    if (!selection.hasModel) {
      throw const MomentGenerationException('请先在「设置 > 模型」中选择一个模型。');
    }

    final momentImage = imageMoment?.image;
    final canViewImage =
        momentImage != null && ModelStore.instance.supportsVision(selection);
    final userMessage = ChatMessage(
      role: ChatRole.user,
      content: userPrompt,
      image: canViewImage
          ? ChatImage(bytes: momentImage.bytes, mimeType: momentImage.mimeType)
          : null,
    );

    final buffer = StringBuffer();
    try {
      await for (final chunk in _chatService.streamChat(
        [userMessage],
        provider: provider,
        apiKey: apiKey,
        model: selection.modelId,
        systemPrompt: systemPrompt,
        temperature: temperature,
      )) {
        buffer.write(chunk);
      }
    } on ChatServiceException catch (error) {
      throw MomentGenerationException(error.message);
    } catch (_) {
      throw const MomentGenerationException('生成内容失败，请稍后重试。');
    }

    final content = _normalize(
      buffer.toString(),
      characterName,
      maxLength: maxLength,
    );
    if (content.isEmpty) {
      throw const MomentGenerationException('角色没有生成内容，请再试一次。');
    }
    return content;
  }

  String _normalize(
    String raw,
    String characterName, {
    required int maxLength,
  }) {
    var content = stripLeadingSpeakerName(raw, characterName).trim();
    if (content.length >= 2) {
      final first = content[0];
      final last = content[content.length - 1];
      final wrapped =
          (first == '“' && last == '”') ||
          (first == '「' && last == '」') ||
          (first == '『' && last == '』') ||
          (first == '"' && last == '"');
      if (wrapped) {
        content = content.substring(1, content.length - 1).trim();
      }
    }
    if (content.length > maxLength) {
      content = '${content.substring(0, maxLength)}…';
    }
    return content;
  }

  @override
  void dispose() {
    _chatService.dispose();
  }
}
