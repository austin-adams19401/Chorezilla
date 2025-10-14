import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/common.dart';
import '../models/user_profile.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../models/chore.dart';
import '../models/assignment.dart';
import '../models/reward.dart';

// Firestore path helpers
DocumentReference userDoc(FirebaseFirestore db, String uid) => db.doc('users/$uid');
DocumentReference familyDoc(FirebaseFirestore db, String familyId) => db.doc('families/$familyId');
CollectionReference membersColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/members');
CollectionReference choresColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/chores');
CollectionReference assignmentsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/assignments');
CollectionReference rewardsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/rewards');
CollectionReference devicesColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/devices');
CollectionReference eventsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/events');

class FamilyRepo {
  final FirebaseFirestore db;
  FamilyRepo({required this.db});

  // ---------------------------
  // Bootstrap / Profiles
  // ---------------------------
  Future<UserProfile> ensureUserProfile(
    String uid, {
    String? displayName,
    String? email,
  }) async {
    final ref = userDoc(db, uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'displayName': displayName,
        'email': email,
        'defaultFamilyId': null,
        'memberships': {},
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignInAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({'lastSignInAt': FieldValue.serverTimestamp()});
    }

    var profile = UserProfile.fromDoc(await ref.get());

    if (profile.defaultFamilyId == null || profile.defaultFamilyId!.isEmpty) {
      // Create a new family and parent member for this user
      final newFamId = await _createFamilyWithOwner(
        ownerUid: uid,
        familyName: displayName == null || displayName.isEmpty
            ? 'My Family'
            : "${displayName.split(' ').first}'s Family",
        parentDisplayName: displayName ?? 'Parent',
      );

      // Update user profile with default family + membership (placeholder)
      await db.runTransaction((tx) async {
        final uSnap = await tx.get(ref);
        final existing = UserProfile.fromDoc(uSnap);
        final memberships = Map<String, Membership>.from(existing.memberships);
        memberships[newFamId] = const Membership(memberId: 'mem_parent_owner', role: FamilyRole.parent);
        tx.update(ref, {
          'defaultFamilyId': newFamId,
          'memberships.$newFamId': {
            'memberId': 'mem_parent_owner', // will be corrected below
            'role': 'parent',
          },
        });
      });

      // Correct the membership with real memberId
      final parentMemberId = await _findFirstParentMemberId(newFamId, uid);
      await ref.update({'memberships.$newFamId.memberId': parentMemberId});

      profile = UserProfile.fromDoc(await ref.get());
    }

    return profile;
  }

  Future<String> _findFirstParentMemberId(String familyId, String ownerUid) async {
    final q = await membersColl(db, familyId).where('userUid', isEqualTo: ownerUid).limit(1).get();
    if (q.docs.isEmpty) return 'mem_parent_owner';
    return q.docs.first.id;
  }

