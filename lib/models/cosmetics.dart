// lib/models/cosmetics.dart

import 'package:chorezilla/models/common.dart';

class CosmeticItem {
  final String id; // e.g. 'bg_blue_sky'
  final CosmeticType type; // background / zillaSkin
  final String name; // 'Blue Sky'
  final String description; // 'Soft blue gradient background'
  final int costCoins; // 0 for default
  final String assetKey; // 'assets/backgrounds/blue_sky.png'
  final bool isDefault;

  const CosmeticItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.costCoins,
    required this.assetKey,
    this.isDefault = false,
  });
}

class CosmeticCatalog {
  static const items = <CosmeticItem>[
    // BACKGROUNDS
    CosmeticItem(
      id: 'bg_default',
      type: CosmeticType.background,
      name: 'Default',
      description: 'Classic Chorezilla look',
      costCoins: 0,
      assetKey: 'assets/backgrounds/default.png',
      isDefault: true,
    ),
    CosmeticItem(
      id: 'bg_sunset',
      type: CosmeticType.background,
      name: 'Sunset Glow',
      description: 'Warm orange and pink gradient',
      costCoins: 50,
      assetKey: 'assets/backgrounds/sunset.png',
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
  ];

  /// Returns the cosmetic for [id], or a default cosmetic if unknown.
  static CosmeticItem byId(String id) {
    final exact = items.where((c) => c.id == id);
    if (exact.isNotEmpty) return exact.first;

    final defaults = items.where((c) => c.isDefault);
    if (defaults.isNotEmpty) return defaults.first;

    return items.first;
  }

  static Iterable<CosmeticItem> backgrounds() =>
      items.where((c) => c.type == CosmeticType.background);

  static Iterable<CosmeticItem> zillaSkins() =>
      items.where((c) => c.type == CosmeticType.zillaSkin);
}
