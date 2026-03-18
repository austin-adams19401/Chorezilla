/// Defines all Zilla mascot animations, their asset paths, and sprite sheet
/// metadata. Free animations are always available. Premium animations are
/// unlocked one per level-up for premium subscribers.
class ZillaAnimationDef {
  final String id;
  final String assetPath;
  final int columns;
  final int rows;
  final Duration duration;

  const ZillaAnimationDef({
    required this.id,
    required this.assetPath,
    required this.columns,
    required this.rows,
    required this.duration,
  });
}

class ZillaAnimations {
  const ZillaAnimations._();

  // ── Free tier ────────────────────────────────────────────────────────────────
  static const walking = ZillaAnimationDef(
    id: 'walking',
    assetPath: 'assets/mascot/sprite-sheets/walking.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const idle = ZillaAnimationDef(
    id: 'idle',
    assetPath: 'assets/mascot/sprite-sheets/idle.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1500),
  );

  static const looking = ZillaAnimationDef(
    id: 'looking',
    assetPath: 'assets/mascot/sprite-sheets/idle2.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1400),
  );

  // Sleep sequence — always free, triggered by inactivity (not random cycling)
  static const goingToSleep = ZillaAnimationDef(
    id: 'going_to_sleep',
    assetPath: 'assets/mascot/sprite-sheets/going-to-sleep.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 2000),
  );

  static const sleepingLoop = ZillaAnimationDef(
    id: 'sleeping_loop',
    assetPath: 'assets/mascot/sprite-sheets/sleeping.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 2500),
  );

  static const wakingUp = ZillaAnimationDef(
    id: 'waking_up',
    assetPath: 'assets/mascot/sprite-sheets/wake-up.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1800),
  );

  // ── Premium level-up unlocks ─────────────────────────────────────────────────
  static const wave = ZillaAnimationDef(
    id: 'wave',
    assetPath: 'assets/mascot/sprite-sheets/wave.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const sweeping = ZillaAnimationDef(
    id: 'sweeping',
    assetPath: 'assets/mascot/sprite-sheets/sweeping.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1400),
  );

  static const wiping = ZillaAnimationDef(
    id: 'wiping',
    assetPath: 'assets/mascot/sprite-sheets/wiping.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const dance = ZillaAnimationDef(
    id: 'dance',
    assetPath: 'assets/mascot/sprite-sheets/dance.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1600),
  );

  // ── All definitions by ID ────────────────────────────────────────────────────
  static const _all = <String, ZillaAnimationDef>{
    'walking': walking,
    'idle': idle,
    'looking': looking,
    'going_to_sleep': goingToSleep,
    'sleeping_loop': sleepingLoop,
    'waking_up': wakingUp,
    'wave': wave,
    'sweeping': sweeping,
    'wiping': wiping,
    'dance': dance,
  };

  static ZillaAnimationDef? byId(String id) => _all[id];

  // ── Free set (always available) ───────────────────────────────────────────────
  static const List<String> freeAnimationIds = [
    'walking',
    'idle',
    'looking',       // idle2
    'going_to_sleep',
    'sleeping_loop',
    'waking_up',
  ];

  // ── Premium unlocks by level (level → animationId) ───────────────────────────
  static const Map<int, String> premiumUnlockByLevel = {
    2: 'wave',
    4: 'sweeping',
    5: 'wiping',
    6: 'dance',
  };

  /// Returns the animation to unlock at [level], or null if none.
  static String? unlockForLevel(int level) => premiumUnlockByLevel[level];

  /// Returns all animation defs available for a member given their
  /// [unlockedAnimationIds] list (from Firestore) and whether they have premium.
  /// Free users always get [freeAnimationIds]. Premium users also get their
  /// unlocked extras.
  static List<ZillaAnimationDef> availableFor({
    required bool isPremium,
    required List<String> unlockedAnimationIds,
  }) {
    final ids = <String>{...freeAnimationIds};
    if (isPremium) {
      ids.addAll(unlockedAnimationIds);
    }
    return ids
        .map((id) => _all[id])
        .whereType<ZillaAnimationDef>()
        .toList();
  }
}
