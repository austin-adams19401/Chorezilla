import 'package:flutter/material.dart';
import '../models/family_models.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

class AppState extends ChangeNotifier {
  Family? _family;
  final List<Member> _members = [];
  String? _currentProfileId; // active local profile for shared tablets

  Family? get family => _family;
  List<Member> get members => List.unmodifiable(_members);
  String? get currentProfileId => _currentProfileId;
  Member? get currentProfile =>
      _members.where((m) => m.id == _currentProfileId).cast<Member?>().firstOrNull;

  // Create/rename family
  void createOrUpdateFamily(String name) {
    if (_family == null) {
      _family = Family(id: _id(), name: name, createdAt: DateTime.now());
    } else {
      _family!.name = name;
    }
    notifyListeners();
  }

  void addMember({required String name, required MemberRole role, required String avatar, bool usesThisDevice = true}) {
    final fam = _family ?? Family(id: _id(), name: 'Family', createdAt: DateTime.now());
    _family ??= fam;

    final m = Member(
      id: _id(),
      familyId: fam.id,
      name: name,
      role: role,
      avatar: avatar,
      usesThisDevice: usesThisDevice,
    );
    _members.add(m);

    // If first child added, set as current profile by default
    _currentProfileId ??= m.id;
    notifyListeners();
  }

  void updateMemberRole(String memberId, MemberRole role) {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i != -1) {
      _members[i].role = role;
      notifyListeners();
    }
  }

  void updateUsesThisDevice(String memberId, bool value) {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i != -1) {
      _members[i].usesThisDevice = value;
      notifyListeners();
    }
  }

  void removeMember(String memberId) {
    _members.removeWhere((m) => m.id == memberId);
    if (_currentProfileId == memberId) {
      _currentProfileId = _members.isEmpty ? null : _members.first.id;
    }
    notifyListeners();
  }

  void setCurrentProfile(String memberId) {
    _currentProfileId = memberId;
    notifyListeners();
  }
}

// tiny extension just for convenience
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
