// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/local_account_service.dart';
import '../services/system_overlay_service.dart';

/// [역할 설명]: 유저 인증 및 프로필 상태를 앱 전역에 공급(Provider)하는 ChangeNotifier입니다.
/// 회원가입, 자동 로그인, 내 정보 수정, 계정 탈퇴 액션을 중앙에서 관장합니다.
class AuthProvider extends ChangeNotifier {
  final StorageService _storageService;
  final _accounts = LocalAccountService();

  UserModel? _currentUser;
  bool _isInitialized = false;

  AuthProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  /// 앱 구동 시 자동 로그인 초기화
  Future<void> initializeAuth() async {
    _currentUser = await _storageService.getCurrentUser();
    final legacy = _currentUser;
    if (legacy != null && legacy.password.isNotEmpty) {
      final clean = legacy.copyWith(password: '');
      await _accounts.register(clean, legacy.password);
      _currentUser = clean;
      await _storageService.saveUserSession(clean);
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// 1. 회원가입 액션
  Future<bool> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final newUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email.trim().toLowerCase(),
      name: name,
      phone: phone,
      password: '',
    );

    if (!await _accounts.register(newUser, password)) return false;
    _currentUser = newUser;
    await _storageService.saveUserSession(newUser);
    notifyListeners();
    return true;
  }

  /// 2. 로그인 액션
  Future<bool> login(String email, String password) async {
    final savedUser = await _accounts.authenticate(email, password);
    if (savedUser == null) return false;
    _currentUser = savedUser;
    await _storageService.saveUserSession(_currentUser!);
    notifyListeners();
    return true;
  }

  /// 3. 내 정보 수정 액션 (이름, 전화번호, 비밀번호 변경)
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? password,
    String? age,
    String? gender,
    String? occupation,
    String? bio,
  }) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      name: name,
      phone: phone,
      password: password,
      age: age,
      gender: gender,
      occupation: occupation,
      bio: bio,
    );

    await _storageService.saveUserSession(_currentUser!);
    await _accounts.updateUser(_currentUser!);
    notifyListeners();
  }

  /// 4. 로그아웃 액션
  Future<void> logout() async {
    await SystemOverlayService.closeSystemOverlay();
    _currentUser = null;
    await _storageService.clearUserSession(isDeleteAccount: false);
    notifyListeners();
  }

  /// 5. 계정 탈퇴 액션 (모든 데이터 파기 및 초기화)
  Future<void> deleteAccount() async {
    await SystemOverlayService.closeSystemOverlay();
    final user = _currentUser;
    if (user != null) await _accounts.delete(user);
    _currentUser = null;
    await _storageService.clearUserSession(isDeleteAccount: true);
    notifyListeners();
  }
}
