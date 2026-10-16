import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import '../services/system_overlay_service.dart';
import '../widgets/contact_editor_dialog.dart';

/// [역할 설명]: 상대방(Target) 한 명의 상세 정보를 보여주는 화면입니다.
///
/// 목록 화면에서 요약으로 보던 이름/관계/메모/AI 성향을 전체 문장으로 확인하고,
/// 수정, 삭제, 분석 대상 지정까지 한 곳에서 처리합니다.
class ContactDetailScreen extends StatelessWidget {
  final String contactId;

  const ContactDetailScreen({
    super.key,
    required this.contactId,
  });

  /// [수정 액션]: 공용 편집 다이얼로그를 열어 상세 화면에서도 같은 저장 로직을 사용합니다.
  Future<void> _handleEdit(BuildContext context, ContactModel contact) async {
    final updated = await showContactEditorDialog(context, contact: contact);
    if (updated == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.name} 님 정보가 수정되었습니다.')),
    );
  }

  /// [삭제 액션]: 상대방 삭제 전 확인 팝업을 띄워 실수 삭제를 방지합니다.
  Future<void> _handleDelete(BuildContext context, ContactModel contact) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('상대방 삭제'),
        content: Text('${contact.name} 님을 목록에서 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) return;

    final provider = context.read<ContactProvider>();
    await provider.deleteContact(contact.id);
    final nextTarget = provider.activeTarget;
    if (nextTarget != null) {
      await SystemOverlayService.updateTarget(nextTarget);
    } else {
      await SystemOverlayService.closeSystemOverlay();
    }
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${contact.name} 님이 삭제되었습니다.')),
    );
  }

  /// [Target 지정 액션]: 이 상대방을 오버레이 분석 Context의 기준으로 저장합니다.
  Future<void> _handleSetTarget(BuildContext context, ContactModel contact) async {
    await context.read<ContactProvider>().setActiveTarget(contact.id);
    await SystemOverlayService.updateTarget(contact);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${contact.name} 님이 AI 분석 대상으로 지정되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contact = context.watch<ContactProvider>().findById(contactId);

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('상대방 상세')),
        body: const Center(child: Text('상대방 정보를 찾을 수 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('상대방 상세'),
        actions: [
          IconButton(
            tooltip: '수정',
            icon: const Icon(Icons.edit),
            onPressed: () => _handleEdit(context, contact),
          ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _handleDelete(context, contact),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Header(contact: contact),
          const SizedBox(height: 20),

          // [상세 정보 블록]: API Context에 들어가는 관계/메모/성향을 사용자가 눈으로 검수할 수 있게 합니다.
          _InfoSection(
            title: '관계',
            icon: Icons.group_outlined,
            child: Text(contact.relationship),
          ),
          const SizedBox(height: 12),
          _InfoSection(
            title: '관계 메모',
            icon: Icons.sticky_note_2_outlined,
            child: Text(contact.memo.isEmpty ? '등록된 메모가 없습니다.' : contact.memo),
          ),
          const SizedBox(height: 12),
          _InfoSection(
            title: 'AI 맞춤형 성향',
            icon: Icons.psychology_alt_outlined,
            child: Text(contact.personality),
          ),
          const SizedBox(height: 24),

          // [핵심 요구사항 버튼]: 선택된 상대방 정보가 향후 분석/추천 오버레이 Context로 포함됩니다.
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: contact.isAnalysisTarget ? const Color(0xFF5C6BC0) : Colors.grey.shade200,
              foregroundColor: contact.isAnalysisTarget ? Colors.white : Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _handleSetTarget(context, contact),
            icon: Icon(contact.isAnalysisTarget ? Icons.check_circle : Icons.gps_fixed),
            label: Text(
              contact.isAnalysisTarget ? '현재 대화 분석 대상입니다' : '대화 분석 대상으로 지정하기',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _handleEdit(context, contact),
            icon: const Icon(Icons.edit_note),
            label: const Text('정보 수정하기'),
          ),
        ],
      ),
    );
  }
}

/// [역할 설명]: 상세 화면 상단의 프로필성 헤더입니다.
///
/// Target 활성 여부를 배지로 보여줘 사용자가 지금 오버레이가 누구를 기준으로 분석하는지 빠르게 알 수 있습니다.
class _Header extends StatelessWidget {
  final ContactModel contact;

  const _Header({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: contact.isAnalysisTarget ? const Color(0xFF5C6BC0) : Colors.grey.shade300,
          child: Text(
            contact.name.isNotEmpty ? contact.name[0] : '?',
            style: TextStyle(
              color: contact.isAnalysisTarget ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                contact.isAnalysisTarget ? '현재 AI 분석 Target' : '등록된 상대방',
                style: TextStyle(
                  color: contact.isAnalysisTarget ? const Color(0xFF5C6BC0) : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [역할 설명]: 상세 정보 카드의 반복 레이아웃을 담당하는 작은 위젯입니다.
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF5C6BC0)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DefaultTextStyle(
              style: const TextStyle(color: Colors.black87, height: 1.45, fontSize: 14),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
