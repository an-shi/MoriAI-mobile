import 'dart:convert';
import 'dart:math';

/// 一条回复最多拆成多少条气泡。
const int defaultMaxChatBubbles = 5;

final RegExp _bubbleDelimiter = RegExp(r'\s*(?:\|\|\||｜｜｜)\s*');
final RegExp _streamBubbleDelimiter = RegExp(r'\s*(?:\|\|\||｜｜｜)\s*|\r?\n+');

/// 超过这个长度的内容不按换行/标点拆分，避免把长段落切碎。
const int _maxSplitLength = 240;

/// 按句末标点拆分时，只处理较短回复。
const int _maxSentenceSplitLength = 160;

/// 强制拆条时，逗号拆分只处理较短回复。
const int _maxCommaSplitLength = 120;

/// 是否包含显式气泡分隔符。
bool containsChatBubbleDelimiter(String text) {
  return _bubbleDelimiter.hasMatch(text);
}

/// 按显式气泡分隔符切分，保留最后一段作为未完成内容。
List<String> splitChatBubbleDelimiters(String text) {
  return text.split(_bubbleDelimiter);
}

/// 流式连发时按显式分隔符或换行切分，避免换行留在一个气泡里。
List<String> splitChatStreamSegments(String text) {
  return text.split(_streamBubbleDelimiter);
}

/// 只按显式分隔符拆分；没有分隔符时保持一整条。
List<String> splitExplicitChatBubbles(
  String raw, {
  int maxBubbles = defaultMaxChatBubbles,
}) {
  final text = raw.trim();
  if (text.isEmpty) {
    return const [];
  }
  if (!containsChatBubbleDelimiter(text)) {
    return [text];
  }
  final parts = text
      .split(_bubbleDelimiter)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return const [];
  }
  return _capBubbles(parts, maxBubbles);
}

