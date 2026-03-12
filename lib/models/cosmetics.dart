// lib/models/cosmetics.dart

import 'dart:math' as math;

import 'package:chorezilla/models/common.dart';

class CosmeticItem {
  final String id; // e.g. 'bg_blue_sky'
  final CosmeticType type; // background / zillaSkin / avatarFrame / title
  final String name; // 'Blue Sky'
  final String description; // 'Soft blue gradient background'
  final int costCoins; // 0 for default
  final String assetKey; // 'assets/backgrounds/blue_sky.png' (empty for text/drawn types)
  final bool isDefault;

  const CosmeticItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.costCoins,
    this.assetKey = '',
    this.isDefault = false,
  });
}

// ---------------------------------------------------------------------------
// Loot box models
// ---------------------------------------------------------------------------

class LootBoxPoolEntry {
  final String cosmeticId;
  final int weight; // higher = more likely

  const LootBoxPoolEntry({required this.cosmeticId, required this.weight});
}

class LootBoxDefinition {
  final String id;
  final String name;
  final String description;
  final String tierEmoji;
  final int costCoins;
  final int duplicateCoinRefund;
  final List<LootBoxPoolEntry> pool;

  const LootBoxDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.tierEmoji,
    required this.costCoins,
    required this.duplicateCoinRefund,
    required this.pool,
  });
}

class LootBoxResult {
  final CosmeticItem wonItem;
  final bool isDuplicate;
  final int coinRefund;

