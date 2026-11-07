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
