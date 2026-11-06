// lib/widgets/floating_overlay_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../services/screen_capture_service.dart';
import '../services/openrouter_service.dart';
import 'recommendation_dialog.dart';
import 'moonchul_dialog.dart';

/// [역할 설명]: 전면 개편된 플로팅 오버레이 위젯입니다.
/// 1) 화면 어디든 제스처 드래그로 자유롭게 이동 가능
/// 2) 탭 시 애니메이션과 함께 [분석/추천], [문철], [나가기] 3개 버튼이 확장됨
/// 3) '분석/추천': 화면 캡처 + 활성 Target 정보 OpenRouter Vision API 전송 -> 3개 답장 팝업
/// 4) '문철': ImagePicker 갤러리 복수 사진 전송 -> 과실 비율 다이얼로그 팝업
/// 5) '나가기': 확장 메뉴를 닫고 원래 플로팅 아이콘 상태로 복귀
class FloatingOverlayWidget extends StatefulWidget {
  const FloatingOverlayWidget({super.key});

  @override
  State<FloatingOverlayWidget> createState() => _FloatingOverlayWidgetState();
}

class _FloatingOverlayWidgetState extends State<FloatingOverlayWidget> with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 140);
  bool _isExpanded = false;
  bool _isProcessing = false;

  // OpenRouter 서비스 인스턴스 (실제 운영 시 주입 또는 전역 관리)
  final OpenRouterService _openRouterService = OpenRouterService(
    apiKey: 'sk-or-v1-YOUR_OPENROUTER_API_KEY_HERE',
  );

  /// 1. '분석/추천' 핸들러 (실시간 화면 캡처 및 AI 추천 답장 3개 도출)
  Future<void> _handleAnalyzeAndRecommend() async {
    setState(() {
      _isExpanded = false;
      _isProcessing = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📸 화면을 캡처하여 AI 분석을 시작합니다...')),
    );

    // [A] 화면 전체 캡처 수행
    final base64Img = await ScreenCaptureService.captureScreenAsBase64();

    // [B] 지정된 Target 상대방 정보 획득
    final target = context.read<ContactProvider>().activeTarget;

    // [C] OpenRouter API 호출
    final recommendations = await _openRouterService.getChatRecommendations(
      base64Screenshot: base64Img,
      targetContact: target!,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    // [D] 추천 답장 결과 다이얼로그 띄우기
    showDialog(
      context: context,
      builder: (ctx) => RecommendationDialog(
        targetName: target.name,
        recommendations: recommendations,
      ),
    );
  }

  /// 2. '문철' 핸들러 (사진 첨부 및 과실 비율 분석)
  void _handleMoonchul() {
    setState(() => _isExpanded = false);
    final target = context.read<ContactProvider>().activeTarget;

    showDialog(
      context: context,
      builder: (ctx) => MoonchulDialog(
        targetContact: target,
        openRouterService: _openRouterService,
      ),
    );
  }

  /// 3. '나가기' 핸들러 (확장 메뉴 닫고 기본 아이콘 복귀)
  void _handleExit() {
    setState(() => _isExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final activeTarget = context.watch<ContactProvider>().activeTarget;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          color: Colors.transparent,
          elevation: 10,
          borderRadius: BorderRadius.circular(_isExpanded ? 20 : 32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: _isExpanded ? 240 : 64,
            padding: EdgeInsets.all(_isExpanded ? 12 : 0),
            decoration: BoxDecoration(
              color: const Color(0xFF3F51B5),
              borderRadius: BorderRadius.circular(_isExpanded ? 20 : 32),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: _isExpanded ? _buildExpandedMenu(activeTarget?.name) : _buildFloatingIcon(),
          ),
        ),
      ),
    );
  }

  /// 기본 상태: 동그란 플로팅 AI 아이콘
  Widget _buildFloatingIcon() {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () => setState(() => _isExpanded = true),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isProcessing)
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              )
            else
              const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 32),
            const Positioned(
              right: 8,
              top: 8,
              child: CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent),
            ),
          ],
        ),
      ),
    );
  }

  /// [핵심 요구사항 C-1]: 탭 시 확장되는 3개 버튼 메뉴 ('분석/추천', '문철', '나가기')
  Widget _buildExpandedMenu(String? targetName) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 상단 헤더 (타겟 이름 표시)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  targetName != null ? 'Target: $targetName' : 'SmartChat AI',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: _handleExit,
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 16),

        // 버튼 1: [분석/추천] (실시간 화면 캡처 및 AI 추천 3개 도출)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF3F51B5),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _handleAnalyzeAndRecommend,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('분석 / 추천', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),

        // 버튼 2: [문철] (사진 첨부 및 대화 과실 비율 진단)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5252),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _handleMoonchul,
          icon: const Icon(Icons.balance, size: 18),
          label: const Text('문철 (과실 분석)', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),

        // 버튼 3: [나가기] (메뉴 닫기)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _handleExit,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('나가기', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
