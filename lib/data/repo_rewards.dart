// lib/data/repo_rewards.dart
part of 'chorezilla_repo.dart';

extension RewardRepo on ChorezillaRepo {
  // Watchers (rewards)
  Stream<List<Reward>> watchRewards(
    String familyId, {
    bool? activeOnly = true,
  }) {
    Query q = rewardsColl(firebaseDB, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Reward.fromDoc).toList());
  }

  // Writes: Rewards (coins store)
  Future<String> createReward(
    String familyId, {
    required String name,
    required int priceCoins,
    int? stock,
  }) async {
    final ref = rewardsColl(firebaseDB, familyId).doc();
    await ref.set({
      'name': name,
      'priceCoins': priceCoins,
      'stock': stock,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> purchaseReward(
    String familyId, {
    required String memberId,
    required Reward reward,
  }) async {
    final memberRef = membersColl(firebaseDB, familyId).doc(memberId);
    final rewardRef = rewardsColl(firebaseDB, familyId).doc(reward.id);

    await firebaseDB.runTransaction((tx) async {
      final memSnap = await tx.get(memberRef);
      if (!memSnap.exists) throw Exception('Member not found');
      final member = Member.fromDoc(memSnap);

      if (member.coins < reward.priceCoins) {
        throw Exception('Not enough coins');
      }

      tx.update(memberRef, {'coins': FieldValue.increment(-reward.priceCoins)});

      if (reward.stock != null) {
        final rSnap = await tx.get(rewardRef);
        if (!rSnap.exists) throw Exception('Reward not found');
        final current = Reward.fromDoc(rSnap);
        final newStock = (current.stock ?? 0) - 1;
        if (newStock < 0) throw Exception('Out of stock');
        tx.update(rewardRef, {'stock': newStock});
      }

      final evRef = eventsColl(firebaseDB, familyId).doc();
      tx.set(evRef, {
        'type': 'reward_purchased',
        'actorMemberId': memberId,
        'targetMemberId': memberId,
        'payload': {
          'rewardId': reward.id,
          'name': reward.name,
          'priceCoins': reward.priceCoins,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
