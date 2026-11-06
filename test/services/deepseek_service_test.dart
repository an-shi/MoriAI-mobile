import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/deepseek_service.dart';

void main() {
  test('streams assistant content from a DeepSeek SSE response', () async {
    late http.BaseRequest capturedRequest;

    final client = MockClient.streaming((request, bodyStream) async {
      capturedRequest = request;
      final body = utf8.decode(await bodyStream.toBytes());

      expect(body, contains('"model":"deepseek-flash"'));
      expect(body, contains('"stream":true'));
      expect(body, contains('"thinking":{"type":"disabled"}'));

      const sse =
          'data: {"choices":[{"delta":{"content":"你"}}]}\n'
          'data: {"choices":[{"delta":{"content":"好"}}]}\n'
          'data: [DONE]\n';

      return http.StreamedResponse(
        Stream.value(utf8.encode(sse)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });

    final service = DeepSeekService(client: client);
    addTearDown(service.dispose);

    final chunks = await service
        .streamChat(
          [const ChatMessage(role: ChatRole.user, content: '嗨')],
          apiKey: 'test-key',
          model: 'deepseek-flash',
        )
        .toList();

    expect(chunks, ['你', '好']);
    expect(
      capturedRequest.url.toString(),
      'https://api.deepseek.com/chat/completions',
    );
    expect(capturedRequest.headers['Authorization'], 'Bearer test-key');
  });

  test('throws a clear error when the API key is missing', () async {
    final service = DeepSeekService();
    addTearDown(service.dispose);

    await expectLater(
      service
          .streamChat(
            [const ChatMessage(role: ChatRole.user, content: '嗨')],
            apiKey: '',
            model: 'deepseek-flash',
          )
          .toList(),
      throwsA(isA<DeepSeekException>()),
    );
  });
}
