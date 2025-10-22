import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:chorezilla/models/award.dart';
import '../models/common.dart';
import '../models/user_profile.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../models/chore.dart';
import '../models/assignment.dart';
import '../models/reward.dart';

// Firestore path helpers
DocumentReference userDoc(FirebaseFirestore db, String userId) => db.doc('users/$userId');
DocumentReference familyDoc(FirebaseFirestore db, String familyId) => db.doc('families/$familyId');
CollectionReference membersColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/members');
CollectionReference choresColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/chores');
CollectionReference assignmentsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/assignments');
CollectionReference rewardsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/rewards');
CollectionReference devicesColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/devices');
CollectionReference eventsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/events');

class ChorezillaRepo {
  final FirebaseFirestore firebaseDB;
  ChorezillaRepo({required this.firebaseDB});

  // ---------------------------
  // Bootstrap / Profiles
  // ---------------------------
Future<UserProfile> ensureUserProfile(
  String userID, {
  String? displayName,
  String? email,
}) async {
  final userData = userDoc(firebaseDB, userID);      // assumes you have `db` on repo
  final docSnapshot = await userData.get();

  if (!docSnapshot.exists) {
    await userData.set({
      'displayName': displayName,
      'email': email,
      'defaultFamilyId': null,
      'memberships': {},
      'createdAt': FieldValue.serverTimestamp(),
      'lastSignInAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } else {
    await userData.update({'lastSignInAt': FieldValue.serverTimestamp()});
  }

  var profile = UserProfile.fromDoc(await userData.get());

  if (profile.defaultFamilyId == null || profile.defaultFamilyId!.isEmpty) {
    // Create the family + parent member and wire memberships in one atomic batch
    await _createFamilyWithOwner(
      ownerUid: userID,
      parentDisplayName: (displayName == null || displayName.isEmpty)
          ? 'Parent'
          : displayName,
      familyName: (displayName == null || displayName.isEmpty)
          ? 'Your Family'
          : "${displayName.split(' ').first}'s Family",
    );

    // Re-fetch with the new defaultFamilyId and memberships
    profile = UserProfile.fromDoc(await userData.get());
    // (optional) sanity: ensure profile.defaultFamilyId == famId
  }

  return profile;
}


  Future<String> _findFirstParentMemberId(String familyId, String ownerUid) async {
    final q = await membersColl(firebaseDB, familyId).where('userUid', isEqualTo: ownerUid).limit(1).get();
    if (q.docs.isEmpty) return 'mem_parent_owner';
    return q.docs.first.id;
  }

Future<String> _createFamilyWithOwner({
  required String ownerUid,
  required String parentDisplayName,
  String? familyName,
}) async {
  final topLevel = FirebaseFirestore.instance;

  final familyDoc = topLevel.collection('families').doc();
  final memberRef = familyDoc.collection('members').doc(); // real member id available now
  final userRef = topLevel.collection('users').doc(ownerUid);

  final ownerFirst = parentDisplayName.trim().isEmpty
      ? 'Parent'
      : parentDisplayName.trim().split(' ').first;

  final famName = (familyName == null || familyName.trim().isEmpty)
      ? '$ownerFirst Family'
      : familyName.trim();

  final batch = topLevel.batch();

  // Family
  batch.set(familyDoc, {
    'name': famName,
    'ownerUid': ownerUid,
    'createdAt': FieldValue.serverTimestamp(),
    'active': true,
    'settings': {
      'pointsPerDifficulty': {'1': 10, '2': 20, '3': 35, '4': 55, '5': 80},
    },
  }, SetOptions(merge: true));

  // Parent member
  batch.set(memberRef, {
    'userId': ownerUid,
    'displayName': parentDisplayName.trim().isEmpty ? 'Parent' : parentDisplayName.trim(),
    'role': 'parent',
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  // User profile: default family + membership (using real member id)
  batch.set(userRef, {
    'defaultFamilyId': familyDoc.id,
    'memberships': {
      familyDoc.id: {
        'memberId': memberRef.id,
        'role': 'parent',
      }
    },
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await batch.commit();
  return familyDoc.id;
}


  // Update family fields (e.g., name)
  Future<void> updateFamily(String familyId, Map<String, dynamic> patch) async {
    await familyDoc(firebaseDB, familyId).set(patch, SetOptions(merge: true));
  }

  /// Join a family as a Parent (idempotent)
  /// - Creates a parent Member linked to this user (if not already present)
  /// - Updates users/{uid} memberships + defaultFamilyId
  /// - Returns the memberId
  Future<String> joinFamilyAsParent({
    required String familyId,
    required String uid,
    String? displayName,
  }) async {
    // Already a member?
    final existing = await membersColl(firebaseDB, familyId)
        .where('userUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      // ensure defaultFamilyId points here
      await userDoc(firebaseDB, uid).set({'defaultFamilyId': familyId}, SetOptions(merge: true));
      return existing.docs.first.id;
    }

    final memberRef = membersColl(firebaseDB, familyId).doc();
    final userRef = userDoc(firebaseDB, uid);

    await firebaseDB.runTransaction((tx) async {
      // create member (parent)
      tx.set(memberRef, {
        'displayName': (displayName == null || displayName.trim().isEmpty) ? 'Parent' : displayName.trim(),
        'role': 'parent',
        'userUid': uid,
        'avatarKey': null,
        'pinHash': null,
        'level': 1,
        'xp': 0,
        'coins': 0,
        'badges': [],
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
      });

      // update user profile mapping + default family
      tx.set(userRef, {
        'defaultFamilyId': familyId,
        'memberships': {
          familyId: {'memberId': memberRef.id, 'role': 'parent'}
        }
      }, SetOptions(merge: true));
    });

    return memberRef.id;
  }

  // === Invites / Join Codes ===

  // Generate or return existing join code for a family.
  // Backwards compatible: reads 'joinCode' or legacy 'code' on the family doc.
  Future<String> ensureJoinCode(String familyId) async {
    final famRef = familyDoc(firebaseDB, familyId);
    final snap = await famRef.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};

    // prefer 'joinCode', fall back to legacy 'code'
    String? code = (data['joinCode'] as String?)?.trim();
    code ??= (data['code'] as String?)?.trim(); // legacy

    if (code == null || code.isEmpty) {
      code = _randomCode(6);

      // write to family (normalized to 'joinCode')
      await famRef.set({'joinCode': code}, SetOptions(merge: true));
    }

    // mirror in /joinCodes/{code} for lookup
    await firebaseDB.collection('joinCodes').doc(code).set({
      'familyId': familyId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return code;
  }

  // Lookup a familyId for a given code (does NOT link current user)
  Future<String?> redeemJoinCode(String code) async {
    code = code.trim().toUpperCase();
    if (code.isEmpty) return null;
    final doc = await firebaseDB.collection('joinCodes').doc(code).get();
    if (!doc.exists) return null;
    return (doc.data()?['familyId'] as String?);
  }

  // --- private helper ---
  String _randomCode(int len) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // avoid 0/O/1/I
    var x = DateTime.now().microsecondsSinceEpoch;
    final sb = StringBuffer();
    for (int i = 0; i < len; i++) {
      x = (x * 48271) % 0x7fffffff;
      sb.write(chars[x % chars.length]);
    }
    return sb.toString();
  }


  // ---------------------------
  // Watchers (Streams)
  // ---------------------------
  Stream<Family> watchFamily(String familyId) => familyDoc(firebaseDB, familyId).snapshots().map(Family.fromDoc);

  Stream<List<Member>> watchMembers(String familyId, {bool? activeOnly = true}) {
    Query q = membersColl(firebaseDB, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Member.fromDoc).toList());
  }

  Stream<List<Chore>> watchChores(String familyId, {bool? activeOnly = true}) {
    Query q = choresColl(firebaseDB, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Chore.fromDoc).toList());
  }

  Stream<List<Assignment>> watchAssignmentsForMember(
    String familyId, {
    required String memberId,
    List<AssignmentStatus>? statuses,
  }) {
    Query q = assignmentsColl(firebaseDB, familyId).where('memberId', isEqualTo: memberId);
    if (statuses != null && statuses.isNotEmpty) {
      q = q.where('status', whereIn: statuses.map(statusToString).toList());
    }
    q = q.orderBy('due');
    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  // Watch assignments due in [start, end). We only query by "due" to avoid composite index requirements.
  // We filter to status==assigned in memory.
  Stream<List<Assignment>> watchAssignmentsDueRange(
    String familyId, {
    required DateTime start,
    required DateTime end,
  }) {
    final q = assignmentsColl(firebaseDB, familyId)
        .where('due', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('due', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('due');

    return q.snapshots().map((s) => s.docs
        .map(Assignment.fromDoc)
        .toList());
  }

  // Assignments due today (filters status in memory to avoid composite indexes)
  Stream<List<Assignment>> watchAssignmentsDueToday(String familyId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final q = assignmentsColl(firebaseDB, familyId)
        .where('due', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('due', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('due');  
    return q.snapshots().map((s) => s.docs
        .map(Assignment.fromDoc)
        .toList());
  }

  Stream<List<Assignment>> watchReviewQueue(String familyId) {
    return assignmentsColl(firebaseDB, familyId)
        .where('status', isEqualTo: statusToString(AssignmentStatus.completed))
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  Stream<List<Reward>> watchRewards(String familyId, {bool? activeOnly = true}) {
    Query q = rewardsColl(firebaseDB, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Reward.fromDoc).toList());
  }

  // ---------------------------
  // Writes: Members
  // ---------------------------
  Future<String> addChild(String familyId, {required String displayName, String? avatarKey, String? pinHash}) async {
    final ref = membersColl(firebaseDB, familyId).doc();
    await ref.set({
      'displayName': displayName,
      'role': 'child',
      'userUid': null,
      'avatarKey': avatarKey,
      'pinHash': pinHash,
      'level': 1,
      'xp': 0,
      'coins': 0,
      'badges': [],
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
    return ref.id;
  }

  Future<void> updateMember(String familyId, String memberId, Map<String, dynamic> patch) async {
    await membersColl(firebaseDB, familyId).doc(memberId).update(patch);
  }

  Future<void> removeMember(String familyId, String memberId) async {
    await membersColl(firebaseDB, familyId).doc(memberId).delete();
  }

  // ---------------------------
  // Writes: Chores & Assignments
  // ---------------------------
  Future<String> createChoreTemplate(
    String familyId, {
    required String title,
    String? description,
    String? iconKey,                
    required int difficulty,
    required FamilySettings settings,
    String? createdByMemberId,
    Recurrence? recurrence,
  }) async {
    final awards = calcAwards(difficulty: difficulty, settings: settings);
    final ref = choresColl(firebaseDB, familyId).doc();
    await ref.set({
      'title': title,
      'description': description,
      'icon': iconKey,               
      'difficulty': difficulty,
      'xp': awards.xp,
      'coins' : awards.coins,
      'recurrence': recurrence?.toMap(),
      'createdByMemberId': createdByMemberId,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
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
    await choresColl(firebaseDB, familyId).doc(choreId).update(patch);
  }

  Future<void> updateChoreAssignees(
    String familyId, {
    required String choreId,
    required List<String> memberIds,
  }) async {
    // de-dupe, drop empties, keep stable order
    final ids = memberIds.where((e) => e.isNotEmpty).toSet().toList()..sort();

    await choresColl(firebaseDB, familyId)
        .doc(choreId)
        .set({'assignees': ids}, SetOptions(merge: true));
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
  for (final m in members) {
    final ref = assignmentsColl(firebaseDB, familyId).doc();
    final awards = calcAwards(difficulty: chore.difficulty, settings: settings);
    createdIds.add(ref.id);
    batch.set(ref, {
      'familyId'          : familyId,
      'memberId'          : m.id,
      'memberName'        : m.displayName,
      'choreId'           : chore.id,
      'choreTitle'        : chore.title,
      'choreIcon'         : chore.icon,
      'difficulty'        : chore.difficulty,
      'xp'                : awards.xp,
      'coins'             : awards.coins,
      'requiresApproval'  : false,
      'status'            : 'assigned',
      'assignedAt'        : FieldValue.serverTimestamp(),
      'due'               : Timestamp.fromDate(due),
      'proof'             : null,
    });
  }
  await batch.commit();
  return createdIds;
}

Future<void> updateChoreDefaultAssignees(
  String familyId, {
  required String choreId,
  required List<String> memberIds,
}) {
  return choresColl(firebaseDB, familyId)
      .doc(choreId)
      .update({'defaultAssignees': memberIds});
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

// Future<void> markApproved(...) => /* same, status: 'approved' */;
// Future<void> markSkipped(...)  => /* same, status: 'skipped'  */;


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
  Future<void> approveAssignment(String familyId, String assignmentId, {String? parentMemberId}) async {
    final famRef = familyDoc(firebaseDB, familyId);
    final asnRef = assignmentsColl(firebaseDB, familyId).doc(assignmentId);

    await firebaseDB.runTransaction((tx) async {
      final famSnap = await tx.get(famRef);
      final asnSnap = await tx.get(asnRef);
      if (!asnSnap.exists) throw Exception('Assignment not found');

      final family = Family.fromDoc(famSnap);
      final asn = Assignment.fromDoc(asnSnap);

      if (asn.status != AssignmentStatus.completed) {
        throw Exception('Only completed assignments can be approved');
      }

      final memberRef = membersColl(firebaseDB, familyId).doc(asn.memberId);
      final memSnap = await tx.get(memberRef);
      if (!memSnap.exists) throw Exception('Member not found');

      final coins = (asn.xp * family.settings.coinPerPoint).round();

      tx.update(asnRef, {
        'status': 'approved',
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
        'payload': {
          'assignmentId': asn.id,
          'xp': asn.xp,
          'coins': coins,
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


  // ---------------------------
  // Rewards (coins store)
  // ---------------------------
  Future<String> createReward(String familyId, {required String name, required int priceCoins, int? stock}) async {
    final ref = rewardsColl(firebaseDB, familyId).doc();
    await ref.set({
      'name': name,
      'priceCoins': priceCoins,
      'stock': stock,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> purchaseReward(String familyId, {required String memberId, required Reward reward}) async {
    final memberRef = membersColl(firebaseDB, familyId).doc(memberId);
    final rewardRef = rewardsColl(firebaseDB, familyId).doc(reward.id);

    await firebaseDB.runTransaction((tx) async {
      final memSnap = await tx.get(memberRef);
      if (!memSnap.exists) throw Exception('Member not found');
      final member = Member.fromDoc(memSnap);

      if (member.coins < reward.priceCoins) {
        throw Exception('Not enough coins');
      }

      tx.update(memberRef, {'coins': FieldValue.increment(-reward.priceCoins)});

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
          'name': reward.name,
          'priceCoins': reward.priceCoins,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  DateTime _startOfLocalDayWithHour(int hour) {
  final now = DateTime.now();
  final candidate = DateTime(now.year, now.month, now.day, hour);
  return now.isBefore(candidate) ? candidate.subtract(const Duration(days: 1)) : candidate;
}

  // DateTime _endOfLocalDayWithHour(int hour) =>
  //     _startOfLocalDayWithHour(hour).add(const Duration(days: 1));

  String _yyyymmdd(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';

  // Combine a date with HH:mm from recurrence.timeOfDay (or fallback to dayStartHour)
  // DateTime _combineDateAndTime(DateTime dayStart, String? hhmm, int dayStartHour) {
  //   if (hhmm == null) return DateTime(dayStart.year, dayStart.month, dayStart.day, dayStartHour);
  //   final p = hhmm.split(':');
  //   return DateTime(dayStart.year, dayStart.month, dayStart.day, int.parse(p[0]), int.parse(p[1]));
  // }
}
