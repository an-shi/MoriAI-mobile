import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/services/chat_reply_scheduler.dart';

void main() {
  test('replies after the send delay when the user stops sending', () {
    fakeAsync((async) {
      var ready = 0;
      final scheduler = ChatReplyScheduler(
        onReady: () => ready++,
        sendDelay: () => const Duration(seconds: 2),
        focusLeaveDelay: () => const Duration(seconds: 1),
      );

      scheduler.scheduleAfterSend();
      async.elapse(const Duration(milliseconds: 1900));
      expect(ready, 0);
      async.elapse(const Duration(milliseconds: 200));
      expect(ready, 1);
    });
  });

  test('multiple sends reset the send timer and become one turn', () {
    fakeAsync((async) {
      var ready = 0;
      final scheduler = ChatReplyScheduler(
        onReady: () => ready++,
        sendDelay: () => const Duration(seconds: 2),
        focusLeaveDelay: () => const Duration(seconds: 1),
      );

      scheduler.scheduleAfterSend();
      async.elapse(const Duration(milliseconds: 1500));
      scheduler.scheduleAfterSend();
      async.elapse(const Duration(milliseconds: 1900));
      expect(ready, 0);
      async.elapse(const Duration(milliseconds: 200));
      expect(ready, 1);
    });
  });

  test('typing after send waits for focus leave', () {
    fakeAsync((async) {
      var ready = 0;
      final scheduler = ChatReplyScheduler(
        onReady: () => ready++,
        sendDelay: () => const Duration(seconds: 2),
        focusLeaveDelay: () => const Duration(seconds: 1),
      );

      scheduler.scheduleAfterSend();
      scheduler.noteInputActivity();
      async.elapse(const Duration(seconds: 5));
      expect(ready, 0);

      scheduler.noteFocusChanged(false);
      async.elapse(const Duration(milliseconds: 900));
      expect(ready, 0);
      async.elapse(const Duration(milliseconds: 200));
      expect(ready, 1);
    });
  });

  test('regaining focus cancels the focus-leave timer', () {
    fakeAsync((async) {
      var ready = 0;
      final scheduler = ChatReplyScheduler(
        onReady: () => ready++,
        sendDelay: () => const Duration(seconds: 2),
        focusLeaveDelay: () => const Duration(seconds: 1),
      );

      scheduler.scheduleAfterSend();
      scheduler.noteInputActivity();
      scheduler.noteFocusChanged(false);
      async.elapse(const Duration(milliseconds: 500));
      scheduler.noteFocusChanged(true);
      async.elapse(const Duration(seconds: 2));
      expect(ready, 0);
    });
  });

  test('markStarted cancels pending timers', () {
    fakeAsync((async) {
      var ready = 0;
      final scheduler = ChatReplyScheduler(
        onReady: () => ready++,
        sendDelay: () => const Duration(seconds: 2),
        focusLeaveDelay: () => const Duration(seconds: 1),
      );

      scheduler.scheduleAfterSend();
      scheduler.markStarted();
      async.elapse(const Duration(seconds: 5));
      expect(ready, 0);
    });
  });
}
