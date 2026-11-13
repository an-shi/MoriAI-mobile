import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/services/moribot/mori_bot_client.dart';

http.Response _jsonResponse(Object body, [int statusCode = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('MoriBotClient', () {
    test('normalizes server origins', () {
      expect(
        MoriBotClient.normalizeServerUrl('mori.example.com'),
        'https://mori.example.com',
      );
      expect(
        MoriBotClient.normalizeServerUrl('http://192.168.1.8:8000/'),
        'http://192.168.1.8:8000',
      );
      expect(
        MoriBotClient.normalizeServerUrl('10.0.2.2:8000'),
        'http://10.0.2.2:8000',
      );
      expect(
        () => MoriBotClient.normalizeServerUrl('ftp://example.com'),
        throwsA(isA<MoriApiException>()),
      );
    });

    test('pairs without an existing device token', () async {
      late http.Request captured;
      final client = MoriBotClient(
        client: MockClient((request) async {
          captured = request;
          return _jsonResponse({
            'status': 'ok',
            'message': '设备配对成功',
            'data': {
              'device_token': 'mm_test',
              'device': {'id': 'device-1', 'name': 'Pixel 9', 'online': false},
            },
          });
        }),
      );

      final result = await client.pair(
        baseUrl: 'https://mori.example.com',
        code: 'H63M-5LQF',
        deviceName: 'Pixel 9',
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://mori.example.com/api/v1/mobile/pair',
      );
      expect(captured.headers['Authorization'], isNull);
      expect(jsonDecode(captured.body), {
        'code': 'H63M-5LQF',
        'device_name': 'Pixel 9',
      });
      expect(result.deviceToken, 'mm_test');
      expect(result.device.id, 'device-1');
      expect(result.device.name, 'Pixel 9');
    });

    test('authenticates business calls and parses conversations', () async {
      final client =
          MoriBotClient(
            client: MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer mm_token');
              if (request.url.path.endsWith('/app/conversations')) {
                expect(request.url.queryParameters['limit'], '50');
                return _jsonResponse({
                  'status': 'ok',
                  'data': {
                    'conversations': [
                      {
                        'id': 'conversation-1',
                        'character_id': 1,
                        'character_name': 'Mori',
                        'character_available': true,
                        'title': '今天有点累',
                        'last_message_preview': '辛苦啦，先缓一缓。',
                        'message_count': 2,
                        'created_at': '2026-11-13T09:00:00',
                        'updated_at': '2026-11-13T09:12:34.567890',
                      },
                    ],
                    'has_more': true,
                  },
                });
              }
              return _jsonResponse({
                'status': 'ok',
                'data': {
                  'device': {'id': 'device-1', 'name': 'Pixel 9'},
                  'user': {
                    'id': 1,
                    'username': 'admin',
                    'display_name': 'Administrator',
                    'role': 'admin',
                  },
                  'server_version': '0.1.0',
                  'protocol': 1,
                },
              });
            }),
          )..configure(
            baseUrl: 'https://mori.example.com',
            deviceToken: 'mm_token',
          );

      final self = await client.me();
      expect(self.user.username, 'admin');
      expect(self.serverVersion, '0.1.0');
      expect(self.protocol, 1);

      final page = await client.conversations(limit: 50);
      expect(page.hasMore, isTrue);
      expect(page.conversations, hasLength(1));
      expect(page.conversations.first.id, 'conversation-1');
      expect(page.conversations.first.preview, '辛苦啦，先缓一缓。');
    });

    test('reads messages with an incremental cursor', () async {
      final client =
          MoriBotClient(
            client: MockClient((request) async {
              expect(request.url.queryParameters['after_id'], '120');
              return _jsonResponse({
                'status': 'ok',
                'data': {
                  'messages': [
                    {
                      'id': 121,
                      'conversation_id': 'conversation-1',
                      'role': 'user',
                      'content': '今天有点累',
                      'client_message_id': 'local-42',
                      'created_at': '2026-11-13T09:12:33.123456',
                    },
                    {
                      'id': 122,
                      'conversation_id': 'conversation-1',
                      'role': 'assistant',
                      'content': '辛苦啦，先缓一缓。',
                      'speech': {
                        'url': '/api/v1/mobile/app/media/8f2a.mp3',
                        'mime_type': 'audio/mpeg',
                        'format': 'mp3',
                        'byte_length': 18432,
                      },
                      'provider_id': '3',
                      'model': 'gpt-4.1-mini',
                      'created_at': '2026-11-13T09:12:34.567890',
                    },
                  ],
                  'has_more': false,
                  'earliest_id': 121,
                  'latest_id': 122,
                },
              });
            }),
          )..configure(
            baseUrl: 'https://mori.example.com',
            deviceToken: 'mm_token',
          );

      final page = await client.messages('conversation-1', afterId: 120);
      expect(page.messages, hasLength(2));
      expect(page.messages.first.isUser, isTrue);
      expect(page.messages.last.isAssistant, isTrue);
      expect(page.messages.last.speech?.format, 'mp3');
      expect(page.messages.last.speech?.byteLength, 18432);
      expect(page.earliestId, 121);
      expect(page.latestId, 122);
    });

    test('sends a message and parses both stored messages', () async {
      late http.Request captured;
      final client =
          MoriBotClient(
            client: MockClient((request) async {
              captured = request;
              return _jsonResponse({
                'status': 'ok',
                'data': {
                  'conversation': {
                    'id': 'conversation-1',
                    'character_id': 1,
                    'character_name': 'Mori',
                    'title': '今天有点累',
                    'message_count': 2,
                    'created_at': '2026-11-13T09:00:00',
                    'updated_at': '2026-11-13T09:12:34.567890',
                  },
                  'user_message': {
                    'id': 121,
                    'conversation_id': 'conversation-1',
                    'role': 'user',
                    'content': '今天有点累',
                    'client_message_id': 'local-42',
                  },
                  'assistant_message': {
                    'id': 122,
                    'conversation_id': 'conversation-1',
                    'role': 'assistant',
                    'content': '辛苦啦，先缓一缓。',
                    'client_message_id': 'local-42',
                  },
                },
              });
            }),
          )..configure(
            baseUrl: 'https://mori.example.com',
            deviceToken: 'mm_token',
          );

      final result = await client.sendMessage(
        'conversation-1',
        content: '今天有点累',
        clientMessageId: 'local-42',
        speech: true,
      );
      expect(jsonDecode(captured.body), {
        'content': '今天有点累',
        'client_message_id': 'local-42',
        'speech': true,
      });
      expect(result.conversation.title, '今天有点累');
      expect(result.userMessage.clientMessageId, 'local-42');
      expect(result.assistantMessage.id, 122);
    });

    test('surfaces the server error message', () async {
      final client =
          MoriBotClient(
            client: MockClient((request) async {
              return _jsonResponse({
                'status': 'error',
                'message': '角色没有可用的对话模型',
                'data': null,
              }, 409);
            }),
          )..configure(
            baseUrl: 'https://mori.example.com',
            deviceToken: 'mm_token',
          );

      await expectLater(
        client.sendMessage(
          'conversation-1',
          content: 'hello',
          clientMessageId: 'local-1',
        ),
        throwsA(
          isA<MoriApiException>()
              .having((error) => error.statusCode, 'statusCode', 409)
              .having((error) => error.message, 'message', '角色没有可用的对话模型'),
        ),
      );
    });

    test('downloads server media with the device token', () async {
      late http.Request captured;
      final client =
          MoriBotClient(
            client: MockClient((request) async {
              captured = request;
              return http.Response.bytes([1, 2, 3], 200);
            }),
          )..configure(
            baseUrl: 'https://mori.example.com',
            deviceToken: 'mm_token',
          );

      final bytes = await client.downloadMedia(
        '/api/v1/mobile/app/media/8f2a.mp3',
      );
      expect(bytes, [1, 2, 3]);
      expect(
        captured.url.toString(),
        'https://mori.example.com/api/v1/mobile/app/media/8f2a.mp3',
      );
      expect(captured.headers['Authorization'], 'Bearer mm_token');
    });

    test('builds the authenticated WebSocket URI', () {
      final client = MoriBotClient()
        ..configure(
          baseUrl: 'https://mori.example.com/base',
          deviceToken: 'mm_token',
        );
      expect(
        client.webSocketUri.toString(),
        'wss://mori.example.com/base/api/v1/mobile/ws',
      );
    });
  });
}
