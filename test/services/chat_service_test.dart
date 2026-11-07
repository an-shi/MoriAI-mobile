import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/services/chat_service.dart';

void main() {
  test(
    'streams assistant content from an OpenAI-compatible SSE response',
    () async {
      late http.BaseRequest capturedRequest;

      final client = MockClient.streaming((request, bodyStream) async {
        capturedRequest = request;
        final body = utf8.decode(await bodyStream.toBytes());

        expect(body, contains('"model":"deepseek-chat"'));
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

      final service = ChatService(client: client);
      addTearDown(service.dispose);

      final chunks = await service
          .streamChat(
            [const ChatMessage(role: ChatRole.user, content: '嗨')],
            provider: ModelProviderCatalog.deepSeek,
            apiKey: 'test-key',
            model: 'deepseek-chat',
          )
          .toList();

      expect(chunks, ['你', '好']);
      expect(
        capturedRequest.url.toString(),
        'https://api.deepseek.com/chat/completions',
      );
      expect(capturedRequest.headers['Authorization'], 'Bearer test-key');
    },
  );

  test('omits the DeepSeek thinking option for other providers', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      final body = utf8.decode(await bodyStream.toBytes());
      expect(body, isNot(contains('"thinking"')));

      return http.StreamedResponse(
        Stream.value(utf8.encode('data: [DONE]\n')),
        200,
      );
    });

    final service = ChatService(client: client);
    addTearDown(service.dispose);

    const provider = ModelProvider(
      id: 'other',
      name: 'Other',
      baseUrl: 'https://api.example.com',
      apiKeyHint: 'key',
      description: 'Other provider',
    );

    final chunks = await service
        .streamChat(
          [const ChatMessage(role: ChatRole.user, content: '嗨')],
          provider: provider,
          apiKey: 'test-key',
          model: 'some-model',
        )
        .toList();

    expect(chunks, isEmpty);
  });

  test('throws a clear error when the API key is missing', () async {
    final service = ChatService();
    addTearDown(service.dispose);

    await expectLater(
      service
          .streamChat(
            [const ChatMessage(role: ChatRole.user, content: '嗨')],
            provider: ModelProviderCatalog.deepSeek,
            apiKey: '',
            model: 'deepseek-chat',
          )
          .toList(),
      throwsA(isA<ChatServiceException>()),
    );
  });
}
