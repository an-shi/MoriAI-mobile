import 'dart:async';

/// 控制用户发消息后，什么时候真正开始请求角色回复。
///
/// 规则：
/// - 发送后用户没有继续输入：等待 [sendDelay] 后回复；
/// - 发送后用户继续输入过：等待输入框失焦，再等待 [focusLeaveDelay] 后回复；
/// - 多条连续发送会合并到同一轮，最后一次发送或失焦会重新计时。
class ChatReplyScheduler {
  ChatReplyScheduler({
    required this.onReady,
    required this.sendDelay,
    required this.focusLeaveDelay,
  });

  final void Function() onReady;
  final Duration Function() sendDelay;
  final Duration Function() focusLeaveDelay;

  Timer? _sendTimer;
  Timer? _focusLeaveTimer;
  bool _pending = false;
  bool _typedSinceSend = false;
  bool _disposed = false;

  bool get isPending => _pending;

  /// 用户发送了一条消息，开始等待下一轮回复。
  ///
  /// [typedSinceSend] 用于回复期间就继续输入的情况：回复结束后恢复等待时，
  /// 直接把“已经打过字”的状态带回来。
  void scheduleAfterSend({bool typedSinceSend = false}) {
    if (_disposed) {
      return;
    }
    if (!_pending) {
      _pending = true;
      _typedSinceSend = typedSinceSend;
    }
    _sendTimer?.cancel();
    _sendTimer = null;
    _focusLeaveTimer?.cancel();
    _focusLeaveTimer = null;

    // 用户在上一轮发送后已经打过字，必须等输入框失焦后再回复。
    if (_typedSinceSend) {
      return;
    }
    _startSendTimer();
  }

  /// 用户在发送后继续输入，取消即将触发的定时器，改为等待失焦。
  void noteInputActivity() {
    if (!_pending || _disposed) {
      return;
    }
    _typedSinceSend = true;
    _sendTimer?.cancel();
    _sendTimer = null;
    _focusLeaveTimer?.cancel();
    _focusLeaveTimer = null;
  }

  /// 输入框焦点变化。
  void noteFocusChanged(bool focused) {
    if (!_pending || _disposed) {
      return;
    }
    if (focused) {
      _focusLeaveTimer?.cancel();
      _focusLeaveTimer = null;
      return;
    }
    if (_typedSinceSend) {
      _startFocusLeaveTimer();
    } else if (_sendTimer == null) {
      _startSendTimer();
    }
  }

  /// 回复真正开始，取消所有等待。
  void markStarted() {
    _sendTimer?.cancel();
    _sendTimer = null;
    _focusLeaveTimer?.cancel();
    _focusLeaveTimer = null;
    _pending = false;
    _typedSinceSend = false;
  }

  /// 清空会话、停止回复或离开页面时取消等待。
  void cancel() {
    markStarted();
  }

  void dispose() {
    cancel();
    _disposed = true;
  }

  void _startSendTimer() {
    _focusLeaveTimer?.cancel();
    _focusLeaveTimer = null;
    _sendTimer?.cancel();
    _sendTimer = Timer(sendDelay(), () {
      _sendTimer = null;
      if (_disposed || !_pending || _typedSinceSend) {
        return;
      }
      _ready();
    });
  }

  void _startFocusLeaveTimer() {
    _sendTimer?.cancel();
    _sendTimer = null;
    _focusLeaveTimer?.cancel();
    _focusLeaveTimer = Timer(focusLeaveDelay(), () {
      _focusLeaveTimer = null;
      if (_disposed || !_pending) {
        return;
      }
      _ready();
    });
  }

  void _ready() {
    _pending = false;
    _typedSinceSend = false;
    onReady();
  }
}
