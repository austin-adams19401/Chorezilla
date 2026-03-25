// lib/state/app_state_badges.dart
part of 'app_state.dart';

const _badgeCoinBonuses = <String, int>{
  'streak_1': 5,
  'streak_3': 10,
  'streak_7': 25,
  'streak_15': 50,
  'streak_30': 100,
  'streak_60': 200,
  'first_win': 5,
  'fast_finisher': 10,
  'early_bird': 10,
  'all_done': 10,
  'bonus_boss': 15,
  'weekend_warrior': 15,
  'sunrise_starter': 10,
  'night_owl': 10,
  'perfect_day': 20,
  'mix_master': 15,
  'overachiever': 20,
  'trash_trooper_daily': 15,
  'task_crusher': 25,
};

const _tieredBadgeCoinBonuses = <BadgeTier, int>{
  BadgeTier.bronze: 10,
  BadgeTier.silver: 25,
  BadgeTier.gold: 50,
};

extension BadgeStateAuth on AppState {
  // ---------------------------------------------------------------------------
  // Helper: build today's full assignment list for a member
  // ---------------------------------------------------------------------------

  /// Returns today's snapshot of assignments for [memberId]: in-progress
  /// (assigned/pending) + completed today from the kid's completed cache.
  List<Assignment> getTodaysAssignmentsForMember(String memberId) {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    bool isToday(DateTime? dt) =>
        dt != null && !dt.isBefore(dayStart) && dt.isBefore(dayEnd);

    final assigned = _kidAssigned[memberId] ?? const <Assignment>[];
    final completedToday = (_kidCompleted[memberId] ?? const <Assignment>[])
        .where((a) => isToday(a.completedAt ?? a.approvedAt))
        .toList();

    final seen = <String>{};
    final all = <Assignment>[];
    for (final a in [...assigned, ...completedToday]) {
      if (seen.add(a.id)) all.add(a);
    }
    return all;
  }

  // ---------------------------------------------------------------------------
  // Main badge check — call after every assignment completion
  // ---------------------------------------------------------------------------

