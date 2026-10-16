import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/storage_service.dart';

/// [역할 설명]: 사용자 인증과 내 정보(Profile) 상태를 앱 전역에 공급하는 Provider입니다.
///
/// 화면은 이 Provider만 구독하면 로그인 여부, 현재 사용자, 에러 메시지를 알 수 있습니다.
/// 실제 저장/로드는 [StorageService]로 위임하여 UI와 저장소 구현을 분리했습니다.
class AuthProvider extends ChangeNotifier {
  final StorageService _storageService;

  UserModel? _currentUser;
  bool _isInitialized = false;
  bool _isBusy = false;
  String? _errorMessage;

  AuthProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  /// [초기화]: 앱 실행 직후 로컬 세션을 확인해 자동 로그인 상태를 복원합니다.
  ///
  /// main.dart에서 runApp 전에 기다리므로 사용자는 깜빡이는 로그인 화면 없이
  /// 바로 홈 또는 로그인 화면 중 올바른 곳으로 진입합니다.
  Future<void> initializeAuth() async {
    _setBusy(true);
    _currentUser = await _storageService.getCurrentUser();
    _isInitialized = true;
    _setBusy(false);
  }

  /// [회원가입]: 이메일 중복 여부를 확인한 뒤 새 계정을 로컬에 저장하고 즉시 로그인합니다.
  ///
  /// 서버 API가 추가되더라도 이 메서드의 성공/실패 계약은 유지할 수 있게 bool을 반환합니다.
  Future<bool> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _clearError();
    _setBusy(true);

    final normalizedEmail = email.trim().toLowerCase();
    final existingUser = await _storageService.findRegisteredUserByEmail(normalizedEmail);

    if (existingUser != null) {
      _setError('이미 가입된 이메일입니다. 로그인 화면에서 로그인해주세요.');
      _setBusy(false);
      return false;
    }

    final newUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: normalizedEmail,
      name: name.trim(),
      phone: phone.trim(),
      password: password,
    );

    _currentUser = newUser;
    await _storageService.saveUserSession(newUser);
    _setBusy(false);
    return true;
  }

  /// [로그인]: 등록된 사용자와 비밀번호를 검증한 뒤 자동 로그인 세션을 저장합니다.
  ///
  /// 기존 코드처럼 임의 데모 사용자를 생성하지 않고, 회원가입된 사용자만 로그인되게 하여
  /// 인증 흐름이 요구사항과 일치하도록 했습니다.
  Future<bool> login(String email, String password) async {
    _clearError();
    _setBusy(true);

    final savedUser = await _storageService.findRegisteredUserByEmail(email);
    if (savedUser == null) {
      _setError('가입되지 않은 이메일입니다. 먼저 회원가입을 진행해주세요.');
      _setBusy(false);
      return false;
    }

    if (savedUser.password != password) {
      _setError('비밀번호가 일치하지 않습니다.');
      _setBusy(false);
      return false;
    }

    _currentUser = savedUser;
    await _storageService.saveUserSession(savedUser);
    _setBusy(false);
    return true;
  }

  /// [내 정보 수정]: 이름, 전화번호, 비밀번호를 변경하고 현재 세션/가입자 목록에 동시 반영합니다.
  ///
  /// 빈 문자열이 들어오면 사용자가 해당 값을 지우려 한 것으로 보지 않고 기존 값을 유지해
  /// 실수로 프로필이 비어버리는 상황을 막습니다.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? password,
  }) async {
    if (_currentUser == null) return;

    final trimmedName = name?.trim();
    final trimmedPhone = phone?.trim();

    _currentUser = _currentUser!.copyWith(
      name: trimmedName == null || trimmedName.isEmpty ? _currentUser!.name : trimmedName,
      phone: trimmedPhone == null || trimmedPhone.isEmpty ? _currentUser!.phone : trimmedPhone,
      password: password == null || password.isEmpty ? _currentUser!.password : password,
    );

    await _storageService.saveUserSession(_currentUser!);
    notifyListeners();
  }

  /// [로그아웃]: 계정 데이터는 유지하고 현재 자동 로그인 세션만 제거합니다.
  Future<void> logout() async {
    _currentUser = null;
    await _storageService.clearUserSession();
    notifyListeners();
  }

  /// [계정 탈퇴]: 현재 계정과 해당 앱 로컬 데이터를 모두 삭제합니다.
  ///
  /// 연락처 Provider의 메모리 목록은 화면에서 별도로 비우므로, 이 메서드는 인증 저장소 정리에 집중합니다.
  Future<void> deleteAccount() async {
    final user = _currentUser;
    _currentUser = null;

    if (user != null) {
      await _storageService.deleteAccount(user);
    } else {
      await _storageService.clearUserSession();
    }

    notifyListeners();
  }

  /// [상태 보조]: 비동기 액션 진행 여부를 화면 버튼/로딩 표시와 동기화합니다.
  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  /// [상태 보조]: 최근 인증 오류 메시지를 저장하여 화면에서 SnackBar로 보여줄 수 있게 합니다.
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// [상태 보조]: 새 인증 액션 시작 전 이전 오류를 제거합니다.
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
