// lib/models/user_model.dart
import 'dart:convert';

/// [역할 설명]: 사용자 인증 및 프로필 정보를 캡슐화한 데이터 모델 클래스입니다.
/// SharedPreferences나 로컬 보안 스토리지에 JSON 형태로 안전하게 직렬화/역직렬화할 수 있도록 지원합니다.
class UserModel {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String password; // 실제 상용 환경에서는 해시 처리 권장
  final String age;
  final String gender;
  final String occupation;
  final String bio;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.password,
    this.age = '',
    this.gender = '',
    this.occupation = '',
    this.bio = '',
  });

  /// 정보 수정(이름, 전화번호, 비밀번호 등) 시 불변성을 유지하며 사본을 생성하는 메서드
  UserModel copyWith({
    String? name,
    String? phone,
    String? password,
    String? age,
    String? gender,
    String? occupation,
    String? bio,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      bio: bio ?? this.bio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'password': password,
      'age': age,
      'gender': gender,
      'occupation': occupation,
      'bio': bio,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      password: map['password'] ?? '',
      age: map['age'] ?? '',
      gender: map['gender'] ?? '',
      occupation: map['occupation'] ?? '',
      bio: map['bio'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) => UserModel.fromMap(json.decode(source));
}