  const LootBoxResult({
    required this.wonItem,
    required this.isDuplicate,
    required this.coinRefund,
  });
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
    // ── 50 coins ──
    CosmeticItem(
      id: 'bg_kitchen',
      type: CosmeticType.background,
      name: 'Kitchen',
      description: 'A bright cozy kitchen',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_kitchen.png',
    ),
    CosmeticItem(
      id: 'bg_backyard',
      type: CosmeticType.background,
      name: 'Backyard',
      description: 'Sunny outdoor fun',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_backyard.png',
    ),
    CosmeticItem(
      id: 'bg_laundry',
      type: CosmeticType.background,
      name: 'Laundry Room',
      description: 'Suds and spin cycles',
      costCoins: 50,
      assetKey: 'assets/backgrounds/bg_laundry.png',
    ),
    // ── 75 coins ──
    CosmeticItem(
      id: 'bg_dino',
      type: CosmeticType.background,
      name: 'Dino World',
      description: 'Prehistoric Zilla territory',
      costCoins: 75,
      assetKey: 'assets/backgrounds/bg_dino.png',
    ),
    CosmeticItem(
      id: 'bg_jungle',
      type: CosmeticType.background,
      name: 'Jungle',
      description: 'Deep in the wild',
      costCoins: 75,
      assetKey: 'assets/backgrounds/bg_jungle.png',
    ),
    CosmeticItem(
      id: 'bg_candyland',
      type: CosmeticType.background,
      name: 'Candy Land',
      description: 'Everything is sweet',
      costCoins: 75,
      assetKey: 'assets/backgrounds/bg_candyland.png',
    ),
    // ── 100 coins ──
    CosmeticItem(
      id: 'bg_ocean',
      type: CosmeticType.background,
      name: 'Ocean',
      description: 'Deep blue waves',
      costCoins: 100,
      assetKey: 'assets/backgrounds/bg_ocean.png',
    ),
    CosmeticItem(
      id: 'bg_space',
      type: CosmeticType.background,
      name: 'Space',
      description: 'Blast off into the cosmos',
      costCoins: 100,
      assetKey: 'assets/backgrounds/bg_space.png',
    ),
    CosmeticItem(
      id: 'bg_minecraft',
      type: CosmeticType.background,
      name: 'Block World',
      description: 'Mine, craft, do chores',
      costCoins: 100,
      assetKey: 'assets/backgrounds/bg_minecraft.png',
    ),
    // ── 150 coins ──
    CosmeticItem(
      id: 'bg_space2',
      type: CosmeticType.background,
      name: 'Deep Space',
      description: 'A galaxy far, far away',
      costCoins: 150,
      assetKey: 'assets/backgrounds/bg_space2.png',
    ),
    CosmeticItem(
      id: 'bg_pirate',
      type: CosmeticType.background,
      name: 'Pirate Seas',
      description: 'Arr, chores on the high seas',
      costCoins: 150,
      assetKey: 'assets/backgrounds/bg_pirate.png',
    ),
    CosmeticItem(
      id: 'bg_dragon',
      type: CosmeticType.background,
      name: 'Dragon Lair',
      description: 'Here be dragons',
      costCoins: 150,
      assetKey: 'assets/backgrounds/bg_dragon.png',
    ),
    // ── 200 coins ──
    CosmeticItem(
      id: 'bg_arena',
      type: CosmeticType.background,
      name: 'Arena',
      description: 'Champion of chores',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_arena.png',
    ),
    CosmeticItem(
      id: 'bg_volcano',
      type: CosmeticType.background,
      name: 'Volcano',
      description: 'Hot hot hot',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_volcano.png',
    ),
    CosmeticItem(
      id: 'bg_treasure',
      type: CosmeticType.background,
      name: 'Treasure Cave',
      description: 'X marks the chore',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_treasure.png',
    ),
    CosmeticItem(
      id: 'bg_unicorn',
      type: CosmeticType.background,
      name: 'Unicorn Land',
      description: 'Magical and sparkly',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_unicorn.png',
    ),
    CosmeticItem(
      id: 'bg_levelup',
      type: CosmeticType.background,
      name: 'Level Up',
      description: 'For the true Chore Champion',
      costCoins: 200,
      assetKey: 'assets/backgrounds/bg_levelup.png',
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
    CosmeticItem(
      id: 'zilla_blue_hoodie',
      type: CosmeticType.zillaSkin,
      name: 'Blue Hoodie',
      description: 'Cozy hoodie Zilla',
      costCoins: 100,
      assetKey: 'assets/zilla/blue/hoodie_sheet.png',
    ),
    CosmeticItem(
      id: 'zilla_red_cape',
      type: CosmeticType.zillaSkin,
      name: 'Red Cape',
      description: 'Super Zilla to the rescue',
      costCoins: 150,
      assetKey: 'assets/zilla/red/cape_sheet.png',
    ),
    CosmeticItem(
      id: 'zilla_pirate',
      type: CosmeticType.zillaSkin,
      name: 'Pirate Zilla',
      description: 'Arr, chores be done on time!',
      costCoins: 200,
      assetKey: 'assets/zilla/pirate/pirate_sheet.png',
    ),
    CosmeticItem(
      id: 'zilla_wizard',
      type: CosmeticType.zillaSkin,
      name: 'Wizard Zilla',
      description: 'Conjuring clean rooms since forever',
      costCoins: 250,
      assetKey: 'assets/zilla/wizard/wizard_sheet.png',
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
    CosmeticItem(
      id: 'frame_stars',
      type: CosmeticType.avatarFrame,
      name: 'Starry',
      description: 'Little gold stars',
      costCoins: 50,
    ),
    CosmeticItem(
      id: 'frame_rainbow',
      type: CosmeticType.avatarFrame,
      name: 'Rainbow',
      description: 'All the colors',
      costCoins: 100,
    ),
    CosmeticItem(
      id: 'frame_gold',
      type: CosmeticType.avatarFrame,
      name: 'Gold',
      description: 'Shiny double gold border',
      costCoins: 150,
    ),
    CosmeticItem(
      id: 'frame_fire',
      type: CosmeticType.avatarFrame,
      name: 'Fire',
      description: 'Blazing flames border',
      costCoins: 200,
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
    CosmeticItem(
      id: 'title_good_helper',
      type: CosmeticType.title,
      name: 'Good Helper',
      description: 'A reliable member of the team',
      costCoins: 30,
    ),
    CosmeticItem(
      id: 'title_chore_champ',
      type: CosmeticType.title,
      name: 'Chore Champ',
      description: 'Crushing it every day',
      costCoins: 50,
    ),
    CosmeticItem(
      id: 'title_streak_master',
      type: CosmeticType.title,
      name: 'Streak Master',
      description: 'Never misses a day',
      costCoins: 75,
    ),
    CosmeticItem(
      id: 'title_legend',
      type: CosmeticType.title,
      name: 'The Legend',
      description: 'Need we say more?',
      costCoins: 150,
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
// Loot box catalog
// ---------------------------------------------------------------------------

class LootBoxCatalog {
  static const boxes = <LootBoxDefinition>[
    LootBoxDefinition(
      id: 'lootbox_common',
      name: 'Common Crate',
      description: 'A mystery box with basic goodies',
      tierEmoji: '📦',
      costCoins: 75,
      duplicateCoinRefund: 15,
      pool: [
        LootBoxPoolEntry(cosmeticId: 'bg_kitchen', weight: 20),
        LootBoxPoolEntry(cosmeticId: 'bg_backyard', weight: 20),
        LootBoxPoolEntry(cosmeticId: 'bg_candyland', weight: 20),
        LootBoxPoolEntry(cosmeticId: 'frame_stars', weight: 25),
        LootBoxPoolEntry(cosmeticId: 'title_good_helper', weight: 15),
      ],
    ),
    LootBoxDefinition(
      id: 'lootbox_rare',
      name: 'Rare Chest',
      description: 'Better odds for cooler stuff',
      tierEmoji: '💎',
      costCoins: 200,
      duplicateCoinRefund: 40,
      pool: [
        LootBoxPoolEntry(cosmeticId: 'bg_ocean', weight: 15),
        LootBoxPoolEntry(cosmeticId: 'bg_dino', weight: 15),
        LootBoxPoolEntry(cosmeticId: 'bg_space', weight: 15),
        LootBoxPoolEntry(cosmeticId: 'frame_rainbow', weight: 20),
        LootBoxPoolEntry(cosmeticId: 'frame_gold', weight: 15),
        LootBoxPoolEntry(cosmeticId: 'zilla_blue_hoodie', weight: 10),
        LootBoxPoolEntry(cosmeticId: 'title_chore_champ', weight: 10),
      ],
    ),
    LootBoxDefinition(
      id: 'lootbox_epic',
      name: 'Epic Vault',
      description: 'Rare skins and legendary items inside',
      tierEmoji: '🌟',
      costCoins: 500,
      duplicateCoinRefund: 100,
      pool: [
        LootBoxPoolEntry(cosmeticId: 'zilla_red_cape', weight: 20),
        LootBoxPoolEntry(cosmeticId: 'zilla_pirate', weight: 15),
        LootBoxPoolEntry(cosmeticId: 'zilla_wizard', weight: 10),
        LootBoxPoolEntry(cosmeticId: 'frame_fire', weight: 20),
        LootBoxPoolEntry(cosmeticId: 'title_streak_master', weight: 20),
        LootBoxPoolEntry(cosmeticId: 'title_legend', weight: 15),
      ],
    ),
  ];

  static LootBoxDefinition? byId(String id) =>
      boxes.cast<LootBoxDefinition?>().firstWhere(
        (b) => b?.id == id,
        orElse: () => null,
      );

  /// Picks a random item from [box]'s weighted pool.
  /// If the item is already in [ownedCosmetics], marks it as a duplicate
  /// and sets the coin refund.
  static LootBoxResult roll(
    LootBoxDefinition box,
    List<String> ownedCosmetics,
  ) {
    final totalWeight = box.pool.fold(0, (sum, e) => sum + e.weight);
    var roll = math.Random().nextInt(totalWeight);

    LootBoxPoolEntry? picked;
    for (final entry in box.pool) {
      roll -= entry.weight;
      if (roll < 0) {
        picked = entry;
        break;
      }
    }
    picked ??= box.pool.last;

    final wonItem = CosmeticCatalog.byId(picked.cosmeticId);
    final isDuplicate = ownedCosmetics.contains(wonItem.id);

    return LootBoxResult(
      wonItem: wonItem,
      isDuplicate: isDuplicate,
      coinRefund: isDuplicate ? box.duplicateCoinRefund : 0,
    );
  }
}
