// lib/widgets/system_overlay_entrypoint.dart
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:convert';
import '../models/contact_model.dart';
import '../services/screen_capture_service.dart';
import '../services/openrouter_service.dart';
import 'recommendation_dialog.dart';
import 'moonchul_dialog.dart';

/// [역할 설명]: 앱을 나갔을 때나 백그라운드, 다른 앱(카톡 등) 위에서 독립적으로 실행되는
/// 시스템 오버레이 윈도우의 최상위 진입점(EntryPoint)입니다.
/// @pragma('vm:entry-point') 어노테이션을 통해 Flutter 엔진이 앱과 독립된 별도 프로세스로 구동합니다.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SystemOverlayFloatingUI(),
    ),
  );
}

class SystemOverlayFloatingUI extends StatefulWidget {
  const SystemOverlayFloatingUI({super.key});

  @override
  State<SystemOverlayFloatingUI> createState() => _SystemOverlayFloatingUIState();
}

class _SystemOverlayFloatingUIState extends State<SystemOverlayFloatingUI> {
  bool _isExpanded = false;
  ContactModel? _targetContact;
  final OpenRouterService _openRouterService = OpenRouterService(
    apiKey: 'sk-or-v1-YOUR_OPENROUTER_API_KEY_HERE',
  );

  @override
  void initState() {
    super.initState();
    // 메인 앱으로부터 전달받은 타겟 상대방 정보 수신
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null) {
        try {
          final map = json.decode(event.toString());
          setState(() {
            _targetContact = ContactModel.fromMap(map);
          });
        } catch (_) {}
      }
    });
  }

  // 1. 분석/추천 실행 (화면 캡처 -> OpenRouter)
  Future<void> _handleAnalyze() async {
    setState(() => _isExpanded = false);
    final base64Img = await ScreenCaptureService.captureScreenAsBase64();
    final target = _targetContact ?? ContactModel(id: '1', name: '상대방', relationship: '대화 상대');

    final replies = await _openRouterService.getChatRecommendations(
      base64Screenshot: base64Img,
      targetContact: target,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => RecommendationDialog(
        targetName: target.name,
        recommendations: replies,
      ),
    );
  }

  // 2. 문철 실행 (과실 분석)
  void _handleMoonchul() {
    setState(() => _isExpanded = false);
    showDialog(
      context: context,
      builder: (ctx) => MoonchulDialog(
        targetContact: _targetContact,
        openRouterService: _openRouterService,
      ),
    );
  }

  // 3. 나가기 (시스템 오버레이 창 닫기)
  void _handleClose() {
    FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: _isExpanded ? _buildExpandedMenu() : _buildFloatingIcon(),
      ),
    );
  }

  Widget _buildFloatingIcon() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = true),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF3F51B5),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildExpandedMenu() {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF303F9F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _targetContact != null ? 'Target: ${_targetContact!.name}' : 'SmartChat AI',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _isExpanded = false),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF3F51B5)),
            onPressed: _handleAnalyze,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('분석 / 추천', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), foregroundColor: Colors.white),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), foregroundColor: Colors.white),
            onPressed: _handleMoonchul,
            icon: const Icon(Icons.balance, size: 16),
            label: const Text('문철 (과실 분석)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: _handleClose,
            icon: const Icon(Icons.power_settings_new, size: 16),
            label: const Text('오버레이 종료'),
          ),
        ],
      ),
    );
  }
}
