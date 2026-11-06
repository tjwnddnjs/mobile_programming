package com.example.smart_chat_ai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

object ImageBridge {
    private var pending: MethodChannel.Result? = null
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.smartchat.ai/screen_capture")
            .setMethodCallHandler { call, result ->
                if (call.method != "captureScreen" && call.method != "pickImage" && call.method != "pickImages") {
                    result.notImplemented(); return@setMethodCallHandler
                }
                if (pending != null) { result.error("busy", "이미 사진을 가져오는 중입니다.", null); return@setMethodCallHandler }
                pending = result
                try {
                    context.startActivity(Intent(context, ImageBridgeActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        .putExtra("operation", call.method))
                } catch (e: Exception) { fail("launch_failed", "사진 가져오기를 시작하지 못했습니다.") }
            }
    }
    fun success(value: Any?) { pending?.success(value); pending = null }
    fun fail(code: String, message: String) { pending?.error(code, message, null); pending = null }
}

class ImageBridgeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) return
        try {
            if (intent.getStringExtra("operation") == "captureScreen") {
                val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                startActivityForResult(manager.createScreenCaptureIntent(), 1)
            } else {
                val picker = Intent(Intent.ACTION_GET_CONTENT).apply { type = "image/*"; addCategory(Intent.CATEGORY_OPENABLE); putExtra(Intent.EXTRA_ALLOW_MULTIPLE, intent.getStringExtra("operation") == "pickImages") }
                startActivityForResult(Intent.createChooser(picker, "사진 선택"), 2)
            }
        } catch (e: Exception) { ImageBridge.fail("launch_failed", "시스템 선택 화면을 열지 못했습니다."); finish() }
    }
    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK || data == null) { ImageBridge.success(null); finish(); return }
        if (requestCode == 1) {
            try {
                val service = Intent(this, ScreenCaptureForegroundService::class.java)
                    .putExtra("resultCode", resultCode).putExtra("data", data)
                if (android.os.Build.VERSION.SDK_INT >= 26) startForegroundService(service) else startService(service)
            } catch (e: Exception) { ImageBridge.fail("capture_failed", "화면 캡처를 시작하지 못했습니다.") }
            finish()
        } else if (requestCode == 2) {
            val uris = if (data.clipData != null) {
                (0 until data.clipData!!.itemCount).map { data.clipData!!.getItemAt(it).uri }
            } else listOfNotNull(data.data)
            val multiple = intent.getStringExtra("operation") == "pickImages"
            finish()
            Thread {
                try {
                    val images = uris.map { uri ->
                        val bitmap = contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) }
                            ?: throw IllegalArgumentException()
                        val bytes = ByteArrayOutputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, out); out.toByteArray() }
                        bitmap.recycle()
                        Base64.encodeToString(bytes, Base64.NO_WRAP)
                    }
                    runOnUiThread { ImageBridge.success(if (multiple) images else images.firstOrNull()) }
                } catch (e: Exception) { runOnUiThread { ImageBridge.fail("image_failed", "선택한 사진을 읽지 못했습니다.") } }
            }.start()
        }
    }
}
