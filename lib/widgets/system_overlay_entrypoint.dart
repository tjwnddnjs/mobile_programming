// lib/widgets/system_overlay_entrypoint.dart
import 'package:flutter/material.dart';

import '../ui/tiki_theme.dart';

import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'dart:convert';
import 'dart:async';

import '../models/contact_model.dart';
import '../models/user_model.dart';
import '../services/screen_capture_service.dart';
import '../services/openrouter_service.dart';
import '../services/storage_service.dart';
import 'recommendation_dialog.dart';
import 'reply_instructions_field.dart';
import 'moonchul_dialog.dart';

/// [역할 설명]: 앱을 나갔을 때나 백그라운드, 다른 앱(카톡 등) 위에서 독립적으로 실행되는
/// 시스템 오버레이 윈도우의 최상위 진입점(EntryPoint)입니다.
/// @pragma('vm:entry-point') 어노테이션을 통해 Flutter 엔진이 앱과 독립된 별도 프로세스로 구동합니다.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Tiki.theme,
      home: const SystemOverlayFloatingUI(),
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
  String _stage = 'Preparing images';
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
    setState(() { _busy = true; _stage = 'Preparing images'; _elapsed = 0; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      await _runAnalyze();
    } finally {
      _timer?.cancel();
      try {
        await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
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
        title: const Text('Choose a conversation image'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.screenshot), title: const Text('Capture screen'), onTap: () => Navigator.pop(context, 'capture')),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Attach images (up to 3)'), onTap: () => Navigator.pop(context, 'gallery')),
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
      if (images.length > 3) throw StateError('Choose up to 3 images.');
      await FlutterOverlayWindow.resizeOverlay(340, 520, false);
      if (!mounted) return;
      await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
      if (!mounted) return;
      final instructions = await showReplyPreview(
        context, images: images, isCapture: source == 'capture',
        barrierColor: Colors.transparent,
      );
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
      if (instructions == null || !mounted) return;
      setState(() { _stage = 'Analyzing the conversation'; _elapsed = 0; });
      final target = _targetContact ?? ContactModel(id: '1', name: 'Other person', relationship: 'Conversation partner');
      final user = await StorageService().getCurrentUser(refresh: true);
      final replies = await _openRouterService.getChatRecommendations(
        base64Images: images,
        targetContact: target,
        user: user,
        additionalInstructions: instructions,
      );
      if (!mounted) return;
      setState(() => _stage = 'Analysis complete');
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => RecommendationDialog(
          targetName: target.name,
          recommendations: replies,
          isSystemOverlay: true,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await FlutterOverlayWindow.resizeOverlay(340, 520, false);
      if (!mounted) return;
      await showDialog(context: context, barrierColor: Colors.transparent, builder: (context) => AlertDialog(
        title: const Text('Could not start analysis'),
        content: Text(error is StateError ? error.message : error is PlatformException ? (error.message ?? 'Could not open the image.') : 'Screen capture or image selection is unavailable.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ));
    }
  }

  // 2. 문철 실행 (과실 분석)
  Future<void> _handleMoonchul() async {
    if (_busy) return;
    setState(() { _isExpanded = false; _busy = true; _stage = 'Opening Moonchul'; _elapsed = 0; });
    try {
      final user = await StorageService().getCurrentUser(refresh: true);
      await FlutterOverlayWindow.resizeOverlay(340, 620, false);
      await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (ctx) => MoonchulDialog(
          targetContact: _targetContact,
          openRouterService: _openRouterService,
          isSystemOverlay: true,
          judgmentStyle: user?.judgmentStyle ?? JudgmentStyle.balanced,
        ),
      );
    } finally {
      try {
        await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
        await FlutterOverlayWindow.resizeOverlay(76, 76, true);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
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
        child: _busy
            ? _buildProgress()
            : _isExpanded
            ? _buildExpandedMenu()
            : _buildFloatingIcon(),
      ),
    );
  }

  /// 서버는 진행률을 제공하지 않으므로 가짜 백분율 대신 단계와 경과 시간을 표시합니다.
  Widget _buildProgress() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 120 || constraints.maxHeight < 100) {
          return const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(),
          );
        }
        return Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _stage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Elapsed: ${_elapsed}s'),
              if (_stage == 'Analyzing the conversation' && _elapsed >= 30)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Waiting for the AI response.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
            ],
          ),
        );
      },
    );
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
          color: Tiki.blue,
          shape: BoxShape.circle,
          boxShadow: const [Tiki.shadow],
          border: Border.all(color: Tiki.ink, width: 2),
        ),
        child: const Icon(Icons.chat_bubble_outline, color: Tiki.ink, size: 28),
      ),
    );
  }

  Widget _buildExpandedMenu() {
    return SizedBox(
      width: 238,
      child: TikiPanel(
        color: Tiki.paper,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TikiTalk',
                          style: Tiki.display.copyWith(fontSize: 20),
                        ),
                        if (_targetContact != null)
                          Text(
                            'Target: ${_targetContact!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Tiki.ink, size: 20),
                    onPressed: () async {
                      setState(() => _isExpanded = false);
                      await FlutterOverlayWindow.resizeOverlay(76, 76, true);
                    },
                  ),
                ],
              ),
              const Divider(height: 12),
              ElevatedButton.icon(
                style: Tiki.filled(),
                onPressed: _handleAnalyze,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text(
                  'Reply Suggestions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                style: Tiki.filled(Tiki.coral),
                onPressed: _handleMoonchul,
                icon: const Icon(Icons.balance, size: 16),
                label: const Text(
                  'Moonchul',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _handleClose,
                icon: const Icon(Icons.power_settings_new, size: 16),
                label: const Text('Turn off assistant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
