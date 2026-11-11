import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/active_conversation_store.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_activity_recorder.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_queue_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/local_notification_service.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/proactive_message_service.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:mori_ai/services/unread_store.dart';
import 'package:mori_ai/utils/chat_bubble_utils.dart';
import 'package:mori_ai/utils/chat_text_utils.dart';
import 'package:mori_ai/utils/group_chat_utils.dart';

/// 用户在等待回复期间离开聊天页后，由这个服务接管这一轮回复。
///
/// 聊天页在 dispose 时把「这一轮要用的提示词构建函数」和消息快照交给服务；
/// 服务在延迟结束后继续请求模型、把回复写入聊天记录，并在会话不在前台时
/// 增加未读数、发送本地通知。
class ChatBackgroundReplyService {
  ChatBackgroundReplyService._({ChatService? chatService})
    : _chatService = chatService ?? ChatService();

  static final ChatBackgroundReplyService instance =
      ChatBackgroundReplyService._();

  @visibleForTesting
  factory ChatBackgroundReplyService.forTest({ChatService? chatService}) {
    return ChatBackgroundReplyService._(chatService: chatService);
  }

  final ChatService _chatService;
  final Set<String> _running = <String>{};
  int _messageSequence = 0;
  Object? lastError;
  StackTrace? lastStackTrace;

  /// 最近一次后台回合的结果。聊天页重新打开时监听它来同步队列和界面。
  final ValueNotifier<ChatBackgroundTurnResult?> lastCompleted =
      ValueNotifier<ChatBackgroundTurnResult?>(null);

  bool isRunning(String conversationId) {
    return _running.contains(conversationId.trim());
  }

  /// 停止某个会话正在等待或生成的后台回复。
  void cancel(String conversationId) {
    _running.remove(conversationId.trim());
  }

  void schedule(ChatBackgroundTurnRequest request) {
    final conversationId = request.conversationId.trim();
    if (conversationId.isEmpty || !_running.add(conversationId)) {
      return;
    }
    ProactiveMessageService.instance.setConversationBusy(conversationId, true);
    unawaited(_run(request));
  }

  Future<void> _run(ChatBackgroundTurnRequest request) async {
    final conversationId = request.conversationId.trim();
    lastError = null;
    lastStackTrace = null;
    final batchIds = <String>[
      for (final message in request.batch)
        if (message.id.trim().isNotEmpty) message.id,
    ];
    var success = false;
    var bubbles = const <ChatMessage>[];

    try {
      if (request.delay > Duration.zero) {
        await Future<void>.delayed(request.delay);
      }
      if (!_running.contains(conversationId)) {
        return;
      }

      final selection = ModelStore.instance.selection.value;
      final provider =
          ModelProviderCatalog.byId(selection.providerId) ??
          ModelProviderCatalog.defaultProvider;
      final apiKey = ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '';
      if (!selection.hasModel || apiKey.isEmpty) {
        return;
      }

      final prompts = await request.buildPrompts();
      if (prompts.isEmpty) {
        return;
      }

      final workingHistory = List<ChatMessage>.of(request.roundHistory);
      final generated = <ChatMessage>[];
      for (final prompt in prompts) {
        if (!_running.contains(conversationId)) {
          return;
        }
        final replies = await _generateSpeaker(
          prompt: prompt,
          roundHistory: workingHistory,
          provider: provider,
          apiKey: apiKey,
          model: selection.modelId,
        );
        if (replies.isEmpty) {
          break;
        }
        generated.addAll(replies);
        workingHistory.addAll(replies);
        unawaited(
          CharacterActivityRecorder.recordChatMessages(
            character: prompt.responder,
            conversationId: conversationId,
            isGroup: prompt.showSender,
            messages: replies,
          ),
        );
      }

      if (generated.isEmpty) {
        return;
      }
      if (!_running.contains(conversationId)) {
        return;
      }

      bubbles = List<ChatMessage>.unmodifiable(generated);
      await _persist(
        request: request,
        bubbles: bubbles,
        batchIds: batchIds,
      );
      success = true;
    } catch (error, stackTrace) {
      // 失败时保留队列，下一次进入聊天页会重新处理。
      lastError = error;
      lastStackTrace = stackTrace;
    } finally {
      _running.remove(conversationId);
      ProactiveMessageService.instance.setConversationBusy(
        conversationId,
        false,
      );
      lastCompleted.value = ChatBackgroundTurnResult(
        conversationId: conversationId,
        batchIds: List<String>.unmodifiable(batchIds),
        bubbles: bubbles,
        success: success,
      );
    }
  }

