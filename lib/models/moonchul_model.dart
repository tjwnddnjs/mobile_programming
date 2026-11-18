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

    final a = map['myRatio'];
    final b = map['otherRatio'];
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
