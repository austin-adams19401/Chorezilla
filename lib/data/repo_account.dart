// lib/data/repo_account.dart
part of 'chorezilla_repo.dart';

extension AccountRepo on ChorezillaRepo {
  /// Delete all family data (subcollections + doc) for the given family.
  Future<void> _deleteFamilyData(String familyId) async {
    final subcollections = [
      'members',
      'chores',
      'assignments',
      'rewards',
      'devices',
      'events',
      'choreMemberSchedules',
      'rewardRedemptions',
    ];

    final batch = firebaseDB.batch();
    for (final sub in subcollections) {
      final snap = await firebaseDB
          .collection('families/$familyId/$sub')
          .get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }
    batch.delete(familyDoc(firebaseDB, familyId));
    await batch.commit();
  }

  /// Count how many parent members exist in a family.
  Future<int> countParents(String familyId) async {
    final snap = await membersColl(firebaseDB, familyId)
        .where('role', isEqualTo: 'parent')
        .get();
    return snap.docs.length;
  }

  /// Delete the current user's account and associated data.
  ///
  /// If [isLastParent] is true, deletes the entire family and all its data.
  /// Otherwise, just removes the user's member doc and user profile.
  ///
  /// The caller must handle re-authentication if Firebase throws
  /// `requires-recent-login`.
  Future<void> deleteAccount({
    required String uid,
    required String? familyId,
    required bool isLastParent,
  }) async {
    if (familyId != null) {
      if (isLastParent) {
        await _deleteFamilyData(familyId);
      } else {
        // Just remove this parent's member doc
        final memberSnap = await membersColl(firebaseDB, familyId)
            .where('userUid', isEqualTo: uid)
            .limit(1)
            .get();
        for (final doc in memberSnap.docs) {
          await doc.reference.delete();
        }
      }
    }

    // Delete the user profile doc
    await userDoc(firebaseDB, uid).delete();

    // Delete the Firebase Auth account (must be called last)
    await FirebaseAuth.instance.currentUser?.delete();
  }
}
