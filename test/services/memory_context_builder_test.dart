import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/memory_context_builder.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MemoryStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await MemoryStore.instance.load();
  });

  Future<void> save(String id, String text, {double importance = 0.6}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MemoryStore.instance.saveEntry(
      MemoryEntry(
        id: id,
        characterId: 'mori',
        text: text,
        importance: importance,
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
  }

  test('recalls relevant private memories', () async {
    await save('milk', '用户喜欢睡前喝热牛奶', importance: 0.8);
    await save('city', '用户住在杭州', importance: 0.4);

    final context = MemoryContextBuilder.instance.buildForPrivateChat(
      'mori',
      query: '牛奶',
    );
    expect(context, contains('热牛奶'));
    expect(context, contains('长期记得'));
  });

  test('does not inject private memories into group chat', () async {
    await save('milk', '用户喜欢睡前喝热牛奶');
    expect(
      MemoryContextBuilder.instance.buildForGroupChat('mori', query: '牛奶'),
      isEmpty,
    );
  });

  test('returns empty when memory or recall is disabled', () async {
    await save('milk', '用户喜欢睡前喝热牛奶');
    await MemoryStore.instance.saveSettings(
      const MemorySettings(enabled: false),
    );
    expect(
      MemoryContextBuilder.instance.buildForPrivateChat('mori', query: '牛奶'),
      isEmpty,
    );

    await MemoryStore.instance.saveSettings(
      const MemorySettings(enabled: true, recallCount: 0),
    );
    expect(
      MemoryContextBuilder.instance.buildForPrivateChat('mori', query: '牛奶'),
      isEmpty,
    );
  });

  test('falls back to important memories for an empty query', () async {
    await save('low', '用户偶尔看电影', importance: 0.2);
    await save('high', '用户非常重视家人', importance: 0.95);
    final context = MemoryContextBuilder.instance.buildForPrivateChat('mori');
    expect(context, contains('非常重视家人'));
  });
}
