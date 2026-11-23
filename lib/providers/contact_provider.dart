// lib/providers/contact_provider.dart
import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/storage_service.dart';
import '../services/system_overlay_service.dart';

/// [역할 설명]: 상대방(Target) 목록과 현재 활성화된 '대화 분석 대상'을 관리하는 Provider입니다.
/// '대화 분석 대상(Target)으로 지정하기' 클릭 시, 단 하나의 대상만 isAnalysisTarget=true로 유지하며
/// 오버레이 위젯에서 이 타겟의 성향과 메모를 AI 프롬프트 Context로 즉시 주입할 수 있도록 제공합니다.
class ContactProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<ContactModel> _contacts = [];
  String? _userId;

  ContactProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _contacts = [];
    if (userId != null) loadContacts();
  }

  List<ContactModel> get contacts => _contacts;

  Future<void> _syncOverlay() async {
    final target = activeTarget;
    if (target != null) await SystemOverlayService.updateTarget(target);
  }

  /// 현재 대화 분석 대상(Target)으로 지정된 상대방 반환 (없을 시 첫 번째 또는 기본 상대방)
  ContactModel? get activeTarget {
    try {
      return _contacts.firstWhere((c) => c.isAnalysisTarget);
    } catch (e) {
      return _contacts.isNotEmpty ? _contacts.first : null;
    }
  }

  Future<void> loadContacts() async {
    final requestedUser = _userId;
    final contacts = await _storageService.getContacts();
    if (requestedUser != _userId) return;
    _contacts = contacts;
    notifyListeners();
  }

  /// 신규 상대방 추가
  Future<void> addContact({
    required String name,
    required String relationship,
    required String memo,
    required String personality,
  }) async {
    final newContact = ContactModel(
      id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      relationship: relationship,
      memo: memo,
      personality: personality,
      isAnalysisTarget: _contacts.isEmpty, // 목록이 비어있으면 자동으로 타겟 지정
    );

    _contacts.add(newContact);
    await _storageService.saveContacts(_contacts);
    notifyListeners();
    await _syncOverlay();
  }

  /// 상대방 정보 수정
  Future<void> updateContact(ContactModel updated) async {
    final idx = _contacts.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _contacts[idx] = updated;
      await _storageService.saveContacts(_contacts);
      notifyListeners();
      await _syncOverlay();
    }
  }

  /// 상대방 삭제
  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    // 삭제 후 활성 타겟이 없다면 첫 번째 요소를 자동 지정
    if (_contacts.isNotEmpty && !_contacts.any((c) => c.isAnalysisTarget)) {
      _contacts[0] = _contacts[0].copyWith(isAnalysisTarget: true);
    }
    await _storageService.saveContacts(_contacts);
    notifyListeners();
    await _syncOverlay();
  }

  /// [핵심 요구사항]: '대화 분석 대상(Target)으로 지정하기' 액션
  Future<void> setActiveTarget(String contactId) async {
    _contacts = _contacts.map((c) {
      return c.copyWith(isAnalysisTarget: c.id == contactId);
    }).toList();

    await _storageService.saveContacts(_contacts);
    notifyListeners();
    await _syncOverlay();
  }
}
