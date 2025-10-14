import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Member {
  final String id;
  final String displayName;
  final FamilyRole role;
  final String? userUid; // null for kid without auth user
  final String? avatarKey;
  final String? pinHash; // optional for kid login on shared device
  final int level;
  final int xp;
  final int coins;
  final List<String> badges;
  final DateTime? createdAt;
  final bool active;

  const Member({
    required this.id,
    required this.displayName,
    required this.role,
    this.userUid,
    this.avatarKey,
    this.pinHash,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.badges = const [],
    this.createdAt,
    this.active = true,
  });

  Member copyWith({
    String? displayName,
    FamilyRole? role,
    String? userUid,
    String? avatarKey,
    String? pinHash,
    int? level,
    int? xp,
    int? coins,
    List<String>? badges,
    DateTime? createdAt,
    bool? active,
  }) =>
      Member(
        id: id,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        userUid: userUid ?? this.userUid,
        avatarKey: avatarKey ?? this.avatarKey,
        pinHash: pinHash ?? this.pinHash,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        coins: coins ?? this.coins,
        badges: badges ?? this.badges,
        createdAt: createdAt ?? this.createdAt,
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'role': roleToString(role),
        'userUid': userUid,
        'avatarKey': avatarKey,
        'pinHash': pinHash,
        'level': level,
        'xp': xp,
        'coins': coins,
        'badges': badges,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
        'active': active,
      };

  factory Member.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Member(
      id: doc.id,
      displayName: data['displayName'] as String? ?? 'Member',
      role: roleFromString(data['role'] as String? ?? 'child'),
      userUid: data['userUid'] as String?,
      avatarKey: data['avatarKey'] as String?,
      pinHash: data['pinHash'] as String?,
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      badges: (data['badges'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: tsAsDate(data['createdAt']),
      active: (data['active'] as bool?) ?? true,
    );
  }
}
