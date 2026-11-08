import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_burst_settings.dart';
import 'package:mori_ai/services/chat_burst_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatBurstSettingsStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatBurstSettingsStore.instance.load();
  });

  test('loads defaults and resolves character overrides', () async {
    final defaults = ChatBurstSettingsStore.instance.settings.value;
    expect(defaults.globalTendency, ChatBurstTendency.natural);
    expect(defaults.characterTendencies, isEmpty);
    expect(defaults.tendencyFor('mori'), ChatBurstTendency.natural);
    expect(defaults.rangeFor(ChatBurstTendency.natural).maxMessages, 3);
    expect(defaults.rangeFor(ChatBurstTendency.natural).maxChars, 60);
    expect(defaults.rangeFor(ChatBurstTendency.active).minMessages, 2);
    expect(defaults.rangeFor(ChatBurstTendency.active).maxMessages, 5);
    expect(defaults.rangeFor(ChatBurstTendency.active).minChars, 15);
    expect(defaults.rangeFor(ChatBurstTendency.active).maxChars, 100);

    await ChatBurstSettingsStore.instance.setGlobalTendency(
      ChatBurstTendency.active,
    );
    await ChatBurstSettingsStore.instance.setCharacterTendency(
      'mori',
      ChatBurstTendency.off,
    );

    final settings = ChatBurstSettingsStore.instance.settings.value;
    expect(settings.globalTendency, ChatBurstTendency.active);
    expect(settings.tendencyFor('mori'), ChatBurstTendency.off);
    expect(settings.tendencyFor('other'), ChatBurstTendency.active);
  });

  test('updates tendency ranges', () async {
    await ChatBurstSettingsStore.instance.setTendencyRange(
      ChatBurstTendency.active,
      const ChatBurstRange(
        minMessages: 3,
        maxMessages: 6,
        minChars: 20,
        maxChars: 120,
      ),
    );

    final range = ChatBurstSettingsStore.instance.settings.value.rangeFor(
      ChatBurstTendency.active,
    );
    expect(range.minMessages, 3);
    expect(range.maxMessages, 6);
    expect(range.minChars, 20);
    expect(range.maxChars, 120);

    await ChatBurstSettingsStore.instance.load();
    final loaded = ChatBurstSettingsStore.instance.settings.value.rangeFor(
      ChatBurstTendency.active,
    );
    expect(loaded.minMessages, 3);
    expect(loaded.maxMessages, 6);
    expect(loaded.minChars, 20);
    expect(loaded.maxChars, 120);
  });

  test('persists and restores settings', () async {
    await ChatBurstSettingsStore.instance.setGlobalTendency(
      ChatBurstTendency.active,
    );
    await ChatBurstSettingsStore.instance.setCharacterTendency(
      'mori',
      ChatBurstTendency.off,
    );

    await ChatBurstSettingsStore.instance.load();
    final settings = ChatBurstSettingsStore.instance.settings.value;
    expect(settings.globalTendency, ChatBurstTendency.active);
    expect(settings.tendencyFor('mori'), ChatBurstTendency.off);
  });

  test('normalizes follow-global overrides and invalid globals', () async {
    final normalized = const ChatBurstSettings(
      globalTendency: ChatBurstTendency.followGlobal,
      characterTendencies: {
        'mori': ChatBurstTendency.followGlobal,
        'other': ChatBurstTendency.active,
      },
    ).normalized();

    expect(normalized.globalTendency, ChatBurstTendency.natural);
    expect(
      normalized.characterTendencies,
      containsPair('other', ChatBurstTendency.active),
    );
    expect(normalized.characterTendencies.containsKey('mori'), isFalse);
  });
}
