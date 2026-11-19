/// 대화 캡처에 근거한 갈등 분석 결과. 비율은 법적 과실이 아닌 소통 책임 추정치입니다.
class MoonchulResult {
  final int myRatio;
  final int otherRatio;
  final String myFaultAnalysis;
  final String otherFaultAnalysis;
  final String reconciliationAdvice;
  final bool canJudge;
  final String summary;
  final String confidence;
  final List<String> evidence;
  final List<String> missingContext;
  final List<String> recommendedReplies;

  MoonchulResult(
      {required this.myRatio,
      required this.otherRatio,
      required this.myFaultAnalysis,
      required this.otherFaultAnalysis,
      required this.reconciliationAdvice,
      this.canJudge = true,
      this.summary = '',
      this.confidence = '낮음',
      this.evidence = const [],
      this.missingContext = const [],
      this.recommendedReplies = const []});

  factory MoonchulResult.fromMap(Map<String, dynamic> map) {
    String requiredText(String key) {
      final value = map[key];
      if (value is! String || value.trim().isEmpty)
        throw FormatException('누락된 분석 항목: $key');
      return value.trim();
    }

    List<String> strings(String key) {
      final value = map[key];
      if (value == null) return const [];
      if (value is! List ||
          value.any((v) => v is! String || v.trim().isEmpty)) {
        throw FormatException('잘못된 분석 항목: $key');
      }
      return value.cast<String>();
    }

    // JSON 모델이 30을 30.0 또는 "30%"로 반환해도 같은 정수 비율로 해석합니다.
    // 소수 비율을 임의 반올림하거나 범위를 보정하여 판단을 바꾸지는 않습니다.
    int? ratio(dynamic value) {
      final number = value is num ? value : num.tryParse(
          value.toString().trim().replaceFirst(RegExp(r'%$'), '').trim());
      if (number == null || !number.isFinite || number != number.roundToDouble()) return null;
      return number.toInt();
    }
    final a = ratio(map['myRatio']);
    final b = ratio(map['otherRatio']);
    if (a is! int ||
        b is! int ||
        a < 0 ||
        b < 0 ||
        a > 100 ||
        b > 100 ||
        a + b != 100) {
      throw const FormatException('책임 비율의 합은 100이어야 합니다.');
    }
    if (map.containsKey('canJudge') && map['canJudge'] is! bool)
      throw const FormatException('판단 가능 여부 오류');
    return MoonchulResult(
        myRatio: a,
        otherRatio: b,
        myFaultAnalysis: requiredText('myFaultAnalysis'),
        otherFaultAnalysis: requiredText('otherFaultAnalysis'),
        reconciliationAdvice: requiredText('reconciliationAdvice'),
        canJudge: map['canJudge'] as bool? ?? true,
        summary: map['summary'] as String? ?? '',
        confidence: map['confidence'] as String? ?? '낮음',
        evidence: strings('evidence'),
        missingContext: strings('missingContext'),
        recommendedReplies: strings('recommendedReplies'));
  }
}

class ConversationParticipant {
  final String label;
  final String identification;
  final String analysis;

  ConversationParticipant({required this.label, required this.identification, required this.analysis});

  factory ConversationParticipant.fromMap(Map<String, dynamic> map) {
    String text(String key) {
      final value = map[key];
      if (value is! String || value.trim().isEmpty) throw FormatException('잘못된 인물 정보: $key');
      return value.trim();
    }
    return ConversationParticipant(label: text('label'), identification: text('identification'), analysis: text('analysis'));
  }
}

class AnonymousMoonchulResult {
  final bool canJudge;
  final String summary;
  final String confidence;
  final List<ConversationParticipant> participants;
  final List<String> evidence;
  final List<String> missingContext;
  final String reconciliationAdvice;

  AnonymousMoonchulResult({required this.canJudge, required this.summary, required this.confidence,
    required this.participants, required this.evidence, required this.missingContext,
    required this.reconciliationAdvice});

  factory AnonymousMoonchulResult.fromMap(Map<String, dynamic> map) {
    String text(String key) {
      final value = map[key];
      if (value is! String || value.trim().isEmpty) throw FormatException('잘못된 분석 항목: $key');
      return value.trim();
    }
    List<String> strings(String key) {
      final value = map[key];
      if (value is! List || value.any((e) => e is! String || e.trim().isEmpty)) {
        throw FormatException('잘못된 분석 항목: $key');
      }
      return value.cast<String>();
    }
    final canJudge = map['canJudge'];
    final rawParticipants = map['participants'];
    if (canJudge is! bool || rawParticipants is! List) throw const FormatException('잘못된 분석 형식');
    final participants = rawParticipants.map((entry) {
      if (entry is! Map) throw const FormatException('잘못된 인물 형식');
      return ConversationParticipant.fromMap(Map<String, dynamic>.from(entry));
    }).toList();
    final confidence = text('confidence');
    final evidence = strings('evidence');
    final missing = strings('missingContext');
    if (!['낮음', '보통', '높음'].contains(confidence) ||
        participants.map((p) => p.label).toSet().length != participants.length ||
        (canJudge && (participants.length < 2 || evidence.isEmpty)) ||
        (!canJudge && missing.isEmpty)) {
      throw const FormatException('인물 분석 정보가 부족합니다.');
    }
    return AnonymousMoonchulResult(canJudge: canJudge, summary: text('summary'),
      confidence: confidence, participants: participants, evidence: evidence,
      missingContext: missing, reconciliationAdvice: text('reconciliationAdvice'));
  }
}
