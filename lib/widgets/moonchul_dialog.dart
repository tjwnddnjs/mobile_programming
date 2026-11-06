// lib/widgets/moonchul_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/screen_capture_service.dart';
import '../models/contact_model.dart';
import '../models/moonchul_model.dart';
import '../services/openrouter_service.dart';

/// [역할 설명]: '문철' 기능 실행 시 ImagePicker를 통해 갤러리/카메라 사진을 첨부하고,
/// OpenRouter Vision API로 전달하여 [과실 비율(나:상대방)], [각자의 잘못한 점], [보완점]을
/// 시각적 프로그레스 바와 함께 투명/모달 뷰로 객관적으로 렌더링하는 컴포넌트입니다.
class MoonchulDialog extends StatefulWidget {
  final ContactModel? targetContact;
  final OpenRouterService openRouterService;
  final bool isSystemOverlay;

  const MoonchulDialog({
    super.key,
    this.targetContact,
    required this.openRouterService,
    this.isSystemOverlay = false,
  });

  @override
  State<MoonchulDialog> createState() => _MoonchulDialogState();
}

class _MoonchulDialogState extends State<MoonchulDialog> {
  List<String> _selectedImages = [];
  bool _isLoading = false;
  MoonchulResult? _result;

  Future<void> _showError(String message) async {
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('확인'))],
    ));
  }

  /// 갤러리에서 복수 이미지 선택
  Future<void> _pickImages() async {
    var failed = false;
    try {
      if (widget.isSystemOverlay) await FlutterOverlayWindow.resizeOverlay(1, 1, false);
      final images = await ScreenCaptureService.pickImagesAsBase64();
      if (mounted && images != null && images.isNotEmpty) setState(() => _selectedImages = images);
    } catch (_) {
      failed = true;
    } finally {
      if (widget.isSystemOverlay) await FlutterOverlayWindow.resizeOverlay(340, 620, false);
    }
    if (failed && mounted) await _showError('사진 선택기를 열지 못했습니다.');
  }

  /// 선택된 사진들로 문철 과실 분석 수행
  Future<void> _runAnalysis() async {
    if (_selectedImages.isEmpty) {
      await _showError('분석할 대화 캡처 사진을 1장 이상 선택해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await widget.openRouterService.analyzeMoonchulFault(
        base64Images: _selectedImages, targetContact: widget.targetContact,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        await _showError(error is StateError ? error.message : '분석을 완료하지 못했습니다. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Row(
                children: [
                  const Icon(Icons.balance, color: Colors.redAccent, size: 24),
                  const SizedBox(width: 8),
                  const Text('문철 대화 과실 진단', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 16),

              if (_result == null) ...[
                // 1단계: 사진 선택 및 전송 화면
                const Text(
                  '대화 캡처 사진을 첨부하면 AI가 양측의 과실 비율과 맥락을 객관적으로 분석합니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: Text(_selectedImages.isEmpty ? '갤러리에서 사진 첨부 (여러 장 가능)' : '${_selectedImages.length}장의 사진 선택됨'),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _runAnalysis,
                  child: Text(_isLoading ? 'AI가 과실 비율 판정 중...' : '과실 비율 심판 시작'),
                ),
              ] else ...[
                // 2단계: 결과 렌더링 화면
                // 과실 비율 텍스트 및 프로그레스 바
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('나 : ${_result!.myRatio}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                    Text('상대방 : ${_result!.otherRatio}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),

                // 프로그레스 바 (과실 비율 게이지)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: _result!.myRatio,
                        child: Container(height: 16, color: Colors.blue),
                      ),
                      Expanded(
                        flex: _result!.otherRatio,
                        child: Container(height: 16, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 내 잘못 분석
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🔵 내 대화 방식의 아쉬운 점:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                      const SizedBox(height: 4),
                      Text(_result!.myFaultAnalysis, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 상대방 잘못 분석
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🔴 상대방 대화 방식의 아쉬운 점:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
                      const SizedBox(height: 4),
                      Text(_result!.otherFaultAnalysis, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 보완해야 할 점 (코멘트)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 봉합 및 개선 솔루션:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                      const SizedBox(height: 4),
                      Text(_result!.reconciliationAdvice, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인 완료'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
