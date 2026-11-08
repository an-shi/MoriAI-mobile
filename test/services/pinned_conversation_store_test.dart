import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/services/pinned_conversation_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PinnedConversationStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await PinnedConversationStore.instance.load();
  });

  test('persists pinned conversation ids', () async {
    await PinnedConversationStore.instance.setPinned('mori', true);
    await PinnedConversationStore.instance.setPinned('group_1', true);
    await PinnedConversationStore.instance.setPinned('group_1', false);

    expect(PinnedConversationStore.instance.isPinned('mori'), isTrue);
    expect(PinnedConversationStore.instance.isPinned('group_1'), isFalse);

    await PinnedConversationStore.instance.load();

    expect(PinnedConversationStore.instance.isPinned('mori'), isTrue);
    expect(PinnedConversationStore.instance.pinnedIds.value, {'mori'});
  });

  test('toggles a conversation pin state', () async {
    await PinnedConversationStore.instance.toggle('mori');
    expect(PinnedConversationStore.instance.isPinned('mori'), isTrue);

    await PinnedConversationStore.instance.toggle('mori');
    expect(PinnedConversationStore.instance.isPinned('mori'), isFalse);
  });
}
