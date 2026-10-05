import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const SmartChatApp());
}

class SmartChatApp extends StatelessWidget {
  const SmartChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartChat AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5C6BC0)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
