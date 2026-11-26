export 'widgets/system_overlay_entrypoint.dart' show overlayMain;

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/auth_provider.dart';
import 'providers/contact_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/contacts_screen.dart';
import 'ui/tiki_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 인증 상태 로드 (자동 로그인 지원)
  final authProvider = AuthProvider();
  await authProvider.initializeAuth();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProxyProvider<AuthProvider, ContactProvider>(
          create: (_) => ContactProvider(),
          update: (_, auth, contacts) => contacts!..setUser(auth.currentUser?.id),
        ),
      ],
      child: const SmartChatApp(),
    ),
  );
}

class SmartChatApp extends StatelessWidget {
  const SmartChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'TikiTalk',
      debugShowCheckedModeBanner: false,
      theme: Tiki.theme,
      // 자동 로그인 상태에 따른 시작 화면 라우팅
      initialRoute: auth.isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/contacts': (context) => const ContactsScreen(),
      },
    );
  }
}
