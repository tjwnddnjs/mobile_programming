import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_chat_ai/models/contact_model.dart';
import 'package:smart_chat_ai/models/user_model.dart';
import 'package:smart_chat_ai/services/openrouter_service.dart';

void main() {
  const jpeg = '/9j/AA==';
  test('accepts a JSON response wrapped in a markdown code fence', () async {
    final service = OpenRouterService(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response(jsonEncode({
        'choices': [
          {'message': {'content': '```json\n{"recommendations":["a","b","c"]}\n```'}}
        ]
      }), 200)),
    );
    final result = await service.getChatRecommendations(
      base64Screenshot: jpeg,
      targetContact: ContactModel(id: '1', name: 'A', relationship: 'B'),
    );
    expect(result, ['a', 'b', 'c']);
  });

  test('reports a truncated response without exposing its contents', () async {
    final service = OpenRouterService(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response(jsonEncode({
        'choices': [
          {'finish_reason': 'length', 'message': {'content': '{"recommendations":['}}
        ]
      }), 200)),
    );
    expect(
      () => service.getChatRecommendations(
        base64Screenshot: jpeg,
        targetContact: ContactModel(id: '1', name: 'A', relationship: 'B'),
      ),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('cut off'))),
    );
  });
  test('uses the free vision router and the image media type', () async {
    final service = OpenRouterService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['model'], 'openrouter/free');
          expect(request.headers['authorization'], 'Bearer test-key');
          expect(body['messages'][1]['content'][1]['image_url']['url'],
              'data:image/jpeg;base64,$jpeg');
          return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'recommendations': ['a', 'b', 'c']
                      })
                    }
                  }
                ]
              }),
              200);
        }));
    final result = await service.getChatRecommendations(
        base64Screenshot: jpeg,
        targetContact: ContactModel(id: '1', name: 'A', relationship: 'B'));
    expect(result, ['a', 'b', 'c']);
  });

  test('sends saved reply preferences and only the current instructions',
      () async {
    final requestDetails = <Map<String, dynamic>>[];
    final service = OpenRouterService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        final body = jsonDecode(request.body);
        final messages = body['messages'];
        expect(messages[0]['content'], contains('Write in English by default'));
        requestDetails.add(jsonDecode(messages[1]['content'][0]['text']));
        return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'recommendations': ['a', 'b', 'c']
                    })
                  }
                }
              ]
            }),
            200);
      }),
    );
    final contact = ContactModel(id: '1', name: 'A', relationship: 'B');
    final user = UserModel(
      id: '1',
      email: 'user@example.com',
      name: 'Alex',
      phone: '',
      password: '',
      replyTone: 'Friendly and concise',
      useEmojis: true,
    );
    await service.getChatRecommendations(
      base64Screenshot: jpeg,
      targetContact: contact,
      user: user,
      additionalInstructions: ' Politely decline and suggest Friday ',
    );
    await service.getChatRecommendations(
      base64Screenshot: jpeg,
      targetContact: contact,
      user: user,
    );

    expect(requestDetails.first['defaultTone'], 'Friendly and concise');
    expect(requestDetails.first['useEmojis'], isTrue);
    expect(requestDetails.first['additionalInstructions'],
        'Politely decline and suggest Friday');
    expect(requestDetails.last.containsKey('additionalInstructions'), isFalse);
    expect(requestDetails.last['defaultTone'], 'Friendly and concise');
  });

  test('reports API failure rather than returning a sample result', () async {
    final service = OpenRouterService(
        apiKey: 'test-key',
        client: MockClient((_) async => http.Response('', 401)));
    expect(() => service.analyzeMoonchulFault(base64Images: [jpeg]),
        throwsA(isA<StateError>()));
  });

  test(
      'analyzes multiple anonymous participants without assuming the user identity',
      () async {
    final payload = {
      'canJudge': true,
      'summary': 'A disagreement',
      'confidence': 'Medium',
      'participants': [
        {
          'label': 'Person A',
          'identification': 'First visible name',
          'analysis': 'Suggested an agreement'
        },
        {
          'label': 'Person B',
          'identification': 'Second visible name',
          'analysis': 'Objected'
        },
        {
          'label': 'Person C',
          'identification': 'Third visible name',
          'analysis': 'Mediated'
        },
      ],
      'evidence': ['Person C offered to mediate'],
      'missingContext': <String>[],
      'reconciliationAdvice': 'Confirm each perspective',
    };
    final service = OpenRouterService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['messages'][0]['content'],
              contains('Do not infer who the user is'));
          final details = jsonDecode(body['messages'][1]['content'][0]['text']);
          expect(details['context'], 'A is the manager');
          expect(details['judgmentStyle'], JudgmentStyle.feeling.description);
          expect(details.containsKey('speakerMapping'), isFalse);
          return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': jsonEncode(payload)}
                  }
                ]
              }),
              200);
        }));
    final result = await service.analyzeAnonymousConversation(
        base64Images: [jpeg],
        contextNote: 'A is the manager',
        judgmentStyle: JudgmentStyle.feeling);
    expect(result.participants.map((p) => p.label),
        ['Person A', 'Person B', 'Person C']);
  });

  test(
      'anonymous analysis accepts an unidentified conversation when judgment is deferred',
      () async {
    final payload = {
      'canJudge': false,
      'summary': 'Speakers could not be identified',
      'confidence': 'Low',
      'participants': [],
      'evidence': [],
      'missingContext': ['Who said each message?'],
      'reconciliationAdvice': 'Clarify the situation'
    };
    final service = OpenRouterService(
        apiKey: 'test-key',
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': jsonEncode(payload)}
                }
              ]
            }),
            200)));
    final result =
        await service.analyzeAnonymousConversation(base64Images: [jpeg]);
    expect(result.canJudge, isFalse);
    expect(result.participants, isEmpty);
  });

  test('returns a real parsed moonchul response', () async {
    final payload = {
      'myRatio': 40,
      'otherRatio': 60,
      'myFaultAnalysis': 'a',
      'otherFaultAnalysis': 'b',
      'reconciliationAdvice': 'c',
      'canJudge': true,
      'summary': 'Conflict',
      'confidence': 'Medium',
      'evidence': ['Evidence'],
      'missingContext': <String>[],
      'recommendedReplies': ['a', 'b', 'c']
    };
    final service = OpenRouterService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          final body = jsonDecode(request.body);
          final details = jsonDecode(body['messages'][1]['content'][0]['text']);
          expect(details['judgmentStyle'], JudgmentStyle.thinking.description);
          expect(details['speakerMapping'], {
            'user': 'Left-side bubbles',
            'otherPerson': 'Right-side bubbles'
          });
          expect(
              body['response_format']['json_schema']['schema']['properties']
                  ['confidence']['enum'],
              ['Low', 'Medium', 'High']);
          return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': jsonEncode(payload)}
                  }
                ]
              }),
              200);
        }));
    final result = await service.analyzeMoonchulFault(
      base64Images: [jpeg],
      mySide: 'Left-side bubbles',
      judgmentStyle: JudgmentStyle.thinking,
    );
    expect(result.myRatio, 40);
    expect(result.otherFaultAnalysis, 'b');
  });
}
