// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../services/system_overlay_service.dart';
import 'contacts_screen.dart';

/// [역할 설명]: 앱의 메인 허브 화면입니다.
/// [변경사항 준수]: 기존의 '분석로그 탭'과 '오버레이 실행 테스트 탭'을 완전히 제거하였으며,
/// 1) 현재 지정된 '대화 분석 대상(Target)' 상태 배너
/// 2) [신규 요구사항 8]: 'AI 분석 오버레이 켜기' 스위치
///    -> 켜면 SystemOverlayService(SYSTEM_ALERT_WINDOW)를 호출하여 앱을 종료하거나
///       백그라운드로 나가도, 카카오톡 등 다른 앱 위에서도 플로팅 위젯이 계속 동작하도록 구동
/// 3) 플로팅 오버레이 3대 핵심 기능('분석/추천', '문철', '나가기') 안내 카드로 깔끔하게 리팩토링되었습니다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOverlayActive = false;

  Future<void> _setOverlay(bool enabled) async {
    if (!enabled) {
      await SystemOverlayService.closeSystemOverlay();
      if (mounted) setState(() => _isOverlayActive = false);
      return;
    }
    final target = context.read<ContactProvider>().activeTarget;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('먼저 대화 상대를 선택해주세요.')));
      return;
    }
    try {
      final active = await SystemOverlayService.showSystemOverlay(target: target);
      if (mounted) setState(() => _isOverlayActive = active);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오버레이를 시작하지 못했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contactProv = context.watch<ContactProvider>();
    final activeTarget = contactProv.activeTarget;
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              _isOverlayActive ? Icons.layers : Icons.layers_outlined,
              color: _isOverlayActive ? const Color(0xFF5C6BC0) : null,
            ),
            tooltip: '오버레이 토글',
            onPressed: () => _setOverlay(!_isOverlayActive),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. 현재 사용자 환영 & 로그인 상태 카드
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF5C6BC0),
                        child: Text(
                          user != null && user.name.isNotEmpty ? user.name[0] : '김',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user?.name ?? '사용자'} 님 환영합니다',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. [신규 B-2 연동]: 현재 지정된 '대화 분석 대상(Target)' 상태 배너
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  border: Border.all(color: Colors.indigo.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed, color: Color(0xFF5C6BC0)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('현재 AI 분석 대상 (Target)', style: TextStyle(fontSize: 11, color: Color(0xFF5C6BC0), fontWeight: FontWeight.bold)),
                          Text(
                            activeTarget != null ? '${activeTarget.name} (${activeTarget.relationship})' : '지정된 상대방 없음',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (activeTarget != null)
                            Text(
                              '성향: ${activeTarget.personality}',
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ContactsScreen()));
                      },
                      child: const Text('변경'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. [요구사항 8 핵심]: AI 분석 오버레이 스위치 (시스템 백그라운드 & 앱 종료 시에도 유지)
              Card(
                color: _isOverlayActive ? const Color(0xFFE8EAF6) : Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: SwitchListTile(
                  title: const Text('AI 분석 오버레이 켜기', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _isOverlayActive 
                      ? '백그라운드 & 앱 종료 시에도 화면 위에 플로팅 위젯이 유지됩니다. (SYSTEM_ALERT_WINDOW 활성)' 
                      : '오버레이가 꺼져 있습니다.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _isOverlayActive,
                  onChanged: _setOverlay,
                ),
              ),
              const SizedBox(height: 16),

              // 4. [요구사항 1 준수]: 홈화면에서 '내 정보', '상대방 관리' 탭 완전 제거!
              // 대신 오버레이 3대 기능 안내 카드로 대체
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 플로팅 오버레이 3대 핵심 기능', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      _buildFeatureRow(
                        num: '1',
                        color: const Color(0xFF5C6BC0),
                        title: '분석 / 추천',
                        desc: '화면 캡처 또는 사진 첨부 후 타겟 성향에 맞는 답장을 추천합니다. 화면 캡처에는 Android의 승인이 필요합니다.',
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureRow(
                        num: '2',
                        color: Colors.redAccent,
                        title: '문철 (과실 분석)',
                        desc: '갤러리/카메라에서 대화 캡처 사진을 복수 첨부하여 나 : 상대방 과실 비율(예: 30 : 70) 및 원인 분석과 개선 코멘트를 다이얼로그로 확인합니다.',
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureRow(
                        num: '3',
                        color: Colors.grey.shade700,
                        title: '나가기',
                        desc: '확장된 메뉴를 즉시 닫고 기본 플로팅 아이콘 상태로 복귀합니다.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required String num,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: color,
          child: Text(num, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
