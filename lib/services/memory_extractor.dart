import 'dart:convert';

import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';

typedef MemoryCompletion = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
});

class MemoryCandidate {
  const MemoryCandidate({
    required this.text,
    required this.category,
    required this.importance,
    required this.tags,
  });

  final String text;
  final MemoryCategory category;
  final double importance;
  final List<String> tags;
}

class MemoryOpenTopicCandidate {
  const MemoryOpenTopicCandidate({
    this.id = '',
    required this.text,
    this.resolved = false,
    this.importance = 0.6,
  });

  /// 已有未完成话题的 ID；新话题为空。
  final String id;
  final String text;
  final bool resolved;
  final double importance;
}

class MemoryExtractionResult {
  const MemoryExtractionResult({
    required this.candidates,
    required this.raw,
    this.profile = const MemoryProfile(),
    this.openTopics = const [],
  });

  final List<MemoryCandidate> candidates;
  final String raw;
  final MemoryProfile profile;
  final List<MemoryOpenTopicCandidate> openTopics;
}

/// 从聊天记录中提炼值得长期记住的事实、喜好、关系、计划和经历。
class MemoryExtractor {
  MemoryExtractor({MemoryCompletion? complete, ChatService? chatService})
    : this._(complete, chatService ?? ChatService());

  MemoryExtractor._(this._complete, this._chatService);

  static const _maxMessages = 40;
  static const _maxMessageChars = 180;
  static const _maxCandidates = 6;
  static const _maxOpenTopics = 8;

  static final _sensitivePattern = RegExp(
    r'密码|口令|验证码|token|api\s*key|secret|身份证|银行卡|信用卡|住址|家庭地址',
    caseSensitive: false,
  );

  static final _unsafePattern = RegExp(
    r'忽略(?:之前|以上|前面)|系统提示|提示词|开发者消息|你必须|作为\s*AI',
    caseSensitive: false,
  );

  final MemoryCompletion? _complete;
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

