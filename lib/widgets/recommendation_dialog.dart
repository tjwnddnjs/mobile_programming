// lib/widgets/recommendation_dialog.dart
import 'package:flutter/material.dart';
import '../services/reply_clipboard.dart';

/// [역할 설명]: '분석/추천' 결과로 수신한 3개의 추천 대화를 렌더링하는 다이얼로그입니다.
/// [확장성 설계]: 사용자가 추천 답장을 탭했을 때 단순히 클립보드에 복사하는 로직을
/// 별도의 독립 함수 [_handleApplyReply]로 분리하여 작성했습니다.
/// 향후 Android Accessibility Service나 자동 붙여넣기 기능 연동 시 이 함수 내부만 교체하면 됩니다.
class RecommendationDialog extends StatelessWidget {
  final String targetName;
  final List<String> recommendations;
  final bool isSystemOverlay;

  const RecommendationDialog({
    super.key,
    required this.targetName,
    required this.recommendations,
    this.isSystemOverlay = false,
  });

  /// [확장용 독립 함수]: 추천 대화 텍스트 적용 로직
  /// (현재: 기기 클립보드 복사 -> 향후: Accessibility Service 자동 타이핑 연결점)
  Future<void> _handleApplyReply(BuildContext context, String text) async {
    await copyReply(text, isSystemOverlay: isSystemOverlay);
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (!isSystemOverlay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply copied.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF5C6BC0)),
          const SizedBox(width: 8),
          Expanded(child: Text('Suggested replies for $targetName', style: const TextStyle(fontSize: 17))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tap a reply to copy it.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...recommendations.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final reply = entry.value;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF5C6BC0).withValues(alpha: 0.15),
                    child: Text('$idx', style: const TextStyle(color: Color(0xFF5C6BC0), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Text(reply, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.copy, size: 18, color: Color(0xFF5C6BC0)),
                  onTap: () => _handleApplyReply(context, reply),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
