import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/moribot/mori_models.dart';

void main() {
  group('Mori models', () {
    test('parses server timestamps as UTC and converts to local time', () {
      final parsed = parseMoriDate('2026-11-13T09:12:34.567890');
      expect(parsed, isNotNull);
      expect(parsed!.toUtc(), DateTime.utc(2026, 11, 13, 9, 12, 34, 567, 890));
    });

    test('parses character capabilities', () {
      final character = MoriCharacter.fromJson({
        'id': 1,
        'name': 'Mori',
        'avatar': '/avatars/3f2a9c.png',
        'description': '安静、温柔的 AI 伙伴',
        'chat_available': true,
        'speech_available': true,
        'image_available': false,
        'updated_at': '2026-11-13T08:30:00',
      });

      expect(character.id, 1);
      expect(character.displayName, 'Mori');
      expect(character.chatAvailable, isTrue);
      expect(character.speechAvailable, isTrue);
      expect(character.imageAvailable, isFalse);
      expect(character.updatedAt, isNotNull);
      expect(character.toJson()['chat_available'], isTrue);
    });

    test('parses conversation pages', () {
      final page = MoriConversationPage.fromJson({
        'conversations': [
          {
            'id': '484d568bdd164385b96647654c370cf5',
            'character_id': 1,
            'character_name': 'Mori',
            'character_avatar': '/avatars/3f2a9c.png',
            'character_available': true,
            'title': '今天有点累',
            'last_message_preview': '辛苦啦，先缓一缓。',
            'last_message_at': '2026-11-13T09:12:34.567890',
            'message_count': 12,
            'created_at': '2026-11-13T09:00:00',
            'updated_at': '2026-11-13T09:12:34.567890',
          },
        ],
        'has_more': false,
      });

      expect(page.hasMore, isFalse);
      expect(page.conversations, hasLength(1));
      expect(page.conversations.first.displayTitle, '今天有点累');
      expect(page.conversations.first.preview, '辛苦啦，先缓一缓。');
      expect(page.conversations.first.messageCount, 12);
    });

    test('parses message media and page cursors', () {
      final message = MoriMessage.fromJson({
        'id': 122,
        'conversation_id': 'conversation-1',
        'role': 'assistant',
        'content': '',
        'speech': {
          'url': '/api/v1/mobile/app/media/8f2a.mp3',
          'mime_type': 'audio/mpeg',
          'format': 'mp3',
          'byte_length': 18432,
        },
        'images': [
          {'url': 'https://cdn.example.com/a91c.png', 'mime_type': 'image/png'},
        ],
        'client_message_id': 'local-42',
        'provider_id': '3',
        'model': 'gpt-4.1-mini',
        'created_at': '2026-11-13T09:12:34.567890',
      });

      expect(message.isAssistant, isTrue);
      expect(message.hasMedia, isTrue);
      expect(message.isEmpty, isFalse);
      expect(message.speech?.byteLength, 18432);
      expect(message.images.single.url, 'https://cdn.example.com/a91c.png');
      expect(message.model, 'gpt-4.1-mini');
    });

    test('parses pairing links', () {
      final link = MoriPairingLink.tryParse(
        'morimobile://pair?server=https%3A%2F%2Fmori.example.com&code=H63M-5LQF',
      );
      expect(link, isNotNull);
      expect(link!.serverUrl, 'https://mori.example.com');
      expect(link.code, 'H63M-5LQF');
      expect(MoriPairingLink.tryParse('H63M-5LQF'), isNull);
      expect(MoriPairingLink.tryParse('morimobile://other?code=1'), isNull);
    });
  });
}
