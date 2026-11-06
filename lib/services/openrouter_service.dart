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

  OpenRouterService({this.apiKey = const String.fromEnvironment('OPENROUTER_API_KEY'), http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  String _imageUrl(String data) {
    final bytes = base64Decode(data);
    String type;
    if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
      type = 'image/jpeg';
    } else if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47) {
      type = 'image/png';
    } else if (bytes.length >= 12 && ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' && ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      type = 'image/webp';
    } else if (bytes.length >= 6 && ascii.decode(bytes.sublist(0, 3), allowInvalid: true) == 'GIF') {
      type = 'image/gif';
    } else {
      throw StateError('지원하지 않는 이미지 형식입니다. PNG 또는 JPEG 사진을 선택해주세요.');
    }
    return 'data:$type;base64,$data';
  }

  Future<Map<String, dynamic>> _request(List<Map<String, dynamic>> messages) async {
    if (apiKey.trim().isEmpty || apiKey.contains('YOUR_OPENROUTER_API_KEY')) {
      throw StateError('OpenRouter API 키가 설정되지 않았습니다.');
    }
    final http.Response response;
    try {
      response = await _client.post(Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${apiKey.trim()}'},
        body: jsonEncode({'model': 'openrouter/free', 'messages': messages, 'response_format': {'type': 'json_object'}}),
      ).timeout(const Duration(seconds: 90));
    } catch (_) {
      throw StateError('OpenRouter에 연결하지 못했습니다. 네트워크 상태를 확인해주세요.');
    }
    if (response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError('OpenRouter API 키 또는 접근 권한을 확인해주세요.');
      }
      if (response.statusCode == 429) {
        throw StateError('무료 모델 사용 한도에 도달했습니다. 잠시 후 다시 시도해주세요.');
      }
      throw StateError('OpenRouter 요청에 실패했습니다 (HTTP ${response.statusCode}).');
    }
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'] as String;
      final parsed = jsonDecode(content);
      if (parsed is! Map<String, dynamic>) throw const FormatException();
      return parsed;
    } catch (_) {
      throw StateError('AI 응답 형식이 올바르지 않습니다. 다시 시도해주세요.');
    }
  }

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

    final parsed = await _request([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': [
        {'type': 'text', 'text': userPrompt},
        {'type': 'image_url', 'image_url': {'url': _imageUrl(base64Screenshot)}},
      ]},
    ]);
    final list = parsed['recommendations'];
    if (list is! List || list.length != 3 || list.any((item) => item is! String || item.trim().isEmpty)) {
      throw StateError('추천 답변 형식이 올바르지 않습니다. 다시 시도해주세요.');
    }
    return list.cast<String>();
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

    final parsed = await _request([
      {'role': 'system', 'content': moonchulSystemPrompt},
      {'role': 'user', 'content': [
        {'type': 'text', 'text': moonchulUserPrompt},
        for (final image in base64Images)
          {'type': 'image_url', 'image_url': {'url': _imageUrl(image)}},
      ]},
    ]);
    final myRatio = parsed['myRatio'];
    final otherRatio = parsed['otherRatio'];
    if (myRatio is! int || otherRatio is! int || myRatio < 0 || otherRatio < 0 ||
        myRatio > 100 || otherRatio > 100 || myRatio + otherRatio != 100 ||
        ['myFaultAnalysis', 'otherFaultAnalysis', 'reconciliationAdvice'].any(
          (key) => parsed[key] is! String || (parsed[key] as String).trim().isEmpty)) {
      throw StateError('문철 분석 결과 형식이 올바르지 않습니다. 다시 시도해주세요.');
    }
    return MoonchulResult.fromMap(parsed);
  }
}
