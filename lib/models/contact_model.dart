// lib/models/contact_model.dart
import 'dart:convert';

/// [역할 설명]: 대화 상대방(Target)의 메타데이터를 관리하는 모델입니다.
/// 단순한 주소록 정보를 넘어, AI가 대화 분석 시 프롬프트 문맥(Context)으로 주입할
/// [personality(성향)] 및 [isAnalysisTarget(분석 대상 지정 여부)] 속성을 내장합니다.
class ContactModel {
  final String id;
  final String name;
  final String relationship; // 예: 직속 상사, 클라이언트, 입사 동기
  final String memo;         // 대화 시 유의점이나 배경 상황
  final String personality;  // AI 맞춤형 성향 (예: "직설적이며 마감 시간에 민감함")
  final bool isAnalysisTarget; // 오버레이 위젯에서 현재 분석 기준으로 활성화되었는지 여부

  ContactModel({
    required this.id,
    required this.name,
    required this.relationship,
    this.memo = '',
    this.personality = '보통 성향 (상황에 맞춰 유연하게 대처)',
    this.isAnalysisTarget = false,
  });

  ContactModel copyWith({
    String? name,
    String? relationship,
    String? memo,
    String? personality,
    bool? isAnalysisTarget,
  }) {
    return ContactModel(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      memo: memo ?? this.memo,
      personality: personality ?? this.personality,
      isAnalysisTarget: isAnalysisTarget ?? this.isAnalysisTarget,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'memo': memo,
      'personality': personality,
      'isAnalysisTarget': isAnalysisTarget,
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? '',
      memo: map['memo'] ?? '',
      personality: map['personality'] ?? '보통 성향',
      isAnalysisTarget: map['isAnalysisTarget'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory ContactModel.fromJson(String source) => ContactModel.fromMap(json.decode(source));
}
