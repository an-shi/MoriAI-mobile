import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/services/unread_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UnreadStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await UnreadStore.instance.load();
  });

  test('tracks unread counts and total', () async {
    expect(UnreadStore.instance.totalCount, 0);

    await UnreadStore.instance.markUnread('mori', count: 2);
    await UnreadStore.instance.markUnread('sen');

    expect(UnreadStore.instance.countFor('mori'), 2);
    expect(UnreadStore.instance.countFor('sen'), 1);
    expect(UnreadStore.instance.totalCount, 3);
    expect(UnreadStore.instance.hasUnread('mori'), isTrue);
  });

  test('persists and clears unread counts', () async {
    await UnreadStore.instance.markUnread('mori', count: 3);
    await UnreadStore.instance.load();
    expect(UnreadStore.instance.countFor('mori'), 3);

    await UnreadStore.instance.markRead('mori');
    expect(UnreadStore.instance.countFor('mori'), 0);
    await UnreadStore.instance.load();
    expect(UnreadStore.instance.countFor('mori'), 0);
  });

  test('ignores empty ids and non-positive counts', () async {
    await UnreadStore.instance.markUnread('  ', count: 2);
    await UnreadStore.instance.markUnread('mori', count: 0);
    expect(UnreadStore.instance.totalCount, 0);
  });
}
