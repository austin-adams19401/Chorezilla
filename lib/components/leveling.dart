// lib/components/leveling.dart

import 'package:chorezilla/models/cosmetics.dart';

class LevelInfo {
  final int level;
  final int xpStartOfLevel; // total XP at the start of this level
  final int xpForNextLevel; // total XP needed to reach the next level
  final int xpIntoLevel; // XP earned within this level
  final int xpNeededThisLevel; // XP required within this level
  final double progress; // 0.0–1.0

  const LevelInfo({
    required this.level,
    required this.xpStartOfLevel,
    required this.xpForNextLevel,
    required this.xpIntoLevel,
    required this.xpNeededThisLevel,
    required this.progress,
  });
}

/// XP needed to *reach* a given level (total XP, not “within” level).
///
/// Pacing at ~100 XP/day (medium chores):
///   Level 1→5  ≈ 1 week   (quick early rewards to get kids engaged)
///   Level 5→10 ≈ 6 weeks  (gaps grow each level)
///   Level 10+  ≈ gap grows ~30% per level (compounding)
///
/// Gap per level:
///   1→2:  100   2→3:  150   3→4:  200   4→5:  250
///   5→6:  350   6→7:  500   7→8:  700   8→9:  950   9→10: 1250
///   10→11: ~1625  11→12: ~2110  (×1.3 each level after 10)
int xpForLevel(int level) {
  if (level <= 1) return 0;

  // Total XP to *reach* each level (index = level - 1).
  const thresholds = <int>[
    0,    // Level 1
    100,  // Level 2  — gap: 100
    250,  // Level 3  — gap: 150
    450,  // Level 4  — gap: 200
    700,  // Level 5  — gap: 250
    1050, // Level 6  — gap: 350
    1550, // Level 7  — gap: 500
    2250, // Level 8  — gap: 700
    3200, // Level 9  — gap: 950
    4450, // Level 10 — gap: 1250
  ];

  final idx = level - 1;
  if (idx < thresholds.length) {
    return thresholds[idx];
  }

  // Level 11+: compound the gap by 30% each level starting from 1250.
  var xp = thresholds.last; // 4450
  var gap = 1250;
  final extraLevels = level - thresholds.length; // levels above 10
  for (var i = 0; i < extraLevels; i++) {
    gap = (gap * 1.3).round();
    xp += gap;
  }
  return xp;
}

/// Compute level + progress for a given total XP.
LevelInfo levelInfoForXp(int totalXp) {
  var xp = totalXp;
  if (xp < 0) xp = 0;

  // Find the level such that:
  // xpForLevel(L) <= xp < xpForLevel(L+1)
  int level = 1;
  while (xp >= xpForLevel(level + 1)) {
    level++;
    if (level > 1000) break; // safety guard
  }

  final start = xpForLevel(level);
  final next = xpForLevel(level + 1);
  final into = xp - start;
  final span = (next - start).clamp(1, 1 << 30); // avoid divide-by-zero

  final prog = (into.clamp(0, span) / span);

  return LevelInfo(
    level: level,
    xpStartOfLevel: start,
    xpForNextLevel: next,
    xpIntoLevel: into,
    xpNeededThisLevel: span,
    progress: prog,
  );
}

/// A cosmetic / perk reward unlocked at a specific level.
class LevelRewardDefinition {
  final int level;
  final String emoji;
  final String title;
  final String description;
  /// If set, this in-game cosmetic ID is auto-granted to the kid on level-up.
  final String? cosmeticId;

  const LevelRewardDefinition({
    required this.level,
    required this.emoji,
    required this.title,
    required this.description,
    this.cosmeticId,
  });

  Map<String, dynamic> toMap() => {
        'emoji': emoji,
        'title': title,
        'description': description,
        if (cosmeticId != null) 'cosmeticId': cosmeticId,
      };

