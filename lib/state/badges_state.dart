// lib/state/app_state_badges.dart
part of 'app_state.dart';

extension BadgeStateAuth on AppState {
  /// Check the kid's current streak and award any new streak badges.
  /// Returns the list of BadgeDefinitions that were newly unlocked.
  Future<List<BadgeDefinition>> checkAndAwardStreakBadgesForKid(
    String memberId,
  ) async {
    final member =
        members.firstWhere((m) => m.id == memberId, orElse: () => throw Exception('Member not found'));

    final currentStreak = member.currentStreak;
    if (currentStreak <= 0) return const [];

    final newBadgeIds = <String>[];

    void maybeUnlock(String badgeId, bool condition) {
      if (!condition) return;
      if (member.badges.contains(badgeId)) return;
      newBadgeIds.add(badgeId);
    }

    maybeUnlock('streak_3_days', currentStreak >= 3);
    maybeUnlock('streak_7_days', currentStreak >= 7);
    maybeUnlock('streak_14_days', currentStreak >= 14);
    maybeUnlock('streak_30_days', currentStreak >= 30);

    if (newBadgeIds.isEmpty) return const [];

    final updatedBadges = [...member.badges, ...newBadgeIds];

    // Persist badges to Firestore (and local cache via existing helper).
    await updateMember(member.id, {
      'badges': updatedBadges,
    });

    // Return full badge definitions for UI celebrations.
    final unlockedDefs = <BadgeDefinition>[];
    for (final id in newBadgeIds) {
      final def = BadgeCatalog.byId(id);
      if (def != null) unlockedDefs.add(def);
    }
    return unlockedDefs;
  }
}
