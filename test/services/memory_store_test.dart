import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/memory.dart';
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

  test('defaults and settings normalization', () async {
    final defaults = MemoryStore.instance.settings.value;
    expect(defaults.enabled, isTrue);
    expect(defaults.autoExtract, isTrue);
    expect(defaults.recallCount, 6);
    expect(defaults.extractIdleMinutes, 10);
    expect(defaults.extractMinMessages, 8);
    expect(defaults.maxMemoriesPerCharacter, 500);

    final normalized = const MemorySettings(
      recallCount: 99,
      extractIdleMinutes: 0,
      extractMinMessages: 1,
      maxMemoriesPerCharacter: 3,
    ).normalized();
    expect(normalized.recallCount, 20);
    expect(normalized.extractIdleMinutes, 1);
    expect(normalized.extractMinMessages, 2);
    expect(normalized.maxMemoriesPerCharacter, 10);

    await MemoryStore.instance.saveSettings(
      const MemorySettings(
        enabled: false,
        autoExtract: false,
        recallCount: 4,
        extractIdleMinutes: 20,
        extractMinMessages: 12,
        maxMemoriesPerCharacter: 300,
      ),
    );
    await MemoryStore.instance.load();
    final loaded = MemoryStore.instance.settings.value;
    expect(loaded.enabled, isFalse);
    expect(loaded.autoExtract, isFalse);
    expect(loaded.recallCount, 4);
    expect(loaded.extractIdleMinutes, 20);
    expect(loaded.extractMinMessages, 12);
    expect(loaded.maxMemoriesPerCharacter, 300);
  });

  test('serializes a memory entry', () {
    final entry = MemoryEntry(
      id: 'm1',
      characterId: 'mori',
      text: '用户喜欢在晚上喝热牛奶',
      category: MemoryCategory.preference,
      importance: 0.7,
      tags: const ['牛奶', '睡前'],
      source: MemorySource.auto,
      conversationId: 'mori',
      aboutName: '用户',
      createdAtMs: 1000,
      updatedAtMs: 2000,
      lastAccessedAtMs: 3000,
      accessCount: 4,
    ).normalized();
    final restored = MemoryEntry.fromJson(entry.toJson());
    expect(restored.text, entry.text);
    expect(restored.category, MemoryCategory.preference);
    expect(restored.importance, 0.7);
    expect(restored.tags, ['牛奶', '睡前']);
    expect(restored.source, MemorySource.auto);
    expect(restored.accessCount, 4);
  });

  test('saves, updates, touches, deletes and persists memories', () async {
    final entry = MemoryEntry(
      id: 'm1',
      characterId: 'mori',
      text: '用户喜欢在晚上喝热牛奶',
      category: MemoryCategory.preference,
      importance: 0.7,
      createdAtMs: 1000,
      updatedAtMs: 1000,
    );
    await MemoryStore.instance.saveEntry(entry);
    expect(MemoryStore.instance.entriesFor('mori'), hasLength(1));

    await MemoryStore.instance.saveEntry(
      entry.copyWith(text: '用户喜欢在睡前喝热牛奶', updatedAtMs: 2000),
    );
    await MemoryStore.instance.touch(['m1']);
    await MemoryStore.instance.load();
    final loaded = MemoryStore.instance.entriesFor('mori').single;
    expect(loaded.text, contains('睡前'));
    expect(loaded.accessCount, 1);
    expect(loaded.lastAccessedAtMs, greaterThan(0));

    await MemoryStore.instance.archiveEntry('m1');
    expect(MemoryStore.instance.entriesFor('mori'), isEmpty);
    expect(
      MemoryStore.instance.entriesFor('mori', includeArchived: true),
      hasLength(1),
    );

    await MemoryStore.instance.deleteEntry('m1');
    expect(
      MemoryStore.instance.entriesFor('mori', includeArchived: true),
      isEmpty,
    );
  });

  test('persists extraction state and clears a character', () async {
    await MemoryStore.instance.saveEntry(
      MemoryEntry(
        id: 'm1',
        characterId: 'mori',
        text: '用户喜欢热牛奶',
        createdAtMs: 1000,
        updatedAtMs: 1000,
      ),
    );
    await MemoryStore.instance.saveState(
      'mori',
      const MemoryExtractionState(
        lastProcessedMessageId: 'msg_10',
        lastProcessedAtMs: 2000,
        lastError: '网络错误',
        nextRetryAtMs: 3000,
      ),
    );

    await MemoryStore.instance.load();
    final state = MemoryStore.instance.stateFor('mori');
    expect(state.lastProcessedMessageId, 'msg_10');
    expect(state.lastError, '网络错误');

    await MemoryStore.instance.clearForCharacter('mori');
    expect(MemoryStore.instance.entriesFor('mori'), isEmpty);
    expect(
      MemoryStore.instance.stateFor('mori').lastProcessedMessageId,
      isEmpty,
    );
  });

  test('keeps memories when settings json is corrupted', () async {
    final entry = MemoryEntry(
      id: 'm1',
      characterId: 'mori',
      text: '设置损坏时记忆也要保留',
      createdAtMs: 1000,
      updatedAtMs: 1000,
    );
    SharedPreferences.setMockInitialValues({
      'memory_settings_v1': 'not-json',
      'character_memory_v1': jsonEncode([entry.toJson()]),
    });
    await MemoryStore.instance.load();

    expect(MemoryStore.instance.settings.value, const MemorySettings());
    expect(MemoryStore.instance.entriesFor('mori'), hasLength(1));
  });

  test('trims low-importance automatic memories when over capacity', () async {
    await MemoryStore.instance.saveSettings(
      const MemorySettings(maxMemoriesPerCharacter: 10),
    );
    final entries = <MemoryEntry>[
      for (var index = 0; index < 12; index++)
        MemoryEntry(
          id: 'm$index',
          characterId: 'mori',
          text: '记忆 $index',
          importance: index / 20,
          source: index < 2 ? MemorySource.manual : MemorySource.auto,
          createdAtMs: 1000 + index,
          updatedAtMs: 1000 + index,
        ),
    ];
    for (final entry in entries) {
      await MemoryStore.instance.saveEntry(entry);
    }
    final stored = MemoryStore.instance.entriesFor('mori');
    expect(stored, hasLength(10));
    expect(stored.any((entry) => entry.id == 'm0'), isTrue);
    expect(stored.any((entry) => entry.id == 'm1'), isTrue);
    expect(stored.any((entry) => entry.id == 'm2'), isFalse);
  });
}
