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

class MemoryExtractionResult {
  const MemoryExtractionResult({required this.candidates, required this.raw});

  final List<MemoryCandidate> candidates;
  final String raw;
}

/// 从聊天记录中提炼值得长期记住的事实、喜好、关系、计划和经历。
class MemoryExtractor {
  MemoryExtractor({MemoryCompletion? complete, ChatService? chatService})
    : this._(complete, chatService ?? ChatService());

  MemoryExtractor._(this._complete, this._chatService);

  static const _maxMessages = 40;
  static const _maxMessageChars = 180;
  static const _maxCandidates = 6;

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
  }) async {
    final userLabel = _userLabel();
    final transcript = _buildTranscript(messages, userLabel);
    final existingText = _buildExisting(existing);
    final systemPrompt =
        '''
你是一个长期记忆整理助手。你要从角色「${character.displayName}」和对方「$userLabel」的聊天里，提炼值得长期记住的事。
只记录关于对方和你们关系的长期信息：身份或称呼、稳定喜好、重要关系、长期计划、约定、重要经历、相处模式、明确表达过的边界。
不要记录：寒暄、重复、临时情绪、一次性琐事、角色自己的设定、无信息量内容、密码/验证码/银行卡/身份证/API Key 等敏感信息。
每条一句话，主语写清楚；最多 $_maxCandidates 条；importance 用 0-1 表示重要程度。
只输出 JSON 数组，不要输出 Markdown 代码块或数组以外的文字：
[{"text":"...","category":"fact|preference|relationship|plan|event|impression","importance":0.7,"tags":["..."]}]
如果没有值得长期记住的内容，输出 []。''';

    final userPrompt =
        '''
${existingText.isEmpty ? '【已有记忆】\n（暂无）' : '【已有记忆】\n$existingText'}

【聊天素材】
$transcript

请提炼新的、和已有记忆不重复的长期记忆。''';

    final raw = await _completeText(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    final parsed = _tryParseCandidates(raw);
    if (parsed == null) {
      throw const MemoryException('模型没有返回有效的记忆 JSON。');
    }
    return MemoryExtractionResult(candidates: parsed, raw: raw);
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
    return _tryParseCandidates(raw) ?? const [];
  }

  List<MemoryCandidate>? _tryParseCandidates(String raw) {
    var cleaned = raw.trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start < 0 || end <= start) {
      return null;
    }
    final body = cleaned
        .substring(start, end + 1)
        .replaceAllMapped(
          RegExp(r',\s*([\]}])'),
          (match) => match.group(1) ?? '',
        );
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! List) {
      return null;
    }

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

  MemoryCategory _readCategory(Object? raw) {
    for (final category in MemoryCategory.values) {
      if (category.name == raw) {
        return category;
      }
    }
    return MemoryCategory.fact;
  }
}