  Future<List<ChatMessage>> _generateSpeaker({
    required ChatBackgroundSpeakerPrompt prompt,
    required List<ChatMessage> roundHistory,
    required ModelProvider provider,
    required String apiKey,
    required String model,
  }) async {
    var replies = await _streamReply(
      prompt: prompt,
      roundHistory: roundHistory,
      provider: provider,
      apiKey: apiKey,
      model: model,
      continuation: false,
      alreadySent: 0,
      continuationTarget: 0,
    );

    var attempts = 0;
    while (prompt.minimum > 0 &&
        replies.isNotEmpty &&
        replies.length < prompt.minimum &&
        attempts < 2 &&
        _running.contains(prompt.conversationId)) {
      final missing = prompt.minimum - replies.length;
      final extra = await _streamReply(
        prompt: prompt,
        roundHistory: [...roundHistory, ...replies],
        provider: provider,
        apiKey: apiKey,
        model: model,
        continuation: true,
        alreadySent: replies.length,
        continuationTarget: missing,
      );
      if (extra.isEmpty) {
        break;
      }
      replies = [...replies, ...extra];
      attempts++;
    }
    return replies;
  }

  Future<List<ChatMessage>> _streamReply({
    required ChatBackgroundSpeakerPrompt prompt,
    required List<ChatMessage> roundHistory,
    required ModelProvider provider,
    required String apiKey,
    required String model,
    required bool continuation,
    required int alreadySent,
    required int continuationTarget,
  }) async {
    final responder = prompt.responder;
    final history = prompt.showSender
        ? buildGroupRequestHistory(roundHistory, responderId: responder.id)
        : List<ChatMessage>.of(roundHistory);
    final systemPrompt = prompt.buildSystemPrompt(
      roundHistory,
      continuation: continuation,
      alreadySent: alreadySent,
      continuationTarget: continuationTarget,
    );
    final buffer = StringBuffer();
    await for (final chunk in _chatService.streamChat(
      history,
      provider: provider,
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      includeImages: ModelStore.instance.supportsVision(
        ModelStore.instance.selection.value,
      ),
    )) {
      if (!_running.contains(prompt.conversationId)) {
        return const <ChatMessage>[];
      }
      buffer.write(chunk);
    }

    final maxBubbles = continuation
        ? continuationTarget
        : prompt.maxBubbles;
    final burstTarget = continuation ? continuationTarget : prompt.burstTarget;
    final jsonBurst =
        prompt.forceBurst && burstTarget >= 2 && !continuation;
    final raw = buffer.toString();
    final content = prompt.showSender
        ? stripLeadingSpeakerName(raw, responder.displayName).trim()
        : raw.trim();
    if (content.isEmpty) {
      return const <ChatMessage>[];
    }

    final burstMode = containsChatBubbleDelimiter(content);
    List<String> parts;
    if (burstMode) {
      parts = [
        for (final segment in splitChatStreamSegments(content))
          flattenChatBubbleText(
            stripLeadingSpeakerName(segment, responder.displayName).trim(),
          ),
      ];
    } else {
      final parsedBubbles = jsonBurst || continuation
          ? parseJsonChatBubbles(content, maxBubbles: maxBubbles)
          : null;
      final fallbackParts = prompt.allowAutoSplit
          ? splitChatReply(
              content,
              maxBubbles: maxBubbles,
              forceSplit: prompt.forceBurst,
            )
          : splitExplicitChatBubbles(content, maxBubbles: maxBubbles);
      parts = [
        for (final part in (parsedBubbles ?? fallbackParts))
          flattenChatBubbleText(
            stripLeadingSpeakerName(part, responder.displayName).trim(),
          ),
      ];
    }

    parts = [
      for (final part in parts)
        if (part.isNotEmpty) part,
    ];
    if (maxBubbles > 0) {
      parts = capChatBubbleCount(parts, maxBubbles);
    }
    if (parts.isEmpty) {
      return const <ChatMessage>[];
    }

    return [
      for (final part in parts)
        ChatMessage(
          id: _newMessageId(),
          role: ChatRole.assistant,
          content: part,
          createdAt: DateTime.now(),
          senderId: prompt.showSender ? responder.id : '',
          senderName: prompt.showSender ? responder.displayName : '',
        ),
    ];
  }

