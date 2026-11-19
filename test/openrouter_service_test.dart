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

  test('analyzes multiple anonymous participants without assuming the user identity', () async {
    final payload = {
      'canJudge': true, 'summary': '의견 충돌', 'confidence': '보통',
      'participants': [
        {'label': '인물 A', 'identification': '첫 번째 이름', 'analysis': '약속을 제안함'},
        {'label': '인물 B', 'identification': '두 번째 이름', 'analysis': '반대함'},
        {'label': '인물 C', 'identification': '세 번째 이름', 'analysis': '조율함'},
      ],
      'evidence': ['인물 C가 조율을 제안함'], 'missingContext': <String>[],
      'reconciliationAdvice': '각자의 의견을 확인한다',
    };
    final service = OpenRouterService(apiKey: 'test-key', client: MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(body['messages'][0]['content'], contains('나/상대'));
      expect(body['messages'][1]['content'][0]['text'], contains('A는 팀장'));
      return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode(payload)}}]}), 200);
    }));
    final result = await service.analyzeAnonymousConversation(base64Images: [jpeg], contextNote: 'A는 팀장');
    expect(result.participants.map((p) => p.label), ['인물 A', '인물 B', '인물 C']);
  });

  test('anonymous analysis accepts an unidentified conversation when judgment is deferred', () async {
    final payload = {'canJudge': false, 'summary': '발화자 구분 불가', 'confidence': '낮음',
      'participants': [], 'evidence': [], 'missingContext': ['발화자를 알려주세요'],
      'reconciliationAdvice': '상황을 확인해주세요'};
    final service = OpenRouterService(apiKey: 'test-key', client: MockClient((_) async =>
      http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode(payload)}}]}), 200)));
    final result = await service.analyzeAnonymousConversation(base64Images: [jpeg]);
    expect(result.canJudge, isFalse);
    expect(result.participants, isEmpty);
  });

  test('returns a real parsed moonchul response', () async {
    final payload = {'myRatio': 40, 'otherRatio': 60, 'myFaultAnalysis': 'a', 'otherFaultAnalysis': 'b', 'reconciliationAdvice': 'c', 'canJudge': true, 'summary': '갈등', 'confidence': '보통', 'evidence': ['근거'], 'missingContext': <String>[], 'recommendedReplies': ['a', 'b', 'c']};
    final service = OpenRouterService(apiKey: 'test-key', client: MockClient((_) async => http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode(payload)}}]}), 200)));
    final result = await service.analyzeMoonchulFault(base64Images: [jpeg]);
    expect(result.myRatio, 40);
    expect(result.otherFaultAnalysis, 'b');
  });
}
