import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_chat_ai/models/contact_model.dart';
import 'package:smart_chat_ai/services/openrouter_service.dart';

void main() {
  const jpeg = '/9j/AA==';
  test('uses the free vision router and the image media type', () async {
    final service = OpenRouterService(apiKey: 'test-key', client: MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(body['model'], 'openrouter/free');
      expect(request.headers['authorization'], 'Bearer test-key');
      expect(body['messages'][1]['content'][1]['image_url']['url'], 'data:image/jpeg;base64,$jpeg');
      return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({'recommendations': ['a', 'b', 'c']})}}]}), 200);
    }));
    final result = await service.getChatRecommendations(base64Screenshot: jpeg, targetContact: ContactModel(id: '1', name: 'A', relationship: 'B'));
    expect(result, ['a', 'b', 'c']);
  });

  test('reports API failure rather than returning a sample result', () async {
    final service = OpenRouterService(apiKey: 'test-key', client: MockClient((_) async => http.Response('', 401)));
    expect(() => service.analyzeMoonchulFault(base64Images: [jpeg]), throwsA(isA<StateError>()));
  });

  test('returns a real parsed moonchul response', () async {
    final payload = {'myRatio': 40, 'otherRatio': 60, 'myFaultAnalysis': 'a', 'otherFaultAnalysis': 'b', 'reconciliationAdvice': 'c'};
    final service = OpenRouterService(apiKey: 'test-key', client: MockClient((_) async => http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode(payload)}}]}), 200)));
    final result = await service.analyzeMoonchulFault(base64Images: [jpeg]);
    expect(result.myRatio, 40);
    expect(result.otherFaultAnalysis, 'b');
  });
}
