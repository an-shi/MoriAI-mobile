import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/services/chat_queue_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and deduplicates queued message ids', () async {
    await ChatQueueStore.instance.saveFor('chat_1', [
      'message_1',
      'message_2',
      'message_1',
      ' ',
    ]);

    final loaded = await ChatQueueStore.instance.loadFor('chat_1');

    expect(loaded, ['message_1', 'message_2']);
  });

  test('removes the queue when the saved list is empty', () async {
    await ChatQueueStore.instance.saveFor('chat_1', ['message_1']);
    await ChatQueueStore.instance.saveFor('chat_1', const []);

    expect(await ChatQueueStore.instance.loadFor('chat_1'), isEmpty);
  });
}
