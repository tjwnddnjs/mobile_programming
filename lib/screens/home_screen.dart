import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../services/screen_capture_service.dart';
import '../services/system_overlay_service.dart';
import '../widgets/floating_overlay_widget.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

/// [역할 설명]: 로그인 후 진입하는 SmartChat AI의 메인 셸 화면입니다.
///
/// 요구사항에 맞춰 [홈], [상대방], [내 정보] 3개의 실제 사용 탭만 제공합니다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isOverlayActive = false;

  /// [시스템 오버레이 토글]: Android의 다른 앱 위 표시 권한을 확인한 뒤 백그라운드 오버레이를 켜거나 끕니다.
  ///
  /// 활성 Target이 없으면 AI Context를 만들 수 없으므로 사용자에게 먼저 상대방을 등록/지정하도록 안내합니다.
  Future<void> _toggleSystemOverlay(bool enabled) async {
    final activeTarget = context.read<ContactProvider>().activeTarget;

    if (enabled && activeTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오버레이를 켜기 전에 분석 대상 상대방을 먼저 등록해주세요.')),
      );
      return;
    }

    if (enabled) {
      // [화면 캡처 권한 선확보]: 오버레이 자체는 SYSTEM_ALERT_WINDOW만으로 뜰 수 있지만,
      // Google/카카오톡/인스타그램 등 "다른 앱 화면"을 LLM에 보내려면 Android MediaProjection
      // 동의가 별도로 필요합니다. 사용자가 오버레이를 켜는 순간 한 번 동의를 받아두면,
      // 이후 오버레이의 분석/추천 버튼이 실제 현재 화면을 캡처할 수 있습니다.
      final capturePermissionReady =
          await ScreenCaptureService.ensureScreenCapturePermission();
      if (!mounted) return;
      if (!capturePermissionReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('화면 캡처 권한이 필요합니다. 허용 후 다시 오버레이를 켜주세요.')),
        );
        return;
      }

      final shown =
          await SystemOverlayService.showSystemOverlay(target: activeTarget!);
      if (!mounted) return;
      setState(() => _isOverlayActive = shown);
      if (!shown) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오버레이 권한이 필요하거나 실행에 실패했습니다.')),
        );
      }
      return;
    }

    await SystemOverlayService.closeSystemOverlay();
    if (!mounted) return;
    setState(() => _isOverlayActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['홈', '상대방', '내 정보'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: Icon(
                _isOverlayActive ? Icons.layers : Icons.layers_outlined,
                color: _isOverlayActive ? const Color(0xFF5C6BC0) : null,
              ),
              tooltip: _isOverlayActive ? '오버레이 끄기' : '오버레이 켜기',
              onPressed: () => _toggleSystemOverlay(!_isOverlayActive),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _DashboardTab(
            isOverlayActive: _isOverlayActive,
            onOverlayChanged: _toggleSystemOverlay,
            onOpenContacts: () => setState(() => _selectedIndex = 1),
          ),
          const ContactsScreen(embedded: true),
          const ProfileScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '상대방',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}

/// [역할 설명]: Home 탭의 대시보드 영역입니다.
///
/// 현재 로그인 사용자, 활성 Target, 시스템 오버레이 스위치, 기능 안내,
/// 그리고 앱 내부 테스트용 FloatingOverlayWidget을 한 화면에 구성합니다.
class _DashboardTab extends StatelessWidget {
  final bool isOverlayActive;
  final ValueChanged<bool> onOverlayChanged;
  final VoidCallback onOpenContacts;

  const _DashboardTab({
    required this.isOverlayActive,
    required this.onOverlayChanged,
    required this.onOpenContacts,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final activeTarget = contactProvider.activeTarget;
    final user = auth.currentUser;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // [사용자 상태 카드]: 자동 로그인된 현재 사용자의 기본 정보를 요약합니다.
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF5C6BC0),
                      child: Text(
                        user != null && user.name.isNotEmpty
                            ? user.name[0]
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user?.name ?? '사용자'} 님 환영합니다',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // [Target 상태 배너]: 현재 오버레이 분석/추천 API Context로 들어갈 상대방 정보를 보여줍니다.
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
                        const Text(
                          '현재 AI 분석 Target',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5C6BC0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          activeTarget != null
                              ? '${activeTarget.name} (${activeTarget.relationship})'
                              : '지정된 상대방 없음',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (activeTarget != null)
                          Text(
                            '성향: ${activeTarget.personality}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenContacts,
                    child: const Text('변경'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // [시스템 오버레이 스위치]: 앱 밖에서도 떠 있는 Android 오버레이를 켜고 끕니다.
            Card(
              color: isOverlayActive ? const Color(0xFFE8EAF6) : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                title: const Text(
                  'AI 분석 오버레이 켜기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isOverlayActive
                      ? '다른 앱 위에서도 플로팅 위젯이 유지됩니다.'
                      : '오버레이가 꺼져 있습니다.',
                  style: const TextStyle(fontSize: 12),
                ),
                value: isOverlayActive,
                onChanged: onOverlayChanged,
              ),
            ),
            const SizedBox(height: 16),

            // [기능 안내 카드]: 실제 남아 있는 오버레이 메뉴 3개만 설명합니다.
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '플로팅 오버레이 기능',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 12),
                    _FeatureRow(
                      number: '1',
                      color: Color(0xFF5C6BC0),
                      title: '분석 / 추천',
                      description:
                          '현재 화면을 캡처하고 Target 성향/메모와 함께 OpenRouter Vision API로 보내 추천 답장 3개를 받습니다.',
                    ),
                    SizedBox(height: 10),
                    _FeatureRow(
                      number: '2',
                      color: Colors.redAccent,
                      title: '문철',
                      description:
                          '갤러리 또는 카메라 이미지 여러 장을 분석해 나 : 상대방 과실 비율과 개선 코멘트를 보여줍니다.',
                    ),
                    SizedBox(height: 10),
                    _FeatureRow(
                      number: '3',
                      color: Colors.black54,
                      title: '나가기',
                      description: '확장된 메뉴를 닫고 기본 플로팅 아이콘 상태로 돌아갑니다.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // [앱 내부 오버레이]: 개발 중 앱 화면 안에서도 동일한 플로팅 UX를 확인할 수 있습니다.
        if (isOverlayActive) const FloatingOverlayWidget(),
      ],
    );
  }
}

/// [역할 설명]: 홈 대시보드 기능 안내 카드의 반복 행입니다.
class _FeatureRow extends StatelessWidget {
  final String number;
  final Color color;
  final String title;
  final String description;

  const _FeatureRow({
    required this.number,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: color,
          child: Text(
            number,
            style: const TextStyle(
                fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                    fontSize: 11, color: Colors.black87, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
