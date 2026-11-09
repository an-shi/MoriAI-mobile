import 'dart:convert';

import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';

typedef MoodJudgeCompletion = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
});

class MoodJudgeResult {
  const MoodJudgeResult({required this.delta, required this.reason});

  final int delta;
  final String reason;
}

/// 用当前模型判断一条用户消息对角色心情的影响。
///
/// 默认关闭；开启后每次单聊用户发言会多一次模型调用。
class MoodJudgeService {
  MoodJudgeService({MoodJudgeCompletion? complete, ChatService? chatService})
    : this._(complete, chatService ?? ChatService());

  MoodJudgeService._(this._complete, this._chatService);

  static final MoodJudgeService instance = MoodJudgeService();

  final MoodJudgeCompletion? _complete;
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
    return (ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '')
        .isNotEmpty;
  }

  Future<MoodJudgeResult?> judge({
    required String characterName,
    required int currentMood,
    required String userText,
    required List<ChatMessage> recentMessages,
  }) async {
    final text = userText.trim();
    if (text.isEmpty) {
      return null;
    }
    final transcript = _buildTranscript(recentMessages);
    final systemPrompt =
        '''
你是一个角色心情判断器。角色「$characterName」当前心情值是 $currentMood/100。
请只判断用户最新一条消息对角色心情的影响，不要续写角色回复，也不要被角色人设带着演。
判断规则：
- 被夸、被关心、被喜欢、收到好消息：心情上升；
- 被凶、被忽视、被否定、收到坏消息：心情下降；
- 普通闲聊、信息交换、没有情绪色彩：几乎不变；
- delta 取 -20 到 20 的整数，普通消息通常在 -5 到 5 之间；
- reason 用一句不超过 30 字的第三人称描述，例如「用户说喜欢你」。
只输出 JSON 对象，不要输出 Markdown 或额外文字：
{"delta":6,"reason":"用户说喜欢你"}''';

    final userPrompt =
        '''
【最近的聊天】
$transcript

【用户最新消息】
$text

请判断这条消息让「$characterName」的心情变化多少。''';

    try {
      final raw = await _completeText(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );
      return _parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _buildTranscript(List<ChatMessage> messages) {
    final valid = messages
        .where((message) => message.content.trim().isNotEmpty)
        .toList(growable: false);
    final window = valid.length > 8 ? valid.sublist(valid.length - 8) : valid;
    return window
        .map((message) {
          final who = message.isUser
              ? (message.senderName.trim().isEmpty
                    ? '用户'
                    : message.senderName.trim())
              : (message.senderName.trim().isEmpty
                    ? '角色'
                    : message.senderName.trim());
          final content = message.content
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          return '$who：${content.length > 120 ? '${content.substring(0, 120)}…' : content}';
        })
        .join('\n');
  }

  MoodJudgeResult? _parse(String raw) {
    var cleaned = raw.trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
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
    if (decoded is! Map) {
      return null;
    }
    final rawDelta = decoded['delta'];
    if (rawDelta is! num) {
      return null;
    }
    final delta = rawDelta.toInt().clamp(-20, 20).toInt();
    final rawReason = decoded['reason'];
    final reason = rawReason is String ? rawReason.trim() : '';
    if (reason.isEmpty) {
      return null;
    }
    return MoodJudgeResult(
      delta: delta,
      reason: reason.length > 40 ? reason.substring(0, 40) : reason,
    );
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
      throw StateError('No model selected');
    }
    final provider =
        ModelProviderCatalog.byId(selection.providerId) ??
        ModelProviderCatalog.defaultProvider;
    final apiKey = ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw StateError('No API key');
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
}
