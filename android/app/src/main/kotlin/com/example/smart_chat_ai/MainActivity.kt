package com.example.smart_chat_ai

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var overlayPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ImageBridge.register(flutterEngine, applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.smartchat.ai/overlay_setup")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestPermission") {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)) {
                        result.success(true)
                    } else if (overlayPermissionResult != null) {
                        result.error("busy", "Permission request already in progress", null)
                    } else {
                        overlayPermissionResult = result
                        try {
                            startActivityForResult(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")), 4812)
                        } catch (e: Exception) {
                            overlayPermissionResult = null
                            result.error("permission_settings", e.message, null)
                        }
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "prepare") { result.notImplemented(); return@setMethodCallHandler }
                val overlay = FlutterEngineCache.getInstance().get("myCachedEngine")
                if (overlay == null) result.error("overlay_unavailable", "Could not start the floating assistant.", null)
                else {
                    ImageBridge.register(overlay, applicationContext)
                    registerOverlayClipboard(overlay)
                    result.success(null)
                }
            }
    }

    private fun registerOverlayClipboard(engine: FlutterEngine) {
        val context = applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.smartchat.ai/overlay_clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "copyReply") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.arguments as? String
                if (text == null) {
                    result.error("invalid_reply", "Could not copy the reply.", null)
                    return@setMethodCallHandler
                }
                val clipboard = context.getSystemService(ClipboardManager::class.java)
                if (clipboard == null) {
                    result.error("clipboard_unavailable", "Could not open the Android clipboard.", null)
                    return@setMethodCallHandler
                }
                clipboard.setPrimaryClip(ClipData.newPlainText("SmartChat AI", text))
                result.success(null)
            }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 4812) {
            overlayPermissionResult?.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this))
            overlayPermissionResult = null
        }
    }
}
