part of 'app_state.dart';

extension AppStateFamilyStreams on AppState {
  // ───────────────────────────────────────────────────────────────────────────
  // Family streams (bind once per family)
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _startFamilyStreams(String familyId) async {
    debugPrint(
      'STARTING FAMILY STREAMS: famName: ${family?.name} - famId: $familyId',
    );

    _familyLoaded = false;
    _membersLoaded = false;
    _parentPinHash = null;
    _parentPinKnown = false;
    _todayAssignmentsEnsured = false;
    _rewards = const [];
    _rewardsBootstrapped = false;
    rewardsVN.value = const [];
    _unlockedKidIds.clear();

    // Hydrate from cache
    await _loadCachedFamilyData(familyId);

    // Family doc (rare changes — name/settings)
    _familySub?.cancel();
    _familySub = repo.watchFamily(familyId).listen((fam) {
      _family = fam;
      _cache.saveFamily(fam);

      // Keep parent PIN state in sync with the Family doc
      _parentPinHash = fam.parentPinHash;
      _parentPinKnown = true;

      if (!_familyLoaded) {
        _familyLoaded = true;
      }
      _notifyStateChanged();
    });

    _membersSub?.cancel();
    _membersSub = repo.watchMembers(familyId).listen((list) {
      membersVN.value = list;

      _allowanceByMemberId.clear();
      for (final m in list) {
        _allowanceByMemberId[m.id] = AllowanceConfig(
          enabled: m.allowanceEnabled,
          fullAmountCents: m.allowanceFullAmountCents,
          daysRequiredForFull: m.allowanceDaysRequired,
          payDay: m.allowancePayDay,
        );
      }

      _cache.saveMembers(familyId, list);

      if (!_membersLoaded) {
        _membersLoaded = true;
      }
      _notifyStateChanged();
    });

    // Chores (hot list)
    _choresSub?.cancel();
    _choresSub = repo.watchChores(familyId).listen((list) {
      choresVN.value = list;
      _cache.saveChores(familyId, list);

      _notifyStateChanged();

      if (!_todayAssignmentsEnsured) {
        _todayAssignmentsEnsured = true;
        ensureAssignmentsForToday();
      }
    });

    // Rewards (store catalog)
    _rewardsSub?.cancel();
    _rewardsSub = repo.watchRewards(familyId).listen((list) {
      _applyRewardsSnapshot(list);
    });

    // Review queue (completed awaiting approval)
    _reviewSub?.cancel();
    _reviewSub = _watchReviewQueue(familyId).listen((list) {
      reviewQueueVN.value = list;
      _notifyStateChanged();
    });

    // Family-level "assigned" assignments (for avatars + assign sheet)
    _familyAssignedSub?.cancel();
    _familyAssignedSub =
        _watchAssignmentsForFamily(familyId, AssignmentStatus.assigned).listen((
          list,
        ) {
          familyAssignedVN.value = list;
        });

    _missedSub?.cancel();
    _missedSub = _watchMissedAssignmentsForFamily(familyId).listen((list) {
      missedAssignmentsVN.value = list;
    });

    // Pending reward redemptions → grouped by memberId
    _pendingRewardsSub?.cancel();
    _pendingRewardsSub = repo.watchPendingRewardRedemptions(familyId).listen((
      list,
    ) {
      final map = <String, List<RewardRedemption>>{};
      for (final r in list) {
        map.putIfAbsent(r.memberId, () => <RewardRedemption>[]).add(r);
      }
      _pendingRewardsByMemberId
        ..clear()
        ..addAll(map);
      _notifyStateChanged();
    });
  }

  // Assignment streams (family-level)
  Stream<List<Assignment>> _watchMissedAssignmentsForFamily(String familyId) {
    final db = FirebaseFirestore.instance;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTs = Timestamp.fromDate(today);

    // Missed = status == 'assigned' AND due < today (i.e., old assignments)
    Query q = db
        .collection('families')
        .doc(familyId)
        .collection('assignments')
        .where('status', isEqualTo: 'assigned')
        .where('due', isLessThan: todayTs)
        .orderBy('due', descending: true);

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  Stream<List<Assignment>> _watchReviewQueue(String familyId) {
    final db = FirebaseFirestore.instance;

    final q = db
        .collection('families')
        .doc(familyId)
        .collection('assignments')
        .where('requiresApproval', isEqualTo: true)
        .where('status', isEqualTo: 'pending')
        .orderBy('due');

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  String _statusToWire(AssignmentStatus s) {
    switch (s) {
      case AssignmentStatus.assigned:
        return 'assigned';
      case AssignmentStatus.completed:
        return 'completed';
      case AssignmentStatus.pending:
        return 'pending';
      case AssignmentStatus.rejected:
        return 'rejected';
    }
  }

  // Watch all assignments in a family for a given status (no member filter)
  Stream<List<Assignment>> _watchAssignmentsForFamily(
    String familyId,
    AssignmentStatus status,
  ) {
    final db = FirebaseFirestore.instance;
    final statusWire = _statusToWire(status);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final startTs = Timestamp.fromDate(today);
    final endTs = Timestamp.fromDate(tomorrow);

    Query q = db
        .collection('families')
        .doc(familyId)
        .collection('assignments')
        .where('status', isEqualTo: statusWire)
        .where('due', isGreaterThanOrEqualTo: startTs)
        .where('due', isLessThan: endTs)
        .orderBy('due');

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  Future<void> _loadCachedFamilyData(String familyId) async {
    try {
      final cachedFamily = await _cache.loadFamily(familyId);
      final cachedMembers = await _cache.loadMembers(familyId);
      final cachedChores = await _cache.loadChores(familyId);

      bool changed = false;

      if (cachedFamily != null) {
        _family = cachedFamily;
        _familyLoaded = true;
        changed = true;
      }

      if (cachedMembers != null) {
        membersVN.value = cachedMembers;

        _allowanceByMemberId.clear();
        for (final m in cachedMembers) {
          _allowanceByMemberId[m.id] = AllowanceConfig(
            enabled: m.allowanceEnabled,
            fullAmountCents: m.allowanceFullAmountCents,
            daysRequiredForFull: m.allowanceDaysRequired,
            payDay: m.allowancePayDay,
          );
        }

        _membersLoaded = true;
        changed = true;
      }

      if (cachedChores != null) {
        choresVN.value = cachedChores;
        changed = true;
      }

      if (changed) {
        debugPrint('Loaded family data from local cache for $familyId');
        _notifyStateChanged();
      }
    } catch (e) {
      debugPrint('Failed to load local cache for family $familyId: $e');
    }
  }
}
