// lib/models/cosmetics.dart

import 'dart:math' as math;

import 'package:chorezilla/models/common.dart';

// ---------------------------------------------------------------------------
// Rarity
// ---------------------------------------------------------------------------

enum CosmeticRarity { common, rare, epic }

extension CosmeticRarityX on CosmeticRarity {
  String get displayName {
    switch (this) {
      case CosmeticRarity.common:
        return 'Common';
      case CosmeticRarity.rare:
        return 'Rare';
      case CosmeticRarity.epic:
        return 'Epic';
    }
  }

  int get starCount => index + 1; // common=1, rare=2, epic=3
}

// ---------------------------------------------------------------------------
// Cosmetic item
// ---------------------------------------------------------------------------

class CosmeticItem {
  final String id; // e.g. 'bg_blue_sky'
  final CosmeticType type; // background / zillaSkin / avatarFrame / title
  final String name; // 'Blue Sky'
  final String description; // 'Soft blue gradient background'
  final int costCoins; // 0 for default
  final String assetKey; // 'assets/backgrounds/blue_sky.png' (empty for text/drawn types)
  final bool isDefault;
  final CosmeticRarity? rarity; // null for free defaults (excluded from loot box pools)

  const CosmeticItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.costCoins,
    this.assetKey = '',
    this.isDefault = false,
    this.rarity,
  });
}

// ---------------------------------------------------------------------------
// Loot box click state (3-click mechanic)
// ---------------------------------------------------------------------------

class LootBoxClickState {
  final int clickCount; // 0–3
  final CosmeticRarity? currentRarity; // null until first click
  final bool isFinished; // true after 3rd click
  final CosmeticItem? wonItem; // set when isFinished
  final bool isDuplicate;
  final int coinRefund;

  const LootBoxClickState({
    this.clickCount = 0,
    this.currentRarity,
    this.isFinished = false,
    this.wonItem,
    this.isDuplicate = false,
    this.coinRefund = 0,
  });
}

// ---------------------------------------------------------------------------
// Loot box definition (category-based)
// ---------------------------------------------------------------------------

class LootBoxDefinition {
  final String id;
  final String name;
  final String categoryEmoji;
  final CosmeticType cosmeticType;
  final int costCoins;
  final int duplicateCoinRefund;

  const LootBoxDefinition({
    required this.id,
    required this.name,
    required this.categoryEmoji,
    required this.cosmeticType,
    required this.costCoins,
    required this.duplicateCoinRefund,
  });

  /// Advances the loot box session by one click.
  /// On the 3rd click ([state.clickCount] == 2 → new == 3), selects the actual item.
  LootBoxClickState rollClick(
    LootBoxClickState state,
    List<String> ownedCosmetics,
  ) {
    final newCount = state.clickCount + 1;

    // Roll a rarity for this click; keep the best rolled so far
    final rolled = _rollRarity();
    final best = state.currentRarity == null || rolled.index > state.currentRarity!.index
        ? rolled
        : state.currentRarity!;

    if (newCount < 3) {
      return LootBoxClickState(clickCount: newCount, currentRarity: best);
    }

    // 3rd click: finalise rarity and pick the actual item
    final item = _pickItem(best, ownedCosmetics);
    final isDuplicate = ownedCosmetics.contains(item.id);

    return LootBoxClickState(
      clickCount: newCount,
      currentRarity: best,
      isFinished: true,
      wonItem: item,
      isDuplicate: isDuplicate,
      coinRefund: isDuplicate ? duplicateCoinRefund : 0,
    );
  }

  static CosmeticRarity _rollRarity() {
    final r = math.Random().nextInt(100);
    if (r < 60) return CosmeticRarity.common;
    if (r < 90) return CosmeticRarity.rare;
    return CosmeticRarity.epic;
  }

