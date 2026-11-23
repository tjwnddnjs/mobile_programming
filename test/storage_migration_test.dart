import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_chat_ai/services/storage_service.dart';
import 'package:smart_chat_ai/models/user_model.dart';

void main() {
  test(
      'loads defaults for old profiles and saves preferences for the app and overlay',
      () async {
    const legacy = '{"id":"user-1","name":"Alex","email":"alex@example.com"}';
    SharedPreferences.setMockInitialValues({
      'smartchat_profile_user-1': legacy,
      'smartchat_current_user': legacy,
    });
    final storage = StorageService();
    final oldProfile = (await storage.getUserProfile('user-1'))!;
    expect(oldProfile.replyTone, isEmpty);
    expect(oldProfile.useEmojis, isFalse);
    expect(oldProfile.judgmentStyle, JudgmentStyle.balanced);

    final updated = oldProfile.copyWith(
      replyTone: 'Friendly and concise',
      useEmojis: true,
      judgmentStyle: JudgmentStyle.feeling,
    );
    await storage.saveUserProfile(updated);
    await storage.saveUserSession(updated);

    for (final user in [
      await storage.getUserProfile('user-1'),
      await storage.getCurrentUser(refresh: true),
    ]) {
      expect(user?.replyTone, 'Friendly and concise');
      expect(user?.useEmojis, isTrue);
      expect(user?.judgmentStyle, JudgmentStyle.feeling);
    }
    expect(await storage.getUserProfile('other-user'), isNull);
  });

  test(
      'copies legacy contacts without deleting them or overwriting existing data',
      () async {
    SharedPreferences.setMockInitialValues({
      'smartchat_contacts_list_old': '[{"id":"old"}]',
    });
    final storage = StorageService();
    await storage.copyContactsToUser('old', 'new');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('smartchat_contacts_list_old'), '[{"id":"old"}]');
    expect(prefs.getString('smartchat_contacts_list_new'), '[{"id":"old"}]');
    await prefs.setString('smartchat_contacts_list_new', '[{"id":"new"}]');
    await storage.copyContactsToUser('old', 'new');
    expect(prefs.getString('smartchat_contacts_list_new'), '[{"id":"new"}]');
  });
}
