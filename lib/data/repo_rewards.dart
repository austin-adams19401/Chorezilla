// lib/data/repo_rewards.dart
part of 'chorezilla_repo.dart';

extension RewardRepo on ChorezillaRepo {
  // ─────────────────────────────────────────────────────────────────────────
  // Watch rewards for a family
  // ─────────────────────────────────────────────────────────────────────────
  Stream<List<Reward>> watchRewards(String familyId, {bool activeOnly = true}) {
    Query q = rewardsColl(firebaseDB, familyId);
    if (activeOnly) {
      q = q.where('active', isEqualTo: true);
    }

    return q.snapshots().map(
      (snap) => snap.docs.map((d) => Reward.fromDoc(d)).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Create reward
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> createReward(
    String familyId, {
    required String title,
    String? description,
    String? icon,
    required int coinCost,
    required RewardCategory category,
    bool isCustom = true,
    int? stock,
  }) async {
    final ref = rewardsColl(firebaseDB, familyId).doc();
    await ref.set({
      'title': title,
      'name': title, // backwards-compat
      'description': description,
      'icon': icon,
      'coinCost': coinCost,
      'priceCoins': coinCost, // backwards-compat
      'category': category.name,
      'isCustom': isCustom,
      'stock': stock,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Enable / disable reward
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> setRewardActive(
    String familyId, {
    required String rewardId,
    required bool active,
  }) async {
    final ref = rewardsColl(firebaseDB, familyId).doc(rewardId);
    await ref.update({'active': active});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pending rewards
  // ─────────────────────────────────────────────────────────────────────────

    /// Watch all pending reward redemptions for this family.
  Stream<List<RewardRedemption>> watchPendingRewardRedemptions(
    String familyId,
  ) {
    return eventsColl(firebaseDB, familyId)
        .where('type', isEqualTo: 'reward_purchased')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(RewardRedemption.fromDoc).toList());
  }

  /// Mark a pending reward as given by a parent.
  Future<void> markRewardGiven(
    String familyId, {
    required String redemptionId,
    String? parentMemberId,
  }) async {
    final ref = eventsColl(firebaseDB, familyId).doc(redemptionId);
    await ref.update({
      'status': 'granted',
      'grantedAt': FieldValue.serverTimestamp(),
      if (parentMemberId != null) 'grantedByMemberId': parentMemberId,
    });
  }


  // ─────────────────────────────────────────────────────────────────────────
  // Seed starter rewards (the defaults you used with your kids)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> seedStarterRewards(String familyId) async {
    final batch = firebaseDB.batch();
    final coll = rewardsColl(firebaseDB, familyId);

    void addReward({
      required String title,
      String? description,
      String? icon,
      required int coinCost,
      required RewardCategory category,
    }) {
      final ref = coll.doc();
      batch.set(ref, {
        'title': title,
        'name': title,
        'description': description,
        'icon': icon,
        'coinCost': coinCost,
        'priceCoins': coinCost,
        'category': category.name,
        'isCustom': false,
        'stock': null,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Example starter set (tuned to your 80–90 XP/day reality)
    addReward(
      title: 'Pick a dessert for the family',
      description: 'You choose what we have for dessert.',
      icon: '🍨',
      coinCost: 15,
      category: RewardCategory.snack,
    );

    addReward(
      title: 'Extra 15 min screen',
      description: 'Extra 15 minutes of game or show time.',
      icon: '🎮',
      coinCost: 5,
      category: RewardCategory.time,
    );

    addReward(
      title: 'Stay up 15 min late',
      description: 'Bedtime shift: stay up 15 minutes later.',
      icon: '🌙',
      coinCost: 25,
      category: RewardCategory.time,
    );

    addReward(
      title: 'Family movie picker',
      description: 'You pick the movie for family night.',
      icon: '🎬',
      coinCost: 20,
      category: RewardCategory.experience,
    );

    addReward(
      title: 'One-on-one game with a Parent',
      description: '20 minutes of 1:1 game time with a parent.',
      icon: '🎲',
      coinCost: 30,
      category: RewardCategory.experience,
    );

    addReward(
      title: 'Profile border upgrade',
      description: 'Unlock a fun profile frame in the app.',
      icon: '✨',
      coinCost: 5,
      category: RewardCategory.digital,
    );

    addReward(
      title: 'Change avatar background',
      description: 'Customize your avatar background in the app.',
      icon: '🎨',
      coinCost: 5,
      category: RewardCategory.digital,
    );

    addReward(
      title: '\$5 allowance bonus',
      description: 'Extra \$5 in allowance this week.',
      icon: '💵',
      coinCost: 50,
      category: RewardCategory.money,
    );

    await batch.commit();
  }

    Future<void> createRewardRedemption(
    String familyId, {
    required String memberId,
    String? rewardId,
    required String rewardName,
    required int coinCost,
  }) async {
    final ref = rewardRedemptionsColl(firebaseDB, familyId).doc();
    final data = <String, dynamic>{
      'memberId': memberId,
      'rewardName': rewardName,
      'coinCost': coinCost,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (rewardId != null) {
      data['rewardId'] = rewardId;
    }
    await ref.set(data);
  }


  // ─────────────────────────────────────────────────────────────────────────
  // Purchase reward (spend coins + stock + log event)
  // ─────────────────────────────────────────────────────────────────────────
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

      if (member.coins < reward.coinCost) {
        throw Exception('Not enough coins');
      }

      tx.update(memberRef, {'coins': FieldValue.increment(-reward.coinCost)});

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
          'name': reward.title,
          'priceCoins': reward.coinCost,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class RewardRedemption {
  final String id; // event doc id
  final String rewardId;
  final String rewardName;
  final int coinCost;
  final String memberId; // kid who earned it
  final String status; // pending / granted
  final DateTime? createdAt;

  RewardRedemption({
    required this.id,
    required this.rewardId,
    required this.rewardName,
    required this.coinCost,
    required this.memberId,
    required this.status,
    required this.createdAt,
  });

  factory RewardRedemption.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final payload = data['payload'] as Map<String, dynamic>? ?? {};

    return RewardRedemption(
      id: doc.id,
      rewardId: payload['rewardId'] as String? ?? '',
      rewardName: payload['name'] as String? ?? 'Reward',
      coinCost: (payload['priceCoins'] as num?)?.toInt() ?? 0,
      memberId: data['targetMemberId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: tsAsDate(data['createdAt']),
    );
  }
}

