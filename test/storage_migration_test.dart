import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_chat_ai/services/storage_service.dart';

void main() {
  test('copies legacy contacts without deleting them or overwriting existing data', () async {
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