  Future<String> _createFamilyWithOwner({
    required String ownerUid,
    required String familyName,
    required String parentDisplayName,
  }) async {
    final famRef = db.collection('families').doc();
    final membersRef = membersColl(db, famRef.id).doc();

    final batch = db.batch();
    batch.set(famRef, {
      'name': familyName,
      'ownerUid': ownerUid,
      'joinCode': null,
      'settings': const FamilySettings().toMap(),
      'stats': const FamilyStats().toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(membersRef, {
      'displayName': parentDisplayName,
      'role': 'parent',
      'userUid': ownerUid,
      'avatarKey': null,
      'pinHash': null,
      'level': 1,
      'xp': 0,
      'coins': 0,
      'badges': [],
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });

    await batch.commit();
    return famRef.id;
  }

  // Update family fields (e.g., name)
  Future<void> updateFamily(String familyId, Map<String, dynamic> patch) async {
    await familyDoc(db, familyId).set(patch, SetOptions(merge: true));
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
    final existing = await membersColl(db, familyId)
        .where('userUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      // ensure defaultFamilyId points here
      await userDoc(db, uid).set({'defaultFamilyId': familyId}, SetOptions(merge: true));
      return existing.docs.first.id;
    }

    final memberRef = membersColl(db, familyId).doc();
    final userRef = userDoc(db, uid);

    await db.runTransaction((tx) async {
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
    final famRef = familyDoc(db, familyId);
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
    await db.collection('joinCodes').doc(code).set({
      'familyId': familyId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return code;
  }

  // Lookup a familyId for a given code (does NOT link current user)
  Future<String?> redeemJoinCode(String code) async {
    code = code.trim().toUpperCase();
    if (code.isEmpty) return null;
    final doc = await db.collection('joinCodes').doc(code).get();
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
  Stream<Family> watchFamily(String familyId) => familyDoc(db, familyId).snapshots().map(Family.fromDoc);

  Stream<List<Member>> watchMembers(String familyId, {bool? activeOnly = true}) {
    Query q = membersColl(db, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Member.fromDoc).toList());
  }

  Stream<List<Chore>> watchChores(String familyId, {bool? activeOnly = true}) {
    Query q = choresColl(db, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Chore.fromDoc).toList());
  }

  Stream<List<Assignment>> watchAssignmentsForMember(
    String familyId, {
    required String memberId,
    List<AssignmentStatus>? statuses,
  }) {
    Query q = assignmentsColl(db, familyId).where('memberId', isEqualTo: memberId);
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
    final q = assignmentsColl(db, familyId)
        .where('due', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('due', isLessThan: Timestamp.fromDate(end))
        .orderBy('due'); // single-field index only
    return q.snapshots().map((s) => s.docs
        .map(Assignment.fromDoc)
        .where((a) => a.status == AssignmentStatus.assigned)
        .toList());
  }

  // Assignments due today (filters status in memory to avoid composite indexes)
  Stream<List<Assignment>> watchAssignmentsDueToday(String familyId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final q = assignmentsColl(db, familyId)
        .where('due', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('due', isLessThan: Timestamp.fromDate(end))
        .orderBy('due');
    return q.snapshots().map((s) => s.docs
        .map(Assignment.fromDoc)
        .where((a) => a.status == AssignmentStatus.assigned)
        .toList());
  }



  Stream<List<Assignment>> watchReviewQueue(String familyId) {
    return assignmentsColl(db, familyId)
        .where('status', isEqualTo: statusToString(AssignmentStatus.completed))
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  Stream<List<Reward>> watchRewards(String familyId, {bool? activeOnly = true}) {
    Query q = rewardsColl(db, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Reward.fromDoc).toList());
  }

  // ---------------------------
  // Writes: Members
  // ---------------------------
  Future<String> addChild(String familyId, {required String displayName, String? avatarKey, String? pinHash}) async {
    final ref = membersColl(db, familyId).doc();
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
    await membersColl(db, familyId).doc(memberId).update(patch);
  }

  // ---------------------------
  // Writes: Chores & Assignments
  // ---------------------------
  Future<String> createChoreTemplate(
  String familyId, {
  required String title,
  String? description,
  String? iconKey,                 // <-- NEW (optional)
  required int difficulty,
  required FamilySettings settings,
  String? createdByMemberId,
  Recurrence? recurrence,
}) async {
  final points = settings.pointsPerDifficulty[difficulty] ?? (difficulty * 10);
  final ref = choresColl(db, familyId).doc();
  await ref.set({
    'title': title,
    'description': description,
    'icon': iconKey,               // <-- NEW (saved in Firestore)
    'difficulty': difficulty,
    'points': points,
    'recurrence': recurrence?.toMap(),
    'createdByMemberId': createdByMemberId,
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  return ref.id;
}

Future<List<String>> assignChoreToMembers(
  String familyId, {
  required Chore chore,
  required List<Member> members,
  required DateTime due,
}) async {
  final batch = db.batch();
  final createdIds = <String>[];
  for (final m in members) {
    final ref = assignmentsColl(db, familyId).doc();
    createdIds.add(ref.id);
    batch.set(ref, {
      'memberId': m.id,
      'memberName': m.displayName,
      'choreId': chore.id,
      'choreTitle': chore.title,
      'choreIcon': chore.icon,  // <-- NEW
      'difficulty': chore.difficulty,
      'points': chore.points,
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
      'due': Timestamp.fromDate(due),
      'proof': null,
    });
  }
  await batch.commit();
  return createdIds;
}

  Future<void> completeAssignment(
    String familyId,
    String assignmentId, {
    String? note,
    String? photoUrl,
  }) async {
    await assignmentsColl(db, familyId).doc(assignmentId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'proof': {
        'photoUrl': photoUrl,
        'note': note,
      }
    });
  }

  // Parent approves: update assignment + increment kid xp/coins + add event
  Future<void> approveAssignment(String familyId, String assignmentId, {String? parentMemberId}) async {
    final famRef = familyDoc(db, familyId);
    final asnRef = assignmentsColl(db, familyId).doc(assignmentId);

    await db.runTransaction((tx) async {
      final famSnap = await tx.get(famRef);
      final asnSnap = await tx.get(asnRef);
      if (!asnSnap.exists) throw Exception('Assignment not found');

      final family = Family.fromDoc(famSnap);
      final asn = Assignment.fromDoc(asnSnap);

      if (asn.status != AssignmentStatus.completed) {
        throw Exception('Only completed assignments can be approved');
      }

      final memberRef = membersColl(db, familyId).doc(asn.memberId);
      final memSnap = await tx.get(memberRef);
      if (!memSnap.exists) throw Exception('Member not found');

      final coins = (asn.points * family.settings.coinPerPoint).round();

      tx.update(asnRef, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      tx.update(memberRef, {
        'xp': FieldValue.increment(asn.points),
        'coins': FieldValue.increment(coins),
      });

      final evRef = eventsColl(db, familyId).doc();
      tx.set(evRef, {
        'type': 'assignment_approved',
        'actorMemberId': parentMemberId,
        'targetMemberId': asn.memberId,
        'payload': {
          'assignmentId': asn.id,
          'points': asn.points,
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
    final asnRef = assignmentsColl(db, familyId).doc(assignmentId);
    await db.runTransaction((tx) async {
      final asnSnap = await tx.get(asnRef);
      if (!asnSnap.exists) throw Exception('Assignment not found');
      final asn = Assignment.fromDoc(asnSnap);
      if (asn.status != AssignmentStatus.completed) {
        throw Exception('Only completed assignments can be rejected');
      }
      tx.update(asnRef, {'status': 'rejected'});
      final evRef = eventsColl(db, familyId).doc();
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
    final ref = rewardsColl(db, familyId).doc();
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
    final memberRef = membersColl(db, familyId).doc(memberId);
    final rewardRef = rewardsColl(db, familyId).doc(reward.id);

    await db.runTransaction((tx) async {
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

      final evRef = eventsColl(db, familyId).doc();
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
}
