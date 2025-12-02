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

  // Convenience: watch rewards for a specific category.
  Stream<List<Reward>> watchRewardsByCategory(
    String familyId, {
    required RewardCategory category,
    bool activeOnly = true,
  }) {
    Query q = rewardsColl(
      firebaseDB,
      familyId,
    ).where('category', isEqualTo: category.name);
    if (activeOnly) {
      q = q.where('active', isEqualTo: true);
    }
    return q.snapshots().map((snap) => snap.docs.map(Reward.fromDoc).toList());
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
    bool requiresApproval = false,
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
      'requiresApproval': requiresApproval,
      'isCustom': isCustom,
      'stock': stock,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> deleteReward(String familyId, {required String rewardId}) async {
    final ref = rewardsColl(firebaseDB, familyId).doc(rewardId);
    await ref.delete();
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
  // Reward redemptions
  // ─────────────────────────────────────────────────────────────────────────

  /// Watch all pending reward redemptions for this family (parent queue).
  Stream<List<RewardRedemption>> watchPendingRewardRedemptions(
    String familyId,
  ) {
    return rewardRedemptionsColl(firebaseDB, familyId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(RewardRedemption.fromDoc).toList());
  }

  /// Watch reward redemptions for a specific kid (for "My Rewards").
  Stream<List<RewardRedemption>> watchRewardRedemptionsForMember(
    String familyId, {
    required String memberId,
    bool onlyPending = false,
  }) {
    Query q = rewardRedemptionsColl(
      firebaseDB,
      familyId,
    ).where('memberId', isEqualTo: memberId);

    if (onlyPending) {
      q = q.where('status', isEqualTo: 'pending');
    }

    q = q.orderBy('createdAt', descending: true);

    return q.snapshots().map(
      (s) => s.docs.map(RewardRedemption.fromDoc).toList(),
    );
  }

  /// Mark a pending reward as given by a parent.
  Future<void> markRewardGiven(
    String familyId, {
    required String redemptionId,
    String? parentMemberId,
  }) async {
    final ref = rewardRedemptionsColl(firebaseDB, familyId).doc(redemptionId);
    await ref.update({
      'status': 'given',
      'givenAt': FieldValue.serverTimestamp(),
      if (parentMemberId != null) 'parentMemberId': parentMemberId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Seed starter rewards
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
      bool requiresApproval = false,
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
        'requiresApproval': requiresApproval,
        'isCustom': false,
        'stock': null,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
// 5 coins
addReward(
  title: 'Candy',
  description: 'Pick a small candy treat.',
  icon: '🍬',
  coinCost: 5,
  category: RewardCategory.snack,
  requiresApproval: true,
);

addReward(
  title: 'Sticker',
  description: 'Choose a fun sticker.',
  icon: '🏷️',
  coinCost: 5,
  category: RewardCategory.toy,
  requiresApproval: true,
);

addReward(
  title: 'Temporary Tattoo',
  description: 'Pick a temporary tattoo to wear.',
  icon: '🖋️',
  coinCost: 5,
  category: RewardCategory.toy,
  requiresApproval: true,
);

// 10 coins
addReward(
  title: 'Dessert',
  description: 'You choose what we have for dessert tonight.',
  icon: '🍰',
  coinCost: 10,
  category: RewardCategory.snack,
  requiresApproval: true,
);

addReward(
  title: 'Treasure Box',
  description: 'Pick one prize from the family treasure box.',
  icon: '🧰',
  coinCost: 10,
  category: RewardCategory.toy,
  requiresApproval: true,
);

addReward(
  title: 'Choose Dinner',
  description: 'You decide what the family has for dinner.',
  icon: '🍽️',
  coinCost: 10,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: 'Bedtime Story',
  description: 'Choose a special bedtime story and extra reading time.',
  icon: '📚',
  coinCost: 10,
  category: RewardCategory.experience,
  requiresApproval: true,
);

// 20 coins
addReward(
  title: 'Choose Car Music',
  description: 'You control the music in the car for the trip.',
  icon: '🚗',
  coinCost: 20,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: 'Double XP for 1 Day',
  description: 'Earn double XP on all chores for one full day.',
  icon: '✨',
  coinCost: 20,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: 'Go to the Park',
  description: 'Special trip to the park to play.',
  icon: '🏞️',
  coinCost: 20,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: 'Extra Backscratch',
  description: 'Get an extra-long backscratch or cuddle time.',
  icon: '🤗',
  coinCost: 20,
  category: RewardCategory.experience,
  requiresApproval: true,
);

// 30 coins
addReward(
  title: 'Stay Up 30 Minutes Late',
  description: 'Bedtime is moved 30 minutes later for one night.',
  icon: '🌙',
  coinCost: 30,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: '3D Print',
  description: 'Design and print a small item on the 3D printer.',
  icon: '🖨️',
  coinCost: 30,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: 'Bake Cookies',
  description: 'Bake a batch of cookies together.',
  icon: '🍪',
  coinCost: 30,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: 'Gas Station Treats',
  description: 'Trip to the gas station for a drink or snack.',
  icon: '🍩',
  coinCost: 30,
  category: RewardCategory.snack,
  requiresApproval: true,
);

// 40 coins
addReward(
  title: 'Game Night',
  description: 'Family game night with games you choose.',
  icon: '🎲',
  coinCost: 40,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: 'Movie Night',
  description: 'Family movie night with your movie choice.',
  icon: '🎬',
  coinCost: 40,
  category: RewardCategory.experience,
  requiresApproval: true,
);

// 50 coins
addReward(
  title: 'Room Decoration',
  description: 'Pick a new decoration or poster for your room.',
  icon: '🖼️',
  coinCost: 50,
  category: RewardCategory.toy,
  requiresApproval: true,
);

addReward(
  title: 'New Toy',
  description: 'Choose a small new toy within the family budget.',
  icon: '🧸',
  coinCost: 50,
  category: RewardCategory.toy,
  requiresApproval: true,
);

// 80 coins
addReward(
  title: 'Sleepover in Living Room',
  description: 'Sleep in the living room with blankets, pillows, and a movie or game.',
  icon: '🛋️',
  coinCost: 80,
  category: RewardCategory.experience,
  requiresApproval: true,
);

addReward(
  title: '\$5 Cash',
  description: 'Get \$5 to save or spend (with parent help).',
  icon: '💵',
  coinCost: 80,
  category: RewardCategory.money,
  requiresApproval: true,
);

// 150 coins
addReward(
  title: 'New Video Game',
  description: 'Pick a new video game within the family budget.',
  icon: '🎮',
  coinCost: 150,
  category: RewardCategory.toy,
  requiresApproval: true,
);

addReward(
  title: 'Bike Upgrade',
  description: 'Get an upgrade or accessory for your bike.',
  icon: '🚲',
  coinCost: 150,
  category: RewardCategory.toy,
  requiresApproval: true,
);

addReward(
  title: 'Go to Arcade',
  description: 'Trip to the arcade for games and fun.',
  icon: '🕹️',
  coinCost: 150,
  category: RewardCategory.experience,
  requiresApproval: true,
);

// 750 coins
addReward(
  title: '\$100 Cash',
  description: 'Big reward: \$100 to save or spend with parent guidance.',
  icon: '💰',
  coinCost: 750,
  category: RewardCategory.money,
  requiresApproval: true,
);

addReward(
  title: 'Go to Sports Game',
  description: 'Go to a live sports game together.',
  icon: '🏟️',
  coinCost: 750,
  category: RewardCategory.experience,
  requiresApproval: true,
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
        // Still "pending" until parent marks as given.
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await createRewardRedemption(
      familyId,
      memberId: memberId,
      rewardId: reward.id,
      rewardName: reward.title,
      coinCost: reward.coinCost,
    );
  }

  /// Create (or no-op if exists) a pending weekly allowance redemption.
  Future<void> createWeeklyAllowanceRedemption(
    String familyId, {
    required String memberId,
    required int payoutCents,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final coll = rewardRedemptionsColl(firebaseDB, familyId);

    final weekKey =
        '${weekStart.year.toString().padLeft(4, '0')}-'
        '${weekStart.month.toString().padLeft(2, '0')}-'
        '${weekStart.day.toString().padLeft(2, '0')}';

    final docId = 'allowance_${memberId}_$weekKey';
    final ref = coll.doc(docId);

    final existing = await ref.get();
    if (existing.exists) {
      // Already created this week's allowance for this kid.
      return;
    }

    final title =
        'Weekly allowance \$${(payoutCents / 100).toStringAsFixed(2)}';

    await ref.set({
      'memberId': memberId,
      'rewardName': title,
      'coinCost': 0,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),

      // Extra metadata
      'type': 'allowance',
      'payoutCents': payoutCents,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
    });
  }

  Future<void> createLevelUpRewardRedemption(
    String familyId, {
    required String memberId,
    required int level,
    required String rewardTitle,
  }) async {
    final coll = rewardRedemptionsColl(firebaseDB, familyId);

    // One doc per kid + level → prevents duplicates
    final docId = 'level_${memberId}_$level';
    final ref = coll.doc(docId);

    final existing = await ref.get();
    if (existing.exists) {
      // Already created (maybe we re-ran the celebration) → do nothing.
      return;
    }

    await ref.set({
      'memberId': memberId,
      'rewardId': null, // not tied to a specific Reward document
      'rewardName': rewardTitle,
      'coinCost': 0,
      'status': 'pending', // shows as "Waiting for parent"
      'createdAt': FieldValue.serverTimestamp(),
      'givenAt': null,
      'parentMemberId': null,

      // Extra metadata (safe – your model just ignores unknown fields)
      'level': level,
      'source': 'levelUp',
    });
  }
}
