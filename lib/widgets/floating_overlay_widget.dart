import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/contact_provider.dart';
import '../services/openrouter_service.dart';
import '../services/screen_capture_service.dart';
import 'moonchul_dialog.dart';
import 'recommendation_dialog.dart';

/// [역할 설명]: SmartChat AI의 플로팅 오버레이 메뉴 위젯입니다.
///
/// 기본 아이콘을 탭하면 [분석/추천], [문철], [나가기] 3개 메뉴가 애니메이션으로 펼쳐집니다.
/// 이 위젯은 앱 내부 미리보기와 시스템 오버레이 UI에서 동일한 UX를 제공하기 위한 기준 구현입니다.
class FloatingOverlayWidget extends StatefulWidget {
  const FloatingOverlayWidget({super.key});

  @override
  State<FloatingOverlayWidget> createState() => _FloatingOverlayWidgetState();
}

class _FloatingOverlayWidgetState extends State<FloatingOverlayWidget> {
  final OpenRouterService _openRouterService = OpenRouterService.fromEnvironment();

  Offset _position = const Offset(20, 140);
  bool _isExpanded = false;
  bool _isProcessing = false;

  /// [분석/추천 핸들러]: 화면 캡처와 Target Context를 OpenRouter Vision 모델에 전달합니다.
  ///
  /// 추천 결과 3개는 RecommendationDialog로 보여주고, 각 답장을 탭하면 클립보드에 복사됩니다.
  Future<void> _handleAnalyzeAndRecommend() async {
    final target = context.read<ContactProvider>().activeTarget;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('분석 대상 상대방을 먼저 지정해주세요.')),
      );
      setState(() => _isExpanded = false);
      return;
    }

    setState(() {
      _isExpanded = false;
      _isProcessing = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('화면을 캡처하여 AI 분석을 시작합니다.')),
    );

    try {
      final base64Image = await ScreenCaptureService.captureScreenAsBase64();
      final recommendations = await _openRouterService.getChatRecommendations(
        base64Screenshot: base64Image,
        targetContact: target,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      showDialog(
        context: context,
        builder: (dialogContext) => RecommendationDialog(
          targetName: target.name,
          recommendations: recommendations,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  /// [문철 핸들러]: 이미지 선택/분석 다이얼로그를 열어 대화 과실 비율 분석을 시작합니다.
  void _handleMoonchul() {
    setState(() => _isExpanded = false);

    showDialog(
      context: context,
      builder: (dialogContext) => MoonchulDialog(
        targetContact: context.read<ContactProvider>().activeTarget,
        openRouterService: _openRouterService,
      ),
    );
  }

  /// [나가기 핸들러]: 확장 메뉴를 닫고 기본 아이콘 상태로 되돌립니다.
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
          setState(() => _position += details.delta);
        },
        child: Material(
          color: Colors.transparent,
          elevation: 10,
          borderRadius: BorderRadius.circular(_isExpanded ? 20 : 32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: _isExpanded ? 244 : 64,
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

  /// [기본 아이콘]: 오버레이가 접혀 있을 때 보이는 원형 AI 버튼입니다.
  Widget _buildFloatingIcon() {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: _isProcessing ? null : () => setState(() => _isExpanded = true),
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

  /// [확장 메뉴]: 요구사항의 3개 버튼만 노출합니다.
  ///
  /// "나가기"는 오버레이 자체 종료가 아니라 펼쳐진 메뉴를 닫는 동작으로 구현했습니다.
  Widget _buildExpandedMenu(String? targetName) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                targetName != null ? 'Target: $targetName' : 'SmartChat AI',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF3F51B5),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isProcessing ? null : _handleAnalyzeAndRecommend,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('분석 / 추천', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5252),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isProcessing ? null : _handleMoonchul,
          icon: const Icon(Icons.balance, size: 18),
          label: const Text('문철', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _handleExit,
          icon: const Icon(Icons.keyboard_arrow_left, size: 16),
          label: const Text('나가기', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
