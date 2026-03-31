import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/reward.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Hard limits for free-tier families.
class SubscriptionLimits {
  static const int freeKids = 2;
  static const int freeCustomChores = 3;
  static const int freeCustomRewards = 3;
  static const int freeHistoryDays = 14;
}

/// Stateless helpers for checking subscription gates.
/// All methods accept a nullable [Family] — null is treated as free tier.
class SubscriptionService {
  const SubscriptionService._();

  static bool isPremium(Family? family) => family?.isPremium ?? false;

  /// Returns true if the family can add another kid.
  static bool canAddKid(Family? family, int currentKidCount) {
    if (isPremium(family)) return true;
    return currentKidCount < SubscriptionLimits.freeKids;
  }

  /// Returns true if the family can create another custom chore.
  static bool canAddCustomChore(Family? family, int currentCustomChoreCount) {
    if (isPremium(family)) return true;
    return currentCustomChoreCount < SubscriptionLimits.freeCustomChores;
  }

  /// Returns true if the family can create another custom reward.
  static bool canAddCustomReward(Family? family, int currentCustomRewardCount) {
    if (isPremium(family)) return true;
    return currentCustomRewardCount < SubscriptionLimits.freeCustomRewards;
  }

  /// Returns the max days of history to show. 0 means unlimited (premium).
  static int historyDaysLimit(Family? family) {
    if (isPremium(family)) return 0;
    return SubscriptionLimits.freeHistoryDays;
  }

  // ---------------------------------------------------------------------------
  // Degradation helpers (lapsed premium)
  // ---------------------------------------------------------------------------

  /// Returns true if a kid is in limited mode (3rd+ kid by creation date
  /// when the family is not premium). Limited kids can't earn coins, open
  /// loot boxes, or purchase cosmetics.
  static bool isKidLimited(Family? family, Member kid, List<Member> allKids) {
    if (isPremium(family)) return false;
    if (kid.role != FamilyRole.child) return false;

    // Sort kids by createdAt ascending; oldest 2 are unrestricted.
    final sortedKids = allKids
        .where((m) => m.role == FamilyRole.child)
        .toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2100);
        final bDate = b.createdAt ?? DateTime(2100);
        return aDate.compareTo(bDate);
      });

    final index = sortedKids.indexWhere((m) => m.id == kid.id);
    return index >= SubscriptionLimits.freeKids;
  }

  /// Returns true if a specific custom chore is usable (within the oldest 3).
  /// Chores beyond the free limit are visible but disabled.
  static bool isCustomChoreActive(
    Family? family,
    Chore chore,
    List<Chore> allChores,
  ) {
    if (isPremium(family)) return true;
    if (!chore.isCustom) return true;

    final customChores = allChores.where((c) => c.isCustom).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2100);
        final bDate = b.createdAt ?? DateTime(2100);
        return aDate.compareTo(bDate);
      });

    final index = customChores.indexWhere((c) => c.id == chore.id);
    return index < SubscriptionLimits.freeCustomChores;
  }

  /// Returns true if a specific custom reward is usable (within the oldest 3).
  /// Rewards beyond the free limit are visible but disabled.
  static bool isCustomRewardActive(
    Family? family,
    Reward reward,
    List<Reward> allRewards,
  ) {
    if (isPremium(family)) return true;
    if (!reward.isCustom) return true;

    final customRewards = allRewards.where((r) => r.isCustom).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2100);
        final bDate = b.createdAt ?? DateTime(2100);
        return aDate.compareTo(bDate);
      });

    final index = customRewards.indexWhere((r) => r.id == reward.id);
    return index < SubscriptionLimits.freeCustomRewards;
  }

  /// Returns true if the current user is a co-parent (not the owner) and
  /// the family is no longer premium, meaning they should be read-only.
  static bool isCoParentReadOnly(
    Family? family,
    String? currentUserUid,
  ) {
    if (isPremium(family)) return false;
    if (family == null || currentUserUid == null) return false;
    // If they're not the owner, they're a co-parent.
    return currentUserUid != family.ownerUid;
  }

  /// Convenience guard for co-parent read-only mode.
  /// Returns true (and shows a snackbar) if the current user is a read-only
  /// co-parent. Use as an early return in action handlers.
  static bool guardCoParentReadOnly(BuildContext context) {
    final app = context.read<AppState>();
    if (!isCoParentReadOnly(app.family, app.firebaseUser?.uid)) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your account is read-only. Ask the family owner to renew premium.',
        ),
      ),
    );
    return true;
  }
}
