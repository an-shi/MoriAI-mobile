import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/utils/chat_bubble_utils.dart';

void main() {
  test('splits explicit bubbles and newlines', () {
    expect(splitChatReply('第一句|||第二句'), ['第一句', '第二句']);
    expect(splitChatReply('第一句｜｜｜第二句'), ['第一句', '第二句']);
    expect(splitChatReply('第一句\n第二句'), ['第一句', '第二句']);
    expect(splitChatReply('第一句|||第二句\n第三句'), ['第一句', '第二句', '第三句']);
  });

  test('force split falls back to commas', () {
    expect(splitChatReply('第一句，第二句，第三句', forceSplit: true), [
      '第一句',
      '第二句',
      '第三句',
    ]);
    expect(splitChatReply('第一句，第二句，第三句'), ['第一句，第二句，第三句']);
    expect(splitChatReply('嗯，好', forceSplit: true), ['嗯，好']);
  });

  test('splits short replies by Chinese sentence punctuation', () {
    expect(splitChatReply('今天好累。你呢？'), ['今天好累。', '你呢？']);
    expect(splitChatReply('嗯。好。'), ['嗯。好。']);
  });

  test('force split allows longer sentence-based bubbles', () {
    final long = '${'这是一段内容，' * 30}第一句。第二句。';
    expect(splitChatReply(long).length, 1);
    expect(splitChatReply(long, forceSplit: true).length, greaterThan(1));
  });

  test('keeps code blocks and lists intact', () {
    const code = '```dart\nprint(1);\nprint(2);\n```';
    expect(splitChatReply(code), [code]);
    const list = '1. 第一点\n2. 第二点';
    expect(splitChatReply(list), [list]);
  });

  test('caps bubbles and merges the tail', () {
    final parts = splitChatReply('a|||b|||c|||d|||e|||f');
    expect(parts, hasLength(defaultMaxChatBubbles));
    expect(parts.last, 'e，f');
  });

  test('flattens newlines with punctuation instead of keeping them', () {
    expect(flattenChatBubbleText('第一句？\n第二句'), '第一句？第二句');
    expect(flattenChatBubbleText('第一句\n第二句'), '第一句，第二句');
    expect(flattenChatBubbleText('第一句，\n第二句'), '第一句，第二句');
    expect(flattenChatBubbleText('第一句\n\n第二句'), '第一句，第二句');
  });

  test('keeps long paragraphs intact', () {
    final long = '${'这是一段很长的内容，' * 20}结束。';
    expect(splitChatReply(long), [long]);
  });

  test('parses JSON burst arrays', () {
    expect(parseJsonChatBubbles('["第一句","第二句"]'), ['第一句', '第二句']);
    expect(parseJsonChatBubbles('```json\n["第一句","第二句"]\n```'), ['第一句', '第二句']);
    expect(parseJsonChatBubbles('好的：["第一句","第二句"]'), ['第一句', '第二句']);
    expect(parseJsonChatBubbles('[{"text":"第一句"},{"text":"第二句"}]'), [
      '第一句',
      '第二句',
    ]);
    expect(parseJsonChatBubbles('不是 JSON'), isNull);
  });

  test('bubble delay grows with text length and stays bounded', () {
    final short = chatBubbleDelay('嗯', random: Random(1));
    final long = chatBubbleDelay('a' * 100, random: Random(1));

    expect(long, greaterThan(short));
    expect(short.inMilliseconds, inInclusiveRange(250, 450));
    expect(long.inMilliseconds, inInclusiveRange(900, 1600));
  });
}
