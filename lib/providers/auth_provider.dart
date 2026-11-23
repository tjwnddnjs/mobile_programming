// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/local_account_service.dart';
import '../services/system_overlay_service.dart';

/// [역할 설명]: 유저 인증 및 프로필 상태를 앱 전역에 공급(Provider)하는 ChangeNotifier입니다.
/// 회원가입, 자동 로그인, 내 정보 수정, 계정 탈퇴 액션을 중앙에서 관장합니다.
class AuthProvider extends ChangeNotifier {
  final StorageService _storageService;
  final _accounts = LocalAccountService();
  firebase.FirebaseAuth get _firebase => firebase.FirebaseAuth.instance;
  String? lastError;
  bool needsProfileSetup = false;

  UserModel? _currentUser;
  bool _isInitialized = false;

  AuthProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  /// 앱 구동 시 자동 로그인 초기화
  Future<void> initializeAuth() async {
    final user = _firebase.currentUser;
    if (user != null) {
      await _setFirebaseUser(user);
    } else {
      // The old local account database is retained for migration on sign-in.
      await _storageService.clearUserSession();
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _setFirebaseUser(firebase.User user, {UserModel? migrated}) async {
    final saved = await _storageService.getUserProfile(user.uid);
    final source = saved ?? migrated;
    _currentUser = UserModel(
      id: user.uid, email: user.email ?? source?.email ?? '',
      name: source?.name ?? user.displayName ?? 'User',
      phone: source?.phone ?? user.phoneNumber ?? '', password: '',
      age: source?.age ?? '', gender: source?.gender ?? '',
      occupation: source?.occupation ?? '', bio: source?.bio ?? '',
      replyTone: source?.replyTone ?? '',
      useEmojis: source?.useEmojis ?? false,
      judgmentStyle: source?.judgmentStyle ?? JudgmentStyle.balanced,
    );
    if (migrated != null) await _storageService.copyContactsToUser(migrated.id, user.uid);
    await _storageService.saveUserProfile(_currentUser!);
    await _storageService.saveUserSession(_currentUser!);
  }

  String _authMessage(firebase.FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use': return 'An account already exists with that email. Use your original sign-in method.';
      case 'invalid-email': return 'Enter a valid email address.';
      case 'weak-password': return 'Choose a stronger password.';
      case 'network-request-failed': return 'Check your internet connection.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      case 'account-exists-with-different-credential': return 'An account already exists with that email. Use your original sign-in method.';
      default: return 'Authentication failed (${error.code}).';
    }
  }

  Future<bool> signInWithGoogle() async {
    lastError = null;
    try {
      await GoogleSignIn.instance.initialize();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw StateError('Google sign-in did not return a credential.');
      final credential = firebase.GoogleAuthProvider.credential(idToken: token);
      final result = await _firebase.signInWithCredential(credential);
      await _setFirebaseUser(result.user!);
      needsProfileSetup = result.additionalUserInfo?.isNewUser ?? false;
      notifyListeners();
      return true;
    } on firebase.FirebaseAuthException catch (error) {
      lastError = _authMessage(error);
    } catch (_) {
      lastError = 'Google sign-in was canceled or could not connect. Check your setup.';
    }
    return false;
  }

  /// 1. 회원가입 액션
  Future<bool> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    lastError = null;
    needsProfileSetup = false;
    try {
      final result = await _firebase.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await result.user!.updateDisplayName(name);
      final newUser = UserModel(id: result.user!.uid, email: email.trim(), name: name, phone: phone, password: '');
      await _setFirebaseUser(result.user!, migrated: newUser);
      notifyListeners();
      return true;
    } on firebase.FirebaseAuthException catch (error) {
      lastError = _authMessage(error);
      return false;
    }
  }

  /// 2. 로그인 액션
  Future<bool> login(String email, String password) async {
    lastError = null;
    needsProfileSetup = false;
    try {
      final result = await _firebase.signInWithEmailAndPassword(email: email.trim(), password: password);
      await _setFirebaseUser(result.user!);
      notifyListeners();
      return true;
    } on firebase.FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' || error.code == 'invalid-credential') {
        final legacy = await _accounts.authenticate(email, password);
        if (legacy != null) {
          try {
            final result = await _firebase.createUserWithEmailAndPassword(email: email.trim(), password: password);
            await _setFirebaseUser(result.user!, migrated: legacy);
            notifyListeners();
            return true;
          } on firebase.FirebaseAuthException catch (migrationError) {
            lastError = _authMessage(migrationError);
            return false;
          }
        }
      }
      lastError = _authMessage(error);
      return false;
    }
  }

  /// 3. 내 정보 수정 액션 (이름, 전화번호, 비밀번호 변경)
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? age,
    String? gender,
    String? occupation,
    String? bio,
    String? replyTone,
    bool? useEmojis,
    JudgmentStyle? judgmentStyle,
  }) async {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      name: name,
      phone: phone,
      age: age,
      gender: gender,
      occupation: occupation,
      bio: bio,
      replyTone: replyTone,
      useEmojis: useEmojis,
      judgmentStyle: judgmentStyle,
    );

    await _storageService.saveUserSession(_currentUser!);
    await _storageService.saveUserProfile(_currentUser!);
    notifyListeners();
  }

  /// 4. 로그아웃 액션
  Future<void> logout() async {
    await SystemOverlayService.closeSystemOverlay();
    await _firebase.signOut();
    _currentUser = null;
    await _storageService.clearUserSession(isDeleteAccount: false);
    notifyListeners();
  }

  /// 5. 계정 탈퇴 액션 (모든 데이터 파기 및 초기화)
  Future<void> deleteAccount() async {
    await SystemOverlayService.closeSystemOverlay();
    await _firebase.currentUser?.delete();
    _currentUser = null;
    await _storageService.clearUserSession(isDeleteAccount: true);
    notifyListeners();
  }
}
