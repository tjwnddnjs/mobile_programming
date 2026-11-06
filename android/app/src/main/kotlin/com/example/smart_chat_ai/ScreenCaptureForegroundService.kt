package com.example.smart_chat_ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Base64
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.ByteArrayOutputStream

class ScreenCaptureForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var done = false
    private val callback = object : MediaProjection.Callback() {
        override fun onStop() { finishCapture("capture_stopped", "화면 공유가 중단되었습니다.") }
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("screen_capture", "화면 캡처", NotificationManager.IMPORTANCE_LOW))
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "screen_capture") else Notification.Builder(this)
            startForeground(4580, builder.setSmallIcon(applicationInfo.icon).setContentTitle("화면 캡처 중").setContentText("화면을 분석할 사진으로 가져옵니다.").build())
            @Suppress("DEPRECATION")
            val data = intent?.getParcelableExtra<Intent>("data") ?: throw IllegalStateException()
            val pm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            projection = pm.getMediaProjection(intent?.getIntExtra("resultCode", 0) ?: 0, data)
            projection!!.registerCallback(callback, handler)
            handler.postDelayed({ startCapture() }, 600)
            handler.postDelayed({ finishCapture("capture_timeout", "화면 캡처 시간이 초과되었습니다.") }, 12000)
        } catch (e: Exception) { finishCapture("capture_failed", "화면 캡처 권한을 시작하지 못했습니다.") }
        return START_NOT_STICKY
    }
    @Suppress("DEPRECATION")
    private fun startCapture() {
        if (done) return
        try {
            val metrics = DisplayMetrics()
            (getSystemService(WINDOW_SERVICE) as WindowManager).defaultDisplay.getRealMetrics(metrics)
            val width = metrics.widthPixels
            val height = metrics.heightPixels
            reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
            reader!!.setOnImageAvailableListener({ source ->
                val image = try { source.acquireLatestImage() } catch (_: Exception) { null }
                if (image != null && !done) {
                    try {
                        val plane = image.planes[0]
                        val paddedWidth = width + (plane.rowStride - plane.pixelStride * width) / plane.pixelStride
                        val padded = Bitmap.createBitmap(paddedWidth, height, Bitmap.Config.ARGB_8888)
                        padded.copyPixelsFromBuffer(plane.buffer)
                        val bitmap = Bitmap.createBitmap(padded, 0, 0, width, height)
                        val bytes = ByteArrayOutputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, out); out.toByteArray() }
                        if (bitmap !== padded) bitmap.recycle()
                        padded.recycle()
                        image.close()
                        complete(Base64.encodeToString(bytes, Base64.NO_WRAP))
                    } catch (e: Exception) { image.close(); finishCapture("capture_failed", "캡처한 화면을 읽지 못했습니다.") }
                } else image?.close()
            }, handler)
            display = projection!!.createVirtualDisplay("SmartChatCapture", width, height, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, reader!!.surface, null, handler)
        } catch (e: Exception) { finishCapture("capture_failed", "화면을 캡처하지 못했습니다.") }
    }
    private fun complete(value: String) {
        if (done) return
        done = true
        ImageBridge.success(value)
        cleanup()
    }
    private fun finishCapture(code: String, message: String) {
        if (done) return
        done = true
        ImageBridge.fail(code, message)
        cleanup()
    }
    private fun cleanup() {
        handler.removeCallbacksAndMessages(null)
        display?.release(); display = null
        reader?.close(); reader = null
        projection?.unregisterCallback(callback)
        projection?.stop(); projection = null
        stopForeground(true)
        stopSelf()
    }
    override fun onDestroy() { if (!done) finishCapture("capture_stopped", "화면 캡처가 중단되었습니다."); super.onDestroy() }
}
