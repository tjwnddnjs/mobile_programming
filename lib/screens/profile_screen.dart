// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
  // 정보 수정 다이얼로그
  void _showEditProfileDialog() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final pwCtrl = TextEditingController(text: user.password);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '이름')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '전화번호')),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '새 비밀번호'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C6BC0), foregroundColor: Colors.white),
            onPressed: () async {
              await auth.updateProfile(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                password: pwCtrl.text.trim(),
              );
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('회원 정보가 성공적으로 변경되었습니다.')),
              );
            },
            child: const Text('저장'),
          ),
        ],
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
            Text('계정 탈퇴'),
          ],
        ),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n탈퇴 시 등록된 상대방 목록과 저장된 모든 데이터가 영구히 삭제되며 복구할 수 없습니다.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().deleteAccount();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text('탈퇴 확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보 (Profile)')),
      body: user == null
          ? const Center(child: Text('로그인 정보가 없습니다.'))
          : ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFF5C6BC0),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0] : '김',
                          style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.edit, size: 16, color: Color(0xFF5C6BC0)),
                            onPressed: _showEditProfileDialog,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 정보 표시 카드
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person, color: Color(0xFF5C6BC0)),
                          title: const Text('이름', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(user.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.email, color: Color(0xFF5C6BC0)),
                          title: const Text('아이디 / 이메일', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(user.email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.phone, color: Color(0xFF5C6BC0)),
                          title: const Text('전화번호', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(user.phone, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 수정 버튼
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('회원 정보 수정하기'),
                ),
                const SizedBox(height: 12),

                // 로그아웃 버튼
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('로그아웃'),
                ),
                const SizedBox(height: 24),

                // 계정 탈퇴 버튼 (빨간색 텍스트 버튼)
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    onPressed: _showDeleteAccountDialog,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('계정 탈퇴하기', style: TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
                  ),
                ),
              ],
            ),
    );
  }
}
