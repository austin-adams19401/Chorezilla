// lib/state/app_state_writes.dart
part of 'app_state.dart';

extension AppStateWrites on AppState {
  // ───────────────────────────────────────────────────────────────────────────
  // Writes
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> addChild({
    required String name,
    String? avatarKey,
    String? pin,
  }) async {
    final famId = _familyId!;
    debugPrint('ADDING CHILD');

    String? pinHash;
    if (pin != null && pin.isNotEmpty) {
      if (!_isValidPin(pin)) {
        throw ArgumentError('PIN must be exactly 4 digits (0–9).');
      }
      pinHash = _hashPin(pin);
    }

    await repo.addChild(
      famId,
      displayName: name,
      avatarKey: avatarKey,
      pinHash: pinHash,
    );
  }

  Future<void> updateMember(String memberId, Map<String, dynamic> patch) async {
    final famId = _familyId!;
    await repo.updateMember(famId, memberId, patch);
  }

  Future<void> removeMember(String memberId) async {
    final famId = _familyId!;
    await repo.removeMember(famId, memberId);
  }

  Future<void> createChore({
    required String title,
    String? description,
    String? iconKey,
    required int difficulty,
    Recurrence? recurrence,
    bool requiresApproval = true,
  }) async {
    final famId = _familyId!;
    final db = FirebaseFirestore.instance;
    final choresRef = db
        .collection('families')
        .doc(famId)
        .collection('chores')
        .doc();

    final points =
        _family?.settings.difficultyToXP[difficulty] ??
        (difficulty.clamp(1, 5) * 10);

    await choresRef.set({
      'title': title,
      'description': description,
      'icon': iconKey,
      'difficulty': difficulty,
      'points': points,
      'active': true,
      'recurrence': recurrence?.toMap(),
      'requiresApproval': requiresApproval,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateChore({
    required String choreId,
    required String title,
    String? description,
    String? iconKey,
    required int difficulty,
    Recurrence? recurrence,
    bool requiresApproval = true,
  }) async {
    final fam = family!;
    await repo.updateChoreTemplate(
      fam.id,
      choreId: choreId,
      title: title,
      description: description,
      iconKey: iconKey,
      difficulty: difficulty,
      settings: fam.settings,
      recurrence: recurrence,
      requiresApproval: requiresApproval,
    );
  }

  /// Delete a chore template and all its assignments (no orphan docs).
  Future<void> deleteChore(String choreId) async {
    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when calling deleteChore');
    }

    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final choreRef = famRef.collection('chores').doc(choreId);
    final assignmentsRef = famRef.collection('assignments');

    debugPrint('DELETE_CHORE: famId=$famId choreId=$choreId');

    // Delete all assignments for this chore in batches to be safe
    const batchSize = 200;
    while (true) {
      final snap = await assignmentsRef
          .where('choreId', isEqualTo: choreId)
          .limit(batchSize)
          .get();

      if (snap.docs.isEmpty) {
        break;
      }

      final batch = db.batch();
      for (final doc in snap.docs) {
        debugPrint('DELETE_CHORE: deleting assignment ${doc.id}');
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Finally delete the chore doc itself
    await choreRef.delete();
    debugPrint('DELETE_CHORE: chore $choreId deleted.');
  }

  /// This uses the `defaultAssignees` list stored on the Chore template,
  /// not the per-day Assignment docs. That way avatars stay stable even
  /// when today's instance moves from assigned → pending → approved.
  Set<String> assignedMemberIdsForChore(String choreId) {
    try {
      final chore = chores.firstWhere((c) => c.id == choreId);
      return chore.defaultAssignees.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Return the Member objects corresponding to this chore's default assignees.
  List<Member> assignedMembersForChore(String choreId) {
    final ids = assignedMemberIdsForChore(choreId);
    if (ids.isEmpty) return const <Member>[];

    return members.where((m) => ids.contains(m.id)).toList();
  }

  Future<void> unassignChore({
    required String choreId,
    required Set<String> memberIds,
  }) async {
    if (memberIds.isEmpty) return;

    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when calling unassignChore');
    }

    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final assignmentsRef = famRef.collection('assignments');

    // 1) Delete currently "assigned" docs for these kids (for today)
    final toDelete = familyAssignedVN.value
        .where((a) => a.choreId == choreId && memberIds.contains(a.memberId))
        .toList();

    if (toDelete.isNotEmpty) {
      final batch = db.batch();
      for (final a in toDelete) {
        batch.delete(assignmentsRef.doc(a.id));
      }
      await batch.commit();
    }

    // 2) Remove them from defaultAssignees on the chore template
    try {
      final choreRef = famRef.collection('chores').doc(choreId);
      final snap = await choreRef.get();
      final data = snap.data();

      final existing = ((data?['defaultAssignees'] as List?) ?? const [])
          .cast<String>()
          .toSet();

      // subtract the given memberIds
      final updated = existing.difference(memberIds);

      if (updated.length == existing.length) {
        // nothing changed
        return;
      }

      await updateChoreDefaultAssignees(
        choreId: choreId,
        memberIds: updated.toList(),
      );
    } catch (e) {
      debugPrint('unassignChore: failed to update defaultAssignees: $e');
    }
  }

  Future<void> assignChore({
    required String choreId,
    required Iterable<String> memberIds,
    required DateTime due,
  }) async {
    final famId = _familyId;
    if (famId == null) {
      debugPrint('ASSIGN_CHORE: no familyId set!');
      throw StateError('No family selected when calling assignChore');
    }

    debugPrint(
      'ASSIGN_CHORE: famId=$famId choreId=$choreId memberIds=$memberIds',
    );

    final fam = family!;
    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final assignmentsRef = famRef.collection('assignments');

    // Find the chore template
    final chore = chores.firstWhere(
      (c) => c.id == choreId,
      orElse: () {
        debugPrint('ASSIGN_CHORE: chore $choreId not found in chores list!');
        throw Exception('Chore not found');
      },
    );

    // Avoid duplicate assignments for same chore/kid combo
    final ids = memberIds.toSet();
    debugPrint('ASSIGN_CHORE: unique memberIds=$ids');

    final alreadyAssigned = assignedMemberIdsForChore(choreId);
    debugPrint('ASSIGN_CHORE: alreadyAssignedIdsForChore=$alreadyAssigned');

    final targetIds = ids.difference(alreadyAssigned);
    debugPrint('ASSIGN_CHORE: targetIds(after diff)=$targetIds');

    if (targetIds.isEmpty) {
      debugPrint('ASSIGN_CHORE: nothing new to assign, returning early.');
      return;
    }

    final mems = members.where((m) => targetIds.contains(m.id)).toList();
    debugPrint(
      'ASSIGN_CHORE: resolved mems=${mems.map((m) => '${m.id}:${m.displayName}').toList()}',
    );

    if (mems.isEmpty) {
      debugPrint('ASSIGN_CHORE: no valid members found, throwing.');
      throw Exception('No valid members selected');
    }

    debugPrint(
      'FAM_SETTINGS: difficultyToXP=${fam.settings.difficultyToXP} coinPerPoint=${fam.settings.coinPerPoint}',
    );

    // Use your award helper
    final award = calcAwards(
      difficulty: chore.difficulty,
      settings: fam.settings,
    );
    debugPrint('ASSIGN_CHORE: award xp=${award.xp} coins=${award.coins}');

    final normalizedDue = DateTime(due.year, due.month, due.day);
    final dayKey = _dateKey(normalizedDue);

    final batch = db.batch();
    for (final m in mems) {
      final aRef = assignmentsRef.doc();
      debugPrint(
        'ASSIGN_CHORE: creating doc=${aRef.id} for member=${m.id} (${m.displayName})',
      );

      batch.set(aRef, {
        'familyId': famId,
        'choreId': chore.id,
        'choreTitle': chore.title,
        'choreIcon': chore.icon,
        'memberId': m.id,
        'memberName': m.displayName,
        'difficulty': chore.difficulty,
        'xp': award.xp,
        'coinAward': award.coins,
        'requiresApproval': chore.requiresApproval,
        'status': 'assigned',
        'due': Timestamp.fromDate(normalizedDue),
        'dayKey': dayKey,
        'assignedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('ASSIGN_CHORE: batch committed ${mems.length} docs.');

    // Keep defaultAssignees in sync: read latest from Firestore, then union.
    try {
      final famIdNonNull = famId;
      final db2 = FirebaseFirestore.instance;
      final famRef2 = db2.collection('families').doc(famIdNonNull);
      final choreRef = famRef2.collection('chores').doc(choreId);

      final snap = await choreRef.get();
      final data = snap.data();

      final existingDefaults =
          ((data?['defaultAssignees'] as List?) ?? const [])
              .cast<String>()
              .toSet();

      final updatedDefaults = {...existingDefaults, ...ids};

      if (updatedDefaults.length == existingDefaults.length) {
        // no new defaults added
        return;
      }

      await updateChoreDefaultAssignees(
        choreId: choreId,
        memberIds: updatedDefaults.toList(),
      );
    } catch (e) {
      debugPrint('ASSIGN_CHORE: failed to update defaultAssignees: $e');
    }
  }

  Future<void> updateChoreDefaultAssignees({
    required String choreId,
    required List<String> memberIds,
  }) async {
    await repo.updateChoreDefaultAssignees(
      familyId!,
      choreId: choreId,
      memberIds: memberIds,
    );
    // Optional: refresh caches if you keep a local chores list
  }

  Future<void> completeAssignment(String assignmentId) async {
    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when calling completeAssignment');
    }

    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final aRef = famRef.collection('assignments').doc(assignmentId);

    // 1) Load the assignment so we can get choreId + memberId, requiresApproval, etc.
    final snap = await aRef.get();
    if (!snap.exists) {
      throw StateError('Assignment $assignmentId not found');
    }

    final assignment = Assignment.fromDoc(snap);

    // 2) Let the repo handle status + XP/coins
    await repo.completeAssignment(famId, assignmentId);

    // 4) Optimistically update local kid cache so the To Do list updates immediately
    final memberId = assignment.memberId;
    final existingAssigned = _kidAssigned[memberId];

    if (existingAssigned != null && existingAssigned.isNotEmpty) {
      _kidAssigned[memberId] = existingAssigned
          .where((a) => a.id != assignmentId)
          .toList();
    }

    _notifyStateChanged();
  }

  Future<void> approveAssignment(
    String assignmentId, {
    String? parentMemberId,
  }) async {
    final famId = _familyId!;
    await repo.approveAssignment(
      famId,
      assignmentId,
      parentMemberId: parentMemberId,
    );
  }

  Future<void> rejectAssignment(
    String assignmentId, {
    String reason = '',
  }) async {
    final famId = _familyId!;
    await repo.rejectAssignment(famId, assignmentId, reason: reason);
  }

  Future<void> purchaseReward(String memberId, Reward reward) async {
    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when calling purchaseReward');
    }

    await repo.purchaseReward(famId, memberId: memberId, reward: reward);
  }

  Future<void> createLevelUpRewardRedemptionForKid({
    required String memberId,
    required int level,
    required String rewardTitle,
  }) async {
    final fam = family;
    if (fam == null) {
      return;
    }

    await repo.createLevelUpRewardRedemption(
      fam.id,
      memberId: memberId,
      level: level,
      rewardTitle: rewardTitle,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Recurring Assignment Creation Helpers
  // ───────────────────────────────────────────────────────────────────────────

  Member? _findMemberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool _choreOccursOnDate(Chore chore, DateTime date) {
    final r = chore.recurrence;
    if (r == null) {
      // No recurrence → we won't auto-generate; assignments must be manual.
      return false;
    }

    switch (r.type) {
      case 'daily':
        return true;

      case 'weekly':
      case 'custom':
        final days = r.daysOfWeek;
        if (days == null || days.isEmpty) return false;
        // DateTime.weekday: 1=Mon .. 7=Sun (Mon=1)
        return days.contains(date.weekday);

      case 'once':
      default:
        // For now we don't auto-generate "once" chores;
        // you can add date-based logic later.
        return false;
    }
  }

  Future<void> ensureAssignmentsForToday() async {
    final famId = _familyId;
    final fam = _family;

    if (famId == null || fam == null) {
      debugPrint(
        'ensureAssignmentsForToday: no family loaded (famId=$famId, fam=$_family), skipping.',
      );
      return;
    }

    // If you have a getter `chores` that might be null, guard it.
    if (chores.isEmpty) {
      debugPrint(
        'ensureAssignmentsForToday: chores list is empty, nothing to auto-assign.',
      );
      return;
    }

    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final assignmentsRef = famRef.collection('assignments');

    // Normalize "today" to calendar day (midnight local time)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTs = Timestamp.fromDate(today);

    // Stable string key for the calendar day, independent of timezone internals.
    final dayKey = _dateKey(today);

    debugPrint(
      'ensureAssignmentsForToday: famId=$famId date=$today dayKey=$dayKey (chores=${chores.length})',
    );

    // 1) Load all assignments that are already for this dayKey (any status).
    final existingSnap = await assignmentsRef
        .where('dayKey', isEqualTo: dayKey)
        .get();

    debugPrint(
      'ensureAssignmentsForToday: found ${existingSnap.docs.length} existing assignments for dayKey=$dayKey',
    );

    // Map: choreId -> set of memberIds that already have an assignment today.
    final Map<String, Set<String>> existingByChore = {};
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      final choreId = data['choreId'] as String? ?? '';
      final memberId = data['memberId'] as String? ?? '';
      if (choreId.isEmpty || memberId.isEmpty) continue;
      existingByChore.putIfAbsent(choreId, () => <String>{}).add(memberId);
    }

    int createdCount = 0;
    final batch = db.batch();

    for (final chore in chores) {
      if (!chore.active) continue;
      if (!_choreOccursOnDate(chore, today)) continue;
      if (chore.defaultAssignees.isEmpty) continue;

      final alreadyForChore = existingByChore[chore.id] ?? const <String>{};

      debugPrint(
        'ensureAssignmentsForToday: evaluating chore=${chore.title} '
        '(id=${chore.id}), defaultAssignees=${chore.defaultAssignees}, '
        'already=${alreadyForChore.toList()}',
      );

      for (final memberId in chore.defaultAssignees) {
        if (alreadyForChore.contains(memberId)) {
          // This kid already has today's assignment for this chore.
          continue;
        }

        final member = _findMemberById(memberId);
        if (member == null) {
          debugPrint(
            'ensureAssignmentsForToday: member $memberId not found, skipping.',
          );
          continue;
        }

        final award = calcAwards(
          difficulty: chore.difficulty,
          settings: fam.settings,
        );

        // Deterministic doc ID per (chore, member, day)
        final docId = 'asg_${chore.id}_${member.id}_$dayKey';
        final aRef = assignmentsRef.doc(docId);

        debugPrint(
          'ensureAssignmentsForToday: creating assignment docId=$docId '
          'for member=${member.displayName} chore=${chore.title}',
        );

        batch.set(aRef, {
          'familyId': famId,
          'choreId': chore.id,
          'choreTitle': chore.title,
          'choreIcon': chore.icon,
          'memberId': member.id,
          'memberName': member.displayName,
          'difficulty': chore.difficulty,
          'xp': award.xp,
          'coinAward': award.coins,
          'requiresApproval': chore.requiresApproval,
          'status': 'assigned',
          'due': todayTs, // still useful for ordering / UI
          'dayKey': dayKey, // logical calendar day, used for idempotence
          'assignedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // merge for safety

        createdCount++;
      }
    }

    if (createdCount == 0) {
      debugPrint(
        'ensureAssignmentsForToday: no new assignments needed for $dayKey.',
      );
      return;
    }

    await batch.commit();
    debugPrint(
      'ensureAssignmentsForToday: created $createdCount new assignments for $today (dayKey=$dayKey).',
    );
  }
}
