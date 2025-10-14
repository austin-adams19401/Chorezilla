import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Membership {
  final String memberId;
  final FamilyRole role;
  const Membership({required this.memberId, required this.role});

  Map<String, dynamic> toMap() => {
        'memberId': memberId,
        'role': roleToString(role),
      };

  factory Membership.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const Membership(memberId: '', role: FamilyRole.child);
    return Membership(
      memberId: data['memberId'] as String? ?? '',
      role: roleFromString(data['role'] as String? ?? 'child'),
    );
  }
}

class UserProfile {
  final String id; // uid
  final String? displayName;
  final String? email;
  final String? defaultFamilyId;
  final Map<String, Membership> memberships; // familyId -> Membership
  final DateTime? createdAt;
  final DateTime? lastSignInAt;

  const UserProfile({
    required this.id,
    this.displayName,
    this.email,
    this.defaultFamilyId,
    this.memberships = const {},
    this.createdAt,
    this.lastSignInAt,
  });

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? defaultFamilyId,
    Map<String, Membership>? memberships,
    DateTime? createdAt,
    DateTime? lastSignInAt,
  }) =>
      UserProfile(
        id: id,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        defaultFamilyId: defaultFamilyId ?? this.defaultFamilyId,
        memberships: memberships ?? this.memberships,
        createdAt: createdAt ?? this.createdAt,
        lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      );

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    memberships.forEach((famId, mem) => m[famId] = mem.toMap());
    return {
      'displayName': displayName,
      'email': email,
      'defaultFamilyId': defaultFamilyId,
      'memberships': m,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'lastSignInAt': lastSignInAt == null ? null : Timestamp.fromDate(lastSignInAt!),
    };
  }

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawMem = (data['memberships'] as Map<String, dynamic>?) ?? {};
    final mems = <String, Membership>{};
    rawMem.forEach((key, value) {
      mems[key] = Membership.fromMap(value as Map<String, dynamic>?);
    });
    return UserProfile(
      id: doc.id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      defaultFamilyId: data['defaultFamilyId'] as String?,
      memberships: mems,
      createdAt: tsAsDate(data['createdAt']),
      lastSignInAt: tsAsDate(data['lastSignInAt']),
    );
  }
}
