// lib/data/repo_members.dart
part of 'chorezilla_repo.dart';

extension MemberRepo on ChorezillaRepo {
  // Watchers (members)
  Stream<List<Member>> watchMembers(
    String familyId, {
    bool? activeOnly = true,
  }) {
    Query q = membersColl(firebaseDB, familyId);
    if (activeOnly == true) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Member.fromDoc).toList());
  }

  // Writes: Members
  Future<String> addChild(
    String familyId, {
    required String displayName,
    String? avatarKey,
    String? pinHash,
  }) async {
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

  Future<void> updateMember(
    String familyId,
    String memberId,
    Map<String, dynamic> patch,
  ) async {
    await membersColl(firebaseDB, familyId).doc(memberId).update(patch);
  }

  Future<void> removeMember(String familyId, String memberId) async {
    await membersColl(firebaseDB, familyId).doc(memberId).delete();
  }
}
