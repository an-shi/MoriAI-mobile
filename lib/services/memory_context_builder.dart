import 'dart:async';

import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/utils/memory_search.dart';

class MemoryContextBuilder {
  MemoryContextBuilder._();

  static final MemoryContextBuilder instance = MemoryContextBuilder._();

  /// 单聊和主动消息可以召回这个角色的私人记忆。
  String buildForPrivateChat(String characterId, {String query = ''}) {
    return _build(characterId, query: query);
  }

  /// 群聊不注入单聊记忆，避免把私事带进群里。
  String buildForGroupChat(String characterId, {String query = ''}) {
    return '';
  }

  /// 主动消息使用和单聊相同的隐私范围。
  String buildForProactive(String characterId, {String query = ''}) {
    return _build(characterId, query: query);
  }

  String _build(String characterId, {required String query}) {
    final settings = MemoryStore.instance.settings.value;
    if (!settings.enabled || settings.recallCount <= 0) {
      return '';
    }
    final entries = MemoryStore.instance.entriesFor(characterId);
    if (entries.isEmpty) {
      return '';
    }
    final hits = searchMemories(
      entries,
      query,
      limit: settings.recallCount,
      fallbackToImportant: query.trim().isEmpty,
    );
    if (hits.isEmpty) {
      return '';
    }
    unawaited(MemoryStore.instance.touch(hits.map((hit) => hit.entry.id)));
    final now = DateTime.now();
    final lines = <String>[];
    for (final hit in hits) {
      final entry = hit.entry;
      final when = _whenText(entry.updatedAt, now);
      final text = _clip(entry.text);
      lines.add(
        '- [${entry.categoryLabel}${when.isEmpty ? '' : ' · $when'}] $text',
      );
    }
    if (lines.isEmpty) {
      return '';
    }
    return '（以下是你长期记得的关于对方的事，不是对方刚说的。'
        '只在自然相关时使用，可以顺口提起，但不要逐条复述，也不要编造。）\n'
        '${lines.join('\n')}';
  }

  String _clip(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 120) {
      return normalized;
    }
    return '${normalized.substring(0, 120)}…';
  }

  String _whenText(DateTime time, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final days = today.difference(day).inDays;
    if (days <= 0) {
      return '今天';
    }
    if (days == 1) {
      return '昨天';
    }
    if (days < 7) {
      return '$days 天前';
    }
    final month = time.month.toString().padLeft(2, '0');
    final date = time.day.toString().padLeft(2, '0');
    if (time.year == now.year) {
      return '$month-$date';
    }
    return '${time.year}-$month-$date';
  }
}
