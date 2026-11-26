// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';

import '../ui/tiki_theme.dart';

import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;

import '../providers/auth_provider.dart';
import '../models/user_model.dart';

/// [역할 설명]: 사용자 계정 관리(My Info) 화면입니다.
/// 1) 현재 가입된 사용자 정보(이름, 이메일, 전화번호) 열람
/// 2) 다이얼로그 또는 폼을 통한 이름/비밀번호/전화번호 수정 및 실시간 Provider 갱신
/// 3) 확인 팝업을 거친 계정 탈퇴(로컬 스토리지 데이터 완전 삭제 및 로그인 화면 라우팅)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showEditProfileDialog() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    var name = user.name;
    var phone = user.phone;
    var age = user.age;
    var gender = user.gender;
    var occupation = user.occupation;
    var bio = user.bio;
    var replyTone = user.replyTone;
    var useEmojis = user.useEmojis;
    var judgmentStyle = user.judgmentStyle;
    var saving = false;
    String? error;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Edit profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (value) => name = value,
              ),
              TextFormField(
                initialValue: phone,
                enabled: !saving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                onChanged: (value) => phone = value,
              ),
              TextFormField(
                initialValue: age,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age (optional)'),
                onChanged: (value) => age = value,
              ),
              TextFormField(
                initialValue: gender,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Gender (optional)'),
                onChanged: (value) => gender = value,
              ),
              TextFormField(
                initialValue: occupation,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Occupation (optional)'),
                onChanged: (value) => occupation = value,
              ),
              TextFormField(
                initialValue: bio,
                enabled: !saving,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'About me (optional)'),
                onChanged: (value) => bio = value,
              ),
              const SizedBox(height: 20),
              Text('AI preferences', style: Theme.of(ctx).textTheme.titleMedium),
              TextFormField(
                initialValue: replyTone,
                enabled: !saving,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Default reply tone (optional)',
                  hintText: 'e.g., Friendly and concise',
                ),
                onChanged: (value) => replyTone = value,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use emojis in suggested replies'),
                value: useEmojis,
                onChanged: saving ? null : (value) => setDialogState(() => useEmojis = value),
              ),
              DropdownButtonFormField<JudgmentStyle>(
                initialValue: judgmentStyle,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Moonchul analysis style'),
                items: [
                  for (final style in JudgmentStyle.values)
                    DropdownMenuItem(value: style, child: Text(style.label)),
                ],
                onChanged: saving ? null : (value) {
                  if (value != null) setDialogState(() => judgmentStyle = value);
                },
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text(judgmentStyle.description)),
            ],
          ),
          actions: [
            if (error != null)
              Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final ageNumber = int.tryParse(age.trim());
                if (name.trim().isEmpty) {
                  setDialogState(() => error = 'Enter your name.');
                  return;
                }
                if (age.trim().isNotEmpty && (ageNumber == null || ageNumber < 1 || ageNumber > 120)) {
                  setDialogState(() => error = 'Enter an age between 1 and 120.');
                  return;
                }
                setDialogState(() {
                  saving = true;
                  error = null;
                });
                try {
                  await auth.updateProfile(
                    name: name.trim(),
                    phone: phone.trim(),
                    age: age.trim(),
                    gender: gender.trim(),
                    occupation: occupation.trim(),
                    bio: bio.trim(),
                    replyTone: replyTone.trim(),
                    useEmojis: useEmojis,
                    judgmentStyle: judgmentStyle,
                  );
                } catch (_) {
                  if (ctx.mounted) {
                    setDialogState(() {
                      saving = false;
                      error = 'Could not save your profile. Please try again.';
                    });
                  }
                  return;
                }
                if (!mounted || !ctx.mounted || ModalRoute.of(ctx)?.isCurrent != true) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile saved.')),
                );
              },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  // [신규 요구사항 A-2]: 계정 탈퇴 다이얼로그
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete account'),
          ],
        ),
        content: const Text(
          'Delete your account and the profile, preferences, and contacts stored on this device? This cannot be undone.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AuthProvider>().deleteAccount();
              } on FirebaseAuthException catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error.code == 'requires-recent-login'
                      ? 'For security, sign out and sign in again before deleting your account.'
                      : 'Could not delete your account. Please try again.'),
                ));
                return;
              }
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text('Confirm deletion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: const TikiAppBar(title: 'My Profile'),
      body: user == null
          ? const Center(child: Text('You are signed out.'))
          : ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                TikiPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(user.name,
                              style: Tiki.label.copyWith(fontSize: 18)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: Tiki.filled(Tiki.lilac),
                          onPressed: _showEditProfileDialog,
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('Edit profile'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TikiPanel(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'AI preferences',
                          style: Tiki.display.copyWith(fontSize: 22),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Default reply tone'),
                        subtitle: Text(
                          user.replyTone.isEmpty ? 'Not set' : user.replyTone,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Use emojis in suggested replies'),
                        subtitle: Text(user.useEmojis ? 'On' : 'Off'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Moonchul analysis style'),
                        subtitle: Text(user.judgmentStyle.label),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 정보 표시 카드
                TikiPanel(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('Account details',
                              style: Tiki.display.copyWith(fontSize: 20)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.email, color: Tiki.ink),
                          title: const Text(
                            'Email',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          subtitle: Text(
                            user.email,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.phone, color: Tiki.ink),
                          title: const Text(
                            'Phone number',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          subtitle: Text(
                            user.phone,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (final field in <(String, String)>[
                          ('Age', user.age),
                          ('Gender', user.gender),
                          ('Occupation', user.occupation),
                          ('About me', user.bio),
                        ])
                          ListTile(
                            title: Text(field.$1),
                            subtitle: Text(
                              field.$2.isEmpty ? 'Not set' : field.$2,
                            ),
                          ),
                        const ListTile(
                          subtitle: Text(
                            'Reply suggestions use your name, age, gender, occupation, and bio.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 로그아웃 버튼
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
                const SizedBox(height: 24),

                // 계정 탈퇴 버튼 (빨간색 텍스트 버튼)
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: _showDeleteAccountDialog,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text(
                      'Delete my account',
                      style: TextStyle(
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
