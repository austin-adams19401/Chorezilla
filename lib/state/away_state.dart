// lib/state/away_state.dart
part of 'app_state.dart';

extension AwayState on AppState {
  /// Mark a kid as away from [startDate] to [returnDate] (both inclusive).
  /// If [recurring] is true, [intervalDays] sets the full cycle length
  /// (e.g. 14 for biweekly). The away duration is derived from the
  /// difference between [startDate] and [returnDate].
  Future<void> setMemberAway({
    required String memberId,
    required DateTime startDate,
    required DateTime returnDate,
    bool recurring = false,
    int? intervalDays,
  }) async {
    final famId = _familyId;
    if (famId == null) return;

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final until = DateTime(returnDate.year, returnDate.month, returnDate.day);

    await repo.updateMember(famId, memberId, {
      'awayStartDate': Timestamp.fromDate(start),
      'awayUntil': Timestamp.fromDate(until),
      'awayRecurring': recurring,
      'awayIntervalDays': recurring ? intervalDays : null,
    });
  }

  /// Clear a kid's away status and restore their streak continuity.
  Future<void> clearMemberAway(String memberId) async {
    final famId = _familyId;
    if (famId == null) return;

    await repo.updateMember(famId, memberId, {
      'awayUntil': null,
      'awayStartDate': null,
      'awayRecurring': false,
      'awayIntervalDays': null,
    });

    await _restoreStreakForReturningKid(memberId);
  }

  /// Sets lastActiveDate to yesterday so the next chore completion
  /// increments the existing streak rather than resetting it.
  Future<void> _restoreStreakForReturningKid(String memberId) async {
    final famId = _familyId;
    if (famId == null) return;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayNorm = DateTime(yesterday.year, yesterday.month, yesterday.day);

    await repo.updateMember(famId, memberId, {
      'lastActiveDate': Timestamp.fromDate(yesterdayNorm),
    });
  }

  /// Called once after family data is loaded.
  /// Auto-clears non-recurring away periods whose returnDate has passed.
  Future<void> checkAndRestoreReturningKids() async {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    final kids = members.where((m) => m.role == FamilyRole.child);
    for (final kid in kids) {
      if (kid.awayUntil == null) continue;
      if (kid.awayRecurring) continue; // recurring schedule stays active

      final until = DateTime(
        kid.awayUntil!.year,
        kid.awayUntil!.month,
        kid.awayUntil!.day,
      );
      if (until.isBefore(todayNorm)) {
        await clearMemberAway(kid.id);
      }
    }
  }
}
