// lib/data/repo_invites.dart
part of 'chorezilla_repo.dart';

extension InviteRepo on ChorezillaRepo {
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
}

// private helper (library-private)
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
