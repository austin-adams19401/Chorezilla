// lib/data/repo_cosmetics.dart
part of 'chorezilla_repo.dart';

extension CosmeticsRepo on ChorezillaRepo {
  /// Purchases a cosmetic item for a kid using a Firestore transaction.
  /// Deducts [item.costCoins] coins and appends the item id to ownedCosmetics.
  Future<void> purchaseCosmetic(
    String familyId, {
    required String memberId,
    required String itemId,
    required int costCoins,
  }) async {
    final memberRef = membersColl(firebaseDB, familyId).doc(memberId);

    await firebaseDB.runTransaction((tx) async {
      final snap = await tx.get(memberRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final coins = (data['coins'] as num?)?.toInt() ?? 0;
      final owned = (data['ownedCosmetics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      if (coins < costCoins) throw Exception('Not enough coins');
      if (owned.contains(itemId)) throw Exception('Already owned');

      tx.update(memberRef, {
        'coins': coins - costCoins,
        'ownedCosmetics': [...owned, itemId],
      });
    });
  }

  /// Opens a loot box for a kid. The roll result is computed client-side
  /// before calling this. Deducts [boxCostCoins] and:
  /// - If not a duplicate: adds [wonItemId] to ownedCosmetics
  /// - If a duplicate: refunds [coinRefund] coins instead
  Future<void> openLootBox(
    String familyId, {
    required String memberId,
    required int boxCostCoins,
    required String wonItemId,
    required bool isDuplicate,
    required int coinRefund,
  }) async {
    final memberRef = membersColl(firebaseDB, familyId).doc(memberId);

    await firebaseDB.runTransaction((tx) async {
      final snap = await tx.get(memberRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final coins = (data['coins'] as num?)?.toInt() ?? 0;
      final owned = (data['ownedCosmetics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      if (coins < boxCostCoins) throw Exception('Not enough coins');

      final newCoins = coins - boxCostCoins + coinRefund;
      final newOwned = isDuplicate ? owned : [...owned, wonItemId];

      tx.update(memberRef, {
        'coins': newCoins,
        'ownedCosmetics': newOwned,
      });
    });
  }

  /// Equips a cosmetic item for a kid by updating the relevant equipped field.
  Future<void> equipCosmetic(
    String familyId, {
    required String memberId,
    required String fieldName,
    required String itemId,
  }) async {
    await membersColl(firebaseDB, familyId).doc(memberId).update({
      fieldName: itemId,
    });
  }
}
