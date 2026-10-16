import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact_model.dart';
import '../models/user_model.dart';

/// [역할 설명]: 앱에서 사용하는 로컬 영구 저장소 접근을 한 곳으로 모은 서비스입니다.
///
/// UI나 Provider가 SharedPreferences 키 구조를 직접 알지 않아도 되도록 추상화합니다.
/// 현재 구현은 과제/프로토타입 실행 편의를 위해 SharedPreferences를 사용하지만,
/// 상용 앱에서는 비밀번호와 토큰을 flutter_secure_storage 또는 서버 세션으로 옮기는 것이 안전합니다.
class StorageService {
  static const String _keyCurrentUser = 'smartchat_current_user';
  static const String _keyIsLoggedIn = 'smartchat_is_logged_in';
  static const String _keyRegisteredUsers = 'smartchat_registered_users';
  static const String _keyContactsList = 'smartchat_contacts_list';

  /// [자동 로그인 로직]: 앱 시작 시 저장된 세션과 로그인 플래그를 함께 확인합니다.
  ///
  /// 단순히 사용자 JSON만 남아 있는 경우까지 자동 로그인으로 처리하면 로그아웃 이후에도
  /// 홈 화면으로 진입할 수 있으므로, 명시적인 로그인 플래그를 같이 검사합니다.
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    final jsonStr = prefs.getString(_keyCurrentUser);

    if (!isLoggedIn || jsonStr == null) return null;

    try {
      return UserModel.fromJson(jsonStr);
    } catch (_) {
      await prefs.remove(_keyCurrentUser);
      await prefs.setBool(_keyIsLoggedIn, false);
      return null;
    }
  }

  /// [회원 데이터 조회]: 로컬에 가입된 모든 사용자를 반환합니다.
  ///
  /// 서버가 없는 데모 앱에서도 회원가입과 로그인의 흐름이 실제처럼 동작하도록
  /// 가입 사용자 목록을 별도 키에 배열 JSON으로 저장합니다.
  Future<List<UserModel>> getRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRegisteredUsers);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(UserModel.fromMap)
          .toList();
    } catch (_) {
      await prefs.remove(_keyRegisteredUsers);
      return [];
    }
  }

  /// [로그인 검증 보조]: 이메일을 기준으로 등록 사용자를 찾습니다.
  ///
  /// 이메일 대소문자 차이 때문에 로그인에 실패하지 않도록 비교 시 소문자로 정규화합니다.
  Future<UserModel?> findRegisteredUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = await getRegisteredUsers();

    for (final user in users) {
      if (user.email.trim().toLowerCase() == normalizedEmail) {
        return user;
      }
    }
    return null;
  }

  /// [회원가입 저장]: 신규 가입 또는 프로필 수정된 사용자를 가입 목록에 반영합니다.
  ///
  /// 같은 이메일의 기존 항목은 제거한 뒤 최신 값을 추가하여 중복 계정이 생기지 않게 합니다.
  Future<void> saveRegisteredUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await getRegisteredUsers();
    final normalizedEmail = user.email.trim().toLowerCase();

    final updatedUsers = users
        .where((item) => item.email.trim().toLowerCase() != normalizedEmail)
        .toList()
      ..add(user);

    final encoded = json.encode(updatedUsers.map((item) => item.toMap()).toList());
    await prefs.setString(_keyRegisteredUsers, encoded);
  }

  /// [세션 저장]: 로그인 성공 또는 회원가입 직후 현재 사용자를 자동 로그인 대상으로 저장합니다.
  ///
  /// Provider는 이 메서드만 호출하면 현재 세션과 가입자 목록이 동시에 최신 상태로 유지됩니다.
  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    await saveRegisteredUser(user);
    await prefs.setString(_keyCurrentUser, user.toJson());
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  /// [로그아웃]: 현재 세션만 제거하고 가입자/연락처 데이터는 유지합니다.
  ///
  /// 로그아웃은 계정 삭제가 아니므로 다음 로그인 때 기존 정보와 Target 설정을 다시 사용할 수 있습니다.
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  /// [계정 탈퇴]: 현재 사용자와 앱 안의 개인 데이터를 함께 제거합니다.
  ///
  /// 요구사항에 맞춰 탈퇴 시 현재 계정, 자동 로그인 세션, 등록 상대방 목록을 모두 삭제합니다.
  Future<void> deleteAccount(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await getRegisteredUsers();
    final normalizedEmail = user.email.trim().toLowerCase();
    final remainingUsers = users
        .where((item) => item.email.trim().toLowerCase() != normalizedEmail)
        .toList();

    await prefs.setString(
      _keyRegisteredUsers,
      json.encode(remainingUsers.map((item) => item.toMap()).toList()),
    );
    await prefs.remove(_keyCurrentUser);
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyContactsList);
  }

  /// [상대방 목록 조회]: 저장된 Target 목록을 불러옵니다.
  ///
  /// 최초 실행 시에는 앱 기능을 바로 확인할 수 있도록 샘플 상대방 두 명을 제공합니다.
  /// 사용자가 한 번이라도 저장하면 이후부터는 실제 저장 목록만 반환됩니다.
  Future<List<ContactModel>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonListStr = prefs.getString(_keyContactsList);

    if (jsonListStr == null) {
      return [
        ContactModel(
          id: 'contact_1',
          name: '팀장님',
          relationship: '직속 상사 (마케팅본부)',
          memo: '마감 기한을 가장 중시하며, 두괄식 보고를 선호하심.',
          personality: '직설적이고 성과 중심적이며 빠른 피드백을 요구함',
          isAnalysisTarget: true,
        ),
        ContactModel(
          id: 'contact_2',
          name: '이민수 동기',
          relationship: '입사 동기 (디자인팀)',
          memo: '사적인 대화는 편안하지만 업무 요청 시에는 명확한 자료를 선호함.',
          personality: '수용적이고 감성적이며 친근한 어투에 잘 반응함',
        ),
      ];
    }

    try {
      final decoded = json.decode(jsonListStr) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ContactModel.fromMap)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// [상대방 목록 저장]: 추가/수정/삭제/Target 지정 결과를 로컬에 영구 반영합니다.
  Future<void> saveContacts(List<ContactModel> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(contacts.map((contact) => contact.toMap()).toList());
    await prefs.setString(_keyContactsList, encoded);
  }

  /// [상대방 전체 삭제]: 계정 탈퇴 직후 Provider 메모리 상태와 저장소를 동시에 비울 때 사용합니다.
  Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyContactsList);
  }
}
