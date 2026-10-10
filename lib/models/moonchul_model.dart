/// [역할 설명]: '문철' 기능 수행 후 OpenRouter API에서 받은 대화 과실 분석 결과 모델입니다.
///
/// UI는 이 모델만 바라보고 과실 비율 게이지, 내 잘못/상대방 잘못 분석,
/// 그리고 서로 보완할 점을 렌더링합니다.
class MoonchulResult {
  final int myRatio;
  final int otherRatio;
  final String myFaultAnalysis;
  final String otherFaultAnalysis;
  final String reconciliationAdvice;

  MoonchulResult({
    required int myRatio,
    required int otherRatio,
    required this.myFaultAnalysis,
    required this.otherFaultAnalysis,
    required this.reconciliationAdvice,
  })  : myRatio = _clampRatio(myRatio),
        otherRatio = _clampRatio(otherRatio);

  /// [JSON 역직렬화]: 모델이 숫자를 문자열로 반환하는 경우까지 허용합니다.
  ///
  /// myRatio와 otherRatio 합이 100이 아닌 경우에는 두 값의 상대 비율을 유지하면서
  /// 합이 100이 되도록 보정해 UI 프로그레스 바가 안정적으로 그려지게 합니다.
  factory MoonchulResult.fromMap(Map<String, dynamic> map) {
    final rawMyRatio = _parseInt(map['myRatio'], fallback: 50);
    final rawOtherRatio = _parseInt(map['otherRatio'], fallback: 50);
    final normalized = _normalizePair(rawMyRatio, rawOtherRatio);

    return MoonchulResult(
      myRatio: normalized.$1,
      otherRatio: normalized.$2,
      myFaultAnalysis: _parseText(
        map['myFaultAnalysis'],
        fallback: '대화 맥락상 내가 보완해야 할 지점을 충분히 분석하지 못했습니다.',
      ),
      otherFaultAnalysis: _parseText(
        map['otherFaultAnalysis'],
        fallback: '대화 맥락상 상대방이 보완해야 할 지점을 충분히 분석하지 못했습니다.',
      ),
      reconciliationAdvice: _parseText(
        map['reconciliationAdvice'],
        fallback: '다음 대화에서는 의도, 일정, 요청 사항을 짧고 명확하게 나누어 전달해보세요.',
      ),
    );
  }

  /// [숫자 파싱]: int, double, 숫자 문자열을 모두 안전하게 int로 변환합니다.
  static int _parseInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value.replaceAll('%', '').trim()) ?? fallback;
    return fallback;
  }

  /// [문자열 파싱]: 빈 응답을 UI에 그대로 보여주지 않도록 기본 문구를 제공합니다.
  static String _parseText(dynamic value, {required String fallback}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  /// [범위 보정]: 과실 비율이 0~100 사이를 벗어나지 않도록 제한합니다.
  static int _clampRatio(int value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  /// [합계 보정]: 두 비율 합을 100으로 맞춰 프로그레스 바 렌더링 오류를 방지합니다.
  static (int, int) _normalizePair(int myRatio, int otherRatio) {
    final safeMy = _clampRatio(myRatio);
    final safeOther = _clampRatio(otherRatio);
    final total = safeMy + safeOther;

    if (total == 100) return (safeMy, safeOther);
    if (total == 0) return (50, 50);

    final normalizedMy = ((safeMy / total) * 100).round();
    return (normalizedMy, 100 - normalizedMy);
  }
}
