import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/chat_message.dart';

void main() {
  test('serializes an image message as multimodal content', () {
    final message = ChatMessage(
      role: ChatRole.user,
      content: '看看这张图',
      image: ChatImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      ),
    );

    final json = message.toApiJson();
    expect(json['role'], 'user');

    final content = json['content'] as List<dynamic>;
    expect(content, hasLength(2));
    expect(content.first['type'], 'text');
    expect(content.first['text'], '看看这张图');
    expect(content.last['type'], 'image_url');
    expect(content.last['image_url']['url'], 'data:image/png;base64,AQID');
  });

  test('keeps text-only messages as plain string content', () {
    const message = ChatMessage(role: ChatRole.user, content: '嗨');

    expect(message.toApiJson(), {'role': 'user', 'content': '嗨'});
  });

  test('sends only the image part when there is no text', () {
    final message = ChatMessage(
      role: ChatRole.user,
      content: '',
      image: ChatImage(
        bytes: Uint8List.fromList([255]),
        mimeType: 'image/jpeg',
      ),
    );

    final content = message.toApiJson()['content'] as List<dynamic>;
    expect(content, hasLength(1));
    expect(content.single['type'], 'image_url');
  });
}
