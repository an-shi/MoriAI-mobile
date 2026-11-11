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

  test('labels group assistant messages with the sender name', () {
    const message = ChatMessage(
      role: ChatRole.assistant,
      content: '早上好。',
      senderId: 'mori',
      senderName: 'Mori',
    );

    expect(message.toApiJson(), {'role': 'assistant', 'content': 'Mori：早上好。'});
  });

  test('labels group user messages with the user name', () {
    const message = ChatMessage(
      role: ChatRole.user,
      content: '今天吃什么？',
      senderId: 'user',
      senderName: '小森',
    );

    expect(message.toApiJson(), {'role': 'user', 'content': '小森：今天吃什么？'});
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

  test(
    'serializes a sticker with a text fallback when images are disabled',
    () {
      final message = ChatMessage(
        role: ChatRole.user,
        content: '',
        image: ChatImage(
          bytes: Uint8List.fromList([255]),
          mimeType: 'image/jpeg',
        ),
        isSticker: true,
      );

      final content = message.toApiJson()['content'] as List<dynamic>;
      expect(content.first['text'], '[表情包]');
      expect(content.last['type'], 'image_url');

      final textOnly = message.toApiJson(includeImage: false);
      expect(textOnly['content'], '[表情包]');
    },
  );
}
