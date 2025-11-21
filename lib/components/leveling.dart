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
