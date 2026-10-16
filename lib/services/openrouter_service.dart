import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/contact_model.dart';
import '../models/moonchul_model.dart';

/// [역할 설명]: OpenRouter Chat Completions API와 통신하는 AI 연동 서비스입니다.
///
/// 이 클래스는 오버레이의 "분석/추천", "문철", 연락처의 "AI 성향 분석" 기능을 담당합니다.
/// API 키가 없거나 네트워크가 실패해도 UI가 멈추지 않도록 모든 공개 메서드는 안전한 폴백 값을 반환합니다.
class OpenRouterService {
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  /// [운영 설정]: 실행 시 다음처럼 주입합니다.
  ///
  /// flutter run --dart-define=OPENROUTER_API_KEY=sk-or-v1-...
  static const String _envApiKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const String _envModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    defaultValue: 'google/gemini-2.0-flash-001',
  );

  final String apiKey;
  final String model;
  final http.Client _client;

  OpenRouterService({
    required this.apiKey,
    this.model = _envModel,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// [팩토리]: 앱 전체에서 동일한 dart-define API 키 정책을 사용하도록 하는 생성자입니다.
  factory OpenRouterService.fromEnvironment() {
    return OpenRouterService(apiKey: _envApiKey);
  }

  bool get hasApiKey =>
      apiKey.trim().isNotEmpty && !apiKey.contains('YOUR_OPENROUTER');

  /// [분석/추천]: 현재 화면 캡처 이미지와 활성 Target 정보를 Vision 모델에 전달해 답장 3개를 받습니다.
  ///
  /// Target의 이름, 관계, 메모, AI 성향이 user prompt에 함께 들어가기 때문에
  /// 같은 화면 캡처라도 상대방에 따라 추천 문장이 달라질 수 있습니다.
  Future<List<String>> getChatRecommendations({
    required String base64Screenshot,
    required ContactModel targetContact,
  }) async {
    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 - 분석/추천 System 메시지
    // -----------------------------------------------------------------------
    const String systemPrompt = '''
당신은 대한민국 메신저 대화 코칭 전문가입니다.
사용자가 제공한 대화 화면 이미지를 읽고, 상대방의 성향과 관계 맥락에 맞는 다음 답장 3개를 제안하세요.
반드시 아래 JSON 형식으로만 응답하세요.
{
  "recommendations": [
    "추천 답장 1",
    "추천 답장 2",
    "추천 답장 3"
  ]
}
''';

    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 - 분석/추천 User 메시지
    // -----------------------------------------------------------------------
    final String userPrompt = '''
[대화 상대방 Target 정보]
- 이름: ${targetContact.name}
- 관계: ${targetContact.relationship}
- 관계/주의 메모: ${targetContact.memo}
- AI 분석 성향: ${targetContact.personality}

첨부된 스마트폰 화면 캡처에서 최근 대화 흐름을 읽고,
상대방이 부담을 덜 느끼면서도 사용자의 의도가 정확히 전달되는 답장 3개를 작성하세요.
각 답장은 실제 메신저 입력창에 바로 붙여넣을 수 있을 만큼 자연스러워야 합니다.
''';

    if (!hasApiKey) {
      return _fallbackRecommendations(targetContact);
    }

    try {
      final data = await _postChatCompletion({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': userPrompt},
              _imageContent(base64Screenshot),
            ],
          },
        ],
        'temperature': 0.4,
        'response_format': {'type': 'json_object'},
      });

      final content = _messageContent(data);
      final parsed = _decodeJsonObject(content);
      final rawList = parsed['recommendations'];

      if (rawList is List) {
        final recommendations = rawList
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(3)
            .toList();

        if (recommendations.isNotEmpty) {
          return _padRecommendations(recommendations, targetContact);
        }
      }

      return _fallbackRecommendations(targetContact);
    } catch (_) {
      return _fallbackRecommendations(targetContact);
    }
  }

  /// [문철]: 여러 장의 대화 캡처 이미지를 Vision 모델에 전달해 과실 비율과 개선 코멘트를 받습니다.
  ///
  /// 응답 JSON은 [MoonchulResult]로 변환되어 UI에서 프로그레스 바와 분석 문장으로 렌더링됩니다.
  Future<MoonchulResult> analyzeMoonchulFault({
    required List<String> base64Images,
    ContactModel? targetContact,
  }) async {
    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 - 문철 System 메시지
    // -----------------------------------------------------------------------
    const String systemPrompt = '''
당신은 객관적이고 공정한 메신저 대화 갈등 분석가입니다.
제공된 대화 캡처 이미지를 근거로 양측의 커뮤니케이션 과실 비율과 원인을 분석하세요.
감정적 비난 대신 관찰 가능한 말투, 맥락, 대응 타이밍을 기준으로 판단하세요.
반드시 아래 JSON 형식으로만 응답하세요.
{
  "myRatio": 30,
  "otherRatio": 70,
  "myFaultAnalysis": "내가 아쉬웠던 점",
  "otherFaultAnalysis": "상대방이 아쉬웠던 점",
  "reconciliationAdvice": "서로 보완할 점"
}
myRatio와 otherRatio의 합은 반드시 100이어야 합니다.
''';

    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 - 문철 User 메시지
    // -----------------------------------------------------------------------
    final String userPrompt = '''
[분석 맥락]
${targetContact == null ? '- 일반 메신저 대화' : '- 상대방: ${targetContact.name} (${targetContact.relationship})'}
${targetContact == null ? '' : '- 상대방 메모: ${targetContact.memo}'}
${targetContact == null ? '' : '- 상대방 AI 성향: ${targetContact.personality}'}

첨부된 대화 캡처들을 시간 흐름대로 읽고,
나 : 상대방 과실 비율, 각자의 문제점, 갈등을 줄이는 다음 대화 방식을 분석하세요.
''';

    if (!hasApiKey || base64Images.isEmpty) {
      return _fallbackMoonchulResult();
    }

    try {
      final content = <Map<String, dynamic>>[
        {'type': 'text', 'text': userPrompt},
        ...base64Images.map(_imageContent),
      ];

      final data = await _postChatCompletion({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': content},
        ],
        'temperature': 0.2,
        'response_format': {'type': 'json_object'},
      });

      final parsed = _decodeJsonObject(_messageContent(data));
      return MoonchulResult.fromMap(parsed);
    } catch (_) {
      return _fallbackMoonchulResult();
    }
  }

  /// [AI 성향 분석]: 상대방의 관계/메모만으로 초기 personality 값을 생성합니다.
  ///
  /// 사용자가 직접 성향을 쓰기 어려운 경우 버튼 한 번으로 Target Context 초안을 만들 수 있습니다.
  Future<String> analyzeContactPersonality({
    required String name,
    required String relationship,
    required String memo,
  }) async {
    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 - 상대방 성향 분석 System 메시지
    // -----------------------------------------------------------------------
    const String systemPrompt = '''
당신은 메신저 커뮤니케이션 스타일 분석가입니다.
상대방의 관계와 메모를 바탕으로, 향후 AI 답장 추천에 넣을 짧은 성향 설명을 작성하세요.
반드시 아래 JSON 형식으로만 응답하세요.
{ "personality": "성향 설명" }
''';

    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 - 상대방 성향 분석 User 메시지
    // -----------------------------------------------------------------------
    final String userPrompt = '''
- 이름: $name
- 관계: $relationship
- 메모: $memo

답장 추천 프롬프트에 넣기 좋은 1문장 성향 설명을 한국어로 작성하세요.
''';

    if (!hasApiKey) {
      return _localPersonalityHeuristic(relationship: relationship, memo: memo);
    }

    try {
      final data = await _postChatCompletion({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.3,
        'response_format': {'type': 'json_object'},
      });

      final parsed = _decodeJsonObject(_messageContent(data));
      final personality = parsed['personality']?.toString().trim();
      if (personality != null && personality.isNotEmpty) {
        return personality;
      }
    } catch (_) {
      // 아래 휴리스틱 폴백으로 이어집니다.
    }

    return _localPersonalityHeuristic(relationship: relationship, memo: memo);
  }

  /// [오버레이 Target 자동 감지]: 현재 대화 화면 캡처를 Vision 모델에 보내
  /// 상대방 이름/관계 메모/대화 성향을 추정합니다.
  ///
  /// 사용자가 카카오톡/인스타 DM/Google 검색 결과 등 앱 밖 화면에서 바로 오버레이를 켰을 때,
  /// 별도 연락처 등록 없이도 지금 보고 있는 대화의 상대방을 임시 Target으로 채울 수 있게 합니다.
  Future<ContactModel> inferTargetFromScreenshot({
    required String base64Screenshot,
  }) async {
    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 - 오버레이 Target 자동 감지 System 메시지
    // -----------------------------------------------------------------------
    const String systemPrompt = '''
당신은 스마트폰 메신저 화면에서 대화 상대방 정보를 추정하는 분석가입니다.
화면에 보이는 이름, 프로필 영역, 말투, 대화 맥락을 근거로 답장 추천에 필요한 Target 정보를 작성하세요.
확실하지 않은 값은 과장하지 말고 "화면 속 상대방", "현재 대화 상대"처럼 보수적으로 채우세요.
반드시 아래 JSON 형식으로만 응답하세요.
{
  "name": "상대방 이름 또는 화면 속 상대방",
  "relationship": "추정 관계 또는 현재 대화 상대",
  "memo": "화면에서 관찰한 관계/상황 메모",
  "personality": "답장 추천에 넣을 1문장 성향 설명"
}
''';

    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 - 오버레이 Target 자동 감지 User 메시지
    // -----------------------------------------------------------------------
    const String userPrompt = '''
첨부된 현재 스마트폰 화면을 보고,
SmartChat AI가 이후 답장 추천에 사용할 Target 정보를 추정하세요.
상대방 이름이 명확히 보이지 않으면 임의의 실명을 만들지 말고 보수적인 표현을 사용하세요.
''';

    if (!hasApiKey) {
      return _fallbackInferredTarget();
    }

    try {
      final data = await _postChatCompletion({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': userPrompt},
              _imageContent(base64Screenshot),
            ],
          },
        ],
        'temperature': 0.2,
        'response_format': {'type': 'json_object'},
      });

      final parsed = _decodeJsonObject(_messageContent(data));
      return ContactModel(
        id: 'overlay_auto_${DateTime.now().millisecondsSinceEpoch}',
        name: _readNonEmptyString(parsed['name'], '화면 속 상대방'),
        relationship: _readNonEmptyString(parsed['relationship'], '현재 대화 상대'),
        memo: _readNonEmptyString(
          parsed['memo'],
          '현재 화면에서 자동 감지한 임시 Target입니다.',
        ),
        personality: _readNonEmptyString(
          parsed['personality'],
          '현재 대화 흐름에 맞춰 부담이 적고 명확한 답장을 선호하는 편',
        ),
        isAnalysisTarget: true,
      );
    } catch (_) {
      return _fallbackInferredTarget();
    }
  }

  /// [HTTP 공통 로직]: OpenRouter 요청/응답과 상태 코드 검증을 한 곳에서 처리합니다.
  Future<Map<String, dynamic>> _postChatCompletion(
      Map<String, dynamic> payload) async {
    final response = await _client.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://smartchat.ai',
        'X-Title': 'SmartChat AI',
      },
      body: json.encode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OpenRouter API error: ${response.statusCode}');
    }

    return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// [Vision 페이로드]: Base64 이미지를 OpenRouter 멀티모달 content 형식으로 변환합니다.
  Map<String, dynamic> _imageContent(String base64Image) {
    return {
      'type': 'image_url',
      'image_url': {'url': 'data:image/png;base64,$base64Image'},
    };
  }

  /// [문자열 보정]: 모델 응답 JSON 필드가 비어 있거나 null일 때 안전한 기본값을 사용합니다.
  String _readNonEmptyString(dynamic value, String fallback) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  /// [응답 파싱]: choices[0].message.content 위치의 문자열을 안전하게 추출합니다.
  String _messageContent(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('OpenRouter choices가 비어 있습니다.');
    }

    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('OpenRouter choices 형식이 올바르지 않습니다.');
    }

    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('OpenRouter message 형식이 올바르지 않습니다.');
    }

    final content = message['content'];
    if (content is String) return content;

    throw const FormatException('OpenRouter content가 문자열이 아닙니다.');
  }

  /// [JSON 보정]: 모델이 코드펜스나 앞뒤 설명을 붙이는 경우에도 JSON 객체만 골라 파싱합니다.
  Map<String, dynamic> _decodeJsonObject(String content) {
    final trimmed = content.trim();
    final fenceRemoved = trimmed
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();

    try {
      return json.decode(fenceRemoved) as Map<String, dynamic>;
    } catch (_) {
      final start = fenceRemoved.indexOf('{');
      final end = fenceRemoved.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) rethrow;
      return json.decode(fenceRemoved.substring(start, end + 1))
          as Map<String, dynamic>;
    }
  }

  /// [추천 폴백]: API 키 미설정/통신 실패 시에도 사용자가 기능 흐름을 확인할 수 있게 합니다.
  List<String> _fallbackRecommendations(ContactModel targetContact) {
    final name = targetContact.name;
    return [
      '$name님, 말씀하신 부분 확인했습니다. 우선순위 잡아서 바로 정리해보겠습니다.',
      '좋은 지적 감사합니다. 제가 이해한 내용은 이 부분인데, 맞는지 한번만 확인 부탁드립니다.',
      '일정과 방향을 맞춰서 진행하겠습니다. 필요한 부분은 중간에 먼저 공유드릴게요.',
    ];
  }

  /// [추천 개수 보정]: 모델 응답이 1~2개뿐일 때도 UI가 항상 3개의 선택지를 보여주게 합니다.
  List<String> _padRecommendations(
      List<String> recommendations, ContactModel targetContact) {
    final padded = [...recommendations];
    final fallback = _fallbackRecommendations(targetContact);

    for (final item in fallback) {
      if (padded.length >= 3) break;
      if (!padded.contains(item)) padded.add(item);
    }

    return padded.take(3).toList();
  }

  /// [문철 폴백]: API 실패 시 기본 구조를 갖춘 결과를 반환해 결과 화면 렌더링을 보장합니다.
  MoonchulResult _fallbackMoonchulResult() {
    return MoonchulResult(
      myRatio: 40,
      otherRatio: 60,
      myFaultAnalysis: '대화의 의도와 현재 진행 상황을 충분히 설명하지 않아 상대방이 추측하게 만든 부분이 있습니다.',
      otherFaultAnalysis: '상대방도 확인 과정에서 다소 단정적인 표현을 사용해 대화 긴장도를 높인 부분이 있습니다.',
      reconciliationAdvice:
          '다음 답장에서는 현재 상황, 가능한 완료 시점, 필요한 확인 사항을 짧게 나누어 전달하는 것이 좋습니다.',
    );
  }

  /// [Target 자동 감지 폴백]: API 키가 없거나 Vision 분석이 실패해도
  /// 오버레이 Target 필드가 비어 분석 프롬프트가 약해지는 일을 막습니다.
  ContactModel _fallbackInferredTarget() {
    return ContactModel(
      id: 'overlay_auto_fallback_${DateTime.now().millisecondsSinceEpoch}',
      name: '화면 속 상대방',
      relationship: '현재 대화 상대',
      memo: '화면 캡처 기반 자동 감지를 시도했지만 API 키 또는 네트워크 문제로 기본 Target을 사용합니다.',
      personality: '현재 대화 흐름에 맞춰 부드럽고 명확한 답장을 선호하는 편',
      isAnalysisTarget: true,
    );
  }

  /// [로컬 성향 폴백]: API 키가 없어도 관계/메모 기반의 초기 성향 문장을 생성합니다.
  String _localPersonalityHeuristic({
    required String relationship,
    required String memo,
  }) {
    final joined = '$relationship $memo';
    if (joined.contains('상사') ||
        joined.contains('팀장') ||
        joined.contains('마감')) {
      return '결론과 일정이 분명한 답장을 선호하며, 지연 상황에는 선제적 공유가 필요함';
    }
    if (joined.contains('친구') ||
        joined.contains('동기') ||
        joined.contains('편안')) {
      return '친근하고 자연스러운 표현에 잘 반응하지만, 부탁은 구체적으로 말하는 편이 좋음';
    }
    if (joined.contains('고객') ||
        joined.contains('클라이언트') ||
        joined.contains('거래처')) {
      return '정중하고 근거가 분명한 설명을 선호하며, 불확실한 표현보다 확인된 정보를 중시함';
    }
    return '상황 설명과 공감 표현을 균형 있게 담은 부드러운 답장에 잘 반응하는 편';
  }
}
