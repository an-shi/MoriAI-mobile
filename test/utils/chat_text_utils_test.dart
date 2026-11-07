import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/utils/chat_text_utils.dart';

void main() {
  test('strips a leading speaker name with full-width colon', () {
    expect(stripLeadingSpeakerName('Mori：早上好。', 'Mori'), '早上好。');
  });

  test('strips bracketed, bold and repeated speaker names', () {
    expect(stripLeadingSpeakerName('【Mori】：**Mori:** 早上好。', 'Mori'), '早上好。');
  });

  test('strips bold speaker names without eating message formatting', () {
    expect(stripLeadingSpeakerName('**Mori**：你好。', 'Mori'), '你好。');
    expect(stripLeadingSpeakerName('Mori：**你好**', 'Mori'), '**你好**');
  });

  test('keeps text that does not start with the speaker name', () {
    expect(stripLeadingSpeakerName('早上好，Mori。', 'Mori'), '早上好，Mori。');
  });

  test('does nothing when the speaker name is empty', () {
    expect(stripLeadingSpeakerName('Mori：早上好。', ''), 'Mori：早上好。');
  });
}
