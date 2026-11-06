// lib/services/storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';
import 'dart:convert';

/// [역할 설명]: 기기 내 SharedPreferences를 추상화하여 영구 데이터 CRUD를 수행하는 서비스입니다.
/// 유저 세션 관리(자동 로그인), 프로필 수정, 계정 탈퇴(데이터 완전 삭제), 상대방 목록 영속화를 전담합니다.
class StorageService {
  static const String _keyCurrentUser = 'smartchat_current_user';
  static const String _keyIsLoggedIn = 'smartchat_is_logged_in';
  static const String _keyContactsList = 'smartchat_contacts_list';

  /// 현재 로그인된 유저 로드 (앱 기동 시 자동 로그인 판별에 활용)
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyCurrentUser);
    if (jsonStr == null) return null;
    try {
      return UserModel.fromJson(jsonStr);
    } catch (e) {
      return null;
    }
  }

  /// 로그인 성공 또는 회원가입 시 유저 세션 저장
  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, user.toJson());
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  /// 로그아웃 또는 계정 탈퇴 시 로컬 데이터 클리어
  Future<void> clearUserSession({bool isDeleteAccount = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
    await prefs.setBool(_keyIsLoggedIn, false);
    if (isDeleteAccount) {
      // 계정 탈퇴 시 모든 등록된 상대방 데이터도 완전 파기
      await prefs.remove(_keyContactsList);
    }
  }

  /// 상대방 목록 불러오기
  Future<List<ContactModel>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonListStr = prefs.getString(_keyContactsList);
    if (jsonListStr == null) {
      // 초기 기본 상대방 샘플 제공
      return [
        ContactModel(
          id: 'contact_1',
          name: '팀장님',
          relationship: '직속 상사 (마케팅본부)',
          memo: '마감 기한을 가장 중시하며, 두괄식 보고를 선호하심.',
          personality: '직설적이고 성과 중심적이며 빠른 피드백을 요구함',
          isAnalysisTarget: true, // 기본 분석 대상으로 지정
        ),
        ContactModel(
          id: 'contact_2',
          name: '이민수 동기',
          relationship: '입사 동기 (디자인팀)',
          memo: '사적인 대화가 편안하지만 업무 요청 시에는 명확한 자료 필요.',
          personality: '수용적이고 감성적이며 친근한 어투 사용',
          isAnalysisTarget: false,
        ),
      ];
    }
    try {
      final List decoded = json.decode(jsonListStr);
      return decoded.map((e) => ContactModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 상대방 목록 영구 저장
  Future<void> saveContacts(List<ContactModel> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(contacts.map((c) => c.toMap()).toList());
    await prefs.setString(_keyContactsList, encoded);
  }
}
