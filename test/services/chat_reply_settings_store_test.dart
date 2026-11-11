import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_reply_settings.dart';
import 'package:mori_ai/services/chat_reply_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatReplySettingsStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatReplySettingsStore.instance.load();
  });

  test('loads defaults, normalizes and persists', () async {
    final defaults = ChatReplySettingsStore.instance.settings.value;
    expect(defaults.sendDelaySeconds, 2);
    expect(defaults.focusLeaveDelaySeconds, 1);

    final normalized = const ChatReplySettings(
      sendDelaySeconds: -1,
      focusLeaveDelaySeconds: 99,
    ).normalized();
    expect(normalized.sendDelaySeconds, 0);
    expect(normalized.focusLeaveDelaySeconds, 30);

    await ChatReplySettingsStore.instance.save(
      const ChatReplySettings(sendDelaySeconds: 3, focusLeaveDelaySeconds: 2),
    );
    await ChatReplySettingsStore.instance.load();
    expect(ChatReplySettingsStore.instance.settings.value.sendDelaySeconds, 3);
    expect(
      ChatReplySettingsStore.instance.settings.value.focusLeaveDelaySeconds,
      2,
    );
  });
}