  CosmeticItem _pickItem(CosmeticRarity targetRarity, List<String> ownedCosmetics) {
    final pool = CosmeticCatalog.items
        .where((c) => c.type == cosmeticType && !c.isDefault && c.rarity != null)
        .toList();

    // 1. Try exact rarity, unowned
    final exactUnowned = pool
        .where((c) => c.rarity == targetRarity && !ownedCosmetics.contains(c.id))
        .toList();
    if (exactUnowned.isNotEmpty) {
      return exactUnowned[math.Random().nextInt(exactUnowned.length)];
    }

    // 2. Try other rarities (prefer higher), unowned
    for (final rarity in CosmeticRarity.values.reversed) {
      if (rarity == targetRarity) continue;
      final other = pool
          .where((c) => c.rarity == rarity && !ownedCosmetics.contains(c.id))
          .toList();
      if (other.isNotEmpty) return other[math.Random().nextInt(other.length)];
    }

    // 3. All items owned — return a duplicate from target rarity (or any)
    final fallback = pool.where((c) => c.rarity == targetRarity).toList();
    if (fallback.isNotEmpty) return fallback[math.Random().nextInt(fallback.length)];
    return pool[math.Random().nextInt(pool.length)];
  }
}

// ---------------------------------------------------------------------------
// Cosmetic catalog
// ---------------------------------------------------------------------------

