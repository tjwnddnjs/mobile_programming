import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/contact_model.dart';
import '../models/moonchul_model.dart';
import '../services/openrouter_service.dart';

/// [역할 설명]: "문철" 기능을 수행하는 이미지 선택 및 결과 렌더링 다이얼로그입니다.
///
/// 사용자는 갤러리에서 여러 장을 고르거나 카메라로 추가 촬영할 수 있고,
/// 선택한 이미지들은 Base64로 인코딩되어 OpenRouter Vision 모델에 전달됩니다.
class MoonchulDialog extends StatefulWidget {
  final ContactModel? targetContact;
  final OpenRouterService openRouterService;

  const MoonchulDialog({
    super.key,
    this.targetContact,
    required this.openRouterService,
  });

  @override
  State<MoonchulDialog> createState() => _MoonchulDialogState();
}

class _MoonchulDialogState extends State<MoonchulDialog> {
  final ImagePicker _picker = ImagePicker();

  List<XFile> _selectedImages = [];
  bool _isLoading = false;
  MoonchulResult? _result;

  /// [갤러리 선택]: 여러 장의 대화 캡처를 한 번에 첨부합니다.
  ///
  /// 기존 선택 이미지를 덮어쓰지 않고 뒤에 붙여, 카메라 촬영 이미지와 함께 분석할 수 있게 합니다.
  Future<void> _pickImagesFromGallery() async {
    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() => _selectedImages = [..._selectedImages, ...images]);
  }

  /// [카메라 촬영]: 방금 촬영한 이미지 한 장을 분석 목록에 추가합니다.
  Future<void> _pickImageFromCamera() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _selectedImages = [..._selectedImages, image]);
  }

  /// [이미지 제거]: 사용자가 잘못 선택한 사진을 분석 전 목록에서 제외합니다.
  void _removeImageAt(int index) {
    setState(() {
      _selectedImages = [
        ..._selectedImages.take(index),
        ..._selectedImages.skip(index + 1),
      ];
    });
  }

  /// [분석 실행]: 선택된 이미지들을 Base64로 변환한 뒤 OpenRouterService에 전달합니다.
  ///
  /// 네트워크 실패 또는 API 키 미설정은 서비스의 폴백 결과로 처리되어 UI가 중단되지 않습니다.
  Future<void> _runAnalysis() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('분석할 대화 캡처 사진을 1장 이상 선택해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final base64Images = <String>[];
      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        base64Images.add(base64Encode(bytes));
      }

      final result = await widget.openRouterService.analyzeMoonchulFault(
        base64Images: base64Images,
        targetContact: widget.targetContact,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _result = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 분석 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DialogHeader(onClose: () => Navigator.pop(context)),
                const Divider(height: 16),
                if (_result == null)
                  _buildPickerStep()
                else
                  _MoonchulResultView(result: _result!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// [1단계 UI]: 이미지 선택과 분석 시작 버튼을 보여줍니다.
  Widget _buildPickerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '대화 캡처 사진을 첨부하면 AI가 양측의 과실 비율과 맥락을 객관적으로 분석합니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _pickImagesFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('갤러리'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _pickImageFromCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('카메라'),
              ),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SelectedImageList(
            images: _selectedImages,
            onRemove: _removeImageAt,
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _runAnalysis,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('과실 비율 분석 시작 (${_selectedImages.length}장)'),
        ),
      ],
    );
  }
}

/// [역할 설명]: 문철 다이얼로그 상단 제목과 닫기 버튼을 렌더링합니다.
class _DialogHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _DialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.balance, color: Colors.redAccent, size: 24),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '문철 대화 과실 진단',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// [역할 설명]: 선택된 이미지 파일 이름 목록과 제거 버튼을 보여줍니다.
///
/// 썸네일 디코딩 없이 파일명만 표시해 다이얼로그가 가볍게 유지되도록 했습니다.
class _SelectedImageList extends StatelessWidget {
  final List<XFile> images;
  final ValueChanged<int> onRemove;

  const _SelectedImageList({
    required this.images,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var index = 0; index < images.length; index++)
            ListTile(
              dense: true,
              leading: const Icon(Icons.image_outlined, size: 18),
              title: Text(
                images[index].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => onRemove(index),
              ),
            ),
        ],
      ),
    );
  }
}

/// [역할 설명]: 문철 분석 완료 후 과실 비율과 객관적 분석 문장을 렌더링합니다.
class _MoonchulResultView extends StatelessWidget {
  final MoonchulResult result;

  const _MoonchulResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final myFlex = result.myRatio <= 0 ? 1 : result.myRatio;
    final otherFlex = result.otherRatio <= 0 ? 1 : result.otherRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '나 : ${result.myRatio}%',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
            ),
            Text(
              '상대방 : ${result.otherRatio}%',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // [비율 게이지]: 두 Expanded flex가 0이 되지 않게 보정하여 런타임 assert를 방지합니다.
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: myFlex,
                child: Container(height: 16, color: Colors.blue),
              ),
              Expanded(
                flex: otherFlex,
                child: Container(height: 16, color: Colors.redAccent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AnalysisBox(
          title: '내 대화 방식의 아쉬운 점',
          text: result.myFaultAnalysis,
          color: Colors.blue,
          backgroundColor: Colors.blue.shade50,
        ),
        const SizedBox(height: 10),
        _AnalysisBox(
          title: '상대방 대화 방식의 아쉬운 점',
          text: result.otherFaultAnalysis,
          color: Colors.redAccent,
          backgroundColor: Colors.red.shade50,
        ),
        const SizedBox(height: 10),
        _AnalysisBox(
          title: '서로 보완해야 할 점',
          text: result.reconciliationAdvice,
          color: Colors.amber.shade800,
          backgroundColor: Colors.amber.shade50,
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
    );
  }
}

/// [역할 설명]: 분석 결과 문장들을 색상별 박스로 일관되게 보여주는 위젯입니다.
class _AnalysisBox extends StatelessWidget {
  final String title;
  final String text;
  final Color color;
  final Color backgroundColor;

  const _AnalysisBox({
    required this.title,
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }
}
