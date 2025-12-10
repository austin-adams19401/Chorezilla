// lib/data/repo_chores.dart
part of 'chorezilla_repo.dart';

extension ChoreRepo on ChorezillaRepo {
  // Watchers (chores)
  Stream<List<Chore>> watchChores(String familyId, {bool? activeOnly = true}) {
    Query q = choresColl(firebaseDB, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Chore.fromDoc).toList());
  }

  // Writes: Chore templates
  Future<String> createChoreTemplate(
    String familyId, {
    required String title,
    String? description,
    String? iconKey,
    required int difficulty,
    required FamilySettings settings,
    String? createdByMemberId,
    Recurrence? recurrence,
    bool bonusOnly = false,
  }) async {
    final awards = calcAwards(difficulty: difficulty, settings: settings);
    final ref = choresColl(firebaseDB, familyId).doc();
    await ref.set({
      'title': title,
      'description': description,
      'icon': iconKey,
      'difficulty': difficulty,
      'xp': awards.xp,
      'coins': awards.coins,
      'recurrence': recurrence?.toMap(),
      'createdByMemberId': createdByMemberId,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'bonusOnly': bonusOnly,
    });
    return ref.id;
  }

  Future<void> updateChoreTemplate(
    String familyId, {
    required String choreId,
    String? title,
    String? description,
    String? iconKey,
    int? difficulty,
    FamilySettings? settings,
    Recurrence? recurrence,
    bool? active, 
    required bool requiresApproval,
    bool? bonusOnly,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (description != null) patch['description'] = description;
    if (iconKey != null) patch['icon'] = iconKey;
    if (difficulty != null) {
      patch['difficulty'] = difficulty;
      if (settings != null) {
        final awards = calcAwards(difficulty: difficulty, settings: settings);
        patch['xp'] = awards.xp;
        patch['coins'] = awards.coins;
      }
    }
    if (recurrence != null) patch['recurrence'] = recurrence.toMap();
    if (active != null) patch['active'] = active;
    if (bonusOnly != null) patch['bonusOnly'] = bonusOnly;

    await choresColl(firebaseDB, familyId).doc(choreId).update(patch);
  }

    // ───────────────────────────────────────────────────────────────────────────
  // Per-kid schedules for chores (rotation / weekly patterns)
  // Collection: families/{familyId}/choreMemberSchedules
  // ───────────────────────────────────────────────────────────────────────────

  Stream<List<ChoreMemberSchedule>> watchChoreMemberSchedulesForChore(
    String familyId, {
    required String choreId,
  }) {
    return choreMemberSchedulesColl(firebaseDB, familyId)
        .where('choreId', isEqualTo: choreId)
        .snapshots()
        .map((s) => s.docs.map(ChoreMemberSchedule.fromDoc).toList());
  }

  Future<String> createChoreMemberSchedule(
    String familyId, {
    required String choreId,
    required String memberId,
    required Recurrence recurrence,
    bool active = true,
  }) async {
    final coll = choreMemberSchedulesColl(firebaseDB, familyId);
    final ref = coll.doc();

    await ref.set({
      'familyId': familyId,
      'choreId': choreId,
      'memberId': memberId,
      'recurrence': recurrence.toMap(),
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> updateChoreMemberSchedule(
    String familyId, {
    required String scheduleId,
    Recurrence? recurrence,
    bool? active,
  }) async {
    final coll = choreMemberSchedulesColl(firebaseDB, familyId);
    final patch = <String, dynamic>{};

    if (recurrence != null) {
      patch['recurrence'] = recurrence.toMap();
    }
    if (active != null) {
      patch['active'] = active;
    }

    patch['updatedAt'] = FieldValue.serverTimestamp();

    await coll.doc(scheduleId).update(patch);
  }

  Future<void> deleteChoreMemberSchedule(
    String familyId, {
    required String scheduleId,
  }) async {
    final coll = choreMemberSchedulesColl(firebaseDB, familyId);
    await coll.doc(scheduleId).delete();
  }

  Future<void> updateChoreDefaultAssignees(
    String familyId, {
    required String choreId,
    required List<String> memberIds,
  }) {
    return choresColl(
      firebaseDB,
      familyId,
    ).doc(choreId).update({'defaultAssignees': memberIds});
  }
}

