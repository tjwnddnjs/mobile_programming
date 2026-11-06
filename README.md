# SmartChat AI (System Overlay & AI Assistant v2.1)

스마트폰 백그라운드 및 다른 앱(카카오톡, 인스타그램 등) 위에서도 지속 동작하는 시스템 오버레이 플로팅 AI 어시스턴트입니다.

## 📌 백그라운드 오버레이 동작 원리
1. **SYSTEM_ALERT_WINDOW 권한**: 앱 실행 후 오버레이 스위치를 켜면 안드로이드 시스템 '다른 앱 위에 표시' 권한을 검사하고 허용을 요청합니다.
2. **독립된 오버레이 진입점 (`overlayMain`)**: `@pragma('vm:entry-point') void overlayMain()`으로 선언되어 앱 Activity가 백그라운드로 내려가거나 종료되어도 Android WindowManager 위에서 플로팅 위젯이 독립적으로 살아있습니다.
3. **상대방 컨텍스트 동기화**: `FlutterOverlayWindow.shareData()`를 통해 메인 앱에서 지정한 Target(성향, 메모) 정보가 백그라운드 오버레이 프로세스로 실시간 전달됩니다.

## 🚀 3대 오버레이 기능
- **분석 / 추천**: 현재 스마트폰 화면 캡처 + Target 성향 -> OpenRouter Vision API -> 3개 추천 답장 (탭 시 클립보드 복사)
- **문철 (과실 분석)**: 갤러리 복수 사진 선택 -> 나 : 상대방 과실 비율(예: 30 : 70) 및 원인 분석 렌더링
- **나가기**: 오버레이 메뉴 닫기 또는 오버레이 프로세스 종료
