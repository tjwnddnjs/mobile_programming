package com.smartchat.ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Base64
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.io.ByteArrayOutputStream

/**
 * [역할 설명]: 다른 앱 위에 떠 있는 오버레이에서 "분석/추천"을 누를 때
 * 실제 현재 스마트폰 화면을 캡처하기 위한 Android foreground service입니다.
 *
 * [왜 service가 필요한가]: Android는 카카오톡, 인스타그램, Google 같은 다른 앱 화면을 임의로 읽지 못하게 막습니다.
 * 사용자가 MediaProjection 동의 창에서 허용해야 하고, 앱은 foreground service 상태에서 그 권한을 사용해야 합니다.
 * 이 service는 동의 결과로 생성한 MediaProjection을 보관하고, Dart MethodChannel 요청이 들어올 때마다
 * 단발성 VirtualDisplay + ImageReader를 만들어 PNG Base64를 반환합니다.
 */
class ScreenCaptureForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * [service 시작]: MainActivity가 사용자 동의 결과를 넘겨주면 foreground notification을 먼저 띄우고,
     * MediaProjectionManager를 통해 실제 projection 객체를 생성합니다.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startAsForegroundService()

        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, RESULT_CODE_EMPTY) ?: RESULT_CODE_EMPTY
        val resultData = getResultData(intent)

        if (resultCode != RESULT_CODE_EMPTY && resultData != null && mediaProjection == null) {
            val projectionManager =
                getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, resultData)
            registerProjectionCallbackIfNeeded()
        }

        return START_STICKY
    }

    /**
     * [종료 정리]: 사용자가 앱을 끄거나 OS가 service를 종료할 때 projection 자원을 해제합니다.
     */
    override fun onDestroy() {
        mediaProjection?.stop()
        mediaProjection = null
        projectionCallbackRegistered = false
        super.onDestroy()
    }

    /**
     * [알림 채널 생성]: Android O 이상에서는 foreground service 알림 채널이 필수입니다.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "SmartChat 화면 캡처",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "오버레이 분석을 위해 현재 화면 캡처 권한을 유지합니다."
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    /**
     * [foreground 전환]: MediaProjection service type을 명시해 Android 10+ 정책을 만족시킵니다.
     */
    private fun startAsForegroundService() {
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    /**
     * [상태 알림]: 화면 캡처 권한이 유지 중임을 사용자에게 투명하게 보여줍니다.
     */
    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("SmartChat AI 화면 분석 준비 중")
            .setContentText("오버레이에서 현재 화면을 캡처해 AI 추천에 사용할 수 있습니다.")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "smart_chat_screen_capture"
        private const val NOTIFICATION_ID = 4821
        private const val EXTRA_RESULT_CODE = "extra_result_code"
        private const val EXTRA_RESULT_DATA = "extra_result_data"
        private const val RESULT_CODE_EMPTY = -1000
        private const val CAPTURE_TIMEOUT_MS = 2500L
        private const val FRAME_POLL_INTERVAL_MS = 90L
        private const val TAG = "SmartChatCapture"

        @Volatile
        private var mediaProjection: MediaProjection? = null

        @Volatile
        private var projectionCallbackRegistered = false

        /**
         * [service 시작 진입점]: MainActivity의 권한 결과를 받아 service를 foreground로 실행합니다.
         *
         * Android O 이상에서는 background service 제한을 피하기 위해 startForegroundService를 사용합니다.
         */
        fun startProjectionService(
            context: Context,
            resultCode: Int,
            resultData: Intent
        ) {
            val intent = Intent(context, ScreenCaptureForegroundService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, resultData)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /**
         * [권한 준비 상태]: 이미 projection을 들고 있으면 오버레이를 다시 켤 때 동의 창을 반복하지 않습니다.
         */
        fun hasActiveProjection(): Boolean = mediaProjection != null

        /**
         * [현재 화면 캡처]: MediaProjection으로 실제 디스플레이 프레임을 읽어 PNG Base64로 변환합니다.
         *
         * 단발성 캡처이므로 VirtualDisplay와 ImageReader를 매 요청마다 만들고 즉시 해제합니다.
         * 이렇게 하면 지속 캡처보다 리소스를 덜 사용하고, 오버레이 분석 버튼을 눌렀을 때의 화면만 가져옵니다.
         */
        fun captureScreenAsBase64(context: Context): String? {
            val projection = mediaProjection ?: return null
            registerProjectionCallbackIfNeeded()

            val metrics = currentDisplayMetrics(context)
            val width = metrics.widthPixels.coerceAtLeast(1)
            val height = metrics.heightPixels.coerceAtLeast(1)
            val densityDpi = metrics.densityDpi

            val captureThread = HandlerThread("SmartChatScreenCapture").apply { start() }
            val captureHandler = Handler(captureThread.looper)
            val imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
            var virtualDisplay: VirtualDisplay? = null

            return try {
                virtualDisplay = projection.createVirtualDisplay(
                    "SmartChatScreenCapture",
                    width,
                    height,
                    densityDpi,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                    imageReader.surface,
                    null,
                    captureHandler
                )

                val image = waitForNextImage(imageReader)
                if (image == null) {
                    Log.w(TAG, "No frame arrived from MediaProjection within timeout.")
                    return null
                }

                image.use { encodeImageToBase64Png(it, width, height) }
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to capture current screen.", error)
                null
            } finally {
                virtualDisplay?.release()
                imageReader.close()
                captureThread.quitSafely()
            }
        }

        /**
         * [프레임 대기]: VirtualDisplay를 만든 직후에는 ImageReader 큐가 아직 비어 있을 수 있습니다.
         * Lenovo Tab M8처럼 저사양/중저가 기기에서는 첫 프레임 도착이 조금 늦어지므로,
         * 즉시 acquireLatestImage를 한 번만 호출하지 않고 짧게 반복 확인합니다.
         */
        private fun waitForNextImage(imageReader: ImageReader): Image? {
            val deadline = System.currentTimeMillis() + CAPTURE_TIMEOUT_MS
            var latestImage: Image? = null

            while (System.currentTimeMillis() < deadline) {
                val nextImage = imageReader.acquireLatestImage()
                if (nextImage != null) {
                    latestImage?.close()
                    latestImage = nextImage
                }

                if (latestImage != null) return latestImage
                Thread.sleep(FRAME_POLL_INTERVAL_MS)
            }

            return latestImage
        }

        /**
         * [디스플레이 크기 계산]: 태블릿/폰 회전 상태와 실제 해상도를 반영해 ImageReader 크기를 정합니다.
         */
        private fun currentDisplayMetrics(context: Context): DisplayMetrics {
            val metrics = DisplayMetrics()
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(metrics)

            return metrics
        }

        /**
         * [Projection callback 등록]: Android 14부터는 callback 없이 createVirtualDisplay를 호출하면
         * 보안 예외가 발생할 수 있어, projection 생명주기 콜백을 한 번 등록합니다.
         */
        private fun registerProjectionCallbackIfNeeded() {
            val projection = mediaProjection ?: return
            if (projectionCallbackRegistered) return

            val callbackThread = HandlerThread("SmartChatProjectionCallback").apply { start() }
            projection.registerCallback(
                object : MediaProjection.Callback() {
                    override fun onStop() {
                        mediaProjection = null
                        projectionCallbackRegistered = false
                        callbackThread.quitSafely()
                    }
                },
                Handler(callbackThread.looper)
            )
            projectionCallbackRegistered = true
        }

        /**
         * [Image 변환]: ImageReader가 주는 RGBA 버퍼는 rowPadding이 붙을 수 있습니다.
         * 먼저 padded bitmap에 복사한 뒤 실제 화면 크기로 잘라 PNG로 압축합니다.
         */
        private fun encodeImageToBase64Png(
            image: Image,
            width: Int,
            height: Int
        ): String {
            val plane = image.planes.first()
            val buffer = plane.buffer
            val pixelStride = plane.pixelStride
            val rowStride = plane.rowStride
            val rowPadding = rowStride - pixelStride * width
            val paddedWidth = width + rowPadding / pixelStride

            val paddedBitmap = Bitmap.createBitmap(
                paddedWidth,
                height,
                Bitmap.Config.ARGB_8888
            )
            paddedBitmap.copyPixelsFromBuffer(buffer)

            val croppedBitmap = Bitmap.createBitmap(paddedBitmap, 0, 0, width, height)
            val outputStream = ByteArrayOutputStream()
            croppedBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)

            paddedBitmap.recycle()
            croppedBitmap.recycle()

            return Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
        }

        /**
         * [Intent 호환 처리]: getParcelableExtra 제네릭 시그니처가 Android 13부터 바뀌어
         * API 버전에 맞춰 안전하게 화면 캡처 권한 Intent를 꺼냅니다.
         */
        private fun getResultData(intent: Intent?): Intent? {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent?.getParcelableExtra(EXTRA_RESULT_DATA)
            }
        }
    }
}
