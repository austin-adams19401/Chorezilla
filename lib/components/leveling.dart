// lib/models/leveling.dart

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
/// Level 1 → 0 XP (start)
/// Level 2 → 100 XP
/// Level 3 → 240 XP
/// Level 4 → 450 XP
/// Level 5 → 700 XP
/// Level 6+ → +300 XP per level (simple tail rule you can tweak)
int xpForLevel(int level) {
  if (level <= 1) return 0;

  // Early levels: hand-tuned thresholds
  const thresholds = <int>[
    0, // index 0 → Level 1
    100, // index 1 → Level 2
    240, // index 2 → Level 3
    450, // index 3 → Level 4
    700, // index 4 → Level 5
  ];

  final idx = level - 1;

  if (idx < thresholds.length) {
    return thresholds[idx];
  }

  // For higher levels, grow linearly after Level 5.
  const tailStep = 300; // XP per level after 5 (tweakable)
  final lastKnownLevel = thresholds.length; // 5
  final lastKnownXp = thresholds.last; // 700

  final extraLevels = level - lastKnownLevel;
  return lastKnownXp + extraLevels * tailStep;
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
/// For now this is a static config; later we can move to Firestore.
class LevelRewardDefinition {
  final int level;
  final String emoji;
  final String title;
  final String description;

  const LevelRewardDefinition({
    required this.level,
    required this.emoji,
    required this.title,
    required this.description,
  });
}

/// Default level-up rewards (v2 baseline).
///
/// You can tweak these anytime, or later replace with per-family config.
const List<LevelRewardDefinition> kDefaultLevelRewards = [
  LevelRewardDefinition(
    level: 2,
    emoji: '🍬',
    title: 'Small Treat',
    description: 'Pick a small snack or candy.',
  ),
    LevelRewardDefinition(
    level: 3,
    emoji: '🎬',
    title: 'Pick the movie',
    description: 'Choose the show to watch.',
  ),
    LevelRewardDefinition(
    level: 4,
    emoji: '🎖',
    title: 'Treasure Box Prize',
    description: 'Pick 2 prizes from the treasure box.',
  ),
  LevelRewardDefinition(
    level: 5,
    emoji: '🧱',
    title: 'Room Decoration',
    description: 'Pick out a decoration for your room',
  ),
    LevelRewardDefinition(
    level: 6,
    emoji: '💻',
    title: 'Extra Screen Time',
    description: 'Earn 60 minutes of bonus screen time.',
  ),
    LevelRewardDefinition(
    level: 7,
    emoji: '🎮',
    title: 'Game Night',
    description: '1 hour game night with Mom or Dad',
  ),
  LevelRewardDefinition(
    level: 8,
    emoji: '🛏',
    title: 'Late Bedtime',
    description: 'Stay up 30 minutes later than usual.',
  ),
    LevelRewardDefinition(
    level: 9,
    emoji: '🍭',
    title: 'Gas Station Treats',
    description: 'Pick out a drink and a snack',
  ),
    LevelRewardDefinition(
    level: 10,
    emoji: '💰',
    title: '\$10 to spend',
    description: 'You get a \$10 bill!',
  ),
    LevelRewardDefinition(
    level: 11,
    emoji: '👫',
    title: 'Parents do your chores',
    description: 'Mom and Dad do your chores for the day.',
  ),
  LevelRewardDefinition(
    level: 12,
    emoji: '🛏️',
    title: 'Stay Up Late',
    description: 'Stay up 20 minutes past usual bedtime.',
  ),
    LevelRewardDefinition(
    level: 13,
    emoji: '🧑‍🍳',
    title: 'Choose a meal',
    description: 'Choose what the family eats for one meal',
  ),
    LevelRewardDefinition(
    level: 14,
    emoji: '👨‍👩‍👦',
    title: 'Date Night',
    description: 'Get a date night with Mom or Dad.',
  ),
  LevelRewardDefinition(
    level: 15,
    emoji: '🛋',
    title: 'Later Bedtime',
    description: 'You\'re bedtime is now an hour later.',
  ),
];

/// Reward for this exact level, if any.
LevelRewardDefinition? levelRewardForLevel(int level) {
  for (final def in kDefaultLevelRewards) {
    if (def.level == level) return def;
  }
  return null;
}

/// Next upcoming reward *after* the given level, if any.
LevelRewardDefinition? nextLevelRewardFromLevel(int currentLevel) {
  LevelRewardDefinition? best;
  for (final def in kDefaultLevelRewards) {
    if (def.level > currentLevel) {
      if (best == null || def.level < best.level) {
        best = def;
      }
    }
  }
  return best;
}

