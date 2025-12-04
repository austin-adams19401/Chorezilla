// lib/state/app_state_kid_streams.dart
part of 'app_state.dart';

extension AppStateKidStreams on AppState {
  Future<void> startKidStreams(String memberId) async {
    final famId = _familyId;
    if (famId == null) {
      debugPrint('KID_STREAMS: cannot start, no familyId.');
      return;
    }

    debugPrint('KID_STREAMS: starting for member=$memberId family=$famId');

    _kidAssignmentsBootstrapped.remove(memberId);
    // ASSIGNED
    _kidAssignedSubs[memberId]?.cancel();
    _kidAssignedSubs[memberId] =
        _watchAssignmentsForKid(
          famId,
          memberId,
          AssignmentStatus.assigned,
        ).listen((list) {
          debugPrint('KID_STREAM_ASSIGNED[$memberId]: count=${list.length}');
          _kidAssigned[memberId] = list;
          _kidAssignmentsBootstrapped.add(memberId);

          _notifyStateChanged();
          _saveKidAssignmentsToCache(famId, memberId); // fire-and-forget
        });

    // PENDING
    _kidPendingSubs[memberId]?.cancel();
    _kidPendingSubs[memberId] =
        _watchAssignmentsForKid(
          famId,
          memberId,
          AssignmentStatus.pending,
        ).listen((list) {
          debugPrint('KID_STREAM_PENDING[$memberId]: count=${list.length}');
          _kidPending[memberId] = list;
          _notifyStateChanged();
          _saveKidAssignmentsToCache(famId, memberId);
        });

    // COMPLETED
    _kidCompletedSubs[memberId]?.cancel();
    _kidCompletedSubs[memberId] =
        _watchAssignmentsForKid(
          famId,
          memberId,
          AssignmentStatus.completed,
        ).listen((list) {
          debugPrint('KID_STREAM_COMPLETED[$memberId]: count=${list.length}');
          _kidCompleted[memberId] = list;
          _notifyStateChanged();
          _saveKidAssignmentsToCache(famId, memberId);
        });

    // Reward redemptions ("My Rewards")
    _kidRewardRedemptionsSubs[memberId]?.cancel();
    _kidRewardRedemptionsSubs[memberId] = repo
        .watchRewardRedemptionsForMember(famId, memberId: memberId)
        .listen((list) {
          debugPrint('KID_STREAM_REWARDS[$memberId]: count=${list.length}');
          _kidRewardRedemptions[memberId] = list;
          _notifyStateChanged();
        });
  }

  Stream<List<Assignment>> _watchAssignmentsForKid(
    String familyId,
    String memberId,
    AssignmentStatus status,
  ) {
    final db = FirebaseFirestore.instance;

    // Define "today" as [todayMidnight, tomorrowMidnight)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final startTs = Timestamp.fromDate(today);
    final endTs = Timestamp.fromDate(tomorrow);

    // Base query: same for all statuses
    Query base = db
        .collection('families')
        .doc(familyId)
        .collection('assignments')
        .where('memberId', isEqualTo: memberId)
        .where('due', isGreaterThanOrEqualTo: startTs)
        .where('due', isLessThan: endTs)
        .orderBy('due');

    Query q;

    if (status == AssignmentStatus.assigned) {
      // For the "assigned" stream, include *both* assigned and rejected
      final assignedWire = _statusToWire(AssignmentStatus.assigned);
      final rejectedWire = _statusToWire(AssignmentStatus.rejected);

      q = base.where('status', whereIn: [assignedWire, rejectedWire]);
    } else {
      // For all other streams (pending, completed, etc.) keep old behaviour
      final statusWire = _statusToWire(status);
      q = base.where('status', isEqualTo: statusWire);
    }

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  Future<void> _saveKidAssignmentsToCache(
    String familyId,
    String memberId,
  ) async {
    try {
      final assigned = _kidAssigned[memberId] ?? const <Assignment>[];
      final pending = _kidPending[memberId] ?? const <Assignment>[];
      final completed = _kidCompleted[memberId] ?? const <Assignment>[];

      await _cache.saveKidTodayAssignments(
        familyId: familyId,
        memberId: memberId,
        day: DateTime.now(),
        assigned: assigned,
        pending: pending,
        completed: completed,
      );
    } catch (e) {
      debugPrint('Failed to save kid cache for member=$memberId: $e');
    }
  }

  void stopKidStreams(String memberId) {
    _kidAssignedSubs.remove(memberId)?.cancel();
    _kidPendingSubs.remove(memberId)?.cancel();
    _kidCompletedSubs.remove(memberId)?.cancel();
    _kidRewardRedemptionsSubs.remove(memberId)?.cancel();

    _kidAssigned.remove(memberId);
    _kidPending.remove(memberId);
    _kidCompleted.remove(memberId);
    _kidRewardRedemptions.remove(memberId);
    _kidAssignmentsBootstrapped.remove(memberId);
  }
}
