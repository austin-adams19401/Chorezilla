// lib/state/app_state_badges.dart
part of 'app_state.dart';

extension BadgeStateAuth on AppState {
  /// Check all badge conditions and award any newly unlocked badges.
  /// Returns the list of BadgeDefinitions that were newly unlocked.
  Future<List<BadgeDefinition>> checkAndAwardBadgesForKid(
    String memberId,
  ) async {
    final member = members.firstWhere(
      (m) => m.id == memberId,
      orElse: () => throw Exception('Member not found'),
    );

    final newBadgeIds = <String>[];

    void maybeUnlock(String badgeId, bool condition) {
      if (!condition) return;
      if (member.badges.contains(badgeId)) return;
      newBadgeIds.add(badgeId);
    }

    // Streak badges
    final streak = member.currentStreak;
    maybeUnlock('streak_3_days', streak >= 3);
    maybeUnlock('streak_7_days', streak >= 7);
    maybeUnlock('streak_14_days', streak >= 14);
    maybeUnlock('streak_30_days', streak >= 30);

    // Chore-count badges
    final total = member.totalChoresCompleted;
    maybeUnlock('chores_1', total >= 1);
    maybeUnlock('chores_10', total >= 10);
    maybeUnlock('chores_25', total >= 25);
    maybeUnlock('chores_50', total >= 50);
    maybeUnlock('chores_100', total >= 100);

    if (newBadgeIds.isEmpty) return const [];

    final updatedBadges = [...member.badges, ...newBadgeIds];

    await updateMember(member.id, {'badges': updatedBadges});

    final unlockedDefs = <BadgeDefinition>[];
    for (final id in newBadgeIds) {
      final def = BadgeCatalog.byId(id);
      if (def != null) unlockedDefs.add(def);
    }
    return unlockedDefs;
  }

  /// Kept for backwards compatibility — delegates to checkAndAwardBadgesForKid.
  Future<List<BadgeDefinition>> checkAndAwardStreakBadgesForKid(
    String memberId,
  ) => checkAndAwardBadgesForKid(memberId);
}
