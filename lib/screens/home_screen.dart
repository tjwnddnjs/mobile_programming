// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/contact_provider.dart';
import '../services/system_overlay_service.dart';
import '../ui/tiki_theme.dart';
import 'contacts_screen.dart';
import 'analysis_screen.dart';
import 'moonchul_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isOverlayActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshOverlayState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOverlayState();
  }

  Future<void> _refreshOverlayState() async {
    final active = await SystemOverlayService.isActive();
    if (mounted) setState(() => _isOverlayActive = active);
  }

  Future<void> _setOverlay(bool enabled) async {
    if (!enabled) {
      await SystemOverlayService.closeSystemOverlay();
      if (mounted) setState(() => _isOverlayActive = false);
      return;
    }
    final target = context.read<ContactProvider>().activeTarget;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a contact first.')));
      return;
    }
    try {
      final active = await SystemOverlayService.showSystemOverlay(target: target);
      if (mounted) setState(() => _isOverlayActive = active);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start the floating assistant.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = context.watch<ContactProvider>().activeTarget;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 20, 22),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TikiTalk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tiki.display.copyWith(fontSize: 36),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: 'Floating assistant',
                          child: Switch(
                            value: _isOverlayActive,
                            onChanged: _setOverlay,
                          ),
                        ),
                        const Text(
                          'Overlay',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1.5, height: 43, color: Tiki.ink),
                    const SizedBox(width: 12),
                    TikiBack(onPressed: () => SystemNavigator.pop()),
                  ],
                ),
                const SizedBox(height: 17),
                _HomeRow(
                  title: 'Select contact',
                  subtitle: target == null
                      ? 'No contact selected'
                      : 'Current: ${target.name}',
                  icon: Icons.person_outline,
                  accentIcon: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactsScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final replies = _FeatureCard(
                      title: 'Reply Suggestions',
                      subtitle: 'Analyze and reply',
                      color: Tiki.blue,
                      artwork: const _TeamStickers(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnalysisScreen(),
                        ),
                      ),
                    );
                    final moonchul = _FeatureCard(
                      title: 'Moonchul',
                      subtitle: 'Analyze a conflict',
                      color: Tiki.coral,
                      artwork: const _Sticker('moonchul'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MoonchulScreen(),
                        ),
                      ),
                    );
                    if (constraints.maxWidth < 320 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.35) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          replies,
                          const SizedBox(height: 12),
                          moonchul,
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: replies),
                          const SizedBox(width: 12),
                          Expanded(child: moonchul),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _HomeRow(
                  title: 'My Profile',
                  icon: Icons.person_outline,
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
                const SizedBox(height: 16),
                TikiPanel(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 12, 13, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How it works',
                          style: Tiki.display.copyWith(fontSize: 23),
                        ),
                        const _GuideRow(
                          icon: Icons.chat_bubble_outline,
                          title: 'Reply Suggestions',
                          description:
                              'Get three replies from a chat screenshot.',
                        ),
                        const Divider(height: 1, color: Tiki.ink),
                        const _GuideRow(
                          icon: Icons.balance_outlined,
                          title: 'Moonchul',
                          description:
                              'Understand a conflict and find a next step.',
                        ),
                        const Divider(height: 1, color: Tiki.ink),
                        const _GuideRow(
                          icon: Icons.layers_outlined,
                          title: 'Overlay',
                          description: 'Open the assistant over other apps.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeRow extends StatelessWidget {
  const _HomeRow({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accentIcon = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool accentIcon;

  @override
  Widget build(BuildContext context) {
    return TikiPanel(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 47,
              alignment: Alignment.center,
              decoration: accentIcon
                  ? const BoxDecoration(
                      color: Tiki.lilac,
                      border: Border(right: Tiki.outline),
                    )
                  : null,
              child: Icon(icon, size: 25),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Tiki.label.copyWith(fontSize: 16)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.artwork,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Widget artwork;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TikiPanel(
      color: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 15, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Tiki.display.copyWith(fontSize: 22)),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, height: 1.2),
                ),
              ],
            ),
          ),
          SizedBox(height: 114, child: ExcludeSemantics(child: artwork)),
        ],
      ),
    );
  }
}

class _TeamStickers extends StatelessWidget {
  const _TeamStickers();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        FractionallySizedBox(
          widthFactor: 0.47,
          alignment: Alignment.bottomLeft,
          child: _Sticker('yedam', fit: BoxFit.cover),
        ),
        FractionallySizedBox(
          widthFactor: 0.47,
          alignment: Alignment.bottomRight,
          child: _Sticker('jaekyung', fit: BoxFit.cover),
        ),
        FractionallySizedBox(
          widthFactor: 0.48,
          alignment: Alignment.bottomCenter,
          child: _Sticker('jungwon', fit: BoxFit.cover),
        ),
      ],
    );
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker(this.name, {this.fit = BoxFit.contain});

  final String name;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/tikitalk/$name.png',
      alignment: fit == BoxFit.cover
          ? const Alignment(0.28, -1)
          : Alignment.bottomCenter,
      fit: fit,
      cacheHeight: 400,
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 41, child: Icon(icon, size: 23)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                border: Border(left: Tiki.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Tiki.label),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: Tiki.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
