import 'package:chorezilla/models/family.dart';

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
}
