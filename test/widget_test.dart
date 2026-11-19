import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_chat_ai/providers/auth_provider.dart';
import 'package:smart_chat_ai/screens/login_screen.dart';

void main() {
  testWidgets('login screen opens registration', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.tap(find.text('회원가입하기'));
    await tester.pumpAndSettle();
    expect(find.text('회원가입 완료하기'), findsOneWidget);
  });
}
