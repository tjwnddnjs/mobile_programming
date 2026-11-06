// lib/services/screen_capture_service.dart
import 'package:flutter/services.dart';

/// [역할 설명]: '분석/추천' 버튼 클릭 시 현재 안드로이드/기기 화면 전체를 캡처하는 네이티브 브릿지 서비스입니다.
/// 실제 기기에서는 Android MediaProjection API 또는 MethodChannel을 통해 캡처를 수행하며,
/// 테스트 및 에뮬레이터 환경에서는 안전한 샘플 Base64 비트맵 데이터를 공급합니다.
class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel('com.smartchat.ai/screen_capture');

  /// 화면 캡처 수행 후 PNG Base64 문자열 반환
  static Future<String> captureScreenAsBase64() async {
    try {
      final String? result = await _channel.invokeMethod<String>('captureScreen');
      if (result != null && result.isNotEmpty) {
        return result;
      }
    } on PlatformException {
      // 네이티브 채널이 연결되지 않은 경우(웹, 시뮬레이터) 투명 1px 샘플 Base64 반환
    }

    // 1x1 투명 PNG Base64 폴백
    return 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
  }
}
