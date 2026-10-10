// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/contact_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/contacts_screen.dart';
import 'widgets/system_overlay_entrypoint.dart' as system_overlay_entrypoint;

/// [시스템 오버레이 진입점]: flutter_overlay_window 플러그인이 별도 FlutterEngine을 띄울 때 호출하는 함수입니다.
///
/// 일부 Android 오버레이 플러그인은 main.dart의 top-level entry point 이름을 기준으로 함수를 찾기 때문에,
/// 실제 UI 구현은 widgets/system_overlay_entrypoint.dart에 두되 main.dart에서 안전하게 위임합니다.
@pragma('vm:entry-point')
void overlayMain() {
  system_overlay_entrypoint.overlayMain();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [앱 시작 로직]: SharedPreferences에 저장된 세션을 먼저 읽어 자동 로그인 여부를 결정합니다.
  final authProvider = AuthProvider();
  await authProvider.initializeAuth();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ContactProvider>(create: (_) => ContactProvider()),
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
      title: 'SmartChat AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // [라우팅]: 현재 앱에서 사용하는 인증/홈/프로필/상대방 관리 화면만 등록합니다.
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
