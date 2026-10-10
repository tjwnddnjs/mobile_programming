import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import '../services/openrouter_service.dart';
import '../services/system_overlay_service.dart';

/// [역할 설명]: 상대방(Target) 추가/수정에 공통으로 쓰이는 입력 다이얼로그를 띄우는 함수입니다.
///
/// ContactsScreen과 ContactDetailScreen이 같은 폼을 사용하므로,
/// 필드 구조와 저장 로직이 화면마다 달라지는 문제를 방지합니다.
Future<ContactModel?> showContactEditorDialog(
  BuildContext context, {
  ContactModel? contact,
}) {
  return showDialog<ContactModel>(
    context: context,
    builder: (dialogContext) => ContactEditorDialog(contact: contact),
  );
}

/// [역할 설명]: 상대방 이름, 관계, 메모, AI 성향을 입력받는 다이얼로그 위젯입니다.
///
/// AI 성향 필드는 직접 입력할 수도 있고, OpenRouterService의 텍스트 분석 기능으로 자동 생성할 수도 있습니다.
class ContactEditorDialog extends StatefulWidget {
  final ContactModel? contact;

  const ContactEditorDialog({
    super.key,
    this.contact,
  });

  @override
  State<ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<ContactEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _memoController = TextEditingController();
  final _personalityController = TextEditingController();
  final _openRouterService = OpenRouterService.fromEnvironment();

  bool _isAnalyzingPersonality = false;

  @override
  void initState() {
    super.initState();

    final contact = widget.contact;
    _nameController.text = contact?.name ?? '';
    _relationshipController.text = contact?.relationship ?? '';
    _memoController.text = contact?.memo ?? '';
    _personalityController.text =
        contact?.personality ?? '대화 데이터를 더 수집한 뒤 성향 분석이 필요함';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _memoController.dispose();
    _personalityController.dispose();
    super.dispose();
  }

  /// [AI 성향 분석]: 현재 입력된 관계/메모를 OpenRouter 또는 로컬 휴리스틱으로 분석합니다.
  ///
  /// 분석 결과는 personality TextFormField에 자동 입력되어, 오버레이 프롬프트 Context로 저장됩니다.
  Future<void> _handleAnalyzePersonality() async {
    if (_nameController.text.trim().isEmpty || _relationshipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 관계를 먼저 입력해주세요.')),
      );
      return;
    }

    setState(() => _isAnalyzingPersonality = true);

    final personality = await _openRouterService.analyzeContactPersonality(
      name: _nameController.text.trim(),
      relationship: _relationshipController.text.trim(),
      memo: _memoController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _personalityController.text = personality;
      _isAnalyzingPersonality = false;
    });
  }

  /// [저장 로직]: 신규 상대방은 addContact, 기존 상대방은 updateContact로 분기합니다.
  ///
  /// 저장된 ContactModel을 Navigator.pop 결과로 돌려줘 상세 화면이 필요할 때 즉시 최신 객체를 알 수 있게 합니다.
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ContactProvider>();
    final existing = widget.contact;

    if (existing == null) {
      final created = await provider.addContact(
        name: _nameController.text.trim(),
        relationship: _relationshipController.text.trim(),
        memo: _memoController.text.trim(),
        personality: _personalityController.text.trim(),
      );
      if (created.isAnalysisTarget) {
        await SystemOverlayService.updateTarget(created);
      }
      if (mounted) Navigator.pop(context, created);
      return;
    }

    final updated = existing.copyWith(
      name: _nameController.text.trim(),
      relationship: _relationshipController.text.trim(),
      memo: _memoController.text.trim(),
      personality: _personalityController.text.trim(),
    );

    await provider.updateContact(updated);
    if (updated.isAnalysisTarget) {
      await SystemOverlayService.updateTarget(updated);
    }
    if (mounted) Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;

    return AlertDialog(
      title: Text(isEditing ? '상대방 정보 수정' : '상대방 추가'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // [입력 필드]: 이름은 목록 카드, 상세 화면, 추천 다이얼로그 제목에 사용됩니다.
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '이름'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '이름을 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // [입력 필드]: 관계는 AI가 말투와 거리감을 조절하는 기본 Context입니다.
              TextFormField(
                controller: _relationshipController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '관계'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '관계를 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // [입력 필드]: 메모는 상대방이 선호하는 화법이나 현재 관계 상황을 보충합니다.
              TextFormField(
                controller: _memoController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '관계 메모',
                  hintText: '예: 두괄식 보고 선호, 감정적 표현에 민감함',
                ),
              ),
              const SizedBox(height: 12),

              // [AI 성향 블록]: 자동 분석 버튼과 직접 수정 필드를 함께 제공해 사용자가 결과를 다듬을 수 있습니다.
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'AI 맞춤형 성향',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isAnalyzingPersonality ? null : _handleAnalyzePersonality,
                    icon: _isAnalyzingPersonality
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI 분석'),
                  ),
                ],
              ),
              TextFormField(
                controller: _personalityController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  helperText: '오버레이 분석/추천 API 호출 시 Context로 포함됩니다.',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'AI 성향을 입력하거나 분석해주세요.';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5C6BC0),
            foregroundColor: Colors.white,
          ),
          onPressed: _handleSave,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
