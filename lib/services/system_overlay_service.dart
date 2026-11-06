// lib/services/system_overlay_service.dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../models/contact_model.dart';

/// [역할 설명]: 앱을 나갔을 때나 백그라운드, 다른 앱(카카오톡, 인스타그램 등) 위에서도
/// 플로팅 오버레이 위젯이 계속 떠있도록 Android System Alert Window(WindowManager)를 제어하는 서비스입니다.
/// flutter_overlay_window 패키지를 래핑하여 권한 검사, 권한 요청, 오버레이 표시 및 종료를 전담합니다.
class SystemOverlayService {
  /// 1. '다른 앱 위에 표시(SYSTEM_ALERT_WINDOW)' 권한 허용 여부 확인
  static Future<bool> isPermissionGranted() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// 2. 시스템 오버레이 권한 요청 (안드로이드 시스템 설정 화면으로 이동)
  static Future<bool?> requestPermission() async {
    return await FlutterOverlayWindow.requestPermission();
  }

  /// 3. 시스템 백그라운드 오버레이 표시 (앱을 닫아도 계속 유지됨)
  static Future<bool> showSystemOverlay({required ContactModel target}) async {
    final bool granted = await isPermissionGranted();
    if (!granted) {
      final bool? requested = await requestPermission();
      if (requested != true) return false;
    }

    await const MethodChannel('com.smartchat.ai/overlay_setup').invokeMethod<void>('prepare');

    // showOverlay uses physical pixels; resizeOverlay uses logical pixels.
    final size = (76 * WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).round();

    // 시스템 오버레이 윈도우 생성 (entryPoint: overlayMain)
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'SmartChat AI 어시스턴트',
      overlayContent: '실시간 대화 코칭 및 문철 오버레이 동작 중',
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.centerLeft,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: size,
      width: size,
    );

    // 활성화된 타겟 상대방 정보를 오버레이 프로세스로 공유
    await FlutterOverlayWindow.shareData(target.toJson());
    return true;
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
