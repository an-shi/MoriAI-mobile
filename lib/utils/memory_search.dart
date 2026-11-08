import 'dart:math';

import 'package:mori_ai/models/memory.dart';

const _memoryStopChars = '的了是我你他她它们在有和就不也都很吗吧呢啊呀哦嗯这那个一上下来去说要会能着过';
const _memoryNoiseChars = '哈呵嘿嘻嗯哦啊呀吗呢吧';

List<String> memoryTokens(String text) {
  final out = <String>[];
  final source = text.toLowerCase();
  final pattern = RegExp(r'[a-z0-9_]{2,}|[\u4e00-\u9fff]+');
  for (final match in pattern.allMatches(source)) {
    final word = match.group(0) ?? '';
    if (word.isEmpty) {
      continue;
    }
    if (RegExp(r'^[a-z0-9_]+$').hasMatch(word)) {
      out.add(word);
      continue;
    }
    if (word.length == 1) {
      if (!_memoryStopChars.contains(word)) {
        out.add(word);
      }
      continue;
    }
    for (var index = 0; index < word.length - 1; index++) {
      final pair = word.substring(index, index + 2);
      if (!(_memoryNoiseChars.contains(pair[0]) &&
          _memoryNoiseChars.contains(pair[1]))) {
        out.add(pair);
      }
    }
  }
  return out;
}

double memorySimilarity(String a, String b) {
  final first = memoryTokens(a).toSet();
  final second = memoryTokens(b).toSet();
  if (first.isEmpty || second.isEmpty) {
    return 0;
  }
  var intersection = 0;
  for (final token in first) {
    if (second.contains(token)) {
      intersection++;
    }
  }
  return intersection / (first.length + second.length - intersection);
}

bool memoryConflicting(String a, String b) {
  final first = a.trim();
  final second = b.trim();
  if (first.isEmpty || second.isEmpty) {
    return false;
  }
  int countNegation(String value) =>
      RegExp(r'[不没未别无非]').allMatches(value).length;
  if (countNegation(first) != countNegation(second)) {
    return true;
  }
  String numbers(String value) =>
      RegExp(r'\d+').allMatches(value).map((match) => match.group(0)).join(',');
  final firstNumbers = numbers(first);
  final secondNumbers = numbers(second);
  if (firstNumbers.isNotEmpty &&
      secondNumbers.isNotEmpty &&
      firstNumbers != secondNumbers) {
    return true;
  }
  var head = 0;
  while (head < first.length &&
      head < second.length &&
      first[head] == second[head]) {
    head++;
  }
  var tail = 0;
  while (tail < first.length - head &&
      tail < second.length - head &&
      first[first.length - 1 - tail] == second[second.length - 1 - tail]) {
    tail++;
  }
  return first.length - head - tail >= 1 && second.length - head - tail >= 1;
}

bool isSameMemoryFact(String a, String b) {
  return memorySimilarity(a, b) >= 0.6 && !memoryConflicting(a, b);
}

double memoryRetention(MemoryEntry entry, DateTime now) {
  final last = max(entry.updatedAtMs, entry.lastAccessedAtMs);
  if (last <= 0) {
    return 0.5;
  }
  final days = max(0.0, (now.millisecondsSinceEpoch - last) / 86400000);
  final strength = 1 + min(10, entry.accessCount);
  final tau = 20 * strength * (0.5 + entry.importance);
  return exp(-days / tau);
}

class MemorySearchHit {
  const MemorySearchHit({required this.entry, required this.score});

  final MemoryEntry entry;
  final double score;
}

List<MemorySearchHit> searchMemories(
  List<MemoryEntry> entries,
  String query, {
  int limit = 6,
  double minScore = 0.25,
  DateTime? now,
  bool fallbackToImportant = true,
}) {
  final normalizedLimit = limit < 0 ? 0 : limit;
  if (normalizedLimit == 0) {
    return const [];
  }
  final time = now ?? DateTime.now();
  final active = entries.where((entry) => entry.isActive).toList();
  if (active.isEmpty) {
    return const [];
  }
  final queryTokens = memoryTokens(query).toSet().toList();
  if (queryTokens.isEmpty) {
    return fallbackToImportant
        ? _importantFallback(active, normalizedLimit, time)
        : const [];
  }

  final documents = <_MemoryDocument>[];
  final documentFrequency = <String, int>{};
  for (final entry in active) {
    final tokens = memoryTokens(
      '${entry.text} ${entry.tags.join(' ')} '
      '${entry.categoryLabel} ${entry.aboutName}',
    );
    final frequency = <String, int>{};
    for (final token in tokens) {
      frequency[token] = (frequency[token] ?? 0) + 1;
    }
    for (final token in frequency.keys) {
      documentFrequency[token] = (documentFrequency[token] ?? 0) + 1;
    }
    documents.add(
      _MemoryDocument(
        entry: entry,
        frequency: frequency,
        length: tokens.isEmpty ? 1 : tokens.length,
      ),
    );
  }

  final averageLength = documents.isEmpty
      ? 1.0
      : documents.map((document) => document.length).reduce((a, b) => a + b) /
            documents.length;
  const k1 = 1.4;
  const b = 0.7;
  final hits = <MemorySearchHit>[];
  for (final document in documents) {
    var keywordScore = 0.0;
    for (final token in queryTokens) {
      final frequency = document.frequency[token];
      if (frequency == null) {
        continue;
      }
      final documentCount = documentFrequency[token] ?? 0;
      final idf = log(
        1 + (documents.length - documentCount + 0.5) / (documentCount + 0.5),
      );
      keywordScore +=
          idf *
          (frequency * (k1 + 1)) /
          (frequency + k1 * (1 - b + b * document.length / averageLength));
    }
    if (keywordScore <= 0) {
      continue;
    }
    final importance = 0.6 + 0.8 * document.entry.importance;
    final retention = 0.55 + 0.45 * memoryRetention(document.entry, time);
    final score = keywordScore * importance * retention;
    if (score >= minScore) {
      hits.add(MemorySearchHit(entry: document.entry, score: score));
    }
  }

  hits.sort((a, b) => b.score.compareTo(a.score));
  if (hits.isNotEmpty) {
    return hits.take(normalizedLimit).toList(growable: false);
  }
  if (!fallbackToImportant) {
    return const [];
  }
  return _importantFallback(active, min(normalizedLimit, 3), time);
}

List<MemorySearchHit> _importantFallback(
  List<MemoryEntry> entries,
  int limit,
  DateTime now,
) {
  if (limit <= 0) {
    return const [];
  }
  final sorted = List<MemoryEntry>.of(entries)
    ..sort((a, b) {
      final scoreA = a.importance * memoryRetention(a, now);
      final scoreB = b.importance * memoryRetention(b, now);
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) {
        return byScore;
      }
      return b.updatedAtMs.compareTo(a.updatedAtMs);
    });
  return [
    for (final entry in sorted.take(limit))
      MemorySearchHit(entry: entry, score: 0),
  ];
}

class _MemoryDocument {
  const _MemoryDocument({
    required this.entry,
    required this.frequency,
    required this.length,
  });

  final MemoryEntry entry;
  final Map<String, int> frequency;
  final int length;
}
