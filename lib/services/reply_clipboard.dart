import 'package:flutter/services.dart';

Future<void> copyReply(String text, {required bool isSystemOverlay}) {
  // The overlay engine runs without a FlutterActivity to handle SystemChannels.platform.
  if (isSystemOverlay) {
    return const MethodChannel('com.smartchat.ai/overlay_clipboard')
        .invokeMethod<void>('copyReply', text);
  }
  return Clipboard.setData(ClipboardData(text: text));
}
