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
    if (r < 50) return CosmeticRarity.common;
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
    // ── Additional defaults ──
    CosmeticItem(
      id: 'avatar_default_banana',
      type: CosmeticType.avatar,
      name: 'Banana',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/banana.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_baseball',
      type: CosmeticType.avatar,
      name: 'Baseball',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/baseball.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_bolt',
      type: CosmeticType.avatar,
      name: 'Bolt',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/bolt.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_cookie',
      type: CosmeticType.avatar,
      name: 'Cookie',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/cookie.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_cute_dragon',
      type: CosmeticType.avatar,
      name: 'Cute Dragon',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/cute-dragon.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_cute_fox',
      type: CosmeticType.avatar,
      name: 'Cute Fox',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/cute-fox.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_cute_unicorn',
      type: CosmeticType.avatar,
      name: 'Cute Unicorn',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/cute-unicorn.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_explorer',
      type: CosmeticType.avatar,
      name: 'Explorer',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/explorer.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'avatar_default_googly_eyes',
      type: CosmeticType.avatar,
      name: 'Googly Eyes',
      description: 'A classic Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/default/googly-eyes.png',
      isDefault: true,
    ),

    // ── Common loot avatars ──
    CosmeticItem(
      id: 'avatar_common_coins',
      type: CosmeticType.avatar,
      name: 'Coins',
      description: 'Shiny and golden',
      costCoins: 0,
      assetKey: 'assets/avatars/common/coins.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_crayons',
      type: CosmeticType.avatar,
      name: 'Crayons',
      description: 'Colorful and creative',
      costCoins: 0,
      assetKey: 'assets/avatars/common/crayons.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_cupcake',
      type: CosmeticType.avatar,
      name: 'Cupcake',
      description: 'Sweet and sprinkled',
      costCoins: 0,
      assetKey: 'assets/avatars/common/cupcake.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_fire',
      type: CosmeticType.avatar,
      name: 'Fire',
      description: 'Hot and blazing',
      costCoins: 0,
      assetKey: 'assets/avatars/common/fire.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_flowers',
      type: CosmeticType.avatar,
      name: 'Flowers',
      description: 'Fresh and blooming',
      costCoins: 0,
      assetKey: 'assets/avatars/common/flowers.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_frog_hat',
      type: CosmeticType.avatar,
      name: 'Frog Hat',
      description: 'Ribbiting style',
      costCoins: 0,
      assetKey: 'assets/avatars/common/frog-hat.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_green_alien',
      type: CosmeticType.avatar,
      name: 'Green Alien',
      description: 'Out of this world',
      costCoins: 0,
      assetKey: 'assets/avatars/common/green-alien.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_hamburger',
      type: CosmeticType.avatar,
      name: 'Hamburger',
      description: 'Double patty power',
      costCoins: 0,
      assetKey: 'assets/avatars/common/hamburger.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_hero_mask',
      type: CosmeticType.avatar,
      name: 'Hero Mask',
      description: 'Every chore needs a hero',
      costCoins: 0,
      assetKey: 'assets/avatars/common/hero-mask.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_knight_helmet',
      type: CosmeticType.avatar,
      name: 'Knight Helmet',
      description: 'Armored and ready',
      costCoins: 0,
      assetKey: 'assets/avatars/common/knight-helmet.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_moon',
      type: CosmeticType.avatar,
      name: 'Moon',
      description: 'Glowing in the night',
      costCoins: 0,
      assetKey: 'assets/avatars/common/moon.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_mustache',
      type: CosmeticType.avatar,
      name: 'Mustache',
      description: 'Fancy and distinguished',
      costCoins: 0,
      assetKey: 'assets/avatars/common/mustashe.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_mystery',
      type: CosmeticType.avatar,
      name: 'Mystery',
      description: 'What could it be?',
      costCoins: 0,
      assetKey: 'assets/avatars/common/mystery.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_ninja',
      type: CosmeticType.avatar,
      name: 'Ninja',
      description: 'Silent but effective',
      costCoins: 0,
      assetKey: 'assets/avatars/common/ninja.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_owl',
      type: CosmeticType.avatar,
      name: 'Owl',
      description: 'Wise and watchful',
      costCoins: 0,
      assetKey: 'assets/avatars/common/owl.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_panda',
      type: CosmeticType.avatar,
      name: 'Panda',
      description: 'Black, white, and awesome',
      costCoins: 0,
      assetKey: 'assets/avatars/common/panda.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_pirate',
      type: CosmeticType.avatar,
      name: 'Pirate',
      description: 'Arr, chore time!',
      costCoins: 0,
      assetKey: 'assets/avatars/common/pirate.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_red_shades',
      type: CosmeticType.avatar,
      name: 'Red Shades',
      description: 'Too cool for chores — but doing them anyway',
      costCoins: 0,
      assetKey: 'assets/avatars/common/red-shades.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_robot_head',
      type: CosmeticType.avatar,
      name: 'Robot Head',
      description: 'Beep boop, chores complete',
      costCoins: 0,
      assetKey: 'assets/avatars/common/robot-head.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_rubber_duck',
      type: CosmeticType.avatar,
      name: 'Rubber Duck',
      description: 'Squeaky clean',
      costCoins: 0,
      assetKey: 'assets/avatars/common/rubber-duck.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_shield',
      type: CosmeticType.avatar,
      name: 'Shield',
      description: 'Defending the household',
      costCoins: 0,
      assetKey: 'assets/avatars/common/shield.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_shoe',
      type: CosmeticType.avatar,
      name: 'Shoe',
      description: 'Always on the move',
      costCoins: 0,
      assetKey: 'assets/avatars/common/shoe.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_space_helmet',
      type: CosmeticType.avatar,
      name: 'Space Helmet',
      description: 'Chores in zero gravity',
      costCoins: 0,
      assetKey: 'assets/avatars/common/space-helmet.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_taco',
      type: CosmeticType.avatar,
      name: 'Taco',
      description: 'Crunchy chore champion',
      costCoins: 0,
      assetKey: 'assets/avatars/common/taco.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_trucker_cap',
      type: CosmeticType.avatar,
      name: 'Trucker Cap',
      description: 'Hat of a hard worker',
      costCoins: 0,
      assetKey: 'assets/avatars/common/trucker-cap.png',
      rarity: CosmeticRarity.common,
    ),
    CosmeticItem(
      id: 'avatar_common_watermelon',
      type: CosmeticType.avatar,
      name: 'Watermelon',
      description: 'One in a melon',
      costCoins: 0,
      assetKey: 'assets/avatars/common/watermelon.png',
      rarity: CosmeticRarity.common,
    ),

    // ── Rare loot avatars ──
    CosmeticItem(
      id: 'avatar_rare_avatar_3',
      type: CosmeticType.avatar,
      name: 'Avatar 3',
      description: 'A rare Chorezilla hero',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/avatar_3.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_zilla',
      type: CosmeticType.avatar,
      name: 'Avatar Zilla',
      description: 'The legendary Zilla avatar',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/avatar-zilla.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_crown',
      type: CosmeticType.avatar,
      name: 'Crown',
      description: 'Royalty of chores',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/crown.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_crystal',
      type: CosmeticType.avatar,
      name: 'Crystal',
      description: 'Rare and radiant',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/crystal.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_diamond',
      type: CosmeticType.avatar,
      name: 'Diamond',
      description: 'Unbreakable work ethic',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/diamond.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_discoball',
      type: CosmeticType.avatar,
      name: 'Disco Ball',
      description: 'Dance while you chore',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/discoball.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_galaxy',
      type: CosmeticType.avatar,
      name: 'Galaxy',
      description: 'A universe of potential',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/galaxy.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_magic_cat',
      type: CosmeticType.avatar,
      name: 'Magic Cat',
      description: 'Mystical feline energy',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/magic-cat.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_ninja_cat',
      type: CosmeticType.avatar,
      name: 'Ninja Cat',
      description: 'Stealthy and swift',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/ninja-cat.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_phoenix',
      type: CosmeticType.avatar,
      name: 'Phoenix',
      description: 'Rising from the mess',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/phoenix.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_green_dragon',
      type: CosmeticType.avatar,
      name: 'Green Dragon',
      description: 'Ancient and powerful',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/rare-green-dragon.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_skull',
      type: CosmeticType.avatar,
      name: 'Skull',
      description: 'Hardcore chore mode',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/skull.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_sword',
      type: CosmeticType.avatar,
      name: 'Sword',
      description: 'Slaying the task list',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/sword.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_viking_helm',
      type: CosmeticType.avatar,
      name: 'Viking Helm',
      description: 'Conquer every chore',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/viking-helm.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_volcano',
      type: CosmeticType.avatar,
      name: 'Volcano',
      description: 'About to erupt with productivity',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/volcano.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_wand',
      type: CosmeticType.avatar,
      name: 'Wand',
      description: 'Magical chore powers',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/wand.png',
      rarity: CosmeticRarity.rare,
    ),
    CosmeticItem(
      id: 'avatar_rare_wings',
      type: CosmeticType.avatar,
      name: 'Wings',
      description: 'Fly through your task list',
      costCoins: 0,
      assetKey: 'assets/avatars/rare/wings.png',
      rarity: CosmeticRarity.rare,
    ),

    // ── Epic loot avatars ──
    CosmeticItem(
      id: 'avatar_epic_cosmic_crown',
      type: CosmeticType.avatar,
      name: 'Cosmic Crown',
      description: 'Rule the cosmos and the chores',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/cosmic-crown.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'avatar_epic_crystal_dragon',
      type: CosmeticType.avatar,
      name: 'Crystal Dragon',
      description: 'Forged from pure crystal',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/crystal-dragon.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'avatar_epic_crystal_skull',
      type: CosmeticType.avatar,
      name: 'Crystal Skull',
      description: 'Mysterious and legendary',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/crystal-skull.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'avatar_epic_green_dragon',
      type: CosmeticType.avatar,
      name: 'Epic Green Dragon',
      description: 'The mightiest dragon of all',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/epic-green-dragon.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'avatar_epic_fire_skull',
      type: CosmeticType.avatar,
      name: 'Fire Skull',
      description: 'Burning determination',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/fire-skull.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'avatar_epic_gold_dragon',
      type: CosmeticType.avatar,
      name: 'Gold Dragon',
      description: 'Worth its weight in chores',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/gold-dragon.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'avatar_epic_green_monster',
      type: CosmeticType.avatar,
      name: 'Green Monster',
      description: 'Monstrously productive',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/green-monster.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'avatar_epic_ice_dragon',
      type: CosmeticType.avatar,
      name: 'Ice Dragon',
      description: 'Chillingly efficient',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/ice-dragon.png',
      rarity: CosmeticRarity.epic,
    ),
    CosmeticItem(
      id: 'avatar_epic_zombie',
      type: CosmeticType.avatar,
      name: 'Zombie',
      description: 'Undead dedication to chores',
      costCoins: 0,
      assetKey: 'assets/avatars/epic/zombie.png',
      rarity: CosmeticRarity.epic,
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