  Future<MemoryExtractionResult> extract({
    required CharacterProfile character,
    required List<ChatMessage> messages,
    required List<MemoryEntry> existing,
    MemoryProfile profile = const MemoryProfile(),
    List<MemoryOpenTopic> openTopics = const [],
  }) async {
    final userLabel = _userLabel();
    final transcript = _buildTranscript(messages, userLabel);
    final existingText = _buildExisting(existing);
    final profileText = _buildProfile(profile);
    final topicText = _buildOpenTopics(openTopics);
    final systemPrompt =
        '''
你是一个长期记忆整理助手。你要从角色「${character.displayName}」和对方「$userLabel」的聊天里，整理值得长期记住的事、一份人物小档案和未完成话题。
只记录关于对方和你们关系的长期信息：身份或称呼、稳定喜好、重要关系、长期计划、约定、重要经历、相处模式、明确表达过的边界。
不要记录：寒暄、重复、临时情绪、一次性琐事、角色自己的设定、无信息量内容、密码/验证码/银行卡/身份证/API Key 等敏感信息。
memories 每条一句话，主语写清楚；最多 $_maxCandidates 条；importance 用 0-1 表示重要程度。
profile 是人物小档案，只写稳定信息：
- summary：对方是谁、身份和你们的关系，最多 200 字；
- preferences：稳定喜好、不喜欢和习惯，最多 200 字；
- recentFocus：最近的重要状态、计划或正在忙的事，最多 200 字；
- importantDates：重要日期或约定，最多 5 条，每条 30 字。
如果本次没有新的或需要修改的档案内容，对应字段输出空字符串或空数组；不要重复已有档案。
openTopics 只列还没有结果、值得之后追问的事：约定、等待结果、用户说以后再聊、未完成计划。已有话题会带 id；如果这次聊天里已经解决，输出该 id 并把 status 设为 resolved；仍在进行可以保留或更新 text。最多 $_maxOpenTopics 条。
只输出 JSON 对象，不要输出 Markdown 代码块或对象以外的文字：
{"memories":[{"text":"...","category":"fact|preference|relationship|plan|event|impression","importance":0.7,"tags":["..."]}],"profile":{"summary":"","preferences":"","recentFocus":"","importantDates":[]},"openTopics":[{"id":"","text":"...","status":"open|resolved","importance":0.6}]}
如果没有值得记录的内容，memories 输出 []，profile 字段留空，openTopics 输出 []。兼容旧格式：只输出数组时会被当作 memories。''';

    final userPrompt =
        '''
${existingText.isEmpty ? '【已有记忆】\n（暂无）' : '【已有记忆】\n$existingText'}

【人物小档案】
${profileText.isEmpty ? '（暂无）' : profileText}

【未完成话题】
${topicText.isEmpty ? '（暂无）' : topicText}

【聊天素材】
$transcript

请整理新的、和已有记忆不重复的长期记忆，并在有变化时更新人物小档案和未完成话题。''';

    final raw = await _completeText(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    final parsed = _tryParsePayload(raw);
    if (parsed == null) {
      throw const MemoryException('模型没有返回有效的记忆 JSON。');
    }
    return MemoryExtractionResult(
      candidates: parsed.candidates,
      raw: raw,
      profile: parsed.profile.copyWith(characterId: character.id),
      openTopics: parsed.openTopics,
    );
  }

  String _buildTranscript(List<ChatMessage> messages, String userLabel) {
    final selected = <ChatMessage>[];
    for (final message in messages) {
      final content = message.content.trim();
      if (content.isEmpty) {
        continue;
      }
      selected.add(message);
    }
    final window = selected.length > _maxMessages
        ? selected.sublist(selected.length - _maxMessages)
        : selected;
    final lines = <String>[];
    for (final message in window) {
      final time = _formatTime(message.createdAt);
      final who = message.isUser ? userLabel : '我';
      lines.add('$time $who：${_clip(contentOf(message))}');
    }
    return lines.isEmpty ? '（没有可整理的聊天）' : lines.join('\n');
  }

  String _buildExisting(List<MemoryEntry> existing) {
    final active = existing.where((entry) => entry.isActive).toList()
      ..sort((a, b) => b.importance.compareTo(a.importance));
    return [for (final entry in active.take(30)) '- ${_clip(entry.text, 100)}']
        .join('\n');
  }

  String _buildProfile(MemoryProfile profile) {
    if (profile.isEmpty) {
      return '';
    }
    return profile.toContextLines().join('\n');
  }

  String _buildOpenTopics(List<MemoryOpenTopic> topics) {
    final open = topics.where((topic) => topic.isOpen).toList()
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return [
      for (final topic in open.take(_maxOpenTopics))
        '- id=${topic.id} ${_clip(topic.text, 100)}',
    ].join('\n');
  }

  String contentOf(ChatMessage message) => message.content.trim();

  String _clip(String text, [int max = _maxMessageChars]) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= max) {
      return normalized;
    }
    return '${normalized.substring(0, max)}…';
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return '';
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _userLabel() {
    final name = UserProfileStore.instance.profile.value.name.trim();
    return name.isEmpty ? '对方' : name;
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
      throw const MemoryException('尚未选择模型，请先在「设置 > 模型」中选择。');
    }
    final provider =
        ModelProviderCatalog.byId(selection.providerId) ??
        ModelProviderCatalog.defaultProvider;
    final apiKey = ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw MemoryException('尚未配置 ${provider.name} API Key，请先在「设置 > 模型」中填写。');
    }

    final chunks = await _chatService
        .streamChat(
          [ChatMessage(role: ChatRole.user, content: userPrompt)],
          provider: provider,
          apiKey: apiKey,
          model: selection.modelId,
          systemPrompt: systemPrompt,
          temperature: 0.2,
        )
        .toList();
    return chunks.join();
  }

  List<MemoryCandidate> parseMemoryCandidates(String raw) {
    return _tryParsePayload(raw)?.candidates ?? const [];
  }

  _ParsedMemoryPayload? _tryParsePayload(String raw) {
    final cleaned = _stripCodeFence(raw);
    if (cleaned.isEmpty) {
      return null;
    }
    final firstArray = cleaned.indexOf('[');
    final firstObject = cleaned.indexOf('{');
    if (firstArray >= 0 && (firstObject < 0 || firstArray < firstObject)) {
      final decoded = _decodeJson(cleaned, '[', ']');
      if (decoded is! List) {
        return null;
      }
      return _ParsedMemoryPayload(
        candidates: _parseCandidateList(decoded),
        profile: const MemoryProfile(),
        openTopics: const [],
      );
    }

    final decoded = _decodeJson(cleaned, '{', '}');
    if (decoded is! Map) {
      return null;
    }
    final memories = decoded['memories'] is List
        ? decoded['memories'] as List
        : decoded['candidates'] is List
        ? decoded['candidates'] as List
        : const [];
    return _ParsedMemoryPayload(
      candidates: _parseCandidateList(memories),
      profile: _parseProfile(decoded['profile']),
      openTopics: _parseOpenTopicCandidates(decoded['openTopics']),
    );
  }

  String _stripCodeFence(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();
  }

  Object? _decodeJson(String text, String open, String close) {
    final start = text.indexOf(open);
    final end = text.lastIndexOf(close);
    if (start < 0 || end <= start) {
      return null;
    }
    final body = text
        .substring(start, end + 1)
        .replaceAllMapped(
          RegExp(r',\s*([\]}])'),
          (match) => match.group(1) ?? '',
        );
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  List<MemoryCandidate> _parseCandidateList(List<dynamic> decoded) {
    final candidates = <MemoryCandidate>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final text = item['text'] is String
          ? (item['text'] as String).trim()
          : '';
      if (text.length < 4 ||
          text.length > MemoryEntry.maxTextLength ||
          _sensitivePattern.hasMatch(text) ||
          _unsafePattern.hasMatch(text)) {
        continue;
      }
      final category = _readCategory(item['category']);
      final importance = item['importance'] is num
          ? (item['importance'] as num).toDouble().clamp(0, 1).toDouble()
          : 0.5;
      final tags = <String>[
        if (item['tags'] is List)
          for (final tag in item['tags'] as List)
            if (tag is String && tag.trim().isNotEmpty) tag.trim(),
      ];
      candidates.add(
        MemoryCandidate(
          text: text,
          category: category,
          importance: importance,
          tags: tags,
        ),
      );
      if (candidates.length >= _maxCandidates) {
        break;
      }
    }
    return candidates;
  }

  MemoryProfile _parseProfile(Object? raw) {
    if (raw is! Map) {
      return const MemoryProfile();
    }
    String readField(String key) {
      final value = raw[key];
      if (value is! String) {
        return '';
      }
      final text = value.trim();
      if (text.isEmpty ||
          _sensitivePattern.hasMatch(text) ||
          _unsafePattern.hasMatch(text)) {
        return '';
      }
      return text;
    }

    final rawDates = raw['importantDates'];
    final dates = <String>[];
    if (rawDates is List) {
      for (final date in rawDates) {
        if (date is! String) {
          continue;
        }
        final text = date.trim();
        if (text.isEmpty ||
            _sensitivePattern.hasMatch(text) ||
            _unsafePattern.hasMatch(text) ||
            dates.contains(text)) {
          continue;
        }
        dates.add(text);
        if (dates.length >= MemoryProfile.maxImportantDates) {
          break;
        }
      }
    }
    return MemoryProfile(
      summary: readField('summary'),
      preferences: readField('preferences'),
      recentFocus: readField('recentFocus'),
      importantDates: dates,
    ).normalized();
  }

  List<MemoryOpenTopicCandidate> _parseOpenTopicCandidates(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final result = <MemoryOpenTopicCandidate>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final id = item['id'] is String ? (item['id'] as String).trim() : '';
      final text = item['text'] is String
          ? (item['text'] as String).trim()
          : '';
      final resolved = item['status'] == 'resolved' || item['resolved'] == true;
      if (text.isEmpty && !(resolved && id.isNotEmpty)) {
        continue;
      }
      if (text.isNotEmpty &&
          (text.length < 4 ||
              text.length > MemoryOpenTopic.maxTextLength ||
              _sensitivePattern.hasMatch(text) ||
              _unsafePattern.hasMatch(text))) {
        continue;
      }
      result.add(
        MemoryOpenTopicCandidate(
          id: id,
          text: text,
          resolved: resolved,
          importance: item['importance'] is num
              ? (item['importance'] as num).toDouble().clamp(0, 1).toDouble()
              : 0.6,
        ),
      );
      if (result.length >= _maxOpenTopics) {
        break;
      }
    }
    return result;
  }

  MemoryCategory _readCategory(Object? raw) {
    for (final category in MemoryCategory.values) {
      if (category.name == raw) {
        return category;
      }
    }
    return MemoryCategory.fact;
  }
}

class _ParsedMemoryPayload {
  const _ParsedMemoryPayload({
    required this.candidates,
    required this.profile,
    required this.openTopics,
  });

  final List<MemoryCandidate> candidates;
  final MemoryProfile profile;
  final List<MemoryOpenTopicCandidate> openTopics;
}
