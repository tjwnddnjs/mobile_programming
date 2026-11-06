// lib/models/moonchul_model.dart

/// [역할 설명]: '문철' 기능 수행 후 OpenRouter API로부터 파싱된 객관적 진단 데이터 구조체입니다.
class MoonchulResult {
  final int myRatio;               // 내 과실 비율 (예: 30)
  final int otherRatio;            // 상대방 과실 비율 (예: 70)
  final String myFaultAnalysis;    // 내가 대화 맥락에서 미흡했던 점
  final String otherFaultAnalysis; // 상대방이 대화 맥락에서 부적절했던 점
  final String reconciliationAdvice; // 양측이 갈등을 봉합하기 위한 구체적 조언

  MoonchulResult({
    required this.myRatio,
    required this.otherRatio,
    required this.myFaultAnalysis,
    required this.otherFaultAnalysis,
    required this.reconciliationAdvice,
  });

  factory MoonchulResult.fromMap(Map<String, dynamic> map) {
    return MoonchulResult(
      myRatio: map['myRatio'] ?? 50,
      otherRatio: map['otherRatio'] ?? 50,
      myFaultAnalysis: map['myFaultAnalysis'] ?? '분석 결과를 불러오지 못했습니다.',
      otherFaultAnalysis: map['otherFaultAnalysis'] ?? '분석 결과를 불러오지 못했습니다.',
      reconciliationAdvice: map['reconciliationAdvice'] ?? '부드러운 대화 전환이 권장됩니다.',
    );
  }
}
