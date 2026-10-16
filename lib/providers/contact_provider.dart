import 'package:flutter/material.dart';

import '../models/contact_model.dart';
import '../services/storage_service.dart';

/// [역할 설명]: 상대방(Target) 목록과 현재 AI 분석 대상을 전역으로 관리하는 Provider입니다.
///
/// 홈 화면, 연락처 화면, 오버레이 위젯이 모두 같은 Provider를 바라보므로,
/// 사용자가 "대화 분석 대상으로 지정"한 상대방의 성향/메모가 API 호출 Context에 그대로 들어갑니다.
class ContactProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<ContactModel> _contacts = [];
  bool _isLoading = false;

  ContactProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService() {
    loadContacts();
  }

  List<ContactModel> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _isLoading;

  /// [활성 Target 조회]: isAnalysisTarget=true인 상대방을 반환합니다.
  ///
  /// 저장 데이터가 손상되어 활성 대상이 없더라도 첫 번째 연락처를 안전하게 반환해
  /// 오버레이 분석 기능이 null 때문에 중단되지 않도록 합니다.
  ContactModel? get activeTarget {
    for (final contact in _contacts) {
      if (contact.isAnalysisTarget) return contact;
    }
    return _contacts.isNotEmpty ? _contacts.first : null;
  }

  /// [상세 화면 보조]: id로 상대방을 찾습니다.
  ///
  /// 상세 화면은 목록에서 넘어온 id를 기준으로 최신 Provider 상태를 다시 읽어
  /// 수정/삭제 직후에도 오래된 객체를 표시하지 않게 합니다.
  ContactModel? findById(String id) {
    for (final contact in _contacts) {
      if (contact.id == id) return contact;
    }
    return null;
  }

  /// [초기 로드]: 로컬 저장소에서 상대방 목록을 불러와 화면에 반영합니다.
  Future<void> loadContacts() async {
    _isLoading = true;
    notifyListeners();

    _contacts = await _storageService.getContacts();
    _ensureOneActiveTarget();

    _isLoading = false;
    notifyListeners();
  }

  /// [상대방 추가]: 이름/관계/메모/AI 성향을 가진 새 Target을 목록에 넣습니다.
  ///
  /// 첫 번째로 추가되는 상대방은 자동으로 분석 대상으로 지정하여 초기 설정 부담을 낮춥니다.
  Future<ContactModel> addContact({
    required String name,
    required String relationship,
    required String memo,
    required String personality,
  }) async {
    final newContact = ContactModel(
      id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      relationship: relationship.trim(),
      memo: memo.trim(),
      personality: personality.trim().isEmpty
          ? '대화 데이터를 더 수집한 뒤 성향 분석이 필요함'
          : personality.trim(),
      isAnalysisTarget: _contacts.isEmpty,
    );

    _contacts = [..._contacts, newContact];
    _ensureOneActiveTarget();
    await _persistAndNotify();
    return newContact;
  }

  /// [상대방 수정]: 기존 Target의 관계 메모와 AI 성향을 갱신합니다.
  Future<void> updateContact(ContactModel updated) async {
    _contacts = _contacts
        .map((contact) => contact.id == updated.id ? updated : contact)
        .toList();
    _ensureOneActiveTarget();
    await _persistAndNotify();
  }

  /// [상대방 삭제]: 선택한 Target을 제거하고, 활성 대상이 사라졌다면 첫 번째 대상을 자동 지정합니다.
  Future<void> deleteContact(String id) async {
    _contacts = _contacts.where((contact) => contact.id != id).toList();
    _ensureOneActiveTarget();
    await _persistAndNotify();
  }

  /// [핵심 요구사항]: 특정 상대방을 향후 오버레이 대화 분석의 Target으로 지정합니다.
  ///
  /// 한 번에 하나의 Target만 true가 되도록 전체 목록을 재계산합니다.
  Future<void> setActiveTarget(String contactId) async {
    _contacts = _contacts
        .map((contact) => contact.copyWith(isAnalysisTarget: contact.id == contactId))
        .toList();
    await _persistAndNotify();
  }

  /// [계정 탈퇴 후 정리]: 저장소와 메모리의 상대방 목록을 모두 비웁니다.
  Future<void> clearAllContacts() async {
    _contacts = [];
    await _storageService.clearContacts();
    notifyListeners();
  }

  /// [무결성 보정]: 목록이 비어 있지 않은데 활성 Target이 없다면 첫 항목을 활성화합니다.
  void _ensureOneActiveTarget() {
    if (_contacts.isEmpty || _contacts.any((contact) => contact.isAnalysisTarget)) {
      return;
    }
    _contacts = [
      _contacts.first.copyWith(isAnalysisTarget: true),
      ..._contacts.skip(1),
    ];
  }

  /// [저장 공통 로직]: 목록 변경 결과를 저장소와 UI에 함께 반영합니다.
  Future<void> _persistAndNotify() async {
    await _storageService.saveContacts(_contacts);
    notifyListeners();
  }
}
