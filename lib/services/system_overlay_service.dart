import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../models/contact_model.dart';
import 'screen_capture_service.dart';

/// [역할 설명]: 앱을 나갔을 때나 백그라운드, 다른 앱(카카오톡, 인스타그램 등) 위에서도
/// 플로팅 오버레이 위젯이 계속 떠있도록 Android System Alert Window(WindowManager)를 제어하는 서비스입니다.
/// flutter_overlay_window 패키지를 래핑하여 권한 검사, 권한 요청, 오버레이 표시 및 종료를 전담합니다.
class SystemOverlayService {
  /// [초기 오버레이 크기]: showOverlay가 양수 크기를 Android px 단위로 해석하기 때문에
  /// 너무 작은 60~90 값을 바로 넣으면 고해상도 태블릿에서 아이콘이 거의 보이지 않을 수 있습니다.
  /// 그래서 처음 생성할 때는 여유 있는 px 크기로 띄우고, 실제 UI 안에서 접힘/펼침 상태에 맞춰
  /// resizeOverlay(dp 기반)를 다시 호출해 기기 밀도에 자연스럽게 맞춥니다.
  static const int _initialOverlayWindowPx = 180;

  /// 1. '다른 앱 위에 표시(SYSTEM_ALERT_WINDOW)' 권한 허용 여부 확인
  static Future<bool> isPermissionGranted() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// 2. 시스템 오버레이 권한 요청 (안드로이드 시스템 설정 화면으로 이동)
  static Future<bool?> requestPermission() async {
    return await FlutterOverlayWindow.requestPermission();
  }

  /// 3. 시스템 백그라운드 오버레이 표시 (앱을 닫아도 계속 유지됨)
  ///
  /// 권한 거부 또는 플러그인 오류가 발생하면 false를 반환하여 UI 스위치 상태를 되돌릴 수 있게 합니다.
  static Future<bool> showSystemOverlay({required ContactModel target}) async {
    final bool granted = await isPermissionGranted();
    if (!granted) {
      final bool? requested = await requestPermission();
      if (requested != true) return false;
    }

    try {
      // [재시작 안정화]: 이미 떠 있는 오버레이가 이전 빌드/이전 타겟 상태로 살아 있으면
      // 새 엔진이 생성되지 않아 사용자가 Google 등 다른 앱으로 나갔을 때 변화가 없어 보일 수 있습니다.
      // 따라서 켤 때마다 기존 서비스를 한 번 정리하고 최신 Target 데이터로 다시 생성합니다.
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 180));
      }

      // 시스템 오버레이 윈도우 생성 (플러그인은 main.dart의 overlayMain 진입점을 호출)
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'SmartChat AI 어시스턴트',
        overlayContent: '실시간 대화 코칭 및 문철 오버레이 동작 중',
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerLeft,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: _initialOverlayWindowPx,
        width: _initialOverlayWindowPx,
      );

      // [캡처 채널 연결]: 시스템 오버레이는 별도 FlutterEngine이므로,
      // showOverlay로 엔진이 준비된 직후 앱 전용 screen_capture MethodChannel을 추가 등록합니다.
      // 이 과정을 거쳐야 Google/카카오톡 위 오버레이의 "분석/추천" 버튼이 실제 화면 캡처를 호출할 수 있습니다.
      await Future.delayed(const Duration(milliseconds: 260));
      await ScreenCaptureService.registerOverlayCaptureChannel();

      // 활성화된 타겟 상대방 정보를 오버레이 프로세스로 공유
      await FlutterOverlayWindow.shareData(target.toJson());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 4. 시스템 오버레이 닫기
  static Future<void> closeSystemOverlay() async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  /// 5. 활성 타겟 정보 변경 시 백그라운드 오버레이로 실시간 동기화
  static Future<void> updateTarget(ContactModel target) async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.shareData(target.toJson());
    }
  }
}
