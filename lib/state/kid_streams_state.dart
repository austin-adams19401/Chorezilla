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

    // Use dayKey (string equality) — consistent with family-level streams and
    // immune to timezone drift that can affect timestamp-range queries.
    final now = DateTime.now();
    final dayKey = _dateKey(DateTime(now.year, now.month, now.day));

    Query base = db
        .collection('families')
        .doc(familyId)
        .collection('assignments')
        .where('memberId', isEqualTo: memberId)
        .where('dayKey', isEqualTo: dayKey);

    Query q;

    if (status == AssignmentStatus.assigned) {
      // Include both assigned and rejected so the "To Do" tab shows rejections.
      q = base.where('status', whereIn: [
        statusToString(AssignmentStatus.assigned),
        statusToString(AssignmentStatus.rejected),
      ]);
    } else {
      q = base.where('status', isEqualTo: statusToString(status));
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
