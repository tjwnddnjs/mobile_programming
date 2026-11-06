package com.example.smart_chat_ai

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ImageBridge.register(flutterEngine, applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.smartchat.ai/overlay_setup")
            .setMethodCallHandler { call, result ->
                if (call.method != "prepare") { result.notImplemented(); return@setMethodCallHandler }
                val overlay = FlutterEngineCache.getInstance().get("myCachedEngine")
                if (overlay == null) result.error("overlay_unavailable", "오버레이 엔진을 시작하지 못했습니다.", null)
                else { ImageBridge.register(overlay, applicationContext); result.success(null) }
            }
    }
}
