import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'password_hash.dart';

/// Accounts are local to this device; passwords are never stored in plaintext.
class LocalAccountService {
  static const _key = 'smartchat_local_accounts_v1';

  Map<String, dynamic> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<bool> register(UserModel user, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = _read(prefs);
    final email = user.email.trim().toLowerCase();
    if (accounts.containsKey(email)) return false;
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    accounts[email] = {'user': user.copyWith(password: '').toMap(),
      'salt': base64Encode(salt), 'hash': derivePasswordHash(password, salt)};
    await prefs.setString(_key, jsonEncode(accounts));
    return true;
  }

  Future<UserModel?> authenticate(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final record = _read(prefs)[email.trim().toLowerCase()];
    if (record is! Map) return null;
    final expected = record['hash'] as String;
    final actual = derivePasswordHash(password, base64Decode(record['salt'] as String));
    var difference = expected.length ^ actual.length;
    for (var i = 0; i < min(expected.length, actual.length); i++) {
      difference |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
    }
    if (difference != 0) return null;
    return UserModel.fromMap(Map<String, dynamic>.from(record['user'] as Map));
  }

  Future<void> updateUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = _read(prefs);
    final record = accounts[user.email.toLowerCase()];
    if (record is! Map) return;
    record['user'] = user.copyWith(password: '').toMap();
    await prefs.setString(_key, jsonEncode(accounts));
  }

  Future<void> delete(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = _read(prefs)..remove(user.email.toLowerCase());
    await prefs.setString(_key, jsonEncode(accounts));
  }
}
