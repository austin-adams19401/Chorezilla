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
  final int? colorValue; // ARGB int for color-tinted skins (e.g. zilla skins)

  const CosmeticItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.costCoins,
    this.assetKey = '',
    this.isDefault = false,
    this.rarity,
    this.colorValue,
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

    if (pool.isEmpty) {
      // No loot items exist for this box type yet — fall back to the default.
      final defaults = CosmeticCatalog.items
          .where((c) => c.type == cosmeticType && c.isDefault)
          .toList();
      return defaults.first;
    }

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
    // ── Common (15 coins) ──
    CosmeticItem(
      id: 'bg_kitchen',
      type: CosmeticType.background,
      name: 'Kitchen',
      description: 'A bright cozy kitchen',
      costCoins: 15,
      assetKey: 'assets/backgrounds/bg_kitchen.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_backyard',
      type: CosmeticType.background,
      name: 'Backyard',
      description: 'Sunny outdoor fun',
      costCoins: 15,
      assetKey: 'assets/backgrounds/bg_backyard.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_laundry',
      type: CosmeticType.background,
      name: 'Laundry Room',
      description: 'Suds and spin cycles',
      costCoins: 15,
      assetKey: 'assets/backgrounds/bg_laundry.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_dino',
      type: CosmeticType.background,
      name: 'Dino World',
      description: 'Prehistoric Zilla territory',
      costCoins: 15,
      assetKey: 'assets/backgrounds/bg_dino.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_jungle',
      type: CosmeticType.background,
      name: 'Jungle',
      description: 'Deep in the wild',
      costCoins: 15,
      assetKey: 'assets/backgrounds/bg_jungle.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'bg_candyland',
      type: CosmeticType.background,
      name: 'Candy Land',
      description: 'Everything is sweet',
      costCoins: 15,
      assetKey: 'assets/backgrounds/bg_candyland.png',
      rarity: CosmeticRarity.common,
    ),
    // ── Rare (25–30 coins) ──
    CosmeticItem(
      id: 'bg_ocean',
      type: CosmeticType.background,
      name: 'Ocean',
      description: 'Deep blue waves',
      costCoins: 25,
      assetKey: 'assets/backgrounds/bg_ocean.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_space',
      type: CosmeticType.background,
      name: 'Space',
      description: 'Blast off into the cosmos',
      costCoins: 25,
      assetKey: 'assets/backgrounds/bg_space.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_minecraft',
      type: CosmeticType.background,
      name: 'Block World',
      description: 'Mine, craft, do chores',
      costCoins: 25,
      assetKey: 'assets/backgrounds/bg_minecraft.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_space2',
      type: CosmeticType.background,
      name: 'Deep Space',
      description: 'A galaxy far, far away',
      costCoins: 30,
      assetKey: 'assets/backgrounds/bg_space2.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_pirate',
      type: CosmeticType.background,
      name: 'Pirate Seas',
      description: 'Arr, chores on the high seas',
      costCoins: 30,
      assetKey: 'assets/backgrounds/bg_pirate.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'bg_dragon',
      type: CosmeticType.background,
      name: 'Dragon Lair',
      description: 'Here be dragons',
      costCoins: 30,
      assetKey: 'assets/backgrounds/bg_dragon.png',
      rarity: CosmeticRarity.rare,
    ),
    // ── Epic (50 coins) ──
    CosmeticItem(
      id: 'bg_arena',
      type: CosmeticType.background,
      name: 'Arena',
      description: 'Champion of chores',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_arena.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'bg_volcano',
      type: CosmeticType.background,
      name: 'Volcano',
      description: 'Hot hot hot',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_volcano.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'bg_treasure',
      type: CosmeticType.background,
      name: 'Treasure Cave',
      description: 'X marks the chore',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_treasure.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'bg_unicorn',
      type: CosmeticType.background,
      name: 'Unicorn Land',
      description: 'Magical and sparkly',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_unicorn.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'bg_levelup',
      type: CosmeticType.background,
      name: 'Level Up',
      description: 'For the true Chore Champion',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_levelup.png',
      rarity: CosmeticRarity.epic,
    ),

    // ZILLA SKINS — color variants
    // ── Default (free, level 1) ──
    CosmeticItem(
      id: 'zilla_green_basic',
      type: CosmeticType.zillaSkin,
      name: 'Classic Green',
      description: 'The original Zilla look',
      costCoins: 0,
      colorValue: 0xFF2ECC71,
      isDefault: true,
    ),
    // ── Common (10–12 coins) ──
    CosmeticItem(
      id: 'zilla_grass_green',
      type: CosmeticType.zillaSkin,
      name: 'Grass Green',
      description: 'Fresh and classic',
      costCoins: 10,
      colorValue: 0xFF4CAF50,
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'zilla_sky_blue',
      type: CosmeticType.zillaSkin,
      name: 'Sky Blue',
      description: 'Cool as a clear day',
      costCoins: 10,
      colorValue: 0xFF42A5F5,
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'zilla_sunny_yellow',
      type: CosmeticType.zillaSkin,
      name: 'Sunny Yellow',
      description: 'Bright and cheerful',
      costCoins: 10,
      colorValue: 0xFFFFD600,
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'zilla_coral',
      type: CosmeticType.zillaSkin,
      name: 'Coral',
      description: 'Warm and energetic',
      costCoins: 12,
      colorValue: 0xFFFF7043,
      rarity: CosmeticRarity.common,
    ),
    // ── Rare (20–25 coins) ──
    CosmeticItem(
      id: 'zilla_purple',
      type: CosmeticType.zillaSkin,
      name: 'Purple',
      description: 'Royally cool',
      costCoins: 20,
      colorValue: 0xFF7B1FA2,
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'zilla_teal',
      type: CosmeticType.zillaSkin,
      name: 'Teal',
      description: 'Deep ocean vibes',
      costCoins: 20,
      colorValue: 0xFF00796B,
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'zilla_hot_pink',
      type: CosmeticType.zillaSkin,
      name: 'Hot Pink',
      description: 'Bold and vibrant',
      costCoins: 22,
      colorValue: 0xFFE91E63,
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'zilla_midnight_blue',
      type: CosmeticType.zillaSkin,
      name: 'Midnight Blue',
      description: 'Dark and mysterious',
      costCoins: 25,
      colorValue: 0xFF283593,
      rarity: CosmeticRarity.rare,
    ),
    // ── Epic (35–45 coins) ──
    CosmeticItem(
      id: 'zilla_gold',
      type: CosmeticType.zillaSkin,
      name: 'Gold',
      description: 'Champion status',
      costCoins: 35,
      colorValue: 0xFFFFB300,
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'zilla_crimson',
      type: CosmeticType.zillaSkin,
      name: 'Crimson',
      description: 'Fierce and powerful',
      costCoins: 35,
      colorValue: 0xFFC62828,
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'zilla_emerald',
      type: CosmeticType.zillaSkin,
      name: 'Emerald',
      description: 'Rare and radiant',
      costCoins: 40,
      colorValue: 0xFF1B5E20,
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'zilla_galaxy',
      type: CosmeticType.zillaSkin,
      name: 'Galaxy',
      description: 'Out of this world',
      costCoins: 45,
      colorValue: 0xFF4A148C,
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
    // ── Default (free, level 1) ──
    CosmeticItem(
      id: 'frame_green_basic',
      type: CosmeticType.avatarFrame,
      name: 'Green Border',
      description: 'A fresh green ring — earned at level 1',
      costCoins: 0,
      isDefault: true,
    ),
    // ── Common (15 coins) ──
    CosmeticItem(
      id: 'frame_stars',
      type: CosmeticType.avatarFrame,
      name: 'Starry',
      description: 'Little gold stars',
      costCoins: 15,
      rarity: CosmeticRarity.common,
    ),
    // ── Rare (25–30 coins) ──
    CosmeticItem(
      id: 'frame_rainbow',
      type: CosmeticType.avatarFrame,
      name: 'Rainbow',
      description: 'All the colors',
      costCoins: 25,
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'frame_gold',
      type: CosmeticType.avatarFrame,
      name: 'Gold',
      description: 'Shiny double gold border',
      costCoins: 30,
      rarity: CosmeticRarity.rare,
    ),
    // ── Epic (50 coins) ──
    CosmeticItem(
      id: 'frame_fire',
      type: CosmeticType.avatarFrame,
      name: 'Fire',
      description: 'Blazing flames border',
      costCoins: 50,
      rarity: CosmeticRarity.epic,
    ),

    // TITLES (text only — assetKey unused; earned via level-ups or achievements, not loot boxes)
    CosmeticItem(
      id: 'title_none',
      type: CosmeticType.title,
      name: 'No Title',
      description: 'Plain and proud',
      costCoins: 0,
      isDefault: true,
    ),

    // Level titles — awarded automatically on reaching the corresponding level
    CosmeticItem(
      id: 'title_level_1',
      type: CosmeticType.title,
      name: 'Rookie Helper',
      description: 'Every hero starts somewhere',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_2',
      type: CosmeticType.title,
      name: 'Task Starter',
      description: 'The journey of a thousand chores begins with one',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_3',
      type: CosmeticType.title,
      name: 'Kinda Getting It Done',
      description: 'Progress is progress',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_4',
      type: CosmeticType.title,
      name: 'Chore Apprentice',
      description: 'Learning the ways of the clean',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_5',
      type: CosmeticType.title,
      name: 'Cleanup Cadet',
      description: 'Reporting for duty',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_6',
      type: CosmeticType.title,
      name: 'Snack-Fueled Worker',
      description: 'Powered by snacks and determination',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_7',
      type: CosmeticType.title,
      name: 'Task Tackler',
      description: 'No chore is safe',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_8',
      type: CosmeticType.title,
      name: 'Reliable(ish) Helper',
      description: 'Usually comes through',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_9',
      type: CosmeticType.title,
      name: 'Chore Champ',
      description: 'Crushing it every day',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_10',
      type: CosmeticType.title,
      name: 'Captain of Clean',
      description: 'Commanding order in every room',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_11',
      type: CosmeticType.title,
      name: 'The Organizer',
      description: 'Everything has a place',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_12',
      type: CosmeticType.title,
      name: 'Efficiency Expert',
      description: 'Done before anyone noticed it was messy',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_13',
      type: CosmeticType.title,
      name: 'The "I Did It Already" Kid',
      description: 'Always one step ahead',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_14',
      type: CosmeticType.title,
      name: 'Master of Tasks',
      description: 'Tasks? What tasks? Already done.',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_15',
      type: CosmeticType.title,
      name: 'The Finisher',
      description: 'Started it, finished it, moved on',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_16',
      type: CosmeticType.title,
      name: 'Household Hero',
      description: 'The whole family noticed',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_17',
      type: CosmeticType.title,
      name: 'Elite Cleaner',
      description: 'A cut above the rest',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_18',
      type: CosmeticType.title,
      name: 'Chaos Controller',
      description: 'Brought order to the storm',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_19',
      type: CosmeticType.title,
      name: 'Supreme Organizer',
      description: 'Legendary status within reach',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_level_20',
      type: CosmeticType.title,
      name: 'The Ultimate Responsibility',
      description: 'With great chores comes great reward',
      costCoins: 0,
    ),

    // Achievement (secret) titles — earned via special conditions
    CosmeticItem(
      id: 'title_treasure_hoarder',
      type: CosmeticType.title,
      name: 'Treasure Hoarder',
      description: 'Held onto 100+ coins for 3 days straight',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_big_spender',
      type: CosmeticType.title,
      name: 'Big Spender',
      description: 'Spent 100+ coins in a single day',
      costCoins: 0,
    ),
    CosmeticItem(
      id: 'title_silent_ninja',
      type: CosmeticType.title,
      name: 'Silent Ninja',
      description: 'Finished all required chores in one session without a fuss',
      costCoins: 0,
    ),

    // AVATARS — image-based avatar icons
    // ── Defaults (always free, no rarity) ──
    CosmeticItem(
      id: 'avatar_default_1',
      type: CosmeticType.avatar,
      name: 'Avatar 1',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/avatar_1.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_2',
      type: CosmeticType.avatar,
      name: 'Avatar 2',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/avatar_2.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_3',
      type: CosmeticType.avatar,
      name: 'Avatar 3',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/avatar_4.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_4',
      type: CosmeticType.avatar,
      name: 'Avatar 4',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/avatar_5.png',
      isDefault: true,
    ),
    // ── Common loot avatars (add asset files to assets/avatars/common/ to activate) ──
    // ── Rare loot avatars (add asset files to assets/avatars/rare/ to activate) ──
    // ── Epic loot avatars (add asset files to assets/avatars/epic/ to activate) ──
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
                    : id.startsWith('avatar_')
                        ? CosmeticType.avatar
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

  static Iterable<CosmeticItem> avatars() =>
      items.where((c) => c.type == CosmeticType.avatar);

  /// Returns the ARGB color value for the given zilla skin ID, or null if the
  /// skin doesn't exist or has no color (e.g. not a color-tinted skin).
  static int? tintColorValueForSkin(String? skinId) {
    if (skinId == null) return null;
    for (final item in items) {
      if (item.id == skinId && item.type == CosmeticType.zillaSkin) {
        return item.colorValue;
      }
    }
    return null;
  }
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
      costCoins: 12,
      duplicateCoinRefund: 3,
    ),
    LootBoxDefinition(
      id: 'lootbox_skins',
      name: 'Skin Box',
      categoryEmoji: '🎨',
      cosmeticType: CosmeticType.zillaSkin,
      costCoins: 8,
      duplicateCoinRefund: 2,
    ),
    LootBoxDefinition(
      id: 'lootbox_frames',
      name: 'Frame Box',
      categoryEmoji: '✨',
      cosmeticType: CosmeticType.avatarFrame,
      costCoins: 12,
      duplicateCoinRefund: 3,
    ),
    LootBoxDefinition(
      id: 'lootbox_avatars',
      name: 'Avatar Box',
      categoryEmoji: '🧑‍🎨',
      cosmeticType: CosmeticType.avatar,
      costCoins: 10,
      duplicateCoinRefund: 2,
    ),
  ];

  static LootBoxDefinition? byId(String id) =>
      boxes.cast<LootBoxDefinition?>().firstWhere(
        (b) => b?.id == id,
        orElse: () => null,
      );
}
