// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';

import '../ui/tiki_theme.dart';

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
      text: contact?.personality ?? 'Direct and attentive to deadlines.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(contact == null ? 'Add contact' : 'Edit contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name (e.g., Manager)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: relCtrl,
                decoration: const InputDecoration(
                  labelText: 'Relationship (e.g., manager)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: memoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (e.g., prefers short updates)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: personalityCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Communication style',
                  helperText: 'Used to tailor suggested replies.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: Tiki.filled(),
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
                prov.updateContact(
                  contact.copyWith(
                    name: nameCtrl.text.trim(),
                    relationship: relCtrl.text.trim(),
                    memo: memoCtrl.text.trim(),
                    personality: personalityCtrl.text.trim(),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
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
      appBar: const TikiAppBar(title: 'Contacts'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TikiPanel(
              color: Tiki.lilac,
              onTap: () => _showAddOrEditDialog(context),
              child: const ListTile(
                leading: Icon(Icons.person_add_outlined),
                title: Text('Add contact', style: Tiki.label),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? const Center(
                    child: Text('No contacts yet. Tap + to add one.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: contacts.length,
                    itemBuilder: (context, idx) {
                      final c = contacts[idx];
                      final isTarget = c.isAnalysisTarget;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TikiPanel(
                          color:
                              isTarget ? const Color(0xFFE4EEFC) : Tiki.white,
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isTarget
                                                ? Tiki.blue
                                                : Tiki.lilac,
                                            child: Text(
                                              c.name.isNotEmpty
                                                  ? c.name[0]
                                                  : '?',
                                              style: Tiki.label,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  c.relationship,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isTarget)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Tiki.lilac,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Tiki.ink,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Selected contact',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Tiki.ink,
                                              ),
                                            ),
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
                                    color: Tiki.paper,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Style: ${c.personality}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (c.memo.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Notes: ${c.memo}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    // [핵심 요구사항 B-2]: 대화 분석 대상(Target)으로 지정하기 버튼
                                    ElevatedButton.icon(
                                      style: Tiki.filled(
                                        isTarget ? Tiki.lilac : Tiki.blue,
                                      ),
                                      onPressed: () {
                                        context
                                            .read<ContactProvider>()
                                            .setActiveTarget(c.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "${c.name} is now the selected contact.",
                                            ),
                                          ),
                                        );
                                      },
                                      icon:
                                          const Icon(Icons.gps_fixed, size: 16),
                                      label: Text(
                                        isTarget
                                            ? 'Selected contact'
                                            : 'Set as analysis contact',
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon:
                                              const Icon(Icons.edit, size: 20),
                                          onPressed: () =>
                                              _showAddOrEditDialog(context, c),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () {
                                            context
                                                .read<ContactProvider>()
                                                .deleteContact(c.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
