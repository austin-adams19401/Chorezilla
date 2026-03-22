// lib/models/badge.dart

import 'package:chorezilla/models/member.dart';

enum BadgeType { streak, chores, coins, special, oneTime, tiered }

enum BadgeTier { locked, bronze, silver, gold }

// ---------------------------------------------------------------------------
// TierDef — defines one tier threshold + optional image asset path
// ---------------------------------------------------------------------------
class TierDef {
  final BadgeTier tier;
  final int threshold;
  /// Asset path relative to assets/, e.g. 'assets/badges/tiered-badges/task-bronze.png'.
  /// If null, the badge falls back to its emoji icon.
  final String? assetPath;

  const TierDef({
    required this.tier,
    required this.threshold,
    this.assetPath,
  });
}

// ---------------------------------------------------------------------------
// BadgeDefinition
// ---------------------------------------------------------------------------
class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final String unlockHint;
  final String icon; // Emoji fallback
  final BadgeType type;

  /// For one-time badges: optional image asset.
  final String? assetPath;

  /// For tiered badges: the three tier definitions in order bronze→silver→gold.
  final List<TierDef>? tiers;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockHint,
    required this.icon,
    required this.type,
    this.assetPath,
    this.tiers,
  });

  bool get isTiered => type == BadgeType.tiered;

  // ---- Tier helpers --------------------------------------------------------

  /// Returns the current tier for this badge based on member.badges.
  BadgeTier currentTierForMember(List<String> memberBadges) {
    if (!isTiered) {
      return memberBadges.contains(id) ? BadgeTier.gold : BadgeTier.locked;
    }
    if (memberBadges.contains('${id}_gold')) return BadgeTier.gold;
    if (memberBadges.contains('${id}_silver')) return BadgeTier.silver;
    if (memberBadges.contains('${id}_bronze')) return BadgeTier.bronze;
    return BadgeTier.locked;
  }

  /// Returns the asset path for the given tier, or null to use emoji.
  String? assetPathForTier(BadgeTier tier) {
    if (!isTiered) return assetPath;
    if (tiers == null) return null;
    try {
      return tiers!.firstWhere((t) => t.tier == tier).assetPath;
    } catch (_) {
      return null;
    }
  }

  /// Returns 0.0–1.0 progress toward the next tier (or 1.0 if maxed/earned).
  double progressForMember(Member member) {
    if (!isTiered) {
      return member.badges.contains(id) ? 1.0 : 0.0;
    }
    final current = _counterForMember(member);
    final currentTier = currentTierForMember(member.badges);

    if (currentTier == BadgeTier.gold) return 1.0;

    final nextTier = _nextTier(currentTier);
    if (nextTier == null || tiers == null) return 0.0;

    final nextThreshold = tiers!.firstWhere((t) => t.tier == nextTier).threshold;
    final prevThreshold = currentTier == BadgeTier.locked
        ? 0
        : tiers!.firstWhere((t) => t.tier == currentTier).threshold;

    final progress = (current - prevThreshold) / (nextThreshold - prevThreshold);
    return progress.clamp(0.0, 1.0);
  }

  /// Returns current counter value for this tiered badge from member fields.
  int counterForMember(Member member) => _counterForMember(member);

  int _counterForMember(Member member) {
    switch (id) {
      case 'task_master':
        return member.totalChoresCompleted;
      case 'room_rescuer':
        return member.roomChoresCompleted;
      case 'laundry_legend':
        return member.laundryChoresCompleted;
      case 'dish_destroyer':
        return member.dishChoresCompleted;
      case 'trash_trooper':
        return member.trashChoresCompleted;
      case 'pet_pal':
        return member.petChoresCompleted;
      case 'clean_sweep':
        return member.allTaskDaysCompleted;
      case 'daily_helper':
        return member.activeDays;
      case 'coin_collector':
        return member.peakCoins;
      default:
        return 0;
    }
  }

  /// Returns the next threshold value (for "X / Y" display), or null if maxed.
  int? nextThresholdForMember(Member member) {
    if (!isTiered || tiers == null) return null;
    final currentTier = currentTierForMember(member.badges);
    if (currentTier == BadgeTier.gold) return null;
    final next = _nextTier(currentTier);
    if (next == null) return null;
    return tiers!.firstWhere((t) => t.tier == next).threshold;
  }

  static BadgeTier? _nextTier(BadgeTier current) {
    switch (current) {
      case BadgeTier.locked:
        return BadgeTier.bronze;
      case BadgeTier.bronze:
        return BadgeTier.silver;
      case BadgeTier.silver:
        return BadgeTier.gold;
      case BadgeTier.gold:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// BadgeEvent — returned from checkAndAwardBadgesForKid
// ---------------------------------------------------------------------------
class BadgeEvent {
  final BadgeDefinition badge;
  /// null for one-time badges; the newly earned/upgraded tier for tiered badges.
  final BadgeTier? newTier;
  /// Coin bonus awarded when this badge is earned or upgraded. 0 if no bonus.
  final int coinBonus;

  const BadgeEvent({required this.badge, this.newTier, this.coinBonus = 0});

  String get dialogTitle {
    if (newTier == null) return 'Badge Unlocked!';
    switch (newTier!) {
      case BadgeTier.bronze:
        return 'Bronze Earned!';
      case BadgeTier.silver:
        return 'Upgraded to Silver!';
      case BadgeTier.gold:
        return 'Upgraded to Gold!';
      case BadgeTier.locked:
        return 'Badge Unlocked!';
    }
  }
}

// ---------------------------------------------------------------------------
// BadgeCatalog
// ---------------------------------------------------------------------------
class BadgeCatalog {
  static const List<BadgeDefinition> items = [

    // ── Streak badges ────────────────────────────────────────────────────────
    BadgeDefinition(
      id: 'streak_1',
      name: 'Day One Done',
      description: 'You started your streak!',
      unlockHint: 'Complete chores 1 day in a row.',
      icon: '🔥',
      type: BadgeType.streak,
      assetPath: 'assets/badges/one-time-badges/day-one-done.png',
    ),
    BadgeDefinition(
      id: 'streak_3',
      name: '3-Day Streaker',
      description: 'Three days in a row — you\'re on fire!',
      unlockHint: 'Complete chores 3 days in a row.',
      icon: '🔥',
      type: BadgeType.streak,
      assetPath: 'assets/badges/one-time-badges/3-day-streaker.png',
    ),
    BadgeDefinition(
      id: 'streak_7',
      name: 'Week Warrior',
      description: 'A full week of chores — incredible!',
      unlockHint: 'Complete chores 7 days in a row.',
      icon: '🔥',
      type: BadgeType.streak,
      assetPath: 'assets/badges/one-time-badges/week-warrior.png',
    ),
    BadgeDefinition(
      id: 'streak_15',
      name: '15-Day Machine',
      description: 'Halfway to a month — you\'re a machine!',
      unlockHint: 'Complete chores 15 days in a row.',
      icon: '🔥',
      type: BadgeType.streak,
      assetPath: 'assets/badges/one-time-badges/15-day-machine.png',
    ),
    BadgeDefinition(
      id: 'streak_30',
      name: 'Monthly Master',
      description: 'An entire month without breaking the chain!',
      unlockHint: 'Complete chores 30 days in a row.',
      icon: '🔥🔥',
      type: BadgeType.streak,
      assetPath: 'assets/badges/one-time-badges/monthly-master.png',
    ),
    BadgeDefinition(
      id: 'streak_60',
      name: 'Unstoppable Legend',
      description: 'Two months straight — you are LEGENDARY!',
      unlockHint: 'Complete chores 60 days in a row.',
      icon: '🔥🔥🔥',
      type: BadgeType.streak,
      assetPath: 'assets/badges/one-time-badges/unstoppable-legend.png',
    ),

    // ── One-time badges ──────────────────────────────────────────────────────
    BadgeDefinition(
      id: 'first_win',
      name: 'First Win',
      description: 'You completed your very first task!',
      unlockHint: 'Complete your first task.',
      icon: '🏅',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/first-win.png',
    ),
    BadgeDefinition(
      id: 'fast_finisher',
      name: 'Fast Finisher',
      description: 'You finished a task within 10 minutes of getting it!',
      unlockHint: 'Complete a task within 10 minutes of assignment.',
      icon: '⚡',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/fast-finisher.png',
    ),
    BadgeDefinition(
      id: 'early_bird',
      name: 'Early Bird',
      description: 'All your daily tasks done before noon!',
      unlockHint: 'Complete all daily tasks before 12 PM.',
      icon: '🌤️',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/early-bird.png',
    ),
    BadgeDefinition(
      id: 'all_done',
      name: 'All Done',
      description: 'You finished every assigned task in one day!',
      unlockHint: 'Complete all assigned tasks in a single day.',
      icon: '📋',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/getting-started.png',
    ),
    BadgeDefinition(
      id: 'bonus_boss',
      name: 'Bonus Boss',
      description: 'You went above and beyond with a bonus task!',
      unlockHint: 'Complete a bonus task.',
      icon: '🎯',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/bonus-boss.png',
    ),
    BadgeDefinition(
      id: 'weekend_warrior',
      name: 'Weekend Warrior',
      description: 'You worked on both Saturday AND Sunday!',
      unlockHint: 'Complete at least 1 task on Saturday AND Sunday in the same weekend.',
      icon: '🏕️',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/weekend-warrior.png',
    ),
    BadgeDefinition(
      id: 'sunrise_starter',
      name: 'Sunrise Starter',
      description: 'Up early and already getting things done!',
      unlockHint: 'Complete a task before 7 AM.',
      icon: '🌅',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/sunrise-starter.png',
    ),
    BadgeDefinition(
      id: 'night_owl',
      name: 'Night Owl',
      description: 'Still helping out after 8 PM!',
      unlockHint: 'Complete a task after 8 PM.',
      icon: '🦉',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/night-owl.png',
    ),
    BadgeDefinition(
      id: 'perfect_day',
      name: 'Perfect Day',
      description: 'All tasks done AND a bonus task — that\'s a perfect day!',
      unlockHint: 'Complete all tasks AND a bonus task in the same day.',
      icon: '⭐',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/perfect-day.png',
    ),
    BadgeDefinition(
      id: 'mix_master',
      name: 'Mix Master',
      description: 'You tackled 3 different types of chores in one day!',
      unlockHint: 'Complete 3 different chore types in one day.',
      icon: '🎨',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/mix-master.png',
    ),
    BadgeDefinition(
      id: 'overachiever',
      name: 'Overachiever',
      description: 'Two bonus tasks in one day? You\'re unstoppable!',
      unlockHint: 'Complete 2 or more bonus tasks in a single day.',
      icon: '🚀',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/overachiever.png',
    ),
    BadgeDefinition(
      id: 'trash_trooper_daily',
      name: 'Trash Trooper',
      description: 'You knocked out 3 trash chores in a single day!',
      unlockHint: 'Complete 3 trash chores in one day.',
      icon: '🗑️',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/trash-trooper.png',
    ),
    BadgeDefinition(
      id: 'task_crusher',
      name: 'Task Crusher',
      description: 'You crushed 10 chores in a single day — that\'s incredible!',
      unlockHint: 'Complete 10 chores in one day.',
      icon: '💪',
      type: BadgeType.oneTime,
      assetPath: 'assets/badges/one-time-badges/task-crusher.png',
    ),

    // ── Tiered badges ────────────────────────────────────────────────────────
    BadgeDefinition(
      id: 'task_master',
      name: 'Task Master',
      description: 'Complete tasks to level this up!',
      unlockHint: 'Complete tasks (Bronze: 5, Silver: 15, Gold: 30).',
      icon: '📈',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 5,  assetPath: 'assets/badges/tiered-badges/task-bronze.png'),
        TierDef(tier: BadgeTier.silver, threshold: 15, assetPath: 'assets/badges/tiered-badges/task-silver.png'),
        TierDef(tier: BadgeTier.gold,   threshold: 30, assetPath: 'assets/badges/tiered-badges/task-gold.png'),
      ],
    ),
    BadgeDefinition(
      id: 'room_rescuer',
      name: 'Room Rescuer',
      description: 'Keep those rooms clean!',
      unlockHint: 'Complete cleaning-type tasks (Bronze: 5, Silver: 15, Gold: 30).',
      icon: '🧹',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 5,  assetPath: 'assets/badges/tiered-badges/room-bronze.png'),
        TierDef(tier: BadgeTier.silver, threshold: 15, assetPath: 'assets/badges/tiered-badges/room-silver.png'),
        TierDef(tier: BadgeTier.gold,   threshold: 30, assetPath: 'assets/badges/tiered-badges/room-gold.png'),
      ],
    ),
    BadgeDefinition(
      id: 'laundry_legend',
      name: 'Laundry Legend',
      description: 'Laundry? No problem!',
      unlockHint: 'Complete laundry tasks (Bronze: 5, Silver: 15, Gold: 30).',
      icon: '🧺',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 5,  assetPath: 'assets/badges/tiered-badges/bronze-laundry.png'),
        TierDef(tier: BadgeTier.silver, threshold: 15, assetPath: 'assets/badges/tiered-badges/silver-laundry.png'),
        TierDef(tier: BadgeTier.gold,   threshold: 30, assetPath: 'assets/badges/tiered-badges/gold-laundry.png'),
      ],
    ),
    BadgeDefinition(
      id: 'dish_destroyer',
      name: 'Dish Destroyer',
      description: 'Crushing those dishes!',
      unlockHint: 'Complete dish-related tasks (Bronze: 5, Silver: 15, Gold: 30).',
      icon: '🍽️',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 5,  assetPath: 'assets/badges/tiered-badges/bronze-dish.png'),
        TierDef(tier: BadgeTier.silver, threshold: 15, assetPath: 'assets/badges/tiered-badges/silver-dish.png'),
        TierDef(tier: BadgeTier.gold,   threshold: 30, assetPath: 'assets/badges/one-time-badges/dish-destroyer.png'),
      ],
    ),
    BadgeDefinition(
      id: 'trash_trooper',
      name: 'Trash Trooper',
      description: 'Taking out the trash like a pro!',
      unlockHint: 'Complete trash tasks (Bronze: 5, Silver: 15, Gold: 30).',
      icon: '🗑️',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 5,  assetPath: 'assets/badges/tiered-badges/bronze-trash.png'),
        TierDef(tier: BadgeTier.silver, threshold: 15), // no silver asset yet
        TierDef(tier: BadgeTier.gold,   threshold: 30), // no gold asset yet
      ],
    ),
    BadgeDefinition(
      id: 'pet_pal',
      name: 'Pet Pal',
      description: 'Taking great care of your furry friends!',
      unlockHint: 'Complete pet-care tasks (Bronze: 5, Silver: 15, Gold: 30).',
      icon: '🐾',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 5,  assetPath: 'assets/badges/one-time-badges/pet-pal.png'),
        TierDef(tier: BadgeTier.silver, threshold: 15, assetPath: 'assets/badges/one-time-badges/pet-pal.png'),
        TierDef(tier: BadgeTier.gold,   threshold: 30, assetPath: 'assets/badges/one-time-badges/pet-pal.png'),
      ],
    ),
    BadgeDefinition(
      id: 'clean_sweep',
      name: 'Clean Sweep',
      description: 'Finishing every task for the day!',
      unlockHint: 'Complete ALL assigned tasks in a day (Bronze: 5 days, Silver: 15 days, Gold: 30 days).',
      icon: '🎯',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 5),
        TierDef(tier: BadgeTier.silver, threshold: 15),
        TierDef(tier: BadgeTier.gold,   threshold: 30),
      ],
    ),
    BadgeDefinition(
      id: 'daily_helper',
      name: 'Daily Helper',
      description: 'Showing up every day!',
      unlockHint: 'Complete at least 1 task per day (Bronze: 5 days, Silver: 15 days, Gold: 30 days).',
      icon: '🔁',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 5,  assetPath: 'assets/badges/one-time-badges/chore-machine.png'),
        TierDef(tier: BadgeTier.silver, threshold: 15, assetPath: 'assets/badges/one-time-badges/chore-machine.png'),
        TierDef(tier: BadgeTier.gold,   threshold: 30, assetPath: 'assets/badges/one-time-badges/chore-machine.png'),
      ],
    ),
    BadgeDefinition(
      id: 'coin_collector',
      name: 'Coin Collector',
      description: 'Stacking up those coins!',
      unlockHint: 'Reach a peak coin balance (Bronze: 50, Silver: 100, Gold: 200).',
      icon: '💰',
      type: BadgeType.tiered,
      tiers: [
        TierDef(tier: BadgeTier.bronze, threshold: 50),
        TierDef(tier: BadgeTier.silver, threshold: 100),
        TierDef(tier: BadgeTier.gold,   threshold: 200),
      ],
    ),
  ];

  static BadgeDefinition? byId(String id) {
    try {
      return items.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find by tiered base ID from a full tier ID like 'task_master_bronze'.
  static BadgeDefinition? byTieredId(String tieredId) {
    for (final b in items) {
      if (!b.isTiered) continue;
      if (tieredId == '${b.id}_bronze' ||
          tieredId == '${b.id}_silver' ||
          tieredId == '${b.id}_gold') {
        return b;
      }
    }
    return null;
  }

  static Iterable<BadgeDefinition> oneTimeBadges() =>
      items.where((b) => b.type == BadgeType.oneTime);

  static Iterable<BadgeDefinition> tieredBadges() =>
      items.where((b) => b.type == BadgeType.tiered);

  static Iterable<BadgeDefinition> streakBadges() =>
      items.where((b) => b.type == BadgeType.streak);

  static Iterable<BadgeDefinition> choresBadges() =>
      items.where((b) => b.type == BadgeType.chores);

  static String tierName(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.locked:
        return 'Locked';
      case BadgeTier.bronze:
        return 'Bronze';
      case BadgeTier.silver:
        return 'Silver';
      case BadgeTier.gold:
        return 'Gold';
    }
  }
}
