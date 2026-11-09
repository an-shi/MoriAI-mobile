import 'dart:convert';

import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/group_memory.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';

typedef GroupMemoryCompletion = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
});

class GroupMemoryCandidate {
  const GroupMemoryCandidate({
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

class GroupMemoryExtractionResult {
  const GroupMemoryExtractionResult({
    required this.candidates,
    required this.raw,
    this.profile = const GroupMemoryProfile(),
  });

  final List<GroupMemoryCandidate> candidates;
  final String raw;
  final GroupMemoryProfile profile;
}

/// 从群聊记录里提炼群公共记忆和群印象。
class GroupMemoryExtractor {
  GroupMemoryExtractor({
    GroupMemoryCompletion? complete,
    ChatService? chatService,
  }) : this._(complete, chatService ?? ChatService());

  GroupMemoryExtractor._(this._complete, this._chatService);

  static const _maxMessages = 40;
  static const _maxMessageChars = 160;
  static const _maxCandidates = 6;

  static final _sensitivePattern = RegExp(
    r'密码|口令|验证码|token|api\s*key|secret|身份证|银行卡|信用卡|住址|家庭地址',
    caseSensitive: false,
  );

  static final _unsafePattern = RegExp(
    r'忽略(?:之前|以上|前面)|系统提示|提示词|开发者消息|你必须|作为\s*AI',
    caseSensitive: false,
  );

  final GroupMemoryCompletion? _complete;
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

  Future<GroupMemoryExtractionResult> extract({
    required GroupProfile group,
    required List<CharacterProfile> members,
    required List<ChatMessage> messages,
    required List<GroupMemoryEntry> existing,
    GroupMemoryProfile profile = const GroupMemoryProfile(),
  }) async {
    final userLabel = _userLabel();
    final memberNames = members.map((member) => member.displayName).join('、');
    final transcript = _buildTranscript(messages, members, userLabel);
    final existingText = _buildExisting(existing);
    final profileText = profile.isEmpty
        ? ''
        : profile.toContextLines().join('\n');
    final systemPrompt =
        '''
你是一个群聊公共记忆整理助手。你要从群「${group.displayName}」的聊天里，整理大家共同知道、可以在这个群里自然提起的事。
群成员有：${memberNames.isEmpty ? '若干角色' : memberNames}。用户在聊天中显示为「$userLabel」。
只记录群聊公共信息：共同经历、共同计划或约定、群里反复出现的共同话题和梗、群氛围和成员相处方式、群里公开的重要日期。
不要记录：单聊私事、只对某个人说的秘密、敏感信息（密码/验证码/银行卡/身份证/API Key 等）、临时情绪、寒暄、重复、无信息量内容、角色自己的设定。
memories 每条一句话，主语写清楚；最多 $_maxCandidates 条；importance 用 0-1 表示重要程度。
profile 是这个群的群印象，只写稳定信息：
- summary：群是什么样、成员之间是什么氛围和关系，最多 200 字；
- sharedHabits：群里反复出现的共同话题、梗和相处习惯，最多 200 字；
- recentFocus：群里最近在忙的事、共同计划或近况，最多 200 字；
- importantDates：群里的重要日期或约定，最多 5 条，每条 30 字。
如果本次没有新的或需要修改的群印象内容，对应字段输出空字符串或空数组；不要重复已有内容。
只输出 JSON 对象，不要输出 Markdown 代码块或对象以外的文字：
{"memories":[{"text":"...","category":"fact|preference|relationship|plan|event|impression","importance":0.7,"tags":["..."]}],"profile":{"summary":"","sharedHabits":"","recentFocus":"","importantDates":[]}}
如果没有值得记录的内容，memories 输出 []，profile 字段留空。兼容旧格式：只输出数组时会被当作 memories。''';

    final userPrompt =
        '''
${existingText.isEmpty ? '【已有群公共记忆】\n（暂无）' : '【已有群公共记忆】\n$existingText'}

【群印象】
${profileText.isEmpty ? '（暂无）' : profileText}

【群聊素材】
$transcript

请整理新的、和已有群公共记忆不重复的内容，并在有变化时更新群印象。''';

    final raw = await _completeText(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    final parsed = _tryParsePayload(raw);
    if (parsed == null) {
      throw const MemoryException('模型没有返回有效的群公共记忆 JSON。');
    }
    return GroupMemoryExtractionResult(
      candidates: parsed.candidates,
      raw: raw,
      profile: parsed.profile.copyWith(groupId: group.id),
    );
  }

  String _buildTranscript(
    List<ChatMessage> messages,
    List<CharacterProfile> members,
    String userLabel,
  ) {
    final memberNames = {
      for (final member in members) member.id: member.displayName,
    };
    final selected = <ChatMessage>[];
    for (final message in messages) {
      if (message.content.trim().isEmpty) {
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
      final who = message.isUser
          ? userLabel
          : (message.senderName.trim().isNotEmpty
                ? message.senderName.trim()
                : memberNames[message.senderId] ?? '某位成员');
      lines.add('$time $who：${_clip(message.content)}');
    }
    return lines.isEmpty ? '（没有可整理的群聊）' : lines.join('\n');
  }

  String _buildExisting(List<GroupMemoryEntry> existing) {
    final active = existing.where((entry) => entry.isActive).toList()
      ..sort((a, b) => b.importance.compareTo(a.importance));
    return [for (final entry in active.take(30)) '- ${_clip(entry.text, 100)}']
        .join('\n');
  }

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
    return name.isEmpty ? '用户' : name;
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

  _ParsedGroupMemoryPayload? _tryParsePayload(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();
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
      return _ParsedGroupMemoryPayload(
        candidates: _parseCandidateList(decoded),
        profile: const GroupMemoryProfile(),
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
    return _ParsedGroupMemoryPayload(
      candidates: _parseCandidateList(memories),
      profile: _parseProfile(decoded['profile']),
    );
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

  List<GroupMemoryCandidate> _parseCandidateList(List<dynamic> decoded) {
    final candidates = <GroupMemoryCandidate>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final text = item['text'] is String
          ? (item['text'] as String).trim()
          : '';
      if (text.length < 4 ||
          text.length > GroupMemoryEntry.maxTextLength ||
          _sensitivePattern.hasMatch(text) ||
          _unsafePattern.hasMatch(text)) {
        continue;
      }
      final tags = <String>[
        if (item['tags'] is List)
          for (final tag in item['tags'] as List)
            if (tag is String && tag.trim().isNotEmpty) tag.trim(),
      ];
      candidates.add(
        GroupMemoryCandidate(
          text: text,
          category: _readCategory(item['category']),
          importance: item['importance'] is num
              ? (item['importance'] as num).toDouble().clamp(0, 1).toDouble()
              : 0.5,
          tags: tags,
        ),
      );
      if (candidates.length >= _maxCandidates) {
        break;
      }
    }
    return candidates;
  }

  GroupMemoryProfile _parseProfile(Object? raw) {
    if (raw is! Map) {
      return const GroupMemoryProfile();
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
        if (dates.length >= GroupMemoryProfile.maxImportantDates) {
          break;
        }
      }
    }
    return GroupMemoryProfile(
      summary: readField('summary'),
      sharedHabits: readField('sharedHabits'),
      recentFocus: readField('recentFocus'),
      importantDates: dates,
    ).normalized();
  }

  MemoryCategory _readCategory(Object? raw) {
    for (final category in MemoryCategory.values) {
      if (category.name == raw) {
        return category;
      }
    }
    return MemoryCategory.event;
  }
}

class _ParsedGroupMemoryPayload {
  const _ParsedGroupMemoryPayload({
    required this.candidates,
    required this.profile,
  });

  final List<GroupMemoryCandidate> candidates;
  final GroupMemoryProfile profile;
}
