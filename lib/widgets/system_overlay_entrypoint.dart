import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../models/contact_model.dart';
import '../services/openrouter_service.dart';
import '../services/screen_capture_service.dart';
import 'moonchul_dialog.dart';
import 'overlay_target_dialog.dart';
import 'recommendation_dialog.dart';

/// [역할 설명]: flutter_overlay_window가 별도 FlutterEngine에서 실행하는 시스템 오버레이 UI 진입점입니다.
///
/// main.dart의 overlayMain wrapper가 이 함수를 호출하며, 백그라운드/다른 앱 위에서도 동일한 메뉴를 렌더링합니다.
@pragma('vm:entry-point')
void overlayMain() {
  // [오버레이 엔진 초기화]: 시스템 오버레이는 메인 앱과 별도의 FlutterEngine에서 실행됩니다.
  // 이 엔진에서도 MethodChannel, ImagePicker, Clipboard 같은 플러그인을 사용할 수 있어야 하므로
  // Widgets 바인딩과 플러그인 등록을 명시적으로 수행합니다.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5C6BC0)),
        useMaterial3: true,
      ),
      home: const SystemOverlayFloatingUI(),
    ),
  );
}

/// [역할 설명]: Android 시스템 오버레이 위에 실제로 표시되는 플로팅 UI입니다.
///
/// 메인 앱에서 FlutterOverlayWindow.shareData로 전달한 ContactModel JSON을 받아
/// 분석/추천과 문철 API 호출의 Target Context로 사용합니다.
class SystemOverlayFloatingUI extends StatefulWidget {
  const SystemOverlayFloatingUI({super.key});

  @override
  State<SystemOverlayFloatingUI> createState() =>
      _SystemOverlayFloatingUIState();
}

class _SystemOverlayFloatingUIState extends State<SystemOverlayFloatingUI> {
  /// [접힌 창 크기]: resizeOverlay는 플러그인 내부에서 dp를 px로 변환하므로,
  /// 접힌 상태는 손가락으로 누르기 쉬운 88dp 정사각형으로 맞춥니다.
  static const int _collapsedWindowSizeDp = 88;

  /// [확장 메뉴 크기]: 3개 버튼과 Target명을 담을 수 있는 최소 크기입니다.
  /// 너무 크게 잡으면 Google/카톡 화면을 불필요하게 가리므로 메뉴에 필요한 영역만 확보합니다.
  static const int _expandedWindowWidthDp = 320;
  static const int _expandedWindowHeightDp = 372;

  /// [결과 다이얼로그 크기]: 추천 답장/문철 결과는 카드와 텍스트가 많기 때문에
  /// 메뉴보다 넓고 높은 투명 오버레이 창으로 확장해 잘림을 줄입니다.
  static const int _dialogWindowWidthDp = 420;
  static const int _dialogWindowHeightDp = 640;

  final OpenRouterService _openRouterService =
      OpenRouterService.fromEnvironment();

  StreamSubscription<dynamic>? _overlaySubscription;
  bool _isExpanded = false;
  bool _isProcessing = false;
  ContactModel? _targetContact;

  @override
  void initState() {
    super.initState();

    // [Target 동기화]: 메인 앱에서 선택한 상대방 정보를 오버레이 엔진으로 전달받습니다.
    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == null) return;

