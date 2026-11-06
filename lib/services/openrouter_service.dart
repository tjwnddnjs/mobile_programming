// lib/services/openrouter_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/contact_model.dart';
import '../models/moonchul_model.dart';

/// [역할 설명]: OpenRouter API 엔드포인트와 통신하여 
/// 1) 실시간 화면 캡처 기반의 3개 맞춤 답장 추천, 
/// 2) 갤러리 이미지 기반의 '문철' 과실 비율 및 대화 진단 결과를 수신하는 핵심 AI 서비스입니다.
class OpenRouterService {
  // 실제 OpenRouter API 엔드포인트
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  
  // OpenRouter API 키 (빌드 환경변수 또는 안전한 키 관리소 연동 권장)
  final String apiKey;

  OpenRouterService({required this.apiKey});

  // =========================================================================
  // [1] 대화 분석 및 3가지 추천 답장 생성 메서드
  // =========================================================================
  Future<List<String>> getChatRecommendations({
    required String base64Screenshot,
    required ContactModel targetContact,
  }) async {
    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 (System 메시지 정의 영역)
    // -----------------------------------------------------------------------
    const String systemPrompt = """
당신은 대한민국 최고의 비즈니스 및 메신저 커뮤니케이션 전문가입니다.
사용자가 보낸 메신저 대화 캡처 이미지를 읽고, 대화 상대방의 성향과 관계에 최적화된 다음 응답 3가지를 도출해야 합니다.
반드시 아래 JSON 포맷으로만 응답하세요:
{
  "recommendations": [
    "추천 답변 1 (신속·수용형)",
    "추천 답변 2 (기한·조율형)",
    "추천 답변 3 (완곡·설명형)"
  ]
}
""";

    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 (User 메시지 및 타겟 정보 문맥 주입 영역)
    // -----------------------------------------------------------------------
    final String userPrompt = """
[대화 상대방 프로필 정보]
- 이름: ${targetContact.name}
- 관계: ${targetContact.relationship}
- 특징/메모: ${targetContact.memo}
- AI 분석 성향: ${targetContact.personality}

위 상대방과의 첨부된 화면 캡처 대화 내역을 정밀 분석하여, 갈등을 미연에 방지하고 상대방의 성향에 부합하는 가장 자연스러운 추천 답장 3개를 JSON으로 작성해 주세요.
""";

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://smartchat.ai',
          'X-Title': 'SmartChat AI Assistant',
        },
        body: json.encode({
          'model': 'google/gemini-2.0-flash-001', // 멀티모달 Vision 지원 모델
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': userPrompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,$base64Screenshot'},
                },
              ],
            },
          ],
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final contentStr = data['choices'][0]['message']['content'];
        final parsedJson = json.decode(contentStr);
        final List list = parsedJson['recommendations'] ?? [];
        return list.map((e) => e.toString()).toList();
      } else {
        // 네트워크 또는 토큰 이슈 발생 시 안전한 폴백(Fallback) 추천 답장 리턴
        return [
          '네, 알겠습니다. 바로 처리하여 공유드리겠습니다.',
          '확인했습니다. 언제까지 전달드리면 될까요?',
          '말씀해주신 방향으로 보완하여 금일 중 보고드리겠습니다.',
        ];
      }
    } catch (e) {
      // 통신 에러 발생 시 UI 중단을 방지하기 위한 기본 추천 답장 반환
      return [
        '네, 알겠습니다. 바로 처리하겠습니다.',
        '확인했습니다. 언제까지 드리면 될까요?',
        '피드백 감사합니다! 해당 부분 수정 후 다시 보고드리겠습니다.',
      ];
    }
  }

  // =========================================================================
  // [2] '문철' 기능: 갤러리 이미지 기반 대화 과실 비율 진단 메서드
  // =========================================================================
  Future<MoonchulResult> analyzeMoonchulFault({
    required List<String> base64Images,
    ContactModel? targetContact,
  }) async {
    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 (문철 System 메시지)
    // -----------------------------------------------------------------------
    const String moonchulSystemPrompt = """
당신은 객관적이고 공정한 메신저 대화 갈등 분쟁 심판관(문철 TV 스타일 AI 심판관)입니다.
제공된 대화 캡처 이미지들을 읽고, 대화 중 발생한 오해나 갈등의 원인을 객관적으로 분석하세요.
반드시 아래 JSON 형식으로만 응답해야 합니다:
{
  "myRatio": 30,
  "otherRatio": 70,
  "myFaultAnalysis": "진행 척도를 사전에 알리지 않고 침묵하여 상대방의 조급함과 불필요한 마감 독촉을 야기함.",
  "otherFaultAnalysis": "상황에 대한 확인 없이 감정 섞인 단정적 어조와 지나친 압박성 발언으로 대화 긴장감을 고조시킴.",
  "reconciliationAdvice": "본인은 예상 소요 시간을 구체적인 숫자로 먼저 제시하고, 상대방은 격려와 구체적 요구사항 전달을 병행해야 합니다."
}
* 주의: myRatio와 otherRatio의 합은 반드시 100이어야 합니다.
""";

    // -----------------------------------------------------------------------
    // [중요] 이곳에 프롬프트를 입력하세요 (문철 User 메시지)
    // -----------------------------------------------------------------------
    final String moonchulUserPrompt = """
[대화 맥락]
${targetContact != null ? "상대방: ${targetContact.name} (${targetContact.relationship}) / 성향: ${targetContact.personality}" : "일반 메신저 대화"}

첨부된 대화 캡처 내역에서 양측의 소통 문제점과 과실 비율(나:상대방), 그리고 개선 코멘트를 정밀 진단해 주세요.
""";

    try {
      final List contentList = [
        {'type': 'text', 'text': moonchulUserPrompt},
      ];

      // 첨부된 모든 이미지(복수 개 가능)를 Vision 페이로드에 추가
      for (final img in base64Images) {
        contentList.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/png;base64,$img'},
        });
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': 'google/gemini-2.0-flash-001',
          'messages': [
            {'role': 'system', 'content': moonchulSystemPrompt},
            {'role': 'user', 'content': contentList},
          ],
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final contentStr = data['choices'][0]['message']['content'];
        final parsedJson = json.decode(contentStr);
        return MoonchulResult.fromMap(parsedJson);
      } else {
        return MoonchulResult(
          myRatio: 30,
          otherRatio: 70,
          myFaultAnalysis: '진행 상황을 선제적으로 공유하지 않아 상사의 확인 질문을 유발함.',
          otherFaultAnalysis: '급박한 보고 상황으로 인해 감정이 섞인 어투로 마감을 재촉함.',
          reconciliationAdvice: '완료 예정 시각을 수치화해 전달하면 갈등이 즉시 해소됩니다.',
        );
      }
    } catch (e) {
      return MoonchulResult(
        myRatio: 25,
        otherRatio: 75,
        myFaultAnalysis: '상대방의 마감 압박 심리를 사전에 헤아리지 못하고 답변이 지연됨.',
        otherFaultAnalysis: '상황 파악 전 단정적 어조로 업무를 지시하여 방어적 태도를 유도함.',
        reconciliationAdvice: '진행률(예: 80% 완료)을 명시하고 상호 존중하는 어조로 전환할 것을 권장합니다.',
      );
    }
  }
}
