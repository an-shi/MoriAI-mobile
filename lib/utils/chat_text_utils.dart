String stripLeadingSpeakerName(String text, String name) {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    return text;
  }

  final escaped = RegExp.escape(trimmedName);
  final pattern = RegExp(
    '^\\s*(?:\\*\\*)?(?:[【\\[]\\s*)?$escaped'
    r'(?:\s*[】\]])?(?:\*\*)?\s*[：:]\s*(?:\*\*(?=\s|$)\s*)?',
    caseSensitive: false,
  );

  var result = text;
  for (var count = 0; count < 3; count++) {
    final next = result.replaceFirst(pattern, '');
    if (next == result) {
      break;
    }
    result = next;
  }
  return result;
}

/// 清理模型生成的聊天文本：去掉开头角色名前缀和包裹引号。
String normalizeGeneratedChatText(String text, String name) {
  var result = stripLeadingSpeakerName(text, name).trim();
  if (result.length >= 2) {
    final first = result[0];
    final last = result[result.length - 1];
    final wrapped =
        (first == '“' && last == '”') ||
        (first == '「' && last == '」') ||
        (first == '『' && last == '』') ||
        (first == '"' && last == '"');
    if (wrapped) {
      result = result.substring(1, result.length - 1).trim();
    }
  }
  return result;
}