      try {
        final decoded = json.decode(event.toString()) as Map<String, dynamic>;
        setState(() => _targetContact = ContactModel.fromMap(decoded));
      } catch (_) {
        // 잘못된 메시지는 오버레이를 중단시키지 않고 무시합니다.
      }
    });
  }

  /// [창 크기 변경 래퍼]: flutter_overlay_window의 resizeOverlay 호출은 기기/OS에 따라
  /// 실패할 수 있으므로 오버레이 UI 자체가 죽지 않도록 예외를 흡수합니다.
  /// 실제 기능 흐름은 계속 이어지고, 크기 조정 실패 시에는 현재 창 크기 안에서 가능한 만큼 렌더링됩니다.
  Future<void> _resizeOverlayWindow({
    required int width,
    required int height,
    bool enableDrag = true,
  }) async {
    try {
      await FlutterOverlayWindow.resizeOverlay(width, height, enableDrag);
    } catch (_) {
      // 시스템 오버레이 크기 조정 실패는 치명 오류가 아니므로 UI 흐름을 유지합니다.
    }
  }

  /// [오버레이 입력 모드 전환]: TextField가 들어간 Target 입력창에서는 키보드 포커스가 필요합니다.
  ///
  /// flutter_overlay_window는 기본 flag에서 키 입력 포커스를 받지 않으므로,
  /// 직접 입력 다이얼로그를 띄울 때만 focusPointer로 바꾸고 닫을 때 defaultFlag로 되돌립니다.
  Future<void> _setOverlayKeyboardMode(bool enabled) async {
    try {
      await FlutterOverlayWindow.updateFlag(
        enabled ? OverlayFlag.focusPointer : OverlayFlag.defaultFlag,
      );
    } catch (_) {
      // flag 전환 실패는 특정 기기/OS 조합에서 발생할 수 있으므로 오버레이 흐름은 유지합니다.
    }
  }

  /// [캡처 전 오버레이 숨김]: MediaProjection은 화면 위의 오버레이까지 함께 찍을 수 있습니다.
  ///
  /// AI가 Google/카톡/인스타 화면 자체를 읽어야 하므로, 캡처 직전 오버레이 창을 1dp로 줄였다가
  /// 캡처 후 다시 로딩 아이콘 크기로 되돌립니다. 이 짧은 깜빡임 덕분에 캡처 이미지에서
  /// SmartChat 메뉴가 대화를 가리는 문제를 줄일 수 있습니다.
  Future<String> _captureCurrentScreenForAi() async {
    await _resizeOverlayWindow(width: 1, height: 1, enableDrag: false);
    await Future<void>.delayed(const Duration(milliseconds: 320));

    try {
      final image = await ScreenCaptureService.captureScreenAsBase64(
        allowFallback: false,
      );

      if (ScreenCaptureService.isFallbackImage(image)) {
        throw const ScreenCaptureException('실제 화면 대신 폴백 이미지가 반환되었습니다.');
      }

      return image;
    } finally {
      await _resizeOverlayWindow(
        width: _collapsedWindowSizeDp,
        height: _collapsedWindowSizeDp,
      );
    }
  }

  /// [오류 안내]: 캡처 권한/채널 문제처럼 사용자가 알아야 하는 실패는 조용히 삼키지 않고
  /// 투명 오버레이 다이얼로그로 보여줍니다.
  Future<void> _showOverlayError({
    required String title,
    required String message,
  }) async {
    await _prepareDialogWindow();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
          ],
        ),
        content:
            Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// [메뉴 펼치기]: 작은 챗헤드 창을 먼저 메뉴 크기로 키운 뒤 상태를 바꿉니다.
  /// 이렇게 해야 Google/Instagram 위에서도 버튼들이 오버레이 창 밖으로 잘리지 않습니다.
  Future<void> _expandMenu() async {
    if (_isProcessing) return;

    await _setOverlayKeyboardMode(false);
    await _resizeOverlayWindow(
      width: _expandedWindowWidthDp,
      height: _expandedWindowHeightDp,
    );

    if (!mounted) return;
    setState(() => _isExpanded = true);
  }

  /// [아이콘으로 접기]: 메뉴/다이얼로그가 끝난 뒤 다시 작은 플로팅 아이콘만 남깁니다.
  /// 사용자가 다른 앱 화면을 최대한 가리지 않게 하는 기본 상태입니다.
  Future<void> _collapseToIcon() async {
    if (mounted) {
      setState(() => _isExpanded = false);
    }

    await _setOverlayKeyboardMode(false);
    await _resizeOverlayWindow(
      width: _collapsedWindowSizeDp,
      height: _collapsedWindowSizeDp,
    );
  }

  /// [결과창 준비]: AlertDialog 계열 UI는 접힌/메뉴 크기 안에서 쉽게 잘리므로,
  /// 결과를 보여주기 직전에 오버레이 창을 다이얼로그용 크기로 넓힙니다.
  Future<void> _prepareDialogWindow({bool allowKeyboard = false}) async {
    await _setOverlayKeyboardMode(allowKeyboard);
    await _resizeOverlayWindow(
      width: _dialogWindowWidthDp,
      height: _dialogWindowHeightDp,
      enableDrag: false,
    );
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    super.dispose();
  }

  /// [Target 직접 입력]: 오버레이 안에서 이름/관계/메모/성향을 직접 입력해
  /// 현재 세션의 분석 Context로 사용합니다.
  Future<void> _handleEditTarget() async {
    setState(() => _isExpanded = false);

    await _prepareDialogWindow(allowKeyboard: true);
    if (!mounted) return;

    final target = await showDialog<ContactModel>(
      context: context,
      builder: (dialogContext) => OverlayTargetDialog(
        initialTarget: _targetContact,
      ),
    );

    await _setOverlayKeyboardMode(false);

    if (!mounted) return;
    if (target != null) {
      setState(() => _targetContact = target);
    }

    await _resizeOverlayWindow(
      width: _expandedWindowWidthDp,
      height: _expandedWindowHeightDp,
    );

    if (!mounted) return;
    setState(() => _isExpanded = true);
  }

  /// [Target 자동 감지]: 현재 화면을 실제로 캡처한 뒤 Vision 모델에 보내
  /// 대화 상대방 정보를 임시 Target으로 채웁니다.
  Future<void> _handleAutoDetectTarget() async {
    setState(() {
      _isExpanded = false;
      _isProcessing = true;
    });

    try {
      final base64Image = await _captureCurrentScreenForAi();
      final target = await _openRouterService.inferTargetFromScreenshot(
        base64Screenshot: base64Image,
      );

      if (!mounted) return;
      setState(() {
        _targetContact = target;
        _isProcessing = false;
        _isExpanded = true;
      });

      await _resizeOverlayWindow(
        width: _expandedWindowWidthDp,
        height: _expandedWindowHeightDp,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      await _showOverlayError(
        title: 'Target 자동 감지 실패',
        message: error.toString(),
      );
      await _collapseToIcon();
    }
  }

  /// [분석/추천 실행]: 현재 화면 캡처와 Target 정보를 OpenRouter Vision 모델에 전달합니다.
  Future<void> _handleAnalyze() async {
    setState(() {
      _isExpanded = false;
      _isProcessing = true;
    });

    try {
      final base64Image = await _captureCurrentScreenForAi();
      final target = _targetContact ??
          await _openRouterService.inferTargetFromScreenshot(
            base64Screenshot: base64Image,
          );

      if (mounted && _targetContact == null) {
        setState(() => _targetContact = target);
      }

      final replies = await _openRouterService.getChatRecommendations(
        base64Screenshot: base64Image,
        targetContact: target,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      await _prepareDialogWindow();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => RecommendationDialog(
          targetName: target.name,
          recommendations: replies,
        ),
      );

      await _collapseToIcon();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      await _showOverlayError(
        title: '화면 캡처 실패',
        message: '${error.toString()}\n\n'
            'SmartChat AI에서 화면 캡처 권한을 다시 허용한 뒤 오버레이를 켜주세요.',
      );
      await _collapseToIcon();
    }
  }

  /// [문철 실행]: 이미지 선택/과실 분석 다이얼로그를 시스템 오버레이 위에 띄웁니다.
  Future<void> _handleMoonchul() async {
    setState(() => _isExpanded = false);

    await _prepareDialogWindow();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MoonchulDialog(
        targetContact: _targetContact,
        openRouterService: _openRouterService,
      ),
    );

    await _collapseToIcon();
  }

  /// [나가기]: 요구사항대로 오버레이 메뉴만 닫고 기본 아이콘 상태로 되돌립니다.
  Future<void> _handleExit() {
    return _collapseToIcon();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isExpanded ? _buildExpandedMenu() : _buildFloatingIcon(),
          ),
        ),
      ),
    );
  }

  /// [기본 아이콘]: 시스템 오버레이가 접힌 상태에서 보이는 원형 버튼입니다.
  Widget _buildFloatingIcon() {
    return GestureDetector(
      onTap: _expandMenu,
      child: Container(
        key: const ValueKey('system-overlay-icon'),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF3F51B5),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: _isProcessing
            ? const Padding(
                padding: EdgeInsets.all(15),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white),
              )
            : const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 30),
      ),
    );
  }

  /// [확장 메뉴]: Target 설정 도구와 분석/추천, 문철, 나가기 액션을 제공합니다.
  Widget _buildExpandedMenu() {
    return Container(
      key: const ValueKey('system-overlay-menu'),
      width: 292,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF303F9F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTargetSummary(),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: _handleExit,
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onPressed: _isProcessing ? null : _handleEditTarget,
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('직접 입력', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onPressed: _isProcessing ? null : _handleAutoDetectTarget,
                  icon: const Icon(Icons.center_focus_strong, size: 16),
                  label: const Text('자동 감지', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3F51B5),
            ),
            onPressed: _isProcessing ? null : _handleAnalyze,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('분석 / 추천',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
            ),
            onPressed: _isProcessing ? null : _handleMoonchul,
            icon: const Icon(Icons.balance, size: 16),
            label:
                const Text('문철', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white30),
            ),
            onPressed: _handleExit,
            icon: const Icon(Icons.keyboard_arrow_left, size: 16),
            label: const Text('나가기'),
          ),
        ],
      ),
    );
  }

  /// [Target 요약]: 현재 분석 Context로 들어갈 상대방 정보를 메뉴 최상단에서 보여줍니다.
  ///
  /// 사용자가 직접 입력하거나 자동 감지한 값이 즉시 반영되어,
  /// 다음 분석/추천이 누구 기준으로 동작하는지 헷갈리지 않게 합니다.
  Widget _buildTargetSummary() {
    final target = _targetContact;
    if (target == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SmartChat AI',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Target 미지정 · 직접 입력 또는 자동 감지',
            style: TextStyle(color: Colors.white70, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target: ${target.name}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          target.relationship,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
