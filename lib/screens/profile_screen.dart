import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';

/// [역할 설명]: 현재 로그인한 사용자의 My Info 관리 화면입니다.
///
/// 사용자는 가입 정보 확인, 이름/전화번호/비밀번호 수정, 로그아웃, 계정 탈퇴를 수행할 수 있습니다.
/// 모든 변경은 AuthProvider를 거쳐 로컬 세션과 가입자 목록에 즉시 반영됩니다.
class ProfileScreen extends StatefulWidget {
  /// [embedded]: HomeScreen의 하단 탭 안에 들어갈 때는 중첩 AppBar/Scaffold를 만들지 않기 위한 플래그입니다.
  final bool embedded;

  const ProfileScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// [정보 수정 다이얼로그]: 이름/전화번호는 기존 값을 보여주고, 비밀번호는 보안상 빈 칸으로 시작합니다.
  ///
  /// 새 비밀번호를 비워두면 기존 비밀번호가 유지되며, 입력한 경우에만 Provider에 변경값을 전달합니다.
  void _showEditProfileDialog() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('내 정보 수정'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // [수정 필드]: 홈 화면 환영 문구와 프로필 아바타에 반영되는 표시 이름입니다.
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '이름'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return '이름을 입력해주세요.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // [수정 필드]: 등록 전화번호를 바꾸면 즉시 Profile 화면 정보 카드에 반영됩니다.
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: '전화번호'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return '전화번호를 입력해주세요.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // [수정 필드]: 새 비밀번호를 입력한 경우에만 기존 비밀번호를 교체합니다.
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: '새 비밀번호 (선택)',
                          helperText: '비워두면 기존 비밀번호가 유지됩니다.',
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              setDialogState(() => obscurePassword = !obscurePassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty && value.length < 6) {
                            return '새 비밀번호는 6자 이상이어야 합니다.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    await auth.updateProfile(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      password: passwordController.text,
                    );

                    if (!mounted || !dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('회원 정보가 변경되었습니다.')),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// [계정 탈퇴 다이얼로그]: 실수로 탈퇴하지 않도록 확인 팝업을 거칩니다.
  ///
  /// 확인 시 인증 정보와 등록 상대방 목록을 모두 지우고 로그인 화면으로 이동합니다.
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('계정 탈퇴'),
          ],
        ),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n탈퇴 시 등록된 상대방 목록과 저장된 모든 데이터가 삭제되며 복구할 수 없습니다.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final contactProvider = context.read<ContactProvider>();
              final navigator = Navigator.of(context);

              Navigator.pop(dialogContext);
              await authProvider.deleteAccount();
              await contactProvider.clearAllContacts();

              if (!mounted) return;
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
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

    final body = user == null
        ? const Center(child: Text('로그인 정보가 없습니다.'))
        : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFF5C6BC0),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0] : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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

                // [정보 표시 블록]: 가입 당시 입력한 사용자 정보를 읽기 전용 카드로 보여줍니다.
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _ProfileTile(
                          icon: Icons.person,
                          label: '이름',
                          value: user.name,
                        ),
                        const Divider(height: 1),
                        _ProfileTile(
                          icon: Icons.email,
                          label: '아이디 / 이메일',
                          value: user.email,
                        ),
                        const Divider(height: 1),
                        _ProfileTile(
                          icon: Icons.phone,
                          label: '전화번호',
                          value: user.phone,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

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

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    final navigator = Navigator.of(context);

                    await authProvider.logout();
                    if (!mounted) return;
                    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('로그아웃'),
                ),
                const SizedBox(height: 24),

                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    onPressed: _showDeleteAccountDialog,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text(
                      '계정 탈퇴하기',
                      style: TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: body,
    );
  }
}

/// [역할 설명]: ProfileScreen의 반복되는 정보 행을 작고 일관된 위젯으로 분리했습니다.
///
/// 아이콘, 라벨, 값의 레이아웃을 한 곳에서 관리해 프로필 항목이 늘어나도 UI가 흐트러지지 않습니다.
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF5C6BC0)),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}