  Future<void> _persist({
    required ChatBackgroundTurnRequest request,
    required List<ChatMessage> bubbles,
    required List<String> batchIds,
  }) async {
    final conversationId = request.conversationId.trim();
    final latest = [
      for (final message in await ChatHistoryStore.instance.loadFor(
        conversationId,
      ))
        if (!(!message.isUser &&
            message.content.trim().isEmpty &&
            message.image == null))
          message,
    ];
    final existingIds = {for (final message in latest) message.id};
    final additions = [
      for (final bubble in bubbles)
        if (existingIds.add(bubble.id)) bubble,
    ];
    if (additions.isNotEmpty) {
      await ChatHistoryStore.instance.saveFor(conversationId, [
        ...latest,
        ...additions,
      ]);
      ChatHistoryStore.instance.notifyExternalMessages(
        conversationId,
        additions,
      );
    }

    final queued = await ChatQueueStore.instance.loadFor(conversationId);
    final batchIdSet = batchIds.toSet();
    await ChatQueueStore.instance.saveFor(conversationId, [
      for (final messageId in queued)
        if (!batchIdSet.contains(messageId)) messageId,
    ]);

    if (!ActiveConversationStore.instance.isActive(conversationId)) {
      if (additions.isNotEmpty) {
        await UnreadStore.instance.markUnread(
          conversationId,
          count: additions.length,
        );
      }
      final last = additions.isNotEmpty
          ? additions.last
          : (bubbles.isNotEmpty ? bubbles.last : null);
      if (last != null && last.content.trim().isNotEmpty) {
        unawaited(
          LocalNotificationService.instance.showProactive(
            conversationId: conversationId,
            characterName: request.notificationTitle,
            body: last.content,
            settings: ProactiveMessageStore.instance.settings.value,
          ),
        );
      }
    }

    if (additions.isNotEmpty) {
      final last = additions.last;
      unawaited(
        ProactiveMessageService.instance.noteAssistantMessage(
          conversationId,
          messageId: last.id,
          text: last.content,
        ),
      );
    }
  }

  String _newMessageId() {
    final sequence = _messageSequence++;
    return '${DateTime.now().microsecondsSinceEpoch}_bg_$sequence';
  }
}

class ChatBackgroundTurnRequest {
  const ChatBackgroundTurnRequest({
    required this.conversationId,
    required this.isGroup,
    required this.notificationTitle,
    required this.batch,
    required this.roundHistory,
    required this.delay,
    required this.buildPrompts,
  });

  final String conversationId;
  final bool isGroup;
  final String notificationTitle;
  final List<ChatMessage> batch;
  final List<ChatMessage> roundHistory;
  final Duration delay;
  final Future<List<ChatBackgroundSpeakerPrompt>> Function() buildPrompts;
}

class ChatBackgroundSpeakerPrompt {
  const ChatBackgroundSpeakerPrompt({
    required this.conversationId,
    required this.responder,
    required this.showSender,
    required this.forceBurst,
    required this.burstTarget,
    required this.minimum,
    required this.allowAutoSplit,
    required this.maxBubbles,
    required this.buildSystemPrompt,
  });

  final String conversationId;
  final CharacterProfile responder;
  final bool showSender;
  final bool forceBurst;
  final int burstTarget;
  final int minimum;
  final bool allowAutoSplit;
  final int maxBubbles;
  final String Function(
    List<ChatMessage> roundHistory, {
    bool continuation,
    int alreadySent,
    int continuationTarget,
  })
  buildSystemPrompt;
}

class ChatBackgroundTurnResult {
  const ChatBackgroundTurnResult({
    required this.conversationId,
    required this.batchIds,
    required this.bubbles,
    required this.success,
  });

  final String conversationId;
  final List<String> batchIds;
  final List<ChatMessage> bubbles;
  final bool success;
}
