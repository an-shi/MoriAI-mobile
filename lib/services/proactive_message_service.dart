import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/config/mori_config.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';
import 'package:mori_ai/models/proactive_message_state.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/character_activity_context_builder.dart';
import 'package:mori_ai/services/character_activity_recorder.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/memory_context_builder.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:mori_ai/utils/chat_bubble_utils.dart';
import 'package:mori_ai/utils/chat_text_utils.dart';

class ProactiveMessageException implements Exception {
  const ProactiveMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 单聊角色主动消息服务。
///
/// 触发方式：
/// - 沉默触发：用户和角色一段时间没有新消息后，在随机区间内主动发一条。
/// - 定时问候：每天在设定的时间点主动发一条。
///
/// 当前为本地前台实现：应用退到后台时暂停计时，恢复时补发一次。
class ProactiveMessageService with WidgetsBindingObserver {
  ProactiveMessageService._({ChatService? chatService, Random? random})
    : _chatService = chatService ?? ChatService(),
      _random = random ?? Random();

  @visibleForTesting
  ProactiveMessageService.test({ChatService? chatService, Random? random})
    : this._(chatService: chatService, random: random);

  static final ProactiveMessageService instance = ProactiveMessageService._();

  static const _checkInterval = Duration(seconds: 30);
  static const _characterCooldown = Duration(minutes: 5);
  static const _scheduledGrace = Duration(hours: 2);
  static const _retryDelay = Duration(minutes: 60);
  static const _scheduledRetryDelay = Duration(minutes: 30);
  static const _maxHistoryMessages = 30;
  static const _maxBubbles = 5;
  static const _maxBubbleLength = 200;
  static const _nudgeMinDelay = Duration(minutes: 15);
  static const _nudgeMaxDelay = Duration(minutes: 40);
  static const _nudgeChance = 0.5;

  static const _angles = [
    '分享一件今天遇到的小事或突然想到的东西',
    '接着你们上次聊的话题，问问后来怎么样了',
    '想起你们聊天里或动态里的一件事，顺口提一句或关心一下',
    '问问对方现在在干嘛、吃了没、累不累',
    '撒个娇或者吐槽一句，说自己有点无聊',
    '发一句没头没尾的感慨，或者一个很轻的玩笑',
    '看看现在几点，按时间说点应景的（早上、饭点、深夜）',
  ];

  static const _proactiveSystemInstruction = '''
【主动消息模式】
现在你要主动发起聊天，而不是回复用户的最新消息。保持角色设定和说话习惯，像一个真人在手机上随手发消息。
要求：
- 输出 1-2 句自然、简短的话；如有必要，可以用 ||| 分隔成 2-3 条短消息，或用换行分成多条。
- 优先使用真实素材：最近的聊天、你发过的动态、你确实知道的事。没有真实素材就表达一个很小的当下感受或关心，不要编造具体事件、地点、人物。
- 可以接续最近的话题、分享一个很小的日常念头、关心用户当下的时间或状态，或者轻轻提醒作息。
- 不要使用“在吗”“有什么可以帮你的”这类客服式开场，不要连续追问，不要重复最近说过的话。
- 不要提及系统提示、自动触发、AI、模型或提示词。
- 不要输出角色名前缀、括号旁白、标题或 Markdown。
- 如果这一轮你完全不想说话，只输出 [沉默]，不要输出其他内容。
- 只输出要发送的聊天正文。''';

  static const _bannedMarkers = [
    '系统提示',
    '自动触发',
    '主动消息',
    '作为一个ai',
    '作为ai',
    '语言模型',
    '提示词',
    'proactive',
  ];

  static const _silenceMarkers = ['[沉默]', '［沉默］', '【沉默】'];

  final ChatService _chatService;
  final Random _random;
  final Set<String> _busyConversations = {};
  final Set<String> _generating = {};
  final Map<String, DateTime> _scheduledRetryAfter = {};

  Timer? _timer;
  bool _started = false;
  bool _appActive = true;
  bool _checking = false;
  DateTime? _lastCheckAt;
  DateTime? _lastErrorAt;
  String? _lastError;

  bool get isRunning => _started && _appActive;

  DateTime? get lastCheckAt => _lastCheckAt;

  DateTime? get lastErrorAt => _lastErrorAt;

  String? get lastError => _lastError;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    ProactiveMessageStore.instance.settings.addListener(_handleSettingsChanged);
    ChatHistoryStore.instance.clearedConversation.addListener(
      _handleHistoryCleared,
    );
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _scheduleTimer();
    unawaited(_checkAll());
  }