class CosmeticCatalog {
  static const items = <CosmeticItem>[
    // BACKGROUNDS
    CosmeticItem(
      id: 'bg_default',
      type: CosmeticType.background,
      name: 'Default',
      description: 'Classic Chorezilla look',
      costCoins: 0,
      assetKey: 'assets/backgrounds/bg_kitchen.png',
      isDefault: true,
    ),
    // ── Common (50–75 coins) ──
    CosmeticItem(
      id: 'bg_kitchen',
      type: CosmeticType.background,
      name: 'Kitchen',
      description: 'A bright cozy kitchen',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_kitchen.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_backyard',
      type: CosmeticType.background,
      name: 'Backyard',
      description: 'Sunny outdoor fun',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_backyard.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_laundry',
      type: CosmeticType.background,
      name: 'Laundry Room',
      description: 'Suds and spin cycles',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_laundry.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_dino',
      type: CosmeticType.background,
      name: 'Dino World',
      description: 'Prehistoric Zilla territory',
      costCoins: 75,
      assetKey: 'assets/backgrounds/bg_dino.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_jungle',
      type: CosmeticType.background,
      name: 'Jungle',
      description: 'Deep in the wild',
      costCoins: 75,
      assetKey: 'assets/backgrounds/bg_jungle.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_candyland',
      type: CosmeticType.background,
      name: 'Candy Land',
      description: 'Everything is sweet',
      costCoins: 75,
      assetKey: 'assets/backgrounds/bg_candyland.png',
      rarity: CosmeticRarity.common,
    ),
    // ── Rare (100–150 coins) ──
    CosmeticItem(
      id: 'bg_ocean',
      type: CosmeticType.background,
      name: 'Ocean',
      description: 'Deep blue waves',
      costCoins: 100,
      assetKey: 'assets/backgrounds/bg_ocean.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_space',
      type: CosmeticType.background,
      name: 'Space',
      description: 'Blast off into the cosmos',
      costCoins: 100,
      assetKey: 'assets/backgrounds/bg_space.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_minecraft',
      type: CosmeticType.background,
      name: 'Block World',
      description: 'Mine, craft, do chores',
      costCoins: 100,
      assetKey: 'assets/backgrounds/bg_minecraft.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_space2',
      type: CosmeticType.background,
      name: 'Deep Space',
      description: 'A galaxy far, far away',
      costCoins: 150,
      assetKey: 'assets/backgrounds/bg_space2.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_pirate',
      type: CosmeticType.background,
      name: 'Pirate Seas',
      description: 'Arr, chores on the high seas',
      costCoins: 150,
      assetKey: 'assets/backgrounds/bg_pirate.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_dragon',
      type: CosmeticType.background,
      name: 'Dragon Lair',
      description: 'Here be dragons',
      costCoins: 150,
      assetKey: 'assets/backgrounds/bg_dragon.png',
      rarity: CosmeticRarity.rare,
    ),
    // ── Epic (200 coins) ──
    CosmeticItem(
      id: 'bg_arena',
      type: CosmeticType.background,
      name: 'Arena',
      description: 'Champion of chores',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_arena.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'bg_volcano',
      type: CosmeticType.background,
      name: 'Volcano',
      description: 'Hot hot hot',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_volcano.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'bg_treasure',
      type: CosmeticType.background,
      name: 'Treasure Cave',
      description: 'X marks the chore',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_treasure.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'bg_unicorn',
      type: CosmeticType.background,
      name: 'Unicorn Land',
      description: 'Magical and sparkly',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_unicorn.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'bg_levelup',
      type: CosmeticType.background,
      name: 'Level Up',
      description: 'For the true Chore Champion',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_levelup.png',
      rarity: CosmeticRarity.epic,
    ),

    // ZILLA SKINS
    CosmeticItem(
      id: 'zilla_green_basic',
      type: CosmeticType.zillaSkin,
      name: 'Classic Zilla',
      description: 'The original green buddy',
      costCoins: 0,
      assetKey: 'assets/zilla/green/basic_sheet.png',
      isDefault: true,
    ),
    // ── Rare (100–150 coins) ──
    CosmeticItem(
      id: 'zilla_blue_hoodie',
      type: CosmeticType.zillaSkin,
      name: 'Blue Hoodie',
      description: 'Cozy hoodie Zilla',
      costCoins: 100,
      assetKey: 'assets/zilla/blue/hoodie_sheet.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'zilla_red_cape',
      type: CosmeticType.zillaSkin,
      name: 'Red Cape',
      description: 'Super Zilla to the rescue',
      costCoins: 150,
      assetKey: 'assets/zilla/red/cape_sheet.png',
      rarity: CosmeticRarity.rare,
    ),
    // ── Epic (200–250 coins) ──
    CosmeticItem(
      id: 'zilla_pirate',
      type: CosmeticType.zillaSkin,
      name: 'Pirate Zilla',
      description: "Arr, chores be done on time!",
      costCoins: 200,
      assetKey: 'assets/zilla/pirate/pirate_sheet.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'zilla_wizard',
      type: CosmeticType.zillaSkin,
      name: 'Wizard Zilla',
      description: 'Conjuring clean rooms since forever',
      costCoins: 250,
      assetKey: 'assets/zilla/wizard/wizard_sheet.png',
      rarity: CosmeticRarity.epic,
    ),

    // AVATAR FRAMES (drawn via Flutter BoxDecoration — assetKey unused)
    CosmeticItem(
      id: 'frame_default',
      type: CosmeticType.avatarFrame,
      name: 'No Frame',
      description: 'Clean and simple',
      costCoins: 0,
      isDefault: true,
    ),
    // ── Common (50 coins) ──
    CosmeticItem(
      id: 'frame_stars',
      type: CosmeticType.avatarFrame,
      name: 'Starry',
      description: 'Little gold stars',
      costCoins: 50,
      rarity: CosmeticRarity.common,
    ),
    // ── Rare (100–150 coins) ──
    CosmeticItem(
      id: 'frame_rainbow',
      type: CosmeticType.avatarFrame,
      name: 'Rainbow',
      description: 'All the colors',
      costCoins: 100,
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'frame_gold',
      type: CosmeticType.avatarFrame,
      name: 'Gold',
      description: 'Shiny double gold border',
      costCoins: 150,
      rarity: CosmeticRarity.rare,
    ),
    // ── Epic (200 coins) ──
    CosmeticItem(
      id: 'frame_fire',
      type: CosmeticType.avatarFrame,
      name: 'Fire',
      description: 'Blazing flames border',
      costCoins: 200,
      rarity: CosmeticRarity.epic,
    ),

    // TITLES (text only — assetKey unused)
    CosmeticItem(
      id: 'title_none',
      type: CosmeticType.title,
      name: 'No Title',
      description: 'Plain and proud',
      costCoins: 0,
      isDefault: true,
    ),
    // ── Common (30–75 coins) ──
    CosmeticItem(
      id: 'title_good_helper',
      type: CosmeticType.title,
      name: 'Good Helper',
      description: 'A reliable member of the team',
      costCoins: 30,
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'title_chore_champ',
      type: CosmeticType.title,
      name: 'Chore Champ',
      description: 'Crushing it every day',
      costCoins: 50,
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'title_streak_master',
      type: CosmeticType.title,
      name: 'Streak Master',
      description: 'Never misses a day',
      costCoins: 75,
      rarity: CosmeticRarity.common,
    ),
    // ── Rare (150 coins) ──
    CosmeticItem(
      id: 'title_legend',
      type: CosmeticType.title,
      name: 'The Legend',
      description: 'Need we say more?',
      costCoins: 150,
      rarity: CosmeticRarity.rare,
    ),
  ];

