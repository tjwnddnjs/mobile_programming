package com.smartchat.ai

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * [역할 설명]: Flutter 앱의 Android 진입 Activity입니다.
 *
 * 이 클래스는 Dart의 ScreenCaptureService와 Android MediaProjection 사이를 연결합니다.
 * 사용자가 홈 화면에서 오버레이를 켤 때 requestScreenCapturePermission을 호출하면
 * Android 시스템 화면 캡처 동의 창을 띄우고, 동의 결과를 ScreenCaptureForegroundService에 넘깁니다.
 *
 * [왜 이렇게 작성했는가]: 시스템 오버레이는 메인 앱과 별도의 FlutterEngine에서 실행됩니다.
 * 따라서 MethodChannel을 메인 엔진에만 등록하면, Google/카톡 위의 오버레이 버튼에서 captureScreen을 호출할 때
 * MissingPluginException이 발생합니다. registerOverlayEngineChannelIfReady가 flutter_overlay_window의
 * 캐시 엔진에도 같은 채널을 붙여 오버레이에서도 동일한 네이티브 캡처 로직을 사용할 수 있게 합니다.
 */
class MainActivity : FlutterActivity() {
    private val screenCaptureChannelName = "com.smartchat.ai/screen_capture"
    private val overlayEngineCacheKey = "myCachedEngine"
    private val screenCaptureRequestCode = 7381

    private var pendingPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * [채널 등록]: FlutterEngine 생성 시 Dart와 Android를 잇는 MethodChannel을 연결합니다.
     *
     * super.configureFlutterEngine이 pubspec 플러그인을 먼저 등록하고,
     * 그 뒤 앱 전용 screen_capture 채널을 메인 엔진과 오버레이 캐시 엔진에 추가합니다.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        registerScreenCaptureChannel(flutterEngine)

        // flutter_overlay_window는 Activity 부착 과정에서 overlayMain용 캐시 엔진을 만듭니다.
        // 생성 타이밍이 기기마다 살짝 다를 수 있어 즉시 한 번, 다음 loop에서 한 번 더 등록합니다.
        registerOverlayEngineChannelIfReady()
        mainHandler.post { registerOverlayEngineChannelIfReady() }
        mainHandler.postDelayed({ registerOverlayEngineChannelIfReady() }, 600)
    }

    /**
     * [권한 결과 복구]: Android가 캡처 동의 창을 띄우는 동안 Activity가 재생성될 수 있으므로
     * savedInstanceState가 null이 아니어도 기본 FlutterActivity 생명주기를 그대로 유지합니다.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    /**
     * [오버레이 엔진 채널 등록]: flutter_overlay_window 내부 캐시 엔진에 screen_capture 채널을 붙입니다.
     *
     * 캐시 키는 해당 플러그인의 OverlayConstants.CACHED_TAG 값과 동일합니다.
     * 상수 필드가 package-private이라 직접 import할 수 없어 문자열 값을 사용합니다.
     */
    private fun registerOverlayEngineChannelIfReady(): Boolean {
        val overlayEngine = FlutterEngineCache.getInstance().get(overlayEngineCacheKey) ?: return false
        registerScreenCaptureChannel(overlayEngine)
        return true
    }

    /**
     * [MethodChannel 처리]: Dart에서 요청하는 두 가지 작업을 처리합니다.
     *
     * - requestScreenCapturePermission: Android 시스템 동의 창을 열고 foreground service를 준비합니다.
     * - registerOverlayCaptureChannel: 별도 오버레이 엔진에도 같은 채널을 뒤늦게 연결합니다.
     * - captureScreen: 이미 준비된 MediaProjection service에서 현재 전체 화면을 PNG Base64로 가져옵니다.
     */
    private fun registerScreenCaptureChannel(engine: FlutterEngine) {
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            screenCaptureChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestScreenCapturePermission" -> requestScreenCapturePermission(result)
                "registerOverlayCaptureChannel" -> {
                    val registeredNow = registerOverlayEngineChannelIfReady()
                    if (registeredNow) {
                        result.success(true)
                    } else {
                        // showOverlay 직후 엔진 생성이 아직 끝나지 않은 기기를 위해 짧게 한 번 더 시도합니다.
                        mainHandler.postDelayed({
                            result.success(registerOverlayEngineChannelIfReady())
                        }, 250)
                    }
                }
                "captureScreen" -> captureCurrentDeviceScreen(result)
                else -> result.notImplemented()
            }
        }
    }

    /**
     * [화면 캡처 권한 요청]: MediaProjection은 사용자가 명시적으로 동의해야만 사용할 수 있습니다.
     *
     * 이미 ScreenCaptureForegroundService가 유효한 projection을 보관 중이면 동의 창을 반복해서 띄우지 않고
     * true를 바로 반환합니다. 그렇지 않으면 Android 시스템 동의 Activity를 실행합니다.
     */
    private fun requestScreenCapturePermission(result: MethodChannel.Result) {
        if (ScreenCaptureForegroundService.hasActiveProjection()) {
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "CAPTURE_PERMISSION_PENDING",
                "이미 화면 캡처 권한 요청이 진행 중입니다.",
                null
            )
            return
        }

        val projectionManager =
            getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        pendingPermissionResult = result
        startActivityForResult(
            projectionManager.createScreenCaptureIntent(),
            screenCaptureRequestCode
        )
    }

    /**
     * [권한 결과 처리]: 사용자가 화면 캡처를 허용하면 foreground service를 시작해 MediaProjection을 유지합니다.
     *
     * 오버레이 위에서 분석/추천을 여러 번 눌러도 매번 시스템 동의를 다시 받지 않도록,
     * 동의 결과 Intent는 service가 보관합니다.
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == screenCaptureRequestCode) {
            val pendingResult = pendingPermissionResult
            pendingPermissionResult = null

            if (resultCode == Activity.RESULT_OK && data != null) {
                ScreenCaptureForegroundService.startProjectionService(
                    context = this,
                    resultCode = resultCode,
                    resultData = data
                )
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    /**
     * [실제 캡처 실행]: MediaProjection capture는 ImageReader 대기 때문에 잠깐 블로킹될 수 있습니다.
     * Flutter platform thread를 멈추지 않도록 별도 Thread에서 처리하고 결과만 main thread로 돌려보냅니다.
     */
    private fun captureCurrentDeviceScreen(result: MethodChannel.Result) {
        Thread {
            val encoded = ScreenCaptureForegroundService.captureScreenAsBase64(this)

            mainHandler.post {
                if (encoded == null) {
                    result.error(
                        "CAPTURE_FAILED",
                        "화면 캡처 권한이 없거나 현재 화면 이미지를 가져오지 못했습니다.",
                        null
                    )
                } else {
                    result.success(encoded)
                }
            }
        }.start()
    }
}