  @visibleForTesting
  void stop() {
    if (!_started) {
      return;
    }
    _started = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    ProactiveMessageStore.instance.settings.removeListener(
      _handleSettingsChanged,
    );
    ChatHistoryStore.instance.clearedConversation.removeListener(
      _handleHistoryCleared,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) {
      return;
    }
    _appActive = active;
    if (active) {
      _scheduleTimer();
      unawaited(_checkAll());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// 标记某个会话正在生成回复，自动消息会让路。
  void setConversationBusy(String conversationId, bool busy) {
    if (busy) {
      _busyConversations.add(conversationId);
    } else {
      _busyConversations.remove(conversationId);
    }
  }

  /// 用户发送或删除消息后调用，重置未回复计数并重新计算沉默时间。
  Future<void> noteUserMessage(String conversationId) async {
    if (!_started || !_isSingleChat(conversationId)) {
      return;
    }
    final now = DateTime.now();
    final state = _rollover(await _stateFor(conversationId), now);
    await _saveState(
      conversationId,
      state.copyWith(
        lastActivityAtMs: now.millisecondsSinceEpoch,
        lastUserMessageAtMs: now.millisecondsSinceEpoch,
        nextSilenceAtMs: now.add(_randomSilence()).millisecondsSinceEpoch,
        unansweredCount: 0,
      ),
    );
  }

  /// 角色正常回复用户后调用，记录最后一条回复并重置下一次沉默触发的计时起点。
  Future<void> noteAssistantMessage(
    String conversationId, {
    String? messageId,
    String? text,
  }) async {
    if (!_started || !_isSingleChat(conversationId)) {
      return;
    }
    final now = DateTime.now();
    final state = _rollover(await _stateFor(conversationId), now);
    var assistantId = messageId?.trim() ?? '';
    var assistantText = text?.trim() ?? '';
    if (assistantId.isEmpty || assistantText.isEmpty) {
      final history = await ChatHistoryStore.instance.loadFor(conversationId);
      for (var index = history.length - 1; index >= 0; index--) {
        if (!history[index].isUser) {
          assistantId = history[index].id;
          assistantText = history[index].content.trim();
          break;
        }
      }
    }
    await _saveState(
      conversationId,
      state.copyWith(
        lastActivityAtMs: now.millisecondsSinceEpoch,
        lastAssistantAtMs: now.millisecondsSinceEpoch,
        lastAssistantMessageId: assistantId,
        lastAssistantText: assistantText.length > 300
            ? assistantText.substring(assistantText.length - 300)
            : assistantText,
        nextSilenceAtMs: now.add(_randomSilence()).millisecondsSinceEpoch,
      ),
    );
  }

  /// 读取并初始化某个角色的自动消息状态，供角色设置页展示。
  Future<ProactiveMessageState> conversationState(String conversationId) {
    return _stateFor(conversationId);
  }

  /// 更新单个角色的自动消息开关和每日上限。
  Future<void> updateConversationConfig(
    String conversationId, {
    bool? enabled,
    int? dailyLimit,
  }) async {
    if (!_isSingleChat(conversationId)) {
      return;
    }
    final state = await _stateFor(conversationId);
    await _saveState(
      conversationId,
      state.copyWith(
        enabled: enabled,
        dailyLimit: dailyLimit == null
            ? null
            : dailyLimit < 0
            ? ProactiveMessageSettings.unlimited
            : dailyLimit,
      ),
    );
  }

  /// 设置页“立即发一条”使用。手动触发不消耗每日额度，也不增加未回复计数。
  /// 返回 false 表示模型这轮选择了沉默或没有发送条件。
  Future<bool> triggerNow(String conversationId) async {
    if (!_isSingleChat(conversationId)) {
      throw const ProactiveMessageException('当前只支持角色单聊主动消息。');
    }
    return _trigger(conversationId, manual: true);
  }

  /// 立即执行一次检查。用于设置页“立即检查一次”。
  Future<void> checkNow() async {
    final wasStarted = _started;
    _started = true;
    _appActive = true;
    try {
      await _checkAll();
    } finally {
      _started = wasStarted;
    }
  }

  @visibleForTesting
  Future<void> runCheckForTest() => checkNow();

  /// 汇总自动消息当前状态，供设置页排查“为什么没有发送”。
  Future<ProactiveMessageDiagnostics> diagnose() async {
    final settings = ProactiveMessageStore.instance.settings.value;
    final now = DateTime.now();
    final modelConfigured = _hasModelConfig();
    final quietNow = settings.isQuietTime(now);
    final cards = CharacterStore.instance.cards.value;

    final states = <String, ProactiveMessageState>{};
    final histories = <String, bool>{};
    var totalToday = 0;
    for (final card in cards) {
      final state = _rollover(await _stateFor(card.id), now);
      states[card.id] = state;
      histories[card.id] =
          await ChatHistoryStore.instance.summaryFor(card.id) != null;
      totalToday += state.dailyCount;
    }

    final rows = <ProactiveMessageDiagnostic>[];
    for (final card in cards) {
      final state = states[card.id]!;
      final hasHistory = histories[card.id] ?? false;
      final characterLimit = state.dailyLimit < 0
          ? null
          : state.dailyLimit > 0
          ? state.dailyLimit
          : (settings.dailyLimit < 0 ? null : settings.dailyLimit);
      final scheduledRetryAt = _scheduledRetryAfter[card.id];
      final scheduledRetryPending =
          scheduledRetryAt != null && scheduledRetryAt.isAfter(now);
      final scheduledDue =
          settings.scheduledEnabled &&
          !scheduledRetryPending &&
          _dueScheduledSlot(settings, state, now) != null;
      final silenceDue = settings.silenceEnabled && _silenceDue(state, now);
      final characterCooldown = _characterCooldownRemaining(state, now);
      final cooldownActive = characterCooldown != null;
      final unansweredBlocked =
          settings.maxUnanswered >= 0 &&
          state.unansweredCount >= settings.maxUnanswered;
      final characterLimitBlocked =
          characterLimit != null && state.dailyCount >= characterLimit;
      final globalLimitBlocked =
          settings.dailyLimit >= 0 && totalToday >= settings.dailyLimit;

      String reason;
      if (!settings.enabled) {
        reason = '全局自动消息已关闭';
      } else if (!modelConfigured) {
        reason = '未配置模型或 API Key';
      } else if (!state.enabled) {
        reason = '该角色已关闭自动消息';
      } else if (!hasHistory) {
        reason = '该角色还没有聊天记录';
      } else if (unansweredBlocked) {
        reason = '连续未回复已达上限';
      } else if (characterLimitBlocked) {
        reason = '该角色今日已达上限';
      } else if (globalLimitBlocked) {
        reason = '所有角色今日总量已达上限';
      } else if (quietNow) {
        reason = '当前处于免打扰时段';
      } else if (_busyConversations.contains(card.id) ||
          _generating.contains(card.id)) {
        reason = '该角色正在生成回复';
      } else if (scheduledRetryPending) {
        reason = '定时问候发送失败，等待重试';
      } else if (scheduledDue) {
        reason = '定时问候已到时间，可以触发（不受角色冷却限制）';
      } else if (cooldownActive) {
        reason = '该角色刚触发过，冷却中';
      } else if (silenceDue) {
        reason = '条件已满足，可以触发';
      } else {
        reason = '等待下一次触发';
      }

      rows.add(
        ProactiveMessageDiagnostic(
          characterName: card.displayName,
          reason: reason,
          dailyCount: state.dailyCount,
          dailyLimit: characterLimit ?? -1,
          unansweredCount: state.unansweredCount,
          maxUnanswered: settings.maxUnanswered,
          nextSilenceAt: state.nextSilenceAt,
          lastProactiveAt: state.lastProactiveAt,
          cooldownRemaining: characterCooldown,
          firedSlots: state.firedSlots,
        ),
      );
    }

    return ProactiveMessageDiagnostics(
      globalEnabled: settings.enabled,
      modelConfigured: modelConfigured,
      serviceRunning: isRunning,
      quietNow: quietNow,
      lastCheckAt: _lastCheckAt,
      lastError: _lastError,
      lastErrorAt: _lastErrorAt,
      totalToday: totalToday,
      globalDailyLimit: settings.dailyLimit,
      conversations: List<ProactiveMessageDiagnostic>.unmodifiable(rows),
    );
  }

  void _scheduleTimer() {
    _timer?.cancel();
    if (!_started || !_appActive) {
      return;
    }
    _timer = Timer.periodic(_checkInterval, (_) {
      unawaited(_checkAll());
    });
  }

  void _handleSettingsChanged() {
    if (_started && _appActive) {
      unawaited(_checkAll());
    }
  }

  void _handleHistoryCleared() {
    final conversationId = ChatHistoryStore.instance.clearedConversation.value;
    if (conversationId.isNotEmpty) {
      unawaited(ProactiveMessageStore.instance.deleteState(conversationId));
    }
  }

  Future<void> _checkAll() async {
    if (!_started || !_appActive || _checking) {
      return;
    }

    final now = DateTime.now();
    _lastCheckAt = now;

    final settings = ProactiveMessageStore.instance.settings.value;
    if (!settings.enabled) {
      return;
    }
    if (!_hasModelConfig()) {
      return;
    }

    _checking = true;
    try {
      _DueConversation? best;
      var totalToday = 0;
      for (final card in CharacterStore.instance.cards.value) {
        if (_busyConversations.contains(card.id) ||
            _generating.contains(card.id)) {
          continue;
        }

        final loaded = await _stateFor(card.id);
        final state = _rollover(loaded, now);
        if (!_sameState(state, loaded)) {
          await _saveState(card.id, state);
        }
        totalToday += state.dailyCount;
        final characterCooldownActive = _characterCooldownActive(state, now);

        if (!state.enabled) {
          continue;
        }

        if (settings.isQuietTime(now)) {
          if (settings.silenceEnabled && _silenceDue(state, now)) {
            final quietEnd = _nextQuietEnd(settings, now);
            await _saveState(
              card.id,
              state.copyWith(
                nextSilenceAtMs: quietEnd
                    .add(Duration(minutes: _random.nextInt(21)))
                    .millisecondsSinceEpoch,
              ),
            );
          }
          continue;
        }

        if (settings.nudgeEnabled &&
            !characterCooldownActive &&
            _nudgeDue(state, now)) {
          best = _DueConversation(
            conversationId: card.id,
            state: state,
            slotKey: null,
            priority: -1,
            nudge: true,
          );
          continue;
        }

        final characterLimit = state.dailyLimit < 0
            ? null
            : state.dailyLimit > 0
            ? state.dailyLimit
            : (settings.dailyLimit < 0 ? null : settings.dailyLimit);
        final unansweredBlocked =
            settings.maxUnanswered >= 0 &&
            state.unansweredCount >= settings.maxUnanswered;
        final characterLimitBlocked =
            characterLimit != null && state.dailyCount >= characterLimit;
        if (unansweredBlocked || characterLimitBlocked) {
          continue;
        }

        final scheduledRetryAt = _scheduledRetryAfter[card.id];
        if (scheduledRetryAt != null && !scheduledRetryAt.isAfter(now)) {
          _scheduledRetryAfter.remove(card.id);
        }
        final scheduledBlocked =
            scheduledRetryAt != null && scheduledRetryAt.isAfter(now);
        final slotKey = settings.scheduledEnabled && !scheduledBlocked
            ? _dueScheduledSlot(settings, state, now)
            : null;
        final silenceDue =
            !characterCooldownActive &&
            settings.silenceEnabled &&
            _silenceDue(state, now);
        if (slotKey == null && !silenceDue) {
          continue;
        }

        final priority = slotKey != null ? 0 : 1;
        if (best == null ||
            priority < best.priority ||
            (priority == best.priority &&
                state.lastProactiveAtMs < best.state.lastProactiveAtMs)) {
          best = _DueConversation(
            conversationId: card.id,
            state: state,
            slotKey: slotKey,
            priority: priority,
            nudge: false,
          );
        }
      }

      final globalLimitBlocked =
          settings.dailyLimit >= 0 && totalToday >= settings.dailyLimit;
      if (best == null || (!best.nudge && globalLimitBlocked)) {
        return;
      }
      await _trigger(
        best.conversationId,
        scheduledSlotKey: best.slotKey,
        nudge: best.nudge,
      );
    } catch (error) {
      _lastError = error.toString();
      _lastErrorAt = DateTime.now();
    } finally {
      _checking = false;
    }
  }

  Future<bool> _trigger(
    String conversationId, {
    String? scheduledSlotKey,
    bool manual = false,
    bool nudge = false,
  }) async {
    if (!_generating.add(conversationId)) {
      if (manual) {
        throw const ProactiveMessageException('该角色正在生成主动消息，请稍候。');
      }
      return false;
    }

    final startedAt = DateTime.now();
    try {
      final character = CharacterStore.instance.cardById(conversationId);
      if (character == null) {
        throw const ProactiveMessageException('角色卡不存在或已被删除。');
      }
      var state = _rollover(await _stateFor(conversationId), startedAt);
      final history = await ChatHistoryStore.instance.loadFor(conversationId);

      if (nudge && state.lastAssistantMessageId.isEmpty) {
        return false;
      }

      // 先占住下一次触发时间，避免生成期间重复触发。
      // 定时槽位不在这里消费：只有发送成功或模型明确沉默后才标记为已完成。
      state = state.copyWith(
        nextSilenceAtMs: startedAt.add(_retryDelay).millisecondsSinceEpoch,
        nudgedMessageId: nudge
            ? state.lastAssistantMessageId
            : state.nudgedMessageId,
      );
      await _saveState(conversationId, state);

      if (!manual && history.isEmpty) {
        await _saveState(
          conversationId,
          state.copyWith(
            nextSilenceAtMs: startedAt
                .add(_randomSilence())
                .millisecondsSinceEpoch,
          ),
        );
        return false;
      }

      final prompt = nudge
          ? _nudgePrompt(character, state, startedAt)
          : _triggerPrompt(character, state, startedAt);
      final content = await _generate(
        character: character,
        history: history,
        trigger: prompt,
      );

      if (CharacterStore.instance.cardById(conversationId) == null) {
        await ProactiveMessageStore.instance.deleteState(conversationId);
        return false;
      }

      if (content == null) {
        // 模型选择沉默：不写入消息，也不消耗额度和未回复计数。
        // 这是有意的“不说”，定时槽位视为已完成。
        await _saveState(
          conversationId,
          _markScheduledSlot(
            state.copyWith(
              nextSilenceAtMs: startedAt
                  .add(_randomSilence())
                  .millisecondsSinceEpoch,
            ),
            scheduledSlotKey,
          ),
        );
        _scheduledRetryAfter.remove(conversationId);
        return false;
      }

      final latest = await ChatHistoryStore.instance.loadFor(conversationId);
      if (!manual) {
        final latestState = await ProactiveMessageStore.instance.loadState(
          conversationId,
        );
        if (latestState != null &&
            latestState.lastActivityAtMs > startedAt.millisecondsSinceEpoch) {
          // 用户在生成期间发过消息，自动消息让路。
          await _saveState(
            conversationId,
            _markScheduledSlot(
              state.copyWith(
                nextSilenceAtMs: startedAt
                    .add(_randomSilence())
                    .millisecondsSinceEpoch,
              ),
              scheduledSlotKey,
            ),
          );
          _scheduledRetryAfter.remove(conversationId);
          await noteUserMessage(conversationId);
          return false;
        }
        if (latest.isEmpty && history.isNotEmpty) {
          // 生成期间聊天记录被清空，放弃这条消息。
          await _saveState(
            conversationId,
            _markScheduledSlot(
              state.copyWith(
                nextSilenceAtMs: startedAt
                    .add(_randomSilence())
                    .millisecondsSinceEpoch,
              ),
              scheduledSlotKey,
            ),
          );
          _scheduledRetryAfter.remove(conversationId);
          return false;
        }
        final userSpoke = latest.any(
          (message) =>
              message.isUser &&
              (message.createdAt?.isAfter(startedAt) ?? false),
        );
        if (userSpoke) {
          // 用户正在聊天，自动消息让路。
          await _saveState(
            conversationId,
            _markScheduledSlot(
              state.copyWith(
                nextSilenceAtMs: startedAt
                    .add(_randomSilence())
                    .millisecondsSinceEpoch,
              ),
              scheduledSlotKey,
            ),
          );
          _scheduledRetryAfter.remove(conversationId);
          await noteUserMessage(conversationId);
          return false;
        }
      }

      final bubbles = _buildBubbles(content, character, startedAt);
      if (bubbles.isEmpty) {
        throw const ProactiveMessageException('角色没有生成有效内容。');
      }

      await ChatHistoryStore.instance.saveFor(conversationId, [
        ...latest,
        ...bubbles,
      ]);
      ChatHistoryStore.instance.notifyExternalMessages(conversationId, bubbles);
      unawaited(
        CharacterActivityRecorder.recordProactiveMessages(
          character: character,
          messages: bubbles,
        ),
      );

      final next = startedAt.add(_randomSilence());
      final countTowardsQuota = !manual && !nudge;
      state = _markScheduledSlot(
        state.copyWith(
          lastActivityAtMs: startedAt.millisecondsSinceEpoch,
          nextSilenceAtMs: next.millisecondsSinceEpoch,
          lastProactiveAtMs: startedAt.millisecondsSinceEpoch,
          unansweredCount: countTowardsQuota
              ? state.unansweredCount + 1
              : state.unansweredCount,
          dailyDate: _dateKey(startedAt),
          dailyCount: countTowardsQuota
              ? state.dailyCount + 1
              : state.dailyCount,
        ),
        scheduledSlotKey,
      );
      await _saveState(conversationId, state);
      _scheduledRetryAfter.remove(conversationId);
      _lastError = null;
      _lastErrorAt = null;
      return true;
    } on ProactiveMessageException catch (error) {
      _lastError = error.message;
      _lastErrorAt = DateTime.now();
      if (scheduledSlotKey != null) {
        _scheduledRetryAfter[conversationId] = startedAt.add(
          _scheduledRetryDelay,
        );
      }
      rethrow;
    } catch (error) {
      _lastError = error.toString();
      _lastErrorAt = DateTime.now();
      if (scheduledSlotKey != null) {
        _scheduledRetryAfter[conversationId] = startedAt.add(
          _scheduledRetryDelay,
        );
      }
      throw const ProactiveMessageException('生成主动消息失败，请稍后重试。');
    } finally {
      _generating.remove(conversationId);
    }
  }

  Future<String?> _generate({
    required CharacterProfile character,
    required List<ChatMessage> history,
    required String trigger,
  }) async {
    final selection = ModelStore.instance.selection.value;
    final provider =
        ModelProviderCatalog.byId(selection.providerId) ??
        ModelProviderCatalog.defaultProvider;
    final apiKey = ApiKeyStore.instance.keyFor(provider.id).value?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw ProactiveMessageException(
        '请先在「设置 > 模型」中填写 ${provider.name} API Key。',
      );
    }
    if (!selection.hasModel) {
      throw const ProactiveMessageException('请先在「设置 > 模型」中选择一个模型。');
    }

    final recent = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    final buffer = StringBuffer();
    final activityContext = CharacterActivityContextBuilder.instance
        .buildForProactive(character.id);
    var memoryQuery = '';
    for (final message in recent.reversed) {
      if (message.isUser && message.content.trim().isNotEmpty) {
        memoryQuery = message.content.trim();
        break;
      }
    }
    final memoryContext = MemoryContextBuilder.instance.buildForProactive(
      character.id,
      query: memoryQuery,
    );
    final moodContext = MoodStore.instance.contextLine(character.id);
    final systemPrompt =
        '${MoriConfig.buildSystemPrompt(character)}\n\n'
        '$_proactiveSystemInstruction'
        '${activityContext.isEmpty ? '' : '\n\n$activityContext'}'
        '${memoryContext.isEmpty ? '' : '\n\n$memoryContext'}'
        '${moodContext.isEmpty ? '' : '\n\n$moodContext'}';
    try {
      await for (final chunk in _chatService.streamChat(
        [...recent, ChatMessage(role: ChatRole.user, content: trigger)],
        provider: provider,
        apiKey: apiKey,
        model: selection.modelId,
        systemPrompt: systemPrompt,
        temperature: 0.95,
      )) {
        buffer.write(chunk);
      }
    } on ChatServiceException catch (error) {
      throw ProactiveMessageException(error.message);
    } catch (_) {
      throw const ProactiveMessageException('生成主动消息失败，请稍后重试。');
    }

    final content = _normalize(buffer.toString(), character.displayName);
    if (_isSilence(content)) {
      return null;
    }
    if (content.isEmpty) {
      throw const ProactiveMessageException('角色没有生成有效内容。');
    }
    final lower = content.toLowerCase();
    if (_bannedMarkers.any((marker) => lower.contains(marker))) {
      throw const ProactiveMessageException('角色生成了不符合聊天语境的内容。');
    }
    return content;
  }

  String _triggerPrompt(
    CharacterProfile character,
    ProactiveMessageState state,
    DateTime now,
  ) {
    final silence = _formatDuration(
      now.difference(state.lastActivityAt ?? now),
    );
    final unanswered = state.unansweredCount;
    final angle = _angles[_random.nextInt(_angles.length)];
    final recentMoments = MomentStore.instance.moments.value
        .where(
          (moment) =>
              moment.authorId == character.id &&
              moment.content.trim().isNotEmpty,
        )
        .take(3)
        .map((moment) {
          final content = moment.content.trim();
          return content.length > 80
              ? '- ${content.substring(0, 80)}…'
              : '- $content';
        })
        .join('\n');
    return '''
（这是一条内部提醒，不是用户消息）
现在是 ${now.month} 月 ${now.day} 日 ${_timeLabel(now)}，距离上次聊天已经过去 $silence。
${unanswered > 0 ? '你最近已经主动发过 $unanswered 条消息，用户还没有回复。请自然一点，不要质问用户为什么不回。' : ''}
${recentMoments.isEmpty ? '' : '你最近发过的动态（可以作为主动聊天的素材，不要照抄）：\n$recentMoments\n'}
这次的由头可以是：$angle。
优先使用真实素材：最近的聊天、你发过的动态、你确实知道的事。没有真实素材就表达一个很小的当下感受或关心，不要编造具体事件、地点或人物。
请以「${character.displayName}」的身份主动给用户发一条消息。只输出要发送的正文；如果这轮不想说，只输出 [沉默]。''';
  }

  String _nudgePrompt(
    CharacterProfile character,
    ProactiveMessageState state,
    DateTime now,
  ) {
    final lastText = state.lastAssistantText.trim();
    final shortText = lastText.length > 80
        ? '…${lastText.substring(lastText.length - 80)}'
        : lastText;
    final quiet = _formatDuration(now.difference(state.lastAssistantAt ?? now));
    return '''
（这是一条内部提醒，不是用户消息）
你刚才对用户说「$shortText」，用户已经 $quiet 没有回复了。
可以轻轻追一句，比如问一句「人呢」「睡着啦？」，或者换个轻松的话题；别催、别抱怨、别连续追问。
如果觉得对方在忙，或者不想打扰，只输出 [沉默]。
请以「${character.displayName}」的身份只输出要发送的正文。''';
  }

  List<ChatMessage> _buildBubbles(
    String content,
    CharacterProfile character,
    DateTime now,
  ) {
    final lines = <String>[];
    for (final part in splitChatReply(content, maxBubbles: _maxBubbles)) {
      final line = flattenChatBubbleText(
        _normalize(part, character.displayName),
      );
      if (line.isNotEmpty) {
        lines.add(
          line.length > _maxBubbleLength
              ? '${line.substring(0, _maxBubbleLength)}…'
              : line,
        );
      }
    }
    return [
      for (var index = 0; index < lines.length; index++)
        ChatMessage(
          id:
              '${now.microsecondsSinceEpoch}_proactive_'
              '${index}_${_random.nextInt(100000)}',
          role: ChatRole.assistant,
          content: lines[index],
          createdAt: now.add(Duration(milliseconds: index)),
        ),
    ];
  }

  String _normalize(String raw, String characterName) {
    var content = normalizeGeneratedChatText(raw, characterName).trim();
    if (content.length > 2000) {
      content = content.substring(0, 2000);
    }
    return content;
  }

  Future<ProactiveMessageState> _stateFor(String conversationId) async {
    final loaded = await ProactiveMessageStore.instance.loadState(
      conversationId,
    );
    if (loaded != null) {
      if (loaded.nextSilenceAtMs > 0) {
        return loaded;
      }
      final base = loaded.lastActivityAt ?? DateTime.now();
      final fixed = loaded.copyWith(
        nextSilenceAtMs: base.add(_randomSilence()).millisecondsSinceEpoch,
      );
      await ProactiveMessageStore.instance.saveState(conversationId, fixed);
      return fixed;
    }

    final now = DateTime.now();
    final history = await ChatHistoryStore.instance.loadFor(conversationId);
    DateTime? lastActivity;
    DateTime? lastUser;
    DateTime? lastAssistant;
    var assistantId = '';
    var assistantText = '';
    for (var index = history.length - 1; index >= 0; index--) {
      final message = history[index];
      if (lastActivity == null && message.createdAt != null) {
        lastActivity = message.createdAt;
      }
      if (message.isUser) {
        lastUser ??= message.createdAt;
      } else {
        lastAssistant ??= message.createdAt;
        if (assistantId.isEmpty && message.content.trim().isNotEmpty) {
          assistantId = message.id;
          assistantText = message.content.trim();
        }
      }
    }
    final base = lastActivity ?? now;
    final state = ProactiveMessageState(
      lastActivityAtMs: base.millisecondsSinceEpoch,
      nextSilenceAtMs: (history.isEmpty ? now : base)
          .add(_randomSilence())
          .millisecondsSinceEpoch,
      lastUserMessageAtMs: lastUser?.millisecondsSinceEpoch ?? 0,
      lastAssistantAtMs: lastAssistant?.millisecondsSinceEpoch ?? 0,
      lastAssistantMessageId: assistantId,
      lastAssistantText: assistantText.length > 300
          ? assistantText.substring(assistantText.length - 300)
          : assistantText,
      dailyDate: _dateKey(now),
    );
    await ProactiveMessageStore.instance.saveState(conversationId, state);
    return state;
  }

  Future<void> _saveState(String conversationId, ProactiveMessageState state) {
    return ProactiveMessageStore.instance.saveState(conversationId, state);
  }

  ProactiveMessageState _markScheduledSlot(
    ProactiveMessageState state,
    String? slotKey,
  ) {
    if (slotKey == null || state.firedSlots.contains(slotKey)) {
      return state;
    }
    return state.copyWith(firedSlots: [...state.firedSlots, slotKey]);
  }

  ProactiveMessageState _rollover(ProactiveMessageState state, DateTime now) {
    final today = _dateKey(now);
    if (state.dailyDate == today) {
      return state;
    }
    return state.copyWith(
      dailyDate: today,
      dailyCount: 0,
      firedSlots: const [],
    );
  }

  bool _silenceDue(ProactiveMessageState state, DateTime now) {
    return state.nextSilenceAtMs > 0 &&
        now.millisecondsSinceEpoch >= state.nextSilenceAtMs;
  }

  bool _nudgeDue(ProactiveMessageState state, DateTime now) {
    if (state.lastAssistantMessageId.isEmpty || state.lastAssistantAtMs == 0) {
      return false;
    }
    if (state.nudgedMessageId == state.lastAssistantMessageId) {
      return false;
    }
    if (state.lastUserMessageAtMs > state.lastAssistantAtMs) {
      return false;
    }
    final elapsed = now.millisecondsSinceEpoch - state.lastAssistantAtMs;
    if (elapsed < _nudgeMinDelay.inMilliseconds ||
        elapsed > _nudgeMaxDelay.inMilliseconds) {
      return false;
    }
    if (!_looksLikeQuestion(state.lastAssistantText)) {
      return false;
    }
    return _random.nextDouble() < _nudgeChance;
  }

  bool _looksLikeQuestion(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return RegExp(r'[？?]|吗|呢|嘛|没$').hasMatch(trimmed);
  }

  bool _isSilence(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.length > 40) {
      return false;
    }
    return _silenceMarkers.any(trimmed.contains);
  }

