// lib/state/cosmetic_state.dart
part of 'app_state.dart';

extension AppStateCosmetics on AppState {
  /// Purchases a cosmetic item for [memberId], deducting coins from their balance.
  /// Throws if they can't afford it or already own it.
  Future<void> purchaseCosmetic(String memberId, CosmeticItem item) async {
    final famId = _familyId!;
    final member = members.firstWhere((m) => m.id == memberId);

    if (member.coins < item.costCoins) {
      throw Exception('Not enough coins to buy ${item.name}');
    }
    if (member.ownsCosmetic(item.id)) {
      throw Exception('Already owned');
    }

    await BackendFunctions.purchaseCosmetic(
      familyId: famId,
      memberId: memberId,
      itemId: item.id,
    );
  }

  /// Opens a loot box server-side. The returned rolls are what the 3-tap
  /// dialog should reveal; the coin deduction already happened.
  Future<LootBoxServerResult> openLootBox(
    String memberId,
    LootBoxDefinition box,
  ) async {
    final famId = _familyId!;
    final member = members.firstWhere((m) => m.id == memberId);

    if (member.coins < box.costCoins) {
      throw Exception('Not enough coins to open ${box.name}');
    }

    return BackendFunctions.openLootBox(
      familyId: famId,
      memberId: memberId,
      boxId: box.id,
    );
  }

  /// Grants the level-up cosmetic for [level] if XP already qualifies.
  Future<String?> grantLevelCosmetic(String memberId, int level) {
    final famId = _familyId!;
    return BackendFunctions.grantLevelCosmetic(
      familyId: famId,
      memberId: memberId,
      level: level,
    );
  }

  /// Equips a cosmetic item for [memberId], updating the relevant Firestore field.
  Future<void> equipCosmetic(String memberId, CosmeticItem item) async {
    final famId = _familyId!;
    final fieldName = _equipFieldForType(item.type);
    await repo.equipCosmetic(
      famId,
      memberId: memberId,
      fieldName: fieldName,
      itemId: item.id,
    );
  }

  String _equipFieldForType(CosmeticType type) {
    switch (type) {
      case CosmeticType.background:
        return 'equippedBackgroundId';
      case CosmeticType.zillaSkin:
        return 'equippedZillaSkinId';
      case CosmeticType.avatarFrame:
        return 'equippedAvatarFrameId';
      case CosmeticType.title:
        return 'equippedTitleId';
      case CosmeticType.avatar:
        return 'avatarKey';
    }
  }
}
