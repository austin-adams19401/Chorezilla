import 'package:chorezilla/models/chore_models.dart';
import 'package:chorezilla/models/family_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

class AppState extends ChangeNotifier {
  Family? _family;
  final List<Member> _members = [];
  String? _currentProfileId;

  final List<Chore> _chores = [];
  final List<ChoreCompletion> _completions = [];

  // ---- Getters ----
  Family? get family => _family;
  List<Member> get members => List.unmodifiable(_members);
  String? get currentProfileId => _currentProfileId;
  Member? get currentProfile =>
      _members.where((m) => m.id == _currentProfileId).firstOrNull;

  List<Chore> get chores => List.unmodifiable(_chores);

  void addChore({
    required String title,
    required int points,
    required ChoreFrequency frequency,
    required Set<String> assigneeIds,
    IconData? icon,
    Color? iconColor,
  }) {
    final c = Chore(
      id: _id(),
      title: title,
      points: points,
      frequency: frequency,
      assigneeIds: assigneeIds,
      icon: icon,
      iconColor: iconColor
    );
    _chores.add(c);
    notifyListeners();
  }

    void assignMembersToChore(String choreId, Set<String> memberIds) {
    final c = _chores.firstWhere((x) => x.id == choreId);
    c.assigneeIds.addAll(memberIds);
    notifyListeners();
  }

  void updateChore({
    required String choreId,
    String? title,
    int? points,
    ChoreFrequency? frequency,
    IconData? icon,
    Color? iconColor,
  }) {
    final c = _chores.firstWhere((x) => x.id == choreId);
    if (title != null) c.title = title;
    if (points != null) c.points = points;
    if (frequency != null) c.frequency = frequency;
    if (icon != null) c.icon = icon;
    if (iconColor != null) c.iconColor = iconColor;
    notifyListeners();
  }

  // Convenience lookups
  Member? memberById(String id) =>
      _members.where((m) => m.id == id).firstOrNull;

  List<Member> membersByIds(Iterable<String> ids) =>
      ids.map(memberById).whereType<Member>().toList();

  // ---- Family/Member methods ----
  void createOrUpdateFamily(String name) {
    if (_family == null) {
      _family = Family(id: _id(), name: name, createdAt: DateTime.now());
    } else {
      _family!.name = name;
    }
    notifyListeners();
  }

  void addMember({
    required String name,
    required MemberRole role,
    required String avatar,
    bool usesThisDevice = true,
    bool requiresPin = false,
    String? pin,
  }) {
    final fam = _family ?? Family(id: _id(), name: 'Family', createdAt: DateTime.now());
    _family ??= fam;

    final m = Member(
      id: _id(),
      familyId: fam.id,
      name: name,
      role: role,
      avatar: avatar,
      usesThisDevice: usesThisDevice,
      requiresPin: requiresPin,
      pin: requiresPin ? pin : null,
    );
    _members.add(m);
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

  void updatePin(String memberId, {required bool requiresPin, String? pin}) {
    final i = _members.indexWhere((m) => m.id == memberId);
    if (i != -1) {
      _members[i].requiresPin = requiresPin;
      _members[i].pin = requiresPin ? pin : null;
      notifyListeners();
    }
  }

  bool verifyPin(String memberId, String input) {
    final m = _members.firstWhere((e) => e.id == memberId, orElse: () => throw StateError('Missing member'));
    if (!m.requiresPin) return true;
    return (m.pin ?? '') == input;
  }

  void removeMember(String memberId) {
    _members.removeWhere((m) => m.id == memberId);
    // Clean up assignees & completions
    for (final c in _chores) {
      c.assigneeIds.remove(memberId);
    }
    _completions.removeWhere((x) => x.memberId == memberId);
    if (_currentProfileId == memberId) {
      _currentProfileId = _members.isEmpty ? null : _members.first.id;
    }
    notifyListeners();
  }

  void setCurrentProfile(String memberId) {
    _currentProfileId = memberId;
    notifyListeners();
  }
  void toggleAssignee(String choreId, String memberId) {
    final c = _chores.firstWhere((x) => x.id == choreId);
    if (c.assigneeIds.contains(memberId)) {
      c.assigneeIds.remove(memberId);
    } else {
      c.assigneeIds.add(memberId);
    }
    notifyListeners();
  }

  void deleteChore(String choreId) {
    _chores.removeWhere((x) => x.id == choreId);
    _completions.removeWhere((x) => x.choreId == choreId);
    notifyListeners();
  }

  void completeChore(String choreId, String memberId) {
    _completions.add(ChoreCompletion(
      id: _id(),
      choreId: choreId,
      memberId: memberId,
      completedAt: DateTime.now(),
    ));
    notifyListeners();
  }

  // Simple derived data
  List<Chore> choresForMember(String memberId) =>
      _chores.where((c) => c.assigneeIds.contains(memberId)).toList();

  int pointsForMemberAllTime(String memberId) {
    var total = 0;
    for (final comp in _completions.where((x) => x.memberId == memberId)) {
      final chore = _chores.firstWhere((c) => c.id == comp.choreId, orElse: () => Chore(id: '', title: '', points: 0, frequency: ChoreFrequency.once));
      total += chore.points;
    }
    return total;
  }

  // === Helpers for weekly grid ===
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Was this chore completed by member on a specific calendar day?
bool wasCompletedOnDay(String choreId, String memberId, DateTime day) {
  final target = _dateOnly(day);
  return _completions.any((c) =>
      c.choreId == choreId &&
      c.memberId == memberId &&
      _dateOnly(c.completedAt) == target);
}

// Did member complete this chore at least once between [start,end] (inclusive)?
bool wasCompletedInRange(String choreId, String memberId, DateTime start, DateTime end) {
  final s = _dateOnly(start);
  final e = _dateOnly(end);
  return _completions.any((c) {
    if (c.choreId != choreId || c.memberId != memberId) return false;
    final d = _dateOnly(c.completedAt);
    return !d.isBefore(s) && !d.isAfter(e);
  });
}

// Mark completion on an arbitrary day (used by parent grid taps)
void completeChoreOn(String choreId, String memberId, DateTime day) {
  _completions.add(ChoreCompletion(
    id: _id(),
    choreId: choreId,
    memberId: memberId,
    // normalize to noon to avoid timezone DST edges
    completedAt: DateTime(day.year, day.month, day.day, 12, 0, 0),
  ));
  notifyListeners();
}
}

// Keep this tiny helper
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}