  bool _characterCooldownActive(ProactiveMessageState state, DateTime now) {
    return _characterCooldownRemaining(state, now) != null;
  }

  Duration? _characterCooldownRemaining(
    ProactiveMessageState state,
    DateTime now,
  ) {
    if (state.lastProactiveAtMs <= 0) {
      return null;
    }
    final elapsed = now.millisecondsSinceEpoch - state.lastProactiveAtMs;
    if (elapsed >= _characterCooldown.inMilliseconds) {
      return null;
    }
    return Duration(milliseconds: _characterCooldown.inMilliseconds - elapsed);
  }

  String? _dueScheduledSlot(
    ProactiveMessageSettings settings,
    ProactiveMessageState state,
    DateTime now,
  ) {
    for (final minute in settings.scheduledMinuteValues) {
      final slot = DateTime(
        now.year,
        now.month,
        now.day,
        minute ~/ 60,
        minute % 60,
      );
      if (slot.isAfter(now)) {
        continue;
      }
      if (now.difference(slot) > _scheduledGrace) {
        continue;
      }
      if (settings.isQuietTime(slot)) {
        continue;
      }
      final key = _slotKey(slot);
      if (!state.firedSlots.contains(key)) {
        return key;
      }
    }
    return null;
  }

  DateTime _nextQuietEnd(ProactiveMessageSettings settings, DateTime now) {
    final endMinute = settings.quietEndMinutes;
    final todayEnd = DateTime(
      now.year,
      now.month,
      now.day,
      endMinute ~/ 60,
      endMinute % 60,
    );
    if (todayEnd.isAfter(now)) {
      return todayEnd;
    }
    return DateTime(
      now.year,
      now.month,
      now.day + 1,
      endMinute ~/ 60,
      endMinute % 60,
    );
  }

