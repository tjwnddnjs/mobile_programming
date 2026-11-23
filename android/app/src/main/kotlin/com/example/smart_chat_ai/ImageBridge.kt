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
                if (pending != null) { result.error("busy", "An image request is already in progress.", null); return@setMethodCallHandler }
                pending = result
                try {
                    context.startActivity(Intent(context, ImageBridgeActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        .putExtra("operation", call.method))
                } catch (e: Exception) { fail("launch_failed", "Could not start the image request.") }
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
                startActivityForResult(Intent.createChooser(picker, "Choose images"), 2)
            }
        } catch (e: Exception) { ImageBridge.fail("launch_failed", "Could not open the system picker."); finish() }
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
            } catch (e: Exception) { ImageBridge.fail("capture_failed", "Could not start screen capture.") }
            finish()
        } else if (requestCode == 2) {
            val uris = if (data.clipData != null) {
                (0 until data.clipData!!.itemCount).map { data.clipData!!.getItemAt(it).uri }
            } else listOfNotNull(data.data)
            val multiple = intent.getStringExtra("operation") == "pickImages"
            Thread {
                try {
                    val images = uris.map { uri ->
                        // 원본 PNG 여러 장은 Base64 변환 후 서버 요청 한도를 초과합니다.
                        // 디코딩 전 크기를 확인하여 태블릿 메모리를 보호하고, JPEG로 전송합니다.
                        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it, null, bounds) }
                        val options = BitmapFactory.Options().apply {
                            inSampleSize = 1
                            while (maxOf(bounds.outWidth, bounds.outHeight) / inSampleSize > 3200) inSampleSize *= 2
                        }
                        val bitmap = contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it, null, options) }
                            ?: throw IllegalArgumentException()
                        var working = bitmap
                        try {
                            val scale = minOf(1.0, 2000.0 / maxOf(bitmap.width, bitmap.height))
                            if (scale < 1.0) working = Bitmap.createScaledBitmap(bitmap,
                                maxOf(1, (bitmap.width * scale).toInt()), maxOf(1, (bitmap.height * scale).toInt()), true)
                            // 장당 450KB 이하로 제한해 5장도 Base64 포함 약 3MB 이내로 유지합니다.
                            var quality = 88
                            var encoded: ByteArray
                            while (true) {
                                encoded = ByteArrayOutputStream().use { out ->
                                    working.compress(Bitmap.CompressFormat.JPEG, quality, out)
                                    out.toByteArray()
                                }
                                if (encoded.size <= 450_000) break
                                if (quality > 58) { quality -= 10; continue }
                                if (minOf(working.width, working.height) < 300) {
                                    throw IllegalArgumentException("Could not reduce the image size.")
                                }
                                val smaller = Bitmap.createScaledBitmap(working,
                                    maxOf(1, working.width * 4 / 5), maxOf(1, working.height * 4 / 5), true)
                                if (working !== bitmap) working.recycle()
                                working = smaller
                                quality = 80
                            }
                            Base64.encodeToString(encoded, Base64.NO_WRAP)
                        } finally {
                            if (working !== bitmap) working.recycle()
                            bitmap.recycle()
                        }
                    }
                    // URI 임시 읽기 권한을 유지하려면 모든 사진 처리가 끝난 뒤 Activity를 종료합니다.
                    runOnUiThread {
                        ImageBridge.success(if (multiple) images else images.firstOrNull())
                        finish()
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        ImageBridge.fail("image_failed", "Could not read the selected images. Download them to this device and try again.")
                        finish()
                    }
                }
            }.start()
        }
    }
}