  /// Checks all badge conditions and updates member counters + badges.
  /// Returns a [BadgeEvent] for each badge that was newly unlocked or upgraded.
  Future<List<BadgeEvent>> checkAndAwardBadgesForKid(
    String memberId, {
    required Assignment completedAssignment,
    required List<Assignment> todaysAssignments,
  }) async {
    final member = members.firstWhere(
      (m) => m.id == memberId,
      orElse: () => throw Exception('Member not found: $memberId'),
    );

    final now = completedAssignment.completedAt ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    // ── Counter increments ───────────────────────────────────────────────────
    final cat = completedAssignment.choreCategory;
    final newRoom =
        member.roomChoresCompleted + (cat == ChoreCategory.cleaning ? 1 : 0);
    final newLaundry =
        member.laundryChoresCompleted + (cat == ChoreCategory.laundry ? 1 : 0);
    final newDish =
        member.dishChoresCompleted + (cat == ChoreCategory.dishes ? 1 : 0);
    final newTrash =
        member.trashChoresCompleted + (cat == ChoreCategory.trash ? 1 : 0);
    final newPet =
        member.petChoresCompleted + (cat == ChoreCategory.petCare ? 1 : 0);

    final lastActive = member.lastActiveDate;
    final lastActiveDay = lastActive == null
        ? null
        : DateTime(lastActive.year, lastActive.month, lastActive.day);
    final isNewDay = lastActiveDay == null || lastActiveDay != todayDate;
    final newActiveDays = member.activeDays + (isNewDay ? 1 : 0);

    final projectedCoins = member.coins + completedAssignment.coinAward;
    final newPeakCoins =
        projectedCoins > member.peakCoins ? projectedCoins : member.peakCoins;

    DateTime? newLastSat = member.lastSatCompleted;
    DateTime? newLastSun = member.lastSunCompleted;
    if (now.weekday == DateTime.saturday) newLastSat = todayDate;
    if (now.weekday == DateTime.sunday) newLastSun = todayDate;

    // ── Day-completion state ─────────────────────────────────────────────────
    // Treat the just-completed assignment as done when evaluating conditions.
    bool isEffectivelyDone(Assignment a) {
      if (a.id == completedAssignment.id) return true;
      return a.status == AssignmentStatus.completed ||
          a.status == AssignmentStatus.pending;
    }

    final requiredToday =
        todaysAssignments.where((a) => !a.bonus).toList();
    final bonusToday = todaysAssignments.where((a) => a.bonus).toList();

    final allRequiredDone =
        requiredToday.isNotEmpty && requiredToday.every(isEffectivelyDone);

    final completedBonusToday =
        bonusToday.where(isEffectivelyDone).toList();
    final completedRequiredToday =
        requiredToday.where(isEffectivelyDone).toList();

    final newAllTaskDays =
        member.allTaskDaysCompleted + (allRequiredDone && isNewDay ? 1 : 0);

    final categoriesCompletedToday = {
      ...completedRequiredToday.map((a) => a.choreCategory),
      ...completedBonusToday.map((a) => a.choreCategory),
    };

    // ── Patch map and badge list ─────────────────────────────────────────────
    final updatedTotalChores = member.totalChoresCompleted + 1;
    final newCurrentBadges = [...member.badges];
    final badgeEvents = <BadgeEvent>[];
    final patchMap = <String, dynamic>{
      'roomChoresCompleted': newRoom,
      'laundryChoresCompleted': newLaundry,
      'dishChoresCompleted': newDish,
      'trashChoresCompleted': newTrash,
      'petChoresCompleted': newPet,
      'activeDays': newActiveDays,
      'allTaskDaysCompleted': newAllTaskDays,
      'peakCoins': newPeakCoins,
      if (isNewDay) 'lastActiveDate': Timestamp.fromDate(todayDate),
      if (newLastSat != member.lastSatCompleted && newLastSat != null)
        'lastSatCompleted': Timestamp.fromDate(newLastSat),
      if (newLastSun != member.lastSunCompleted && newLastSun != null)
        'lastSunCompleted': Timestamp.fromDate(newLastSun),
    };

    // ── One-time badge helper ─────────────────────────────────────────────────
    void maybeUnlock(String badgeId, bool condition) {
      if (!condition) return;
      if (newCurrentBadges.contains(badgeId)) return;
      final def = BadgeCatalog.byId(badgeId);
      if (def == null) return;
      newCurrentBadges.add(badgeId);
      final bonus = _badgeCoinBonuses[badgeId] ?? 0;
      badgeEvents.add(BadgeEvent(badge: def, coinBonus: bonus));
    }

    // ── Streak badges ─────────────────────────────────────────────────────────
    final streak = member.currentStreak;
    maybeUnlock('streak_1', streak >= 1);
    maybeUnlock('streak_3', streak >= 3);
    maybeUnlock('streak_7', streak >= 7);
    maybeUnlock('streak_15', streak >= 15);
    maybeUnlock('streak_30', streak >= 30);
    maybeUnlock('streak_60', streak >= 60);

    // ── New one-time badges ──────────────────────────────────────────────────
    maybeUnlock('first_win', updatedTotalChores == 1);

    final assignedAt = completedAssignment.assignedAt;
    final completedAt = completedAssignment.completedAt;
    if (assignedAt != null && completedAt != null) {
      maybeUnlock('fast_finisher',
          completedAt.difference(assignedAt).inMinutes < 10);
    }

    if (allRequiredDone) {
      final allBeforeNoon = completedRequiredToday.every(
        (a) => (a.completedAt?.hour ?? 12) < 12,
      );
      maybeUnlock('early_bird', allBeforeNoon);
      maybeUnlock('all_done', true);
      maybeUnlock('perfect_day', completedBonusToday.isNotEmpty);
    }

    maybeUnlock('bonus_boss', completedAssignment.bonus);

    if (newLastSat != null && newLastSun != null) {
      final diff = newLastSun.difference(newLastSat).inDays;
      maybeUnlock('weekend_warrior', diff >= 0 && diff <= 1);
    }

    if (completedAt != null) {
      maybeUnlock('sunrise_starter', completedAt.hour < 9);
      maybeUnlock('night_owl', completedAt.hour >= 20);
    }

    maybeUnlock('mix_master', categoriesCompletedToday.length >= 3);
    maybeUnlock('overachiever', completedBonusToday.length >= 2);

    final trashDoneToday = todaysAssignments
        .where((a) =>
            a.choreCategory == ChoreCategory.trash && isEffectivelyDone(a))
        .length;
    maybeUnlock('trash_trooper_daily', trashDoneToday >= 3);

    final totalDoneToday = todaysAssignments.where(isEffectivelyDone).length;
    maybeUnlock('task_crusher', totalDoneToday >= 10);

    // ── Tiered badge upgrades ─────────────────────────────────────────────────
    void maybeUpgradeTier(String baseId, int value,
        {List<int> thresholds = const [5, 15, 30]}) {
      final def = BadgeCatalog.byId(baseId);
      if (def == null) return;

      final tierList = [BadgeTier.bronze, BadgeTier.silver, BadgeTier.gold];
      BadgeTier? highestEarned;
      for (var i = 0; i < tierList.length; i++) {
        if (value >= thresholds[i]) highestEarned = tierList[i];
      }
      if (highestEarned == null) return;

      final currentTier = def.currentTierForMember(newCurrentBadges);
      if (currentTier == highestEarned) return;

      newCurrentBadges.removeWhere((id) =>
          id == '${baseId}_bronze' ||
          id == '${baseId}_silver' ||
          id == '${baseId}_gold');

      final tierLabel = BadgeCatalog.tierName(highestEarned).toLowerCase();
      newCurrentBadges.add('${baseId}_$tierLabel');
      final bonus = baseId == 'coin_collector'
          ? 0
          : (_tieredBadgeCoinBonuses[highestEarned] ?? 0);
      badgeEvents.add(BadgeEvent(badge: def, newTier: highestEarned, coinBonus: bonus));
    }

    maybeUpgradeTier('task_master', updatedTotalChores, thresholds: [25, 75, 150]);
    maybeUpgradeTier('room_rescuer', newRoom, thresholds: [25, 75, 150]);
    maybeUpgradeTier('laundry_legend', newLaundry, thresholds: [25, 75, 150]);
    maybeUpgradeTier('dish_destroyer', newDish, thresholds: [25, 75, 150]);
    maybeUpgradeTier('trash_trooper', newTrash, thresholds: [25, 75, 150]);
    maybeUpgradeTier('pet_pal', newPet, thresholds: [25, 75, 150]);
    maybeUpgradeTier('clean_sweep', newAllTaskDays, thresholds: [25, 75, 150]);
    maybeUpgradeTier('daily_helper', newActiveDays, thresholds: [25, 75, 150]);
    maybeUpgradeTier('coin_collector', newPeakCoins,
        thresholds: [50, 100, 200]);

    // ── Persist in one write ─────────────────────────────────────────────────
    final totalBonusCoins = badgeEvents.fold(0, (acc, e) => acc + e.coinBonus);
    if (totalBonusCoins > 0) {
      patchMap['coins'] = FieldValue.increment(totalBonusCoins);
    }
    patchMap['badges'] = newCurrentBadges;
    await updateMember(memberId, patchMap);

    return badgeEvents;
  }

  /// Kept for backwards compatibility.
  Future<List<BadgeDefinition>> checkAndAwardStreakBadgesForKid(
    String memberId,
  ) async =>
      const [];
}