  Duration _randomSilence() {
    final settings = ProactiveMessageStore.instance.settings.value;
    final min = settings.silenceMinMinutes;
    final max = settings.silenceMaxMinutes;
    final span = max - min;
    final int minutes;
    if (span <= 0) {
      minutes = min;
    } else if (span > 0x7fffffff) {
      minutes = min + (_random.nextDouble() * span).round();
    } else {
      minutes = min + _random.nextInt(span + 1);
    }
    return Duration(minutes: minutes);
  }

  bool _hasModelConfig() {
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

  bool _isSingleChat(String conversationId) {
    return CharacterStore.instance.cardById(conversationId) != null;
  }

  bool _sameState(ProactiveMessageState a, ProactiveMessageState b) {
    return a.enabled == b.enabled &&
        a.dailyLimit == b.dailyLimit &&
        a.dailyDate == b.dailyDate &&
        a.dailyCount == b.dailyCount &&
        a.firedSlots.length == b.firedSlots.length &&
        a.lastActivityAtMs == b.lastActivityAtMs &&
        a.nextSilenceAtMs == b.nextSilenceAtMs &&
        a.lastProactiveAtMs == b.lastProactiveAtMs &&
        a.lastUserMessageAtMs == b.lastUserMessageAtMs &&
        a.lastAssistantAtMs == b.lastAssistantAtMs &&
        a.lastAssistantMessageId == b.lastAssistantMessageId &&
        a.lastAssistantText == b.lastAssistantText &&
        a.nudgedMessageId == b.nudgedMessageId &&
        a.unansweredCount == b.unansweredCount;
  }

  String _timeLabel(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '刚刚';
    }
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) {
      return hours > 0 ? '$days 天 $hours 小时' : '$days 天';
    }
    if (hours > 0) {
      return minutes > 0 ? '$hours 小时 $minutes 分钟' : '$hours 小时';
    }
    if (minutes > 0) {
      return '$minutes 分钟';
    }
    return '刚刚';
  }

  String _dateKey(DateTime time) {
    return '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')}';
  }

  String _slotKey(DateTime time) {
    return '${_dateKey(time)}|${_timeLabel(time)}';
  }
}

