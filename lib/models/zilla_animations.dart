/// Defines all Zilla mascot animations, their asset paths, and sprite sheet
/// metadata. Free animations are always available. Premium animations are
/// unlocked one per level-up for premium subscribers.
class ZillaAnimationDef {
  final String id;
  final String bodyAssetPath;
  final String detailsAssetPath;
  final int columns;
  final int rows;
  final Duration duration;

  const ZillaAnimationDef({
    required this.id,
    required this.bodyAssetPath,
    required this.detailsAssetPath,
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
    bodyAssetPath: 'assets/mascot/sprite-sheets/walking_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/walking_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const idle = ZillaAnimationDef(
    id: 'idle',
    bodyAssetPath: 'assets/mascot/sprite-sheets/idle_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/idle_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1500),
  );

  static const looking = ZillaAnimationDef(
    id: 'looking',
    bodyAssetPath: 'assets/mascot/sprite-sheets/idle2_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/idle2_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1400),
  );

  // Sleep sequence - always free, triggered by inactivity (not random cycling)
  static const goingToSleep = ZillaAnimationDef(
    id: 'going_to_sleep',
    bodyAssetPath: 'assets/mascot/sprite-sheets/going-to-sleep_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/going-to-sleep_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 2000),
  );

  static const sleepingLoop = ZillaAnimationDef(
    id: 'sleeping_loop',
    bodyAssetPath: 'assets/mascot/sprite-sheets/sleeping_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/sleeping_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 2500),
  );

  static const wakingUp = ZillaAnimationDef(
    id: 'waking_up',
    bodyAssetPath: 'assets/mascot/sprite-sheets/wake-up_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/wake-up_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1800),
  );

  // ── Premium level-up unlocks ─────────────────────────────────────────────────
  static const wave = ZillaAnimationDef(
    id: 'wave',
    bodyAssetPath: 'assets/mascot/sprite-sheets/wave_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/wave_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const sweeping = ZillaAnimationDef(
    id: 'sweeping',
    bodyAssetPath: 'assets/mascot/sprite-sheets/sweeping_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/sweeping_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1400),
  );

  static const wiping = ZillaAnimationDef(
    id: 'wiping',
    bodyAssetPath: 'assets/mascot/sprite-sheets/wiping_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/wiping_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const dance = ZillaAnimationDef(
    id: 'dance',
    bodyAssetPath: 'assets/mascot/sprite-sheets/dance_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/dance_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1600),
  );

  // ── State sprites (used by profile header, loot boxes, etc.) ───────────────
  static const grumpy = ZillaAnimationDef(
    id: 'grumpy',
    bodyAssetPath: 'assets/mascot/sprite-sheets/grumpy_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/grumpy_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const grrr = ZillaAnimationDef(
    id: 'grrr',
    bodyAssetPath: 'assets/mascot/sprite-sheets/grrr_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/grrr_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1200),
  );

  static const celebrate = ZillaAnimationDef(
    id: 'celebrate',
    bodyAssetPath: 'assets/mascot/sprite-sheets/celebrate_body.png',
    detailsAssetPath: 'assets/mascot/sprite-sheets/celebrate_details.png',
    columns: 6,
    rows: 6,
    duration: Duration(milliseconds: 1800),
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
    'grumpy': grumpy,
    'grrr': grrr,
    'celebrate': celebrate,
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

  // ── Premium unlocks by level (level -> animationId) ───────────────────────────
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