/// 解析模型按约定输出的 JSON 字符串数组；失败时返回 null。
///
/// 兼容 Markdown 代码块包裹和数组前后的解释文字。
List<String>? parseJsonChatBubbles(
  String raw, {
  int maxBubbles = defaultMaxChatBubbles,
}) {
  var text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  text = text
      .replaceFirst(RegExp(r'^```[a-zA-Z0-9_-]*\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '')
      .trim();
  final start = text.indexOf('[');
  final end = text.lastIndexOf(']');
  if (start < 0 || end <= start) {
    return null;
  }
  try {
    final decoded = jsonDecode(text.substring(start, end + 1));
    if (decoded is! List) {
      return null;
    }
    final parts = <String>[
      for (final item in decoded)
        if (item is String && item.trim().isNotEmpty)
          item.trim()
        else if (item is Map)
          if ((item['text'] ?? item['content'] ?? item['message'])
              case final String value)
            if (value.trim().isNotEmpty) value.trim(),
    ];
    if (parts.isNotEmpty) {
      return _capBubbles(parts, maxBubbles);
    }
  } catch (_) {
    // 继续尝试提取引号里的文本。
  }
  final quoted = <String>[
    for (final match in RegExp(r'"([^"]+)"').allMatches(text))
      if (match.group(1)!.trim().isNotEmpty) match.group(1)!.trim(),
  ];
  if (quoted.length >= 2) {
    return _capBubbles(quoted, maxBubbles);
  }
  return null;
}

/// 把模型的一轮回复拆成多条聊天气泡。
///
/// 拆分优先级：
/// 1. `|||` / `｜｜｜` 显式分隔（推荐由提示词约定）；
/// 2. 换行分隔；
/// 3. 短回复的中文句末标点；
/// 4. [forceSplit] 为 true 时，再用逗号拆分兜底。
///
/// 代码块、列表和超长内容保持原样；超过 [maxBubbles] 的部分合并到最后一条。
List<String> splitChatReply(
  String raw, {
  int maxBubbles = defaultMaxChatBubbles,
  bool forceSplit = false,
}) {
  final text = raw.trim();
  if (text.isEmpty) {
    return const [];
  }

  var parts = <String>[];
  for (final chunk in text.split(_bubbleDelimiter)) {
    final trimmed = chunk.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    parts.addAll(_splitChunk(trimmed, force: forceSplit));
  }
  if (forceSplit && parts.length == 1) {
    final commaParts = _splitCommas(parts.single);
    if (commaParts.length > 1) {
      parts = commaParts;
    }
  }
  if (parts.isEmpty) {
    return const [];
  }
  return _capBubbles(parts, maxBubbles);
}

List<String> _splitChunk(String chunk, {bool force = false}) {
  if (chunk.contains('```')) {
    return [chunk];
  }

  final lines = chunk
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.length > 1) {
    if (chunk.length > _maxSplitLength) {
      return [chunk];
    }
    final listLines = lines.where(_isListLine).length;
    if (listLines >= (lines.length / 2).ceil()) {
      return [chunk];
    }
    return lines;
  }

  return _splitSentences(chunk, force: force);
}

bool _isListLine(String line) {
  return RegExp(r'^(\d+[.、)]|[-*•·])').hasMatch(line);
}

List<String> _splitSentences(String chunk, {bool force = false}) {
  if (!force && chunk.length > _maxSentenceSplitLength) {
    return [chunk];
  }

  final sentences = <String>[
    for (final match in RegExp(r'[^。！？!?…～~]+[。！？!?…～~]*').allMatches(chunk))
      if (match.group(0)!.trim().isNotEmpty) match.group(0)!.trim(),
  ];
  if (sentences.length <= 1) {
    return [chunk];
  }

  final merged = <String>[];
  for (final sentence in sentences) {
    // 把“嗯。”“好。”这类极短碎片并回上一条，避免拆得太碎。
    if (merged.isNotEmpty && sentence.length <= 2) {
      merged[merged.length - 1] = '${merged.last}$sentence';
    } else {
      merged.add(sentence);
    }
  }
  if (merged.length <= 1) {
    return [chunk];
  }
  // 有长句时默认不拆；用户明确要求连发时允许按句拆分。
  if (!force && merged.any((part) => part.length > 80)) {
    return [chunk];
  }
  return merged;
}

List<String> _splitCommas(String chunk) {
  if (chunk.contains('```') || chunk.length > _maxCommaSplitLength) {
    return [chunk];
  }
  final parts = chunk
      .split(RegExp(r'[，,]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length <= 1) {
    return [chunk];
  }
  final merged = <String>[];
  for (final part in parts) {
    if (merged.isNotEmpty && part.length <= 2) {
      merged[merged.length - 1] = '${merged.last}，$part';
    } else {
      merged.add(part);
    }
  }
  return merged.length <= 1 ? [chunk] : merged;
}

List<String> _capBubbles(List<String> parts, int maxBubbles) {
  if (maxBubbles <= 0 || parts.length <= maxBubbles) {
    return parts;
  }
  final head = parts.take(maxBubbles - 1).toList(growable: true);
  head.add(flattenChatBubbleText(parts.skip(maxBubbles - 1).join('\n')));
  return head;
}

/// 把气泡内部的换行压成正常标点，避免一条消息里出现多行。
///
/// 前一句已经有句末/逗号类标点时直接拼接，否则补一个中文逗号。
String flattenChatBubbleText(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.length <= 1) {
    return text.trim();
  }
  final buffer = StringBuffer(lines.first.trimRight());
  for (final line in lines.skip(1)) {
    final current = buffer.toString().trimRight();
    if (current.isEmpty) {
      buffer.write(line);
      continue;
    }
    if (RegExp(r'[。！？!?…～~，,；;：:]$').hasMatch(current)) {
      buffer.write(line);
    } else {
      buffer.write('，');
      buffer.write(line);
    }
  }
  return buffer.toString().trim();
}

/// 把气泡数量压到 [maxBubbles] 条，多出来的内容合并到最后一条。
List<String> capChatBubbleCount(List<String> parts, int maxBubbles) {
  return _capBubbles(parts, maxBubbles);
}

/// 两条气泡之间的等待时间，按“打字速度”估算。
Duration chatBubbleDelay(String text, {Random? random}) {
  final length = text.trim().length;
  final base = (250 + length * 35).clamp(300, 1200).toInt();
  final jitter = 0.85 + (random ?? Random()).nextDouble() * 0.4;
  return Duration(milliseconds: (base * jitter).round());
}
