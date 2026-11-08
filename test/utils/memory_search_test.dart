import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/utils/memory_search.dart';

void main() {
  MemoryEntry entry(
    String id,
    String text, {
    double importance = 0.5,
    MemoryCategory category = MemoryCategory.fact,
    int updatedAtMs = 1000,
    bool active = true,
  }) {
    return MemoryEntry(
      id: id,
      characterId: 'mori',
      text: text,
      importance: importance,
      category: category,
      createdAtMs: updatedAtMs,
      updatedAtMs: updatedAtMs,
      isActive: active,
    );
  }

  test('tokenizes Chinese bigrams and English words', () {
    expect(memoryTokens('喜欢热牛奶'), contains('喜欢'));
    expect(memoryTokens('喜欢热牛奶'), contains('热牛'));
    expect(memoryTokens('hello world'), contains('hello'));
    expect(memoryTokens('hello world'), contains('world'));
  });

  test('detects similar and conflicting facts', () {
    expect(isSameMemoryFact('用户喜欢晚上喝热牛奶', '用户喜欢在晚上喝热牛奶'), isTrue);
    expect(isSameMemoryFact('用户喜欢热牛奶', '用户不喜欢热牛奶'), isFalse);
    expect(isSameMemoryFact('用户周六去北京', '用户周日去北京'), isFalse);
    expect(memoryConflicting('用户周六去北京', '用户周日去北京'), isTrue);
  });

  test('ranks relevant memories and filters inactive ones', () {
    final entries = [
      entry('milk', '用户喜欢睡前喝热牛奶', importance: 0.7),
      entry('city', '用户住在杭州', importance: 0.5),
      entry('inactive', '用户喜欢喝咖啡', active: false),
    ];
    final hits = searchMemories(entries, '牛奶');
    expect(hits, isNotEmpty);
    expect(hits.first.entry.id, 'milk');
    expect(hits.any((hit) => hit.entry.id == 'inactive'), isFalse);
  });

  test('falls back to important memories when query has no hit', () {
    final entries = [
      entry('low', '用户偶尔看电影', importance: 0.3),
      entry('high', '用户非常重视家人', importance: 0.9),
    ];
    final hits = searchMemories(entries, '完全无关的词', limit: 3);
    expect(hits, isNotEmpty);
    expect(hits.first.entry.id, 'high');
  });

  test('returns nothing when recall limit is zero', () {
    final entries = [entry('milk', '用户喜欢热牛奶')];
    expect(searchMemories(entries, '牛奶', limit: 0), isEmpty);
  });
}
