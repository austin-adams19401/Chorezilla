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

    await repo.purchaseCosmetic(
      famId,
      memberId: memberId,
      itemId: item.id,
      costCoins: item.costCoins,
    );
  }

  /// Opens a loot box for [memberId] using the result from the 3-click dialog.
  /// Writes the outcome to Firestore.
  Future<void> openLootBox(
    String memberId,
    LootBoxDefinition box,
    LootBoxClickState result,
  ) async {
    final famId = _familyId!;
    final member = members.firstWhere((m) => m.id == memberId);

    if (member.coins < box.costCoins) {
      throw Exception('Not enough coins to open ${box.name}');
    }

    await repo.openLootBox(
      famId,
      memberId: memberId,
      boxCostCoins: box.costCoins,
      wonItemId: result.wonItem!.id,
      isDuplicate: result.isDuplicate,
      coinRefund: result.coinRefund,
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
    }
  }
}
