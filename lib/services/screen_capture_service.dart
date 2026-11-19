import 'package:flutter/services.dart';

class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel('com.smartchat.ai/screen_capture');
  static Future<String?> captureScreenAsBase64() => _channel.invokeMethod<String>('captureScreen');
  static Future<List<String>?> pickImagesAsBase64() async =>
      (await _channel.invokeListMethod<String>('pickImages'));
  static Future<String?> pickImageAsBase64() => _channel.invokeMethod<String>('pickImage');
}
