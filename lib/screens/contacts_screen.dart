// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../models/contact_model.dart';

/// [역할 설명]: 상대방(Target) 관리 화면입니다.
/// 1) 등록된 상대방 목록 열람 및 추가/수정/삭제
/// 2) [personality(AI 성향)] 필드 입력 및 관리
/// 3) [isAnalysisTarget] '대화 분석 대상(Target)으로 지정하기' 버튼 구현 -> 오버레이 위젯 문맥 주입
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  void _showAddOrEditDialog(BuildContext context, [ContactModel? contact]) {
    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final relCtrl = TextEditingController(text: contact?.relationship ?? '');
    final memoCtrl = TextEditingController(text: contact?.memo ?? '');
    final personalityCtrl = TextEditingController(
      text: contact?.personality ?? '직설적이며 마감 시간에 민감함',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(contact == null ? '상대방 추가' : '상대방 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '이름 (예: 팀장님)')),
              TextField(controller: relCtrl, decoration: const InputDecoration(labelText: '관계 (예: 직속 상사)')),
              TextField(controller: memoCtrl, decoration: const InputDecoration(labelText: '특징/메모 (예: 두괄식 보고 선호)')),
              const SizedBox(height: 8),
              TextField(
                controller: personalityCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'AI 맞춤형 성향',
                  helperText: '오버레이 AI 분석 시 프롬프트 문맥으로 주입됩니다.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C6BC0), foregroundColor: Colors.white),
            onPressed: () {
              final prov = context.read<ContactProvider>();
              if (contact == null) {
                prov.addContact(
                  name: nameCtrl.text.trim(),
                  relationship: relCtrl.text.trim(),
                  memo: memoCtrl.text.trim(),
                  personality: personalityCtrl.text.trim(),
                );
              } else {
                prov.updateContact(contact.copyWith(
                  name: nameCtrl.text.trim(),
                  relationship: relCtrl.text.trim(),
                  memo: memoCtrl.text.trim(),
                  personality: personalityCtrl.text.trim(),
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactProv = context.watch<ContactProvider>();
    final contacts = contactProv.contacts;

    return Scaffold(
      appBar: AppBar(title: const Text('상대방 (Target) 관리')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF5C6BC0),
        onPressed: () => _showAddOrEditDialog(context),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: contacts.isEmpty
          ? const Center(child: Text('등록된 상대방이 없습니다. 우측 하단 버튼을 눌러 추가하세요.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.length,
              itemBuilder: (context, idx) {
                final c = contacts[idx];
                final isTarget = c.isAnalysisTarget;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isTarget ? const Color(0xFF5C6BC0) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isTarget ? const Color(0xFF5C6BC0) : Colors.grey.shade300,
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0] : '?',
                                    style: TextStyle(color: isTarget ? Colors.white : Colors.black87),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(c.relationship, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                            if (isTarget)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Color(0xFF5C6BC0)),
                                    SizedBox(width: 4),
                                    Text('분석 대상(Target)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5C6BC0))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🧠 AI 성향: ${c.personality}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              if (c.memo.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('📝 메모: ${c.memo}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // [핵심 요구사항 B-2]: 대화 분석 대상(Target)으로 지정하기 버튼
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isTarget ? const Color(0xFF5C6BC0) : Colors.grey.shade200,
                                foregroundColor: isTarget ? Colors.white : Colors.black87,
                                elevation: 0,
                              ),
                              onPressed: () {
                                context.read<ContactProvider>().setActiveTarget(c.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("'${c.name}' 님이 AI 대화 분석 대상으로 지정되었습니다.")),
                                );
                              },
                              icon: const Icon(Icons.gps_fixed, size: 16),
                              label: Text(isTarget ? '분석 대상 활성화됨' : '대화 분석 대상으로 지정'),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _showAddOrEditDialog(context, c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  onPressed: () {
                                    context.read<ContactProvider>().deleteContact(c.id);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
