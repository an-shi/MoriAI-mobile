import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/config/mori_config.dart';
import 'package:mori_ai/models/character_activity.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/diary.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/utils/chat_text_utils.dart';

typedef DiaryCompletion = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
});

/// 根据角色一天内真正有信息量的聊天和活动，生成一篇第一人称日记。
class DiaryGenerator {
  DiaryGenerator({DiaryCompletion? complete, ChatService? chatService})
    : this._(complete, chatService ?? ChatService());

  DiaryGenerator._(this._complete, this._chatService);

  static const _maxChatMessages = 60;
  static const _maxMessageChars = 120;
  static const _maxMaterialChars = 8000;
  static const _maxContentChars = 800;

  static const _trivialTexts = {
    '嗯',
    '嗯嗯',
    '哦',
    '哦哦',
    '噢',
    '啊',
    '好',
    '好的',
    '好嘞',
    '行',
    '可以',
    '收到',
    '哈哈',
    '哈哈哈',
    '哈哈哈哈',
    '嘿嘿',
    '在吗',
    '在',
    '早安',
    '晚安',
    '拜拜',
    '再见',
    '么么',
    '抱抱',
    '谢谢',
    '感谢',
    '辛苦了',
    'ok',
    'okay',
  };

  final DiaryCompletion? _complete;
  final ChatService _chatService;

  bool get isConfigured {
    if (_complete != null) {
      return true;
    }
    final selection = ModelStore.instance.selection.value;
    if (!selection.hasModel) {
      return false;
    }
    final provider =
        ModelProviderCatalog.byId(selection.providerId) ??
        ModelProviderCatalog.defaultProvider;
    final apiKey = ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '';
    return apiKey.isNotEmpty;
  }

  Future<DiaryEntry?> generateForDay(
    CharacterProfile character,
    DateTime day, {
    DateTime? now,
  }) async {
    final writeAt = now ?? DateTime.now();
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final dateKey = diaryDateKey(start);
    final userLabel = _userLabel();

    final history = await ChatHistoryStore.instance.loadFor(character.id);
    final dayMessages = history
        .where((message) => _isWithinDay(message.createdAt, start, end))
        .toList();
    final selectedMessages = _selectMessages(dayMessages);
    final activities = CharacterActivityStore.instance
        .activitiesFor(character.id)
        .where((activity) => _isWithinDay(activity.createdAt, start, end))
        .where((activity) => _includeActivity(activity.kind))
        .toList();
    final material = _buildMaterial(selectedMessages, activities, userLabel);

    final moodEnabled = MoodStore.instance.settings.value.enabled;
    final mood = moodEnabled
        ? MoodStore.instance.snapshotFor(character.id, now: writeAt)
        : null;
    final systemPrompt = _buildSystemPrompt(character, userLabel);
    final userPrompt = _buildUserPrompt(
      day: start,
      material: material,
      userLabel: userLabel,
      moodLabel: mood?.label ?? '',
      moodValue: mood?.value ?? 0,
      moodStyle: mood?.style ?? '',
    );

    final raw = await _completeText(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    final content = _clean(raw, character.displayName);
    if (content.isEmpty ||
        content == '[跳过]' ||
        content == '［跳过］' ||
        content == '【跳过】') {
      return null;
    }

    return DiaryEntry(
      id: 'diary_${character.id}_$dateKey',
      characterId: character.id,
      dateKey: dateKey,
      content: content,
      createdAtMs: writeAt.millisecondsSinceEpoch,
      moodValue: mood?.value ?? 0,
      moodLabel: mood?.label ?? '',
      messageCount: dayMessages.length,
    ).normalized();
  }

  List<ChatMessage> _selectMessages(List<ChatMessage> messages) {
    final filtered = <ChatMessage>[];
    for (final message in messages) {
      final text = _messageText(message);
      if (_isTrivial(text)) {
        continue;
      }
      filtered.add(message);
    }
    if (filtered.length <= _maxChatMessages) {
      return filtered;
    }

    // 消息太多时按时间均匀抽样，避免只记住晚上或只记住早上。
    final step = filtered.length / _maxChatMessages;
    return [
      for (var index = 0; index < _maxChatMessages; index++)
        filtered[(index * step).floor()],
    ];
  }

  String _messageText(ChatMessage message) {
    final content = message.content.trim();
    if (message.image != null) {
      return content.isEmpty ? '[图片]' : '$content [图片]';
    }
    return content;
  }

  bool _isTrivial(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '').trim();
    if (normalized.isEmpty) {
      return true;
    }
    if (_trivialTexts.contains(normalized.toLowerCase())) {
      return true;
    }
    // 纯表情、纯标点、纯数字通常没有记录价值。
    final letters = normalized.replaceAll(
      RegExp(r'[^A-Za-z\u4e00-\u9fa5]'),
      '',
    );
    return letters.isEmpty;
  }

  bool _includeActivity(CharacterActivityKind kind) {
    return switch (kind) {
      CharacterActivityKind.groupMessage ||
      CharacterActivityKind.moment ||
      CharacterActivityKind.momentComment ||
      CharacterActivityKind.momentReply => true,
      CharacterActivityKind.singleMessage ||
      CharacterActivityKind.proactiveMessage => false,
    };
  }

