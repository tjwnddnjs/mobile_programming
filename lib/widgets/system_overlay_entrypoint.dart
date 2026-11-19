// lib/widgets/system_overlay_entrypoint.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:convert';
import 'dart:async';
import '../models/contact_model.dart';
import '../services/screen_capture_service.dart';
import '../services/openrouter_service.dart';
import '../services/storage_service.dart';
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
  bool _busy = false;
  String _stage = '사진 준비 중';
  int _elapsed = 0;
  Timer? _timer;
  StreamSubscription<dynamic>? _subscription;
  ContactModel? _targetContact;
  final OpenRouterService _openRouterService = OpenRouterService();

  @override
  void initState() {
    super.initState();
    // 메인 앱으로부터 전달받은 타겟 상대방 정보 수신
    _subscription = FlutterOverlayWindow.overlayListener.listen((event) {
      if (!mounted || _busy) return;
      if (event != null) {
        try {
          final map = event is String ? json.decode(event) : event;
          if (map is! Map) return;
          if (map['action'] == 'start') {
            Navigator.of(context).popUntil((route) => route.isFirst);
            final target = Map<String, dynamic>.from(map['target'] as Map);
            setState(() {
              _isExpanded = false;
              _targetContact = ContactModel.fromMap(target);
            });
            return;
          }
          setState(() {
            _targetContact = ContactModel.fromMap(Map<String, dynamic>.from(map));
          });
        } catch (_) {}
      }
    });
  }

  /// 선택 화면부터 결과창을 닫을 때까지 한 작업만 허용합니다.
  /// 창 크기 복원도 작업이 끝난 뒤에만 수행하여 중복 호출 간 충돌을 막습니다.
  Future<void> _handleAnalyze() async {
    if (_busy) return;
    setState(() { _busy = true; _stage = '사진 준비 중'; _elapsed = 0; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      await _runAnalyze();
    } finally {
      _timer?.cancel();
      try {
        await FlutterOverlayWindow.resizeOverlay(76, 76, true);
      } finally {
        if (mounted) setState(() { _busy = false; _isExpanded = false; });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _runAnalyze() async {
    setState(() => _isExpanded = false);
    await FlutterOverlayWindow.resizeOverlay(340, 520, false);
    if (!mounted) return;
    final source = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        title: const Text('분석할 사진 선택'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.screenshot), title: const Text('화면 캡처'), onTap: () => Navigator.pop(context, 'capture')),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('사진 첨부 (최대 3장)'), onTap: () => Navigator.pop(context, 'gallery')),
        ]),
      ),
    );
    if (source == null || !mounted) {
      await FlutterOverlayWindow.resizeOverlay(76, 76, true);
      return;
    }
    await FlutterOverlayWindow.resizeOverlay(1, 1, false);
    try {
      final List<String> images;
      if (source == 'capture') {
        final image = await ScreenCaptureService.captureScreenAsBase64();
        images = [if (image != null) image];
      } else {
        images = await ScreenCaptureService.pickImagesAsBase64() ?? [];
      }
      if (images.isEmpty) return;
      if (images.length > 3) throw StateError('사진은 최대 3장까지 선택해주세요.');
      await FlutterOverlayWindow.resizeOverlay(340, 520, false);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(context: context, barrierColor: Colors.transparent, builder: (dialogContext) => AlertDialog(
        title: Text(source == 'capture' ? '캡처한 화면' : '선택한 사진 ${images.length}장'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < images.length; i++) ...[
            Text('${i + 1}번'),
            Image.memory(base64Decode(images[i]), fit: BoxFit.contain),
            const SizedBox(height: 12),
          ]],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('분석하기')),
        ],
      ));
      if (confirmed != true) return;
      setState(() { _stage = 'AI 대화 분석 중'; _elapsed = 0; });
      final target = _targetContact ?? ContactModel(id: '1', name: '상대방', relationship: '대화 상대');
      final user = await StorageService().getCurrentUser(refresh: true);
      final replies = await _openRouterService.getChatRecommendations(base64Images: images, targetContact: target, user: user);
      if (!mounted) return;
      setState(() => _stage = '분석 완료');
      await showDialog(context: context, barrierColor: Colors.transparent, builder: (_) => RecommendationDialog(targetName: target.name, recommendations: replies));
    } catch (error) {
      if (!mounted) return;
      await FlutterOverlayWindow.resizeOverlay(340, 520, false);
      if (!mounted) return;
      await showDialog(context: context, barrierColor: Colors.transparent, builder: (context) => AlertDialog(
        title: const Text('분석을 시작하지 못했습니다'),
        content: Text(error is StateError ? error.message : error is PlatformException ? (error.message ?? '사진을 가져오지 못했습니다.') : '화면 캡처 또는 사진 선택을 사용할 수 없습니다.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ));
    } finally {
      await FlutterOverlayWindow.resizeOverlay(76, 76, true);
    }
  }

  // 2. 문철 실행 (과실 분석)
  Future<void> _handleMoonchul() async {
    if (_busy) return;
    setState(() => _isExpanded = false);
    await FlutterOverlayWindow.resizeOverlay(340, 620, false);
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => MoonchulDialog(
        targetContact: _targetContact,
        openRouterService: _openRouterService,
        isSystemOverlay: true,
      ),
    );
    await FlutterOverlayWindow.resizeOverlay(76, 76, true);
  }

  // 3. 나가기 (시스템 오버레이 창 닫기)
  Future<void> _handleClose() async {
    if (_busy) return;
    setState(() => _isExpanded = false);
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: _busy ? _buildProgress() : _isExpanded ? _buildExpandedMenu() : _buildFloatingIcon(),
      ),
    );
  }

  /// 서버는 진행률을 제공하지 않으므로 가짜 백분율 대신 단계와 경과 시간을 표시합니다.
  Widget _buildProgress() {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 120 || constraints.maxHeight < 100) {
        return const SizedBox(width: 40, height: 40,
            child: CircularProgressIndicator());
      }
      return Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(8)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_stage, style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('경과 시간 $_elapsed초'),
          if (_stage == 'AI 대화 분석 중' && _elapsed >= 30)
            const Padding(padding: EdgeInsets.only(top: 8),
                child: Text('AI 응답을 기다리고 있습니다.',
                    style: TextStyle(color: Colors.black54))),
        ]),
      );
    });
  }

  Widget _buildFloatingIcon() {
    return GestureDetector(
      onTap: () async {
        if (_busy) return;
        await FlutterOverlayWindow.resizeOverlay(260, 270, false);
        if (mounted) setState(() => _isExpanded = true);
      },
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
                onPressed: () async {
                  setState(() => _isExpanded = false);
                  await FlutterOverlayWindow.resizeOverlay(76, 76, true);
                },
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
