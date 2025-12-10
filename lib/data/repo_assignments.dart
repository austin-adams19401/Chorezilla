// lib/data/repo_assignments.dart
part of 'chorezilla_repo.dart';

extension AssignmentRepo on ChorezillaRepo {
  // Watchers (assignments)
  Stream<List<Assignment>> watchAssignmentsForMember(
    String familyId, {
    required String memberId,
    List<AssignmentStatus>? statuses,
  }) {
    Query q = assignmentsColl(
      firebaseDB,
      familyId,
    ).where('memberId', isEqualTo: memberId);
    if (statuses != null && statuses.isNotEmpty) {
      q = q.where('status', whereIn: statuses.map(statusToString).toList());
    }
    q = q.orderBy('due');
    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  // Watch assignments due in [start, end). Filter status in memory to avoid composite indexes.
  Stream<List<Assignment>> watchAssignmentsDueRange(
    String familyId, {
    required DateTime start,
    required DateTime end,
  }) {
  final q = assignmentsColl(firebaseDB, familyId)
        .where('due', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('due', isLessThan: Timestamp.fromDate(end))
        .orderBy('due');

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  Stream<List<Assignment>> watchAssignmentsDueToday(String familyId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayKey = _dayKeyFor(today);

    // Super simple query: equality on dayKey only.
    // No orderBy → no composite index required, avoids subtle index/remote issues.
    final q = assignmentsColl(
      firebaseDB,
      familyId,
    ).where('dayKey', isEqualTo: dayKey);

    return q.snapshots().map((s) {
      final list = s.docs.map(Assignment.fromDoc).toList()
        ..sort((a, b) {
          final ad = a.due;
          final bd = b.due;
          if (ad == null && bd == null) {
            return a.choreTitle.compareTo(b.choreTitle);
          } else if (ad == null) {
            return 1;
          } else if (bd == null) {
            return -1;
          } else {
            final cmp = ad.compareTo(bd);
            return cmp != 0 ? cmp : a.choreTitle.compareTo(b.choreTitle);
          }
        });

      debugPrint(
        'watchAssignmentsDueToday: fam=$familyId dayKey=$dayKey count=${list.length}',
      );
      return list;
    });
  }

  Stream<List<ChoreMemberSchedule>> watchAllChoreMemberSchedules(
    String familyId,
  ) {
    return choreMemberSchedulesColl(firebaseDB, familyId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map(ChoreMemberSchedule.fromDoc).toList());
  }

  Stream<List<Assignment>> watchReviewQueue(String familyId) {
    final pending = statusToString(AssignmentStatus.pending);

    return assignmentsColl(firebaseDB, familyId)
        .where('requiresApproval', isEqualTo: true)
        .where('status', isEqualTo: pending)
        .orderBy('due')
        .snapshots()
        .map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

Future<List<String>> assignChoreToMembers(
    String familyId, {
    required Chore chore,
    required List<Member> members,
    required DateTime due,
    required FamilySettings settings,
  }) async {
    final batch = firebaseDB.batch();
    final createdIds = <String>[];

    // Normalize to calendar day and build a stable dayKey
    final normalizedDue = DateTime(due.year, due.month, due.day);
    final dayKey = _dayKeyFor(normalizedDue);

    for (final m in members) {
      final ref = assignmentsColl(firebaseDB, familyId).doc();
      final awards = calcAwards(
        difficulty: chore.difficulty,
        settings: settings,
      );

      createdIds.add(ref.id);

      batch.set(ref, {
        'familyId': familyId,
        'memberId': m.id,
        'memberName': m.displayName,
        'choreId': chore.id,
        'choreTitle': chore.title,
        'choreIcon': chore.icon,
        'difficulty': chore.difficulty,
        'xp': awards.xp,
        'coinAward': awards.coins,
        'requiresApproval': chore.requiresApproval,
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'due': Timestamp.fromDate(normalizedDue),
        'dayKey': dayKey,
        'proof': null,
      });
    }

    await batch.commit();
    return createdIds;
  }

  // Helper in this file (private to the library)
  String _dayKeyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';


  Future<void> markCompleted({
    required String familyId,
    required String choreId,
    required String memberId,
    required int dayStartHour,
  }) {
    final start = _startOfLocalDayWithHour(dayStartHour);
    final dayKey = _yyyymmdd(start);
    final id = '${choreId}_${memberId}_$dayKey';
    final ref = eventsColl(firebaseDB, familyId).doc(id);
    return ref.set({
      'familyId': familyId,
      'choreId': choreId,
      'memberId': memberId,
      'dayKey': dayKey,
      'status': 'done',
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

Future<void> completeAssignment(
    String familyId,
    String assignmentId, {
    String? note,
  }) async {
    final db = firebaseDB;
    final assignRef = assignmentsColl(db, familyId).doc(assignmentId);

    await db.runTransaction((tx) async {
      final snap = await tx.get(assignRef);
      if (!snap.exists) {
        throw Exception('Assignment not found');
      }

      final data = snap.data() as Map<String, dynamic>;

      final String status = (data['status'] as String?) ?? 'assigned';
      final bool requiresApproval =
          (data['requiresApproval'] as bool?) ?? false;
      final String? memberId = data['memberId'] as String?;
      final int xp = (data['xp'] as num?)?.toInt() ?? 0;
      final int coins = (data['coinAward'] as num?)?.toInt() ?? 0;

      if (memberId == null || memberId.isEmpty) {
        throw Exception('Assignment missing memberId');
      }

      // If it's already pending or completed, do nothing.
      if (status == 'pending' || status == 'completed') {
        return;
      }

      final now = FieldValue.serverTimestamp();
      final updates = <String, dynamic>{'completedAt': now};

      // Optional: attach / merge note into proof
      if (note != null && note.isNotEmpty) {
        final existingProof =
            (data['proof'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        updates['proof'] = {...existingProof, 'note': note};
      }

      if (requiresApproval) {
        // No XP/coins yet — parent approval will handle rewards.
        updates['status'] = 'pending';
        tx.update(assignRef, updates);
        return;
      }

      updates['status'] = 'completed';
      tx.update(assignRef, updates);

      final memberRef = membersColl(db, familyId).doc(memberId);
      tx.update(memberRef, {
        'xp': FieldValue.increment(xp),
        'coins': FieldValue.increment(coins),
      });
    });
  }

  // Parent approves: update assignment + increment kid xp/coins + add event
  Future<void> approveAssignment(
    String familyId,
    String assignmentId, {
    String? parentMemberId,
  }) async {
    final famRef = familyDoc(firebaseDB, familyId);
    final asnRef = assignmentsColl(firebaseDB, familyId).doc(assignmentId);

    await firebaseDB.runTransaction((tx) async {
      final famSnap = await tx.get(famRef);
      final asnSnap = await tx.get(asnRef);
      if (!asnSnap.exists) throw Exception('Assignment not found');

      final family = Family.fromDoc(famSnap);
      final asn = Assignment.fromDoc(asnSnap);

      debugPrint('APPROVING: chore ${asn.choreTitle} - ${asn.status}');
      debugPrint('APPROVING: requires approval? ${asn.requiresApproval}');

      if (asn.requiresApproval == false || asn.status != AssignmentStatus.pending) {
        throw Exception('Only pending assignments can be approved');
      }

      final memberRef = membersColl(firebaseDB, familyId).doc(asn.memberId);
      final memSnap = await tx.get(memberRef);
      if (!memSnap.exists) throw Exception('Member not found');

      final coins = (asn.xp * family.settings.coinPerPoint).round();

      tx.update(asnRef, {
        'status': 'completed',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      tx.update(memberRef, {
        'xp': FieldValue.increment(asn.xp),
        'coins': FieldValue.increment(coins),
      });

      final evRef = eventsColl(firebaseDB, familyId).doc();
      tx.set(evRef, {
        'type': 'assignment_approved',
        'actorMemberId': parentMemberId,
        'targetMemberId': asn.memberId,
        'payload': {'assignmentId': asn.id, 'xp': asn.xp, 'coins': coins},
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

Future<void> undoAssignmentCompletion(
    String familyId,
    String assignmentId, {
    String? parentMemberId,
  }) async {
    final famRef = familyDoc(firebaseDB, familyId);
    final asnRef = assignmentsColl(firebaseDB, familyId).doc(assignmentId);

    await firebaseDB.runTransaction((tx) async {
      // 1) READ: assignment
      final asnSnap = await tx.get(asnRef);
      if (!asnSnap.exists) throw Exception('Assignment not found');

      final asn = Assignment.fromDoc(asnSnap);

      // Only completed assignments can be undone
      if (asn.status != AssignmentStatus.completed) {
        return;
      }

      // 2) READ: family (only if we need coinPerPoint)
      int xpToRevert = asn.xp;
      int coinsToRevert;

      if (asn.requiresApproval) {
        final famSnap = await tx.get(famRef);
        if (!famSnap.exists) throw Exception('Family not found');
        final family = Family.fromDoc(famSnap);
        coinsToRevert = (asn.xp * family.settings.coinPerPoint).round();
      } else {
        coinsToRevert = asn.coinAward;
      }

      // 3) READ: member (before any writes)
      final memberRef = membersColl(firebaseDB, familyId).doc(asn.memberId);
      final memSnap = await tx.get(memberRef);
      if (!memSnap.exists) {
        // If the member was deleted, just bail out
        return;
      }

      final memData = memSnap.data() as Map<String, dynamic>;
      final currentXp = (memData['xp'] as num?)?.toInt() ?? 0;
      final currentCoins = (memData['coins'] as num?)?.toInt() ?? 0;

      var newXp = currentXp - xpToRevert;
      var newCoins = currentCoins - coinsToRevert;
      if (newXp < 0) newXp = 0;
      if (newCoins < 0) newCoins = 0;

      // 4) WRITES: now that all reads are done

      // Re-open the assignment
      tx.update(asnRef, {
        'status': 'assigned',
        'completedAt': null,
        'approvedAt': null,
      });

      // Adjust XP/coins
      tx.update(memberRef, {'xp': newXp, 'coins': newCoins});

      // Optional: log an event
      final evRef = eventsColl(firebaseDB, familyId).doc();
      tx.set(evRef, {
        'type': 'assignment_undone',
        'actorMemberId': parentMemberId,
        'targetMemberId': asn.memberId,
        'payload': {
          'assignmentId': asn.id,
          'xp': xpToRevert,
          'coins': coinsToRevert,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }


  Future<void> rejectAssignment(
    String familyId,
    String assignmentId, {
    String? parentMemberId,
    String? reason,
  }) async {
    final asnRef = assignmentsColl(firebaseDB, familyId).doc(assignmentId);
    await firebaseDB.runTransaction((tx) async {
      final asnSnap = await tx.get(asnRef);
      if (!asnSnap.exists) throw Exception('Assignment not found');
      final asn = Assignment.fromDoc(asnSnap);

      if (asn.status != AssignmentStatus.pending) {
        throw Exception('Only pending assignments can be rejected');
      }
      tx.update(asnRef, {'status': 'rejected'});
      final evRef = eventsColl(firebaseDB, familyId).doc();
      tx.set(evRef, {
        'type': 'assignment_rejected',
        'actorMemberId': parentMemberId,
        'targetMemberId': asn.memberId,
        'payload': {'assignmentId': asn.id, 'reason': reason},
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}


// Local date helpers (library-private)
DateTime _startOfLocalDayWithHour(int hour) {
  final now = DateTime.now();
  final candidate = DateTime(now.year, now.month, now.day, hour);
  return now.isBefore(candidate)
      ? candidate.subtract(const Duration(days: 1))
      : candidate;
}

String _yyyymmdd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
