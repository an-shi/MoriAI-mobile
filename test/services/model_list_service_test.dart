import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mori_ai/config/model_providers.dart';
import 'package:mori_ai/services/model_list_service.dart';

void main() {
  test('fetches models and their vision capability', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://api.deepseek.com/models');
      expect(request.headers['Authorization'], 'Bearer test-key');

      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            {
              'id': 'deepseek-reasoner',
              'name': 'DeepSeek Reasoner',
              'input_modalities': ['text'],
            },
            {
              'id': 'deepseek-flash',
              'name': 'DeepSeek Flash',
              'input_modalities': ['text', 'image'],
            },
            {
              'id': 'deepseek-flash',
              'name': 'DeepSeek Flash',
              'input_modalities': ['text', 'image'],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = ModelListService(client: client);
    addTearDown(service.dispose);

    final models = await service.fetchModels(
      provider: ModelProviderCatalog.deepSeek,
      apiKey: 'test-key',
    );

    expect(models.map((model) => model.id), [
      'deepseek-flash',
      'deepseek-reasoner',
    ]);
    expect(models.first.name, 'DeepSeek Flash');
    expect(models.first.supportsVision, isTrue);
    expect(models.last.name, 'DeepSeek Reasoner');
    expect(models.last.supportsVision, isFalse);
  });

  test('throws a clear error when the API key is missing', () async {
    final service = ModelListService();
    addTearDown(service.dispose);

    await expectLater(
      service.fetchModels(provider: ModelProviderCatalog.deepSeek, apiKey: ''),
      throwsA(isA<ModelListException>()),
    );
  });

  test('surfaces provider error details', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {'message': 'Authentication Fails'},
        }),
        401,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = ModelListService(client: client);
    addTearDown(service.dispose);

    await expectLater(
      service.fetchModels(
        provider: ModelProviderCatalog.deepSeek,
        apiKey: 'bad-key',
      ),
      throwsA(
        isA<ModelListException>().having(
          (error) => error.message,
          'message',
          contains('Authentication Fails'),
        ),
      ),
    );
  });
}
