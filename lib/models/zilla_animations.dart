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
    assetPath: 'assets/icons/mascot/sprite-sheets/walking.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const idle = ZillaAnimationDef(
    id: 'idle',
    assetPath: 'assets/icons/mascot/sprite-sheets/idle.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1500),
  );

  static const poked = ZillaAnimationDef(
    id: 'poked',
    assetPath: 'assets/icons/mascot/sprite-sheets/surprised.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 800),
  );

  // ── Premium level-up unlocks ─────────────────────────────────────────────────
  static const wave = ZillaAnimationDef(
    id: 'wave',
    assetPath: 'assets/icons/mascot/sprite-sheets/wave.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const looking = ZillaAnimationDef(
    id: 'looking',
    assetPath: 'assets/icons/mascot/sprite-sheets/idle2.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1400),
  );

  static const sweeping = ZillaAnimationDef(
    id: 'sweeping',
    assetPath: 'assets/icons/mascot/sprite-sheets/sweeping.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1400),
  );

  static const wiping = ZillaAnimationDef(
    id: 'wiping',
    assetPath: 'assets/icons/mascot/sprite-sheets/wiping.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const dance = ZillaAnimationDef(
    id: 'dance',
    assetPath: 'assets/icons/mascot/sprite-sheets/dance.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1600),
  );

  static const sleeping = ZillaAnimationDef(
    id: 'sleeping',
    assetPath: 'assets/icons/mascot/sprite-sheets/going-to-sleep.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 2000),
  );

  static const sittingDown = ZillaAnimationDef(
    id: 'sitting_down',
    assetPath: 'assets/icons/mascot/sprite-sheets/wake-up.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  // ── All definitions by ID ────────────────────────────────────────────────────
  static const _all = <String, ZillaAnimationDef>{
    'walking': walking,
    'idle': idle,
    'poked': poked,
    'wave': wave,
    'looking': looking,
    'sweeping': sweeping,
    'wiping': wiping,
    'dance': dance,
    'sleeping': sleeping,
    'sitting_down': sittingDown,
  };

  static ZillaAnimationDef? byId(String id) => _all[id];

  // ── Free set (always available) ───────────────────────────────────────────────
  static const List<String> freeAnimationIds = ['walking', 'idle', 'poked'];

  // ── Premium unlocks by level (level → animationId) ───────────────────────────
  static const Map<int, String> premiumUnlockByLevel = {
    2: 'wave',
    3: 'looking',
    4: 'sweeping',
    5: 'wiping',
    6: 'dance',
    7: 'sleeping',
    8: 'sitting_down',
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
