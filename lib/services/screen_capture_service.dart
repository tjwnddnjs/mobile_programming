import 'package:flutter/services.dart';

/// [역할 설명]: 실제 화면 캡처가 필요한 기능에서 네이티브 캡처 실패를 명확히 전달하는 예외입니다.
///
/// 기존에는 캡처 실패 시 1x1 투명 PNG로 폴백해 UI 흐름만 유지했지만,
/// 오버레이 분석/추천처럼 "반드시 현재 화면을 읽어야 하는" 기능에서는 실패를 숨기면
/// 사용자가 AI가 화면을 봤는지 알 수 없습니다. 그래서 strict 모드에서 이 예외를 던집니다.
class ScreenCaptureException implements Exception {
  final String message;

  const ScreenCaptureException(this.message);

  @override
  String toString() => message;
}

/// [역할 설명]: "분석/추천" 실행 시 현재 화면 이미지를 Base64 PNG로 가져오는 네이티브 브릿지입니다.
///
/// Android에서는 MethodChannel을 통해 MainActivity/ScreenCaptureForegroundService의
/// MediaProjection 캡처 메서드를 호출합니다.
/// 사용자가 Android 화면 캡처 동의를 거부하거나 네이티브 구현이 없는 환경에서는
/// 투명 1px PNG를 반환해 API 흐름이 끊기지 않도록 했습니다.
class ScreenCaptureService {
  static const MethodChannel _channel =
      MethodChannel('com.smartchat.ai/screen_capture');

  /// [권한 준비]: 실제 Google/카카오톡/인스타그램 화면을 캡처하려면 Android의 MediaProjection
  /// 사용자 동의가 필요합니다. 이 메서드는 오버레이를 켜기 직전에 호출되어 시스템 동의 창을 띄우고,
  /// 동의가 끝나면 Android foreground service가 캡처 세션을 보관하게 합니다.
  ///
  /// 반환값이 false면 사용자가 동의를 거부했거나 현재 플랫폼에서 캡처 기능을 사용할 수 없다는 뜻입니다.
  static Future<bool> ensureScreenCapturePermission() async {
    try {
      return await _channel
              .invokeMethod<bool>('requestScreenCapturePermission') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// [오버레이 엔진 채널 등록]: flutter_overlay_window는 별도 FlutterEngine을 사용합니다.
  ///
  /// 앱 전용 MethodChannel은 pubspec 플러그인이 아니므로 자동 등록 대상이 아닙니다.
  /// 메인 앱에서 시스템 오버레이를 띄운 직후 이 메서드를 호출하면,
  /// Android MainActivity가 캐시된 오버레이 엔진에도 captureScreen 채널을 붙여 줍니다.
  static Future<bool> registerOverlayCaptureChannel() async {
    try {
      return await _channel
              .invokeMethod<bool>('registerOverlayCaptureChannel') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// [화면 캡처]: 네이티브 채널에서 Base64 PNG를 받아 반환합니다.
  ///
  /// 시스템 오버레이 엔진에서도 같은 채널명을 사용하므로, 분석/추천 버튼은 현재 앱이 아닌
  /// 실제 스마트폰 화면 전체를 캡처하려고 시도합니다.
  static Future<String> captureScreenAsBase64({
    bool allowFallback = true,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('captureScreen');
      if (result != null && result.isNotEmpty) {
        return result;
      }
    } on PlatformException catch (error) {
      if (!allowFallback) {
        throw ScreenCaptureException(
          error.message ?? '네이티브 화면 캡처 중 오류가 발생했습니다.',
        );
      }
    } on MissingPluginException {
      if (!allowFallback) {
        throw const ScreenCaptureException(
          '오버레이 엔진에 화면 캡처 채널이 아직 연결되지 않았습니다.',
        );
      }
    }

    if (!allowFallback) {
      throw const ScreenCaptureException(
        '현재 화면 이미지를 가져오지 못했습니다. 화면 캡처 권한을 다시 허용해주세요.',
      );
    }

    return transparentPngBase64;
  }

  /// [폴백 여부 확인]: 테스트/디버깅에서 AI에 실제 화면이 들어갔는지 빠르게 구분하기 위한 유틸입니다.
  static bool isFallbackImage(String base64Image) {
    return base64Image == transparentPngBase64;
  }

  /// [폴백 이미지]: OpenRouter Vision payload 형식을 유지하기 위한 1x1 투명 PNG입니다.
  static const String transparentPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
}
