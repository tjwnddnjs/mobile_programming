// lib/screens/login_screen.dart
import 'package:flutter/material.dart';

import '../ui/tiki_theme.dart';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'signup_screen.dart';

/// [역할 설명]: 사용자가 아이디/비밀번호를 입력하여 로그인하고,
/// 신규 사용자를 위해 '회원가입(SignupScreen)'으로 이동할 수 있는 관문 화면입니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final pw = _passwordController.text.trim();

    if (email.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await context.read<AuthProvider>().login(email, pw);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<AuthProvider>().lastError ?? 'The email or password is incorrect.')));
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      final navigator = Navigator.of(context);
      navigator.pushReplacementNamed('/home');
      if (auth.needsProfileSetup) navigator.pushNamed('/profile');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.lastError ?? 'Google sign-in failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('TikiTalk', style: Tiki.display.copyWith(fontSize: 43)),
                  const SizedBox(height: 25),
                  Text(
                    'Welcome back',
                    style: Tiki.display.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 28),

                  // 이메일 입력 필드
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 비밀번호 입력 필드
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),

                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 로그인 버튼
                  ElevatedButton(
                    style: Tiki.filled(),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: Text(
                      _isLoading ? 'Signing in…' : 'Sign in',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 14),

                  // [요구사항]: 회원가입 화면으로 이동하는 버튼
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'New to TikiTalk?',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Tiki.ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
