// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// [역할 설명]: 신규 사용자 등록을 담당하는 회원가입 화면입니다.
/// 아이디/이메일, 비밀번호, 이름, 전화번호를 입력받아 유효성을 검증하고,
/// 로컬 스토리지에 세션을 저장하여 가입 즉시 홈 화면으로 진입할 수 있도록 지원합니다.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await context.read<AuthProvider>().signup(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome! Your account is ready.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<AuthProvider>().lastError ?? 'Could not create your account.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign up'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create a SmartChat AI account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                const Text('Firebase handles sign-in. Your profile and contacts are saved on this device.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 6),
                const Text(
                  'Enter your account details to get started.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 28),

                // 1. 이름 입력
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name or nickname',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter your name.' : null,
                ),
                const SizedBox(height: 14),

                // 2. 이메일/아이디 입력
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter your email.';
                    if (!val.contains('@')) return 'Enter a valid email address.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. 비밀번호 입력
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password (at least 6 characters)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) => val != null && val.length < 6 ? 'Enter at least 6 characters.' : null,
                ),
                const SizedBox(height: 14),

                // 4. 전화번호 입력
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter your phone number.' : null,
                ),
                const SizedBox(height: 28),

                // 가입하기 버튼
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleSignup,
                  child: Text(_isLoading ? 'Creating account…' : 'Create account', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
