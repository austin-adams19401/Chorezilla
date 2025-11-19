// lib/data/repo_families.dart
part of 'chorezilla_repo.dart';

extension FamilyRepo on ChorezillaRepo {
  // Update family fields (e.g., name)
  Future<void> updateFamily(String familyId, Map<String, dynamic> patch) async {
    await familyDoc(firebaseDB, familyId).set(patch, SetOptions(merge: true));
  }

  /// Join a family as a Parent (idempotent)
  /// - Creates a parent Member linked to this user (if not already present)
  /// - Updates users/{uid} memberships + defaultFamilyId
  /// - Returns the memberId
  Future<String> joinFamilyAsParent({required String familyId, required String uid, String? displayName}) async {
    // Already a member?
    final existing = await membersColl(
      firebaseDB,
      familyId,
    ).where('userUid', isEqualTo: uid).limit(1).get();

    if (existing.docs.isNotEmpty) {
      await userDoc(
        firebaseDB,
        uid,
      ).set({'defaultFamilyId': familyId}, SetOptions(merge: true));
      return existing.docs.first.id;
    }

    final memberRef = membersColl(firebaseDB, familyId).doc();
    final userRef = userDoc(firebaseDB, uid);

    final effectiveName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : 'Parent';

    await firebaseDB.runTransaction((tx) async {
      // create member (parent)
      tx.set(memberRef, {
        'displayName': effectiveName,
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
        'displayName': effectiveName,
        'memberships.$familyId': {'memberId': memberRef.id, 'role': 'parent'},
      }, SetOptions(merge: true));
    });

    return memberRef.id;
  }


  // Watchers (family)
  Stream<Family> watchFamily(String familyId) =>
      familyDoc(firebaseDB, familyId).snapshots().map(Family.fromDoc);
}
