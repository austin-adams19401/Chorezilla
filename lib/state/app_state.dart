// lib/state/app_state.dart
import 'package:flutter/material.dart';
import 'package:chorezilla/models/family_models.dart';
import 'package:chorezilla/models/chore_models.dart';

/// Simple id helper
String _id() => DateTime.now().microsecondsSinceEpoch.toString();

/// Date helpers (normalize to midnight for comparisons)
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday-start week
DateTime _startOfWeek(DateTime d) {
  final x = _dateOnly(d);
  final diff = x.weekday - DateTime.monday; // 0..6
  return x.subtract(Duration(days: diff));
}

class AppState extends ChangeNotifier {
  // =========================
  // Family / Members
  // =========================
  Family? _family;
  final List<Member> _members = [];
  String? _currentProfileId; // active local profile (kid dashboard target)

  Family? get family => _family;
  List<Member> get members => List.unmodifiable(_members);
  String? get currentProfileId => _currentProfileId;
  Member? get currentProfile =>
      _members.where((m) => m.id == _currentProfileId).firstOrNull;

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
    final fam =
        _family ?? Family(id: _id(), name: 'Family', createdAt: DateTime.now());
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
    final m = _members.firstWhere((e) => e.id == memberId,
        orElse: () => throw StateError('Missing member'));
    if (!m.requiresPin) return true;
    return (m.pin ?? '') == input;
  }

  void removeMember(String memberId) {
    _members.removeWhere((m) => m.id == memberId);
    // Clean up assignees/completions for that member
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

  Member? memberById(String id) =>
      _members.where((m) => m.id == id).firstOrNull;
  List<Member> membersByIds(Iterable<String> ids) =>
      ids.map(memberById).whereType<Member>().toList();

  // =========================
  // Chores / Completions
  // =========================
  final List<Chore> _chores = [];
  final List<ChoreCompletion> _completions = [];

  List<Chore> get chores => List.unmodifiable(_chores);

void addChore({
  required String title,
  required int points,
  required ChoreSchedule schedule,
  Set<int>? daysOfWeek,
  required Set<String> assigneeIds,
  IconData? icon,
  Color? iconColor,
}) {
  _chores.add(Chore(
    id: _id(),
    title: title,
    points: points,
    schedule: schedule,
    daysOfWeek: daysOfWeek != null ? Set<int>.from(daysOfWeek) : {},
    assigneeIds: Set<String>.from(assigneeIds), // <-- copy
    icon: icon,
    iconColor: iconColor,
  ));
  notifyListeners();
}


  void updateChore({
    required String choreId,
    String? title,
    int? points,
    ChoreSchedule? schedule,
    Set<int>? daysOfWeek,
    IconData? icon,
    Color? iconColor,
  }) {
    final c = _chores.firstWhere((x) => x.id == choreId);
    if (title != null) c.title = title;
    if (points != null) c.points = points;
    if (schedule != null) c.schedule = schedule;
    if (daysOfWeek != null) {
      c.daysOfWeek
        ..clear()
        ..addAll(daysOfWeek);
    }
    if (icon != null) c.icon = icon;
    if (iconColor != null) c.iconColor = iconColor;
    notifyListeners();
  }

  void deleteChore(String choreId) {
    _chores.removeWhere((x) => x.id == choreId);
    _completions.removeWhere((x) => x.choreId == choreId);
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

  void assignMembersToChore(String choreId, Set<String> memberIds) {
    final c = _chores.firstWhere((x) => x.id == choreId);
    c.assigneeIds.addAll(memberIds);
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

  /// Record completion on an arbitrary calendar day (used by parent grid taps).
  void completeChoreOn(String choreId, String memberId, DateTime day) {
    _completions.add(ChoreCompletion(
      id: _id(),
      choreId: choreId,
      memberId: memberId,
      // Noon avoids DST edge cases
      completedAt: DateTime(day.year, day.month, day.day, 12),
    ));
    notifyListeners();
  }

  // -------- Queries / Derived --------

  List<Chore> choresForMember(String memberId) =>
      _chores.where((c) => c.assigneeIds.contains(memberId)).toList();

  int pointsForMemberAllTime(String memberId) {
    var total = 0;
    for (final comp in _completions.where((x) => x.memberId == memberId)) {
      final chore = _chores.firstWhere(
        (c) => c.id == comp.choreId,
        orElse: () => Chore(
          id: '',
          title: '',
          points: 0,
          schedule: ChoreSchedule.daily,
        ),
      );
      total += chore.points;
    }
    return total;
  }

  bool wasCompletedOnDay(String choreId, String memberId, DateTime day) {
    final t = _dateOnly(day);
    return _completions.any((c) =>
        c.choreId == choreId &&
        c.memberId == memberId &&
        _dateOnly(c.completedAt) == t);
  }

  bool wasCompletedInWeek(
      String choreId, String memberId, DateTime anyDayInWeek) {
    final s = _startOfWeek(anyDayInWeek);
    final e = s.add(const Duration(days: 6));
    return _completions.any((c) {
      if (c.choreId != choreId || c.memberId != memberId) return false;
      final d = _dateOnly(c.completedAt);
      return !d.isBefore(s) && !d.isAfter(e);
    });
  }

  /// Is this chore scheduled on [day], independent of completions?
  bool isScheduledOnDate(Chore chore, DateTime day) {
    switch (chore.schedule) {
      case ChoreSchedule.daily:
        return true;
      case ChoreSchedule.weeklyAny:
        // If no weekday chosen => any day in the week.
        // If one (or more) weekdays chosen => only those day(s).
        return chore.daysOfWeek.isEmpty
            ? true
            : chore.daysOfWeek.contains(day.weekday);
      case ChoreSchedule.customDays:
        return chore.daysOfWeek.contains(day.weekday);
    }
  }

  /// Should the chore appear for [memberId] on [day]?
  /// This combines scheduling with once-per-week gating (for weekly-any).
  bool isApplicableForMemberOnDate(
      Chore chore, String memberId, DateTime day) {
    if (!isScheduledOnDate(chore, day)) return false;

    if (chore.schedule == ChoreSchedule.weeklyAny) {
      if (chore.daysOfWeek.isEmpty) {
        // Weekly (any day): show until they finish once in the week.
        final doneThisWeek = wasCompletedInWeek(chore.id, memberId, day);
        return !doneThisWeek;
      } else {
        // Weekly on a specific day(s): show on those day(s) (no week-wide gating).
        return true;
      }
    }

    // Daily / Custom days: show on scheduled day
    return true;
  }
}

// Iterable helper (avoids bringing in package:collection)
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
