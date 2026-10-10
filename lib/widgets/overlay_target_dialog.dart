import 'package:flutter/material.dart';

import '../models/contact_model.dart';

/// [역할 설명]: 시스템 오버레이 안에서 임시 Target 정보를 직접 입력하는 다이얼로그입니다.
///
/// 홈/상대방 탭에 저장된 연락처를 쓰지 않고도, 사용자가 지금 보고 있는 대화 상대를
/// 즉석에서 이름/관계/메모/성향으로 입력할 수 있게 합니다.
/// 입력된 값은 현재 오버레이 세션의 분석 Context로 즉시 반영됩니다.
class OverlayTargetDialog extends StatefulWidget {
  final ContactModel? initialTarget;

  const OverlayTargetDialog({
    super.key,
    this.initialTarget,
  });

  @override
  State<OverlayTargetDialog> createState() => _OverlayTargetDialogState();
}

class _OverlayTargetDialogState extends State<OverlayTargetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _memoController;
  late final TextEditingController _personalityController;

  @override
  void initState() {
    super.initState();

    final target = widget.initialTarget;
    _nameController = TextEditingController(text: target?.name ?? '');
    _relationshipController =
        TextEditingController(text: target?.relationship ?? '');
    _memoController = TextEditingController(text: target?.memo ?? '');
    _personalityController =
        TextEditingController(text: target?.personality ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _memoController.dispose();
    _personalityController.dispose();
    super.dispose();
  }

  /// [저장 처리]: 폼 검증 후 ContactModel을 만들어 Navigator 결과로 돌려줍니다.
  ///
  /// 실제 저장소에는 쓰지 않고 오버레이의 임시 분석 Target으로만 반환합니다.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final target = ContactModel(
      id: widget.initialTarget?.id.isNotEmpty == true
          ? widget.initialTarget!.id
          : 'overlay_manual_$now',
      name: _nameController.text.trim(),
      relationship: _relationshipController.text.trim(),
      memo: _memoController.text.trim(),
      personality: _personalityController.text.trim().isEmpty
          ? '사용자가 오버레이에서 직접 입력한 임시 Target입니다.'
          : _personalityController.text.trim(),
      isAnalysisTarget: true,
    );

    Navigator.of(context).pop(target);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: Row(
        children: [
          const Icon(Icons.person_search_rounded, color: Color(0xFF5C6BC0)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Target 직접 입력',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '지금 보고 있는 대화 상대를 오버레이 분석 기준으로 임시 지정합니다.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Target 이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _relationshipController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '관계',
                  hintText: '예: 직장 상사, 친구, 썸, 고객',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.diversity_3_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '관계를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _memoController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '관계/상황 메모',
                  hintText: '예: 말투가 직설적임, 일정에 민감함',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _personalityController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'AI 성향 Context',
                  hintText: '비워두면 기본 설명이 들어갑니다.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.psychology_alt_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('적용'),
        ),
      ],
    );
  }
}
