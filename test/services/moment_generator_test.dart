import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/model_option.dart';
import 'package:mori_ai/models/model_settings.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/chat_service.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/moment_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ModelStore.instance.load();
    ApiKeyStore.instance.keyFor('deepseek').value = null;
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ModelStore.instance.load();
    ApiKeyStore.instance.keyFor('deepseek').value = null;
  });

  test('sends moment images to vision-capable models', () async {
    await ModelStore.instance.saveModels('deepseek', const [
      ModelOption(
        id: 'vision-model',
        name: 'Vision Model',
        supportsVision: true,
      ),
    ]);
    await ModelStore.instance.saveSelection(
      const ModelSelection(providerId: 'deepseek', modelId: 'vision-model'),
    );
    ApiKeyStore.instance.keyFor('deepseek').value = 'test-key';

    late String requestBody;
    final client = MockClient.streaming((request, bodyStream) async {
      requestBody = utf8.decode(await bodyStream.toBytes());
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"图片很好看。"}}]}\n'
            'data: [DONE]\n',
          ),
        ),
        200,
      );
    });
    final chatService = ChatService(client: client);
    final generator = MomentService(chatService: chatService);
    addTearDown(generator.dispose);

    final moment = Moment(
      id: 'moment_image',
      authorId: 'user',
      authorName: '我',
      isUser: true,
      content: '看看这张图。',
      createdAt: DateTime(2026, 11, 8, 12),
      imageFile: 'moment_image.jpg',
      imageMimeType: 'image/png',
      image: MomentImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      ),
    );

    final content = await generator.generateCommentForCharacter(
      character: CharacterProfile.presetMori,
      moment: moment,
    );

    expect(content, '图片很好看。');
    expect(requestBody, contains('"type":"image_url"'));
    expect(requestBody, contains('data:image/png;base64,AQID'));
    expect(requestBody, contains('你是「Mori」'));
    expect(requestBody, contains('标记为「你自己」'));
  });
}