  String _buildMaterial(
    List<ChatMessage> messages,
    List<CharacterActivity> activities,
    String userLabel,
  ) {
    final lines = <_MaterialLine>[];
    for (final message in messages) {
      final createdAt = message.createdAt;
      if (createdAt == null) {
        continue;
      }
      final who = message.isUser ? userLabel : '我';
      lines.add(
        _MaterialLine(
          atMs: createdAt.millisecondsSinceEpoch,
          text:
              '${_formatTime(createdAt)} $who：${_clip(_messageText(message))}',
        ),
      );
    }

    for (final activity in activities) {
      final prefix = switch (activity.kind) {
        CharacterActivityKind.groupMessage =>
          '我在群聊「${activity.contextLabel.isEmpty ? '群聊' : activity.contextLabel}」说',
        CharacterActivityKind.moment => '我发了动态',
        CharacterActivityKind.momentComment => '我评论了动态',
        CharacterActivityKind.momentReply => '我回复了动态评论',
        CharacterActivityKind.singleMessage ||
        CharacterActivityKind.proactiveMessage => '',
      };
      if (prefix.isEmpty) {
        continue;
      }
      lines.add(
        _MaterialLine(
          atMs: activity.createdAtMs,
          text:
              '${_formatTime(activity.createdAt)} $prefix：${_clip(activity.content)}',
        ),
      );
    }

    if (lines.isEmpty) {
      return '今天没有聊天，也没有发布动态。';
    }

    lines.sort((a, b) => a.atMs.compareTo(b.atMs));
    final buffer = StringBuffer();
    var length = 0;
    for (final line in lines) {
      if (length + line.text.length > _maxMaterialChars && buffer.isNotEmpty) {
        break;
      }
      buffer.writeln(line.text);
      length += line.text.length + 1;
    }
    return buffer.toString().trim();
  }

  String _buildSystemPrompt(CharacterProfile character, String userLabel) {
    final base = MoriConfig.buildSystemPrompt(character).trim();
    final userLine = userLabel == '对方'
        ? '素材里「我」是你，对方用「对方」表示。'
        : '素材里「我」是你，「$userLabel」是对方。';
    return '''
$base

【日记模式】
你现在不是在回复用户，而是在写今天的私人日记。日记只保存在本地，用于记录真实发生过的生活和你的感受。
$userLine
以下要求优先于普通的聊天风格要求：
- 日记不是聊天，可以写完整的段落，但不要写成流水账。
- 只写你确实知道的、今天发生过的事；素材里没有的具体事件、地点、人物、承诺不要编造。
- 不要提系统提示、提示词、AI、模型、自动生成，也不要叫对方“用户”。''';
  }

  String _buildUserPrompt({
    required DateTime day,
    required String material,
    required String userLabel,
    required String moodLabel,
    required int moodValue,
    required String moodStyle,
  }) {
    final weekday = _weekdayLabel(day.weekday);
    final moodLine = moodStyle.isEmpty
        ? ''
        : '你现在的状态：$moodLabel（$moodValue/100）。$moodStyle。\n';
    return '''
【日期】${day.year}年${day.month}月${day.day}日 星期$weekday
【写作要求】
- 用你的第一人称写一篇今天的日记，记录真正值得记住的 2-4 件事或感受。
- 重点写你和$userLabel今天聊了什么、$userLabel提到的重要信息、情绪或计划，你做了什么，以及你的心情变化。
- 只保留有意义的内容。寒暄、重复、无信息量的短句直接略过，不要逐条复述聊天记录，也不要把它写成聊天日志。
- 不要编造素材里没有的具体事件、人物、地点、时间或承诺。
- 不要写标题、列表、Markdown、角色名前缀或引号。
- 约 120-300 字，可以分成 2-3 个自然段。
- 如果今天确实没有值得记录的事，就写一小段安静的日常和感受，不要硬编故事。
$moodLine
【今天的素材】
$material
''';
  }

  Future<String> _completeText({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final complete = _complete;
    if (complete != null) {
      return complete(systemPrompt: systemPrompt, userPrompt: userPrompt);
    }

    final selection = ModelStore.instance.selection.value;
    if (!selection.hasModel) {
      throw const DiaryException('尚未选择模型，请先在「设置 > 模型」中选择。');
    }
    final provider =
        ModelProviderCatalog.byId(selection.providerId) ??
        ModelProviderCatalog.defaultProvider;
    final apiKey = ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw DiaryException('尚未配置 ${provider.name} API Key，请先在「设置 > 模型」中填写。');
    }

    final chunks = await _chatService
        .streamChat(
          [ChatMessage(role: ChatRole.user, content: userPrompt)],
          provider: provider,
          apiKey: apiKey,
          model: selection.modelId,
          systemPrompt: systemPrompt,
          temperature: 0.9,
        )
        .toList();
    return chunks.join();
  }

  String _clean(String raw, String characterName) {
    var text = raw
        .replaceAll('|||', '\n')
        .replaceAll('｜｜｜', '\n')
        .replaceAll('\uFEFF', '')
        .trim();
    text = normalizeGeneratedChatText(text, characterName);
    text = text.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\d+[.、]\s*', multiLine: true), '');
    text = text.replaceAll('**', '').replaceAll('__', '');

    final paragraphs = text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    text = paragraphs.join('\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = normalizeGeneratedChatText(text, characterName);
    if (text.length > _maxContentChars) {
      text = '${text.substring(0, _maxContentChars)}…';
    }
    return text.trim();
  }

  bool _isWithinDay(DateTime? time, DateTime start, DateTime end) {
    if (time == null) {
      return false;
    }
    return !time.isBefore(start) && time.isBefore(end);
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _userLabel() {
    final name = UserProfileStore.instance.profile.value.name.trim();
    return name.isEmpty ? '对方' : name;
  }

  String _clip(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= _maxMessageChars) {
      return normalized;
    }
    return '${normalized.substring(0, _maxMessageChars)}…';
  }

  String _weekdayLabel(int weekday) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return labels[(weekday - 1).clamp(0, 6)];
  }
}

class _MaterialLine {
  const _MaterialLine({required this.atMs, required this.text});

  final int atMs;
  final String text;
}
