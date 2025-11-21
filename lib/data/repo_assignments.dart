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
        .where('due', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('due');

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

Stream<List<Assignment>> watchAssignmentsDueToday(String familyId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final q = assignmentsColl(firebaseDB, familyId)
        .where('due', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('due', isLessThan: Timestamp.fromDate(end))
        .orderBy('due');

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }



  Stream<List<Assignment>> watchReviewQueue(String familyId) {
    return assignmentsColl(firebaseDB, familyId)
        .where('status', isEqualTo: statusToString(AssignmentStatus.completed))
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  // Writes
  Future<List<String>> assignChoreToMembers(
    String familyId, {
    required Chore chore,
    required List<Member> members,
    required DateTime due,
    required FamilySettings settings,
  }) async {
    final batch = firebaseDB.batch();
    final createdIds = <String>[];
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
        'requiresApproval': false,
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
        'due': Timestamp.fromDate(due),
        'proof': null,
      });
    }
    await batch.commit();
    return createdIds;
  }

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

  Future<void> completeAssignment({
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

      debugPrint('');

      if (asn.status != AssignmentStatus.completed) {
        throw Exception('Only completed assignments can be rejected');
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