  factory LevelRewardDefinition.fromMap(int level, Map<String, dynamic> m) =>
      LevelRewardDefinition(
        level: level,
        emoji: m['emoji'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        cosmeticId: m['cosmeticId'] as String?,
      );
}

/// Default level-up rewards — a mix of real-world perks and in-game cosmetic unlocks.
/// Cosmetic rewards (cosmeticId set) are auto-granted on level-up.
const List<LevelRewardDefinition> kDefaultLevelRewards = [
  LevelRewardDefinition(
    level: 2,
    emoji: '🍬',
    title: 'Small Treat',
    description: 'Pick a small snack or candy.',
  ),
  LevelRewardDefinition(
    level: 3,
    emoji: '🦎',
    title: 'Sky Blue Zilla Skin!',
    description: 'Your Zilla turns sky blue — auto-unlocked!',
    cosmeticId: 'zilla_sky_blue',
  ),
  LevelRewardDefinition(
    level: 4,
    emoji: '🎬',
    title: 'Pick the Movie',
    description: 'Choose the show or movie to watch tonight.',
  ),
  LevelRewardDefinition(
    level: 5,
    emoji: '💵',
    title: '\$5 to Spend',
    description: 'Five dollars to spend however you want — you earned it!',
  ),
  LevelRewardDefinition(
    level: 6,
    emoji: '🦕',
    title: 'Dino World Background!',
    description: 'Your Zilla now roams a prehistoric world — auto-unlocked!',
    cosmeticId: 'bg_dino',
  ),
  LevelRewardDefinition(
    level: 7,
    emoji: '💻',
    title: 'Extra Screen Time',
    description: 'Earn 60 minutes of bonus screen time.',
  ),
  LevelRewardDefinition(
    level: 8,
    emoji: '⭐',
    title: 'Starry Frame!',
    description: 'A gold star border for your avatar — auto-unlocked!',
    cosmeticId: 'frame_stars',
  ),
  LevelRewardDefinition(
    level: 9,
    emoji: '🎮',
    title: 'Game Night',
    description: '1 hour game night with Mom or Dad.',
  ),
  LevelRewardDefinition(
    level: 10,
    emoji: '💰',
    title: '\$10 to Spend',
    description: 'You earn a \$10 bill — nice work!',
  ),
  LevelRewardDefinition(
    level: 11,
    emoji: '🦎',
    title: 'Coral Zilla Skin!',
    description: 'Your Zilla glows coral orange — auto-unlocked!',
    cosmeticId: 'zilla_coral',
  ),
  LevelRewardDefinition(
    level: 12,
    emoji: '👫',
    title: 'Parents Do Your Chores',
    description: 'Mom and Dad do your chores for the day.',
  ),
  LevelRewardDefinition(
    level: 13,
    emoji: '🌊',
    title: 'Ocean Background!',
    description: 'Deep blue waves behind your Zilla — auto-unlocked!',
    cosmeticId: 'bg_ocean',
  ),
  LevelRewardDefinition(
    level: 14,
    emoji: '🛋',
    title: 'Late Bedtime',
    description: 'Stay up 30 minutes later than usual.',
  ),
  LevelRewardDefinition(
    level: 15,
    emoji: '🍕',
    title: 'Pizza Night',
    description: 'The whole family is having pizza — your pick!',
  ),
  LevelRewardDefinition(
    level: 16,
    emoji: '🦎',
    title: 'Purple Zilla Skin!',
    description: 'Royally cool — your Zilla goes purple! Auto-unlocked.',
    cosmeticId: 'zilla_purple',
  ),
  LevelRewardDefinition(
    level: 17,
    emoji: '👨‍👩‍👦',
    title: 'Date Night',
    description: 'A special one-on-one date night with Mom or Dad.',
  ),
  LevelRewardDefinition(
    level: 18,
    emoji: '🌈',
    title: 'Rainbow Frame!',
    description: 'All the colors around your avatar — auto-unlocked!',
    cosmeticId: 'frame_rainbow',
  ),
  LevelRewardDefinition(
    level: 19,
    emoji: '🏆',
    title: 'Gold Zilla Skin!',
    description: 'Champion status. Your Zilla shines gold — auto-unlocked!',
    cosmeticId: 'zilla_gold',
  ),
  LevelRewardDefinition(
    level: 20,
    emoji: '🕹️',
    title: 'Arcade Day',
    description: 'A trip to the arcade — you made it to level 20!',
  ),
];

/// All rewards for a specific level.
/// If [customRewards] is provided (premium families), those override the defaults.
List<LevelRewardDefinition> levelRewardsForLevel(
  int level, {
  Map<int, List<LevelRewardDefinition>>? customRewards,
}) {
  if (customRewards != null) {
    final custom = customRewards[level];
    if (custom != null && custom.isNotEmpty) return custom;
  }
  return kDefaultLevelRewards.where((r) => r.level == level).toList();
}

/// First reward for this exact level, if any.
/// Pass [customRewards] (from premium family settings) to use family overrides.
LevelRewardDefinition? levelRewardForLevel(
  int level, {
  Map<int, List<LevelRewardDefinition>>? customRewards,
}) {
  final list = levelRewardsForLevel(level, customRewards: customRewards);
  return list.isEmpty ? null : list.first;
}

/// Next upcoming reward *after* the given level, if any.
/// Pass [customRewards] (from premium family settings) to use family overrides.
LevelRewardDefinition? nextLevelRewardFromLevel(
  int currentLevel, {
  Map<int, List<LevelRewardDefinition>>? customRewards,
}) {
  final source = customRewards != null && customRewards.isNotEmpty
      ? [
          for (final entry in customRewards.entries)
            ...entry.value.map((r) => LevelRewardDefinition(
                  level: entry.key,
                  emoji: r.emoji,
                  title: r.title,
                  description: r.description,
                  cosmeticId: r.cosmeticId,
                )),
        ]
      : kDefaultLevelRewards;

  LevelRewardDefinition? best;
  for (final def in source) {
    if (def.level > currentLevel) {
      if (best == null || def.level < best.level) {
        best = def;
      }
    }
  }
  return best;
}

/// Returns the title cosmetic awarded at [level] (levels 1–20), or null if none.
CosmeticItem? titleForLevel(int level) {
  if (level < 1 || level > 20) return null;
  final id = 'title_level_$level';
  try {
    return CosmeticCatalog.items.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}