class ProactiveMessageDiagnostics {
  const ProactiveMessageDiagnostics({
    required this.globalEnabled,
    required this.modelConfigured,
    required this.serviceRunning,
    required this.quietNow,
    required this.lastCheckAt,
    required this.lastError,
    required this.lastErrorAt,
    required this.totalToday,
    required this.globalDailyLimit,
    required this.conversations,
  });

  final bool globalEnabled;
  final bool modelConfigured;
  final bool serviceRunning;
  final bool quietNow;
  final DateTime? lastCheckAt;
  final String? lastError;
  final DateTime? lastErrorAt;
  final int totalToday;
  final int globalDailyLimit;
  final List<ProactiveMessageDiagnostic> conversations;
}

class ProactiveMessageDiagnostic {
  const ProactiveMessageDiagnostic({
    required this.characterName,
    required this.reason,
    required this.dailyCount,
    required this.dailyLimit,
    required this.unansweredCount,
    required this.maxUnanswered,
    required this.nextSilenceAt,
    required this.lastProactiveAt,
    required this.cooldownRemaining,
    required this.firedSlots,
  });

  final String characterName;
  final String reason;
  final int dailyCount;
  final int dailyLimit;
  final int unansweredCount;
  final int maxUnanswered;
  final DateTime? nextSilenceAt;
  final DateTime? lastProactiveAt;
  final Duration? cooldownRemaining;
  final List<String> firedSlots;
}

class _DueConversation {
  const _DueConversation({
    required this.conversationId,
    required this.state,
    required this.slotKey,
    required this.priority,
    required this.nudge,
  });

  final String conversationId;
  final ProactiveMessageState state;
  final String? slotKey;
  final int priority;
  final bool nudge;
}
