import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import '../services/system_overlay_service.dart';
import '../widgets/contact_editor_dialog.dart';
import 'contact_detail_screen.dart';

/// [역할 설명]: 등록된 상대방(Target) 목록을 관리하는 화면입니다.
///
/// 이 화면에서는 상대방 추가, 목록 조회, 분석 대상 지정이 가능하며,
/// 각 카드를 탭하면 별도의 상세 화면에서 메모/성향을 더 자세히 확인하고 수정할 수 있습니다.
class ContactsScreen extends StatelessWidget {
  /// [embedded]: HomeScreen 하단 탭 안에서 사용할 때 중첩 Scaffold/AppBar를 만들지 않기 위한 플래그입니다.
  final bool embedded;

  const ContactsScreen({
    super.key,
    this.embedded = false,
  });

  /// [추가 액션]: 공용 ContactEditorDialog를 열고 저장 결과를 SnackBar로 알려줍니다.
  Future<void> _handleAddContact(BuildContext context) async {
    final created = await showContactEditorDialog(context);
    if (created == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${created.name} 님이 상대방 목록에 추가되었습니다.')),
    );
  }

  /// [상세 이동]: 카드 탭 시 ContactDetailScreen으로 이동합니다.
  ///
  /// id만 넘겨 상세 화면이 Provider에서 최신 객체를 다시 조회하게 하여 수정 후 데이터 불일치를 줄입니다.
  void _openDetail(BuildContext context, ContactModel contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(contactId: contact.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final contacts = contactProvider.contacts;
    final content = contactProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : contacts.isEmpty
            ? const _EmptyContactsView()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return _ContactCard(
                    contact: contact,
                    onTap: () => _openDetail(context, contact),
                  );
                },
              );

    if (embedded) {
      return Stack(
        children: [
          content,
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'embedded_contact_add_fab',
              backgroundColor: const Color(0xFF5C6BC0),
              foregroundColor: Colors.white,
              onPressed: () => _handleAddContact(context),
              icon: const Icon(Icons.person_add),
              label: const Text('추가'),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('상대방 관리')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'contact_add_fab',
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        onPressed: () => _handleAddContact(context),
        icon: const Icon(Icons.person_add),
        label: const Text('추가'),
      ),
      body: content,
    );
  }
}

/// [역할 설명]: 상대방이 하나도 없을 때 사용자가 다음 행동을 바로 이해할 수 있게 하는 빈 상태 위젯입니다.
class _EmptyContactsView extends StatelessWidget {
  const _EmptyContactsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '등록된 상대방이 없습니다.\n우측 하단 추가 버튼으로 분석 Target을 만들어보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, height: 1.5),
        ),
      ),
    );
  }
}

/// [역할 설명]: 상대방 한 명의 요약 정보와 Target 지정 버튼을 보여주는 목록 카드입니다.
///
/// 카드 전체는 상세 화면 진입 역할을 하고, 버튼은 현재 오버레이 분석 대상 지정 역할만 수행합니다.
class _ContactCard extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onTap;

  const _ContactCard({
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTarget = contact.isAnalysisTarget;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isTarget ? const Color(0xFF5C6BC0) : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isTarget ? const Color(0xFF5C6BC0) : Colors.grey.shade300,
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0] : '?',
                      style: TextStyle(color: isTarget ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          contact.relationship,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (isTarget)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EAF6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF5C6BC0)),
                          SizedBox(width: 4),
                          Text(
                            '분석 대상',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5C6BC0),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // [요약 정보 블록]: 오버레이 프롬프트에 포함되는 성향/메모가 목록에서도 보이게 합니다.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 성향: ${contact.personality}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.memo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '메모: ${contact.memo}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    // [핵심 버튼]: 누른 상대방만 향후 분석/추천 API Context로 주입됩니다.
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTarget ? const Color(0xFF5C6BC0) : Colors.grey.shade200,
                        foregroundColor: isTarget ? Colors.white : Colors.black87,
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await context.read<ContactProvider>().setActiveTarget(contact.id);
                        await SystemOverlayService.updateTarget(contact);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${contact.name} 님이 AI 분석 대상으로 지정되었습니다.')),
                        );
                      },
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      label: Text(isTarget ? '활성화됨' : '분석 대상으로 지정'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '상세 보기',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: onTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
