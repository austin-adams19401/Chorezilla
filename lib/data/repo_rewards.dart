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

  Future<void> updateReward(
    String familyId, {
    required String rewardId,
    required String title,
    String? description,
    String? icon,
    required int coinCost,
    required RewardCategory category,
    int? stock,
  }) async {
    final db = FirebaseFirestore.instance;
    final ref = db
        .collection('families')
        .doc(familyId)
        .collection('rewards')
        .doc(rewardId);

    await ref.set({
      'title': title,
      'description': description, // ok if null
      'icon': icon, // ok if null
      'coinCost': coinCost,
      'category': category.name, // assumes you store as string enum name
      'stock': stock, // null = unlimited
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


  Future<void> restockReward(
    String familyId, {
    required String rewardId,
  }) {
    return rewardsColl(firebaseDB, familyId).doc(rewardId).update({
      'memberPurchaseCounts': {},
      'restockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restockRewardForKid(
    String familyId, {
    required String rewardId,
    required String memberId,
  }) {
    return rewardsColl(firebaseDB, familyId).doc(rewardId).update({
      'memberPurchaseCounts.$memberId': FieldValue.delete(),
    });
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

  /// Watch ALL reward redemptions for this family (all statuses, all members).
  /// Used by the parent rewards page to compute per-kid stock counts.
  Stream<List<RewardRedemption>> watchAllRewardRedemptionsForFamily(
    String familyId,
  ) {
    return rewardRedemptionsColl(firebaseDB, familyId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(RewardRedemption.fromDoc).toList());
  }

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
      'status': 'fulfilled',
      'givenAt': FieldValue.serverTimestamp(),
      'parentMemberId': ?parentMemberId,
    });
  }

    /// Refund a pending reward: return coins to the kid and mark as cancelled.
  Future<void> refundRewardRedemption(
    String familyId, {
    required RewardRedemption redemption,
    String? parentMemberId,
  }) async {
    final db = firebaseDB;

    final redemptionRef = rewardRedemptionsColl(
      db,
      familyId,
    ).doc(redemption.id);
    final memberRef = membersColl(db, familyId).doc(redemption.memberId);

    await db.runTransaction((tx) async {
      // ── All reads first ────────────────────────────────────────────────────
      final redeemSnap = await tx.get(redemptionRef);
      if (!redeemSnap.exists) {
        throw Exception('Reward redemption not found');
      }

      final data = redeemSnap.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'pending';

      // Only allow refund while still pending
      if (status != 'pending') {
        return; // no-op if already given or cancelled
      }

      final coinCost =
          (data['coinCost'] as num?)?.toInt() ?? redemption.coinCost;
      final rewardId = data['rewardId'] as String?;

      final memSnap = coinCost > 0 ? await tx.get(memberRef) : null;
      if (memSnap != null && !memSnap.exists) {
        throw Exception('Member not found');
      }

      // Read the reward doc so we can check if it tracks stock.
      final rewardDocRef =
          rewardId != null ? rewardsColl(db, familyId).doc(rewardId) : null;
      final rewardSnap =
          rewardDocRef != null ? await tx.get(rewardDocRef) : null;

      // ── All writes ─────────────────────────────────────────────────────────
      if (memSnap != null) {
        final memData = memSnap.data() as Map<String, dynamic>;
        final currentCoins = (memData['coins'] as num?)?.toInt() ?? 0;
        tx.update(memberRef, {'coins': currentCoins + coinCost});
      }

      // If this reward tracks per-kid stock, decrement the purchase count so
      // the kid can buy it again after a refund.
      if (rewardDocRef != null &&
          rewardSnap != null &&
          rewardSnap.exists) {
        final rewardData = rewardSnap.data() as Map<String, dynamic>;
        if (rewardData['stock'] != null) {
          tx.update(rewardDocRef, {
            'memberPurchaseCounts.${redemption.memberId}':
                FieldValue.increment(-1),
          });
        }
      }

      // Mark redemption as cancelled so it falls out of the pending queue
      tx.update(redemptionRef, {
        'status': 'cancelled',
        // Clear givenAt just in case
        'givenAt': null,
        'parentMemberId': ?parentMemberId,
      });
    });
  }


  // ─────────────────────────────────────────────────────────────────────────
  // Seed starter rewards
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> seedStarterRewards(String familyId) async {
    final batch = firebaseDB.batch();
    final coll = rewardsColl(firebaseDB, familyId);

    for (final template in kDefaultRewards) {
      final ref = coll.doc();
      batch.set(ref, {
        'title': template.title,
        'name': template.title,
        'description': template.description,
        'icon': template.icon,
        'coinCost': template.coinCost,
        'priceCoins': template.coinCost,
        'category': template.category.name,
        'requiresApproval': true,
        'isCustom': false,
        'stock': null,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

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
      // ── All reads first ────────────────────────────────────────────────────
      final memSnap = await tx.get(memberRef);
      if (!memSnap.exists) throw Exception('Member not found');

      Reward? currentReward;
      if (reward.stock != null) {
        final rSnap = await tx.get(rewardRef);
        if (!rSnap.exists) throw Exception('Reward not found');
        currentReward = Reward.fromDoc(rSnap);
      }

      // ── Validation ─────────────────────────────────────────────────────────
      final member = Member.fromDoc(memSnap);
      if (member.coins < reward.coinCost) {
        throw Exception('Not enough coins');
      }

      if (currentReward != null) {
        final kidCount = currentReward.memberPurchaseCounts[memberId] ?? 0;
        if (kidCount >= reward.stock!) throw Exception('Out of stock');
      }

      // ── All writes ─────────────────────────────────────────────────────────
      final newCoins = member.coins - reward.coinCost;

      // Track daily coin spend for Big Spender achievement title.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final spendDate = member.dailyCoinsSpentDate;
      final prevSpendDay = spendDate == null
          ? null
          : DateTime(spendDate.year, spendDate.month, spendDate.day);
      final newDailySpent = (prevSpendDay == today)
          ? member.dailyCoinsSpent + reward.coinCost
          : reward.coinCost;

      // If coins drop below 100, reset the hoard-since timestamp.
      // Use exact computed values (not FieldValue.increment) inside a transaction
      // to avoid "reads and writes were out of order" errors in the Firestore SDK.
      final memberUpdate = <String, dynamic>{
        'coins': newCoins,
        'dailyCoinsSpent': newDailySpent,
        'dailyCoinsSpentDate': Timestamp.fromDate(today),
        if (newCoins < 100) 'coinsHoardSince': null,
      };
      tx.update(memberRef, memberUpdate);

      if (currentReward != null) {
        final newCount = (currentReward.memberPurchaseCounts[memberId] ?? 0) + 1;
        tx.update(rewardRef, {
          'memberPurchaseCounts.$memberId': newCount,
        });
      }

      // Redemption record created inside the transaction so coins can never
      // be deducted without a corresponding redemption doc existing.
      final redemptionRef = rewardRedemptionsColl(firebaseDB, familyId).doc();
      tx.set(redemptionRef, {
        'memberId': memberId,
        'rewardId': reward.id,
        'rewardName': reward.title,
        'coinCost': reward.coinCost,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
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
