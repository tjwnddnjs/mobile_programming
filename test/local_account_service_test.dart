import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_chat_ai/models/user_model.dart';
import 'package:smart_chat_ai/services/local_account_service.dart';

void main() {
  test('registers and verifies credentials and preserves updated profile', () async {
    SharedPreferences.setMockInitialValues({});
    final service = LocalAccountService();
    final user = UserModel(id: '1', email: 'user@example.com', name: '사용자', phone: '', password: '');
    expect(await service.register(user, 'correct password'), isTrue);
    expect(await service.register(user, 'another password'), isFalse);
    expect(await service.authenticate(user.email, 'wrong password'), isNull);
    expect(await service.authenticate('missing@example.com', 'correct password'), isNull);
    final signedIn = await service.authenticate('USER@example.com', 'correct password');
    expect(signedIn?.name, '사용자');
    await service.updateUser(signedIn!.copyWith(age: '21', occupation: '대학생'));
    final updated = await service.authenticate(user.email, 'correct password');
    expect(updated?.age, '21');
    expect(updated?.occupation, '대학생');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('smartchat_local_accounts_v1'), isNot(contains('correct password')));
    await service.delete(updated!);
    expect(await service.authenticate(user.email, 'correct password'), isNull);
  });
}
