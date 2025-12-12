enum CosmeticType { background, zillaSkin }

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

  static CosmeticItem? byId(String id) =>
      items.firstWhere((c) => c.id == id, orElse: () => items.first);
}