  /// Returns the cosmetic for [id], or the default cosmetic of the same type
  /// if unknown. Falls back to the first item if no typed default exists.
  static CosmeticItem byId(String id) {
    final exact = items.where((c) => c.id == id);
    if (exact.isNotEmpty) return exact.first;

    // Infer type from id prefix so we can return the right default.
    final CosmeticType? inferredType = id.startsWith('zilla_')
        ? CosmeticType.zillaSkin
        : id.startsWith('bg_')
            ? CosmeticType.background
            : id.startsWith('frame_')
                ? CosmeticType.avatarFrame
                : id.startsWith('title_')
                    ? CosmeticType.title
                    : null;

    if (inferredType != null) {
      final typedDefault = items.where(
        (c) => c.type == inferredType && c.isDefault,
      );
      if (typedDefault.isNotEmpty) return typedDefault.first;
    }

    final defaults = items.where((c) => c.isDefault);
    if (defaults.isNotEmpty) return defaults.first;

    return items.first;
  }

  static Iterable<CosmeticItem> backgrounds() =>
      items.where((c) => c.type == CosmeticType.background);

  static Iterable<CosmeticItem> zillaSkins() =>
      items.where((c) => c.type == CosmeticType.zillaSkin);

  static Iterable<CosmeticItem> avatarFrames() =>
      items.where((c) => c.type == CosmeticType.avatarFrame);

  static Iterable<CosmeticItem> titles() =>
      items.where((c) => c.type == CosmeticType.title);
}

// ---------------------------------------------------------------------------
// Loot box catalog (4 category boxes)
// ---------------------------------------------------------------------------

class LootBoxCatalog {
  static const boxes = <LootBoxDefinition>[
    LootBoxDefinition(
      id: 'lootbox_backgrounds',
      name: 'Background Box',
      categoryEmoji: '🖼️',
      cosmeticType: CosmeticType.background,
      costCoins: 20,
      duplicateCoinRefund: 5,
    ),
    LootBoxDefinition(
      id: 'lootbox_skins',
      name: 'Skin Box',
      categoryEmoji: '🦎',
      cosmeticType: CosmeticType.zillaSkin,
      costCoins: 25,
      duplicateCoinRefund: 6,
    ),
    LootBoxDefinition(
      id: 'lootbox_frames',
      name: 'Frame Box',
      categoryEmoji: '✨',
      cosmeticType: CosmeticType.avatarFrame,
      costCoins: 20,
      duplicateCoinRefund: 5,
    ),
    LootBoxDefinition(
      id: 'lootbox_titles',
      name: 'Title Box',
      categoryEmoji: '🏆',
      cosmeticType: CosmeticType.title,
      costCoins: 15,
      duplicateCoinRefund: 4,
    ),
  ];

  static LootBoxDefinition? byId(String id) =>
      boxes.cast<LootBoxDefinition?>().firstWhere(
        (b) => b?.id == id,
        orElse: () => null,
      );
}
