import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Member {
  final String id;
  final String displayName;
  final FamilyRole role;
  final String? userUid;
  final String? avatarKey;
  final String? pinHash;
  final int? age;

  /// Kid wallet fields
  final int level;
  final int xp;
  final int coins;

  final List<String> badges;
  final DateTime? createdAt;
  final bool active;

  /// Allowance config
  final bool allowanceEnabled;
  final int allowanceFullAmountCents;
  final int allowanceDaysRequired;
  final int allowancePayDay;

  final bool notificationsEnabled;
  final bool allowBonusChores;

  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;

  final List<String> ownedCosmetics;
  final String? equippedBackgroundId;
  final String? equippedAvatarFrameId;
  final String? equippedZillaSkinId;
  final String? equippedTitleId;

  const Member({
    required this.id,
    required this.displayName,
    required this.role,
    this.userUid,
    this.avatarKey,
    this.pinHash,
    this.age,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.badges = const [],
    this.createdAt,
    this.active = true,
    this.allowanceEnabled = false,
    this.allowanceFullAmountCents = 0,
    this.allowanceDaysRequired = 7,
    this.allowancePayDay = DateTime.sunday,
    this.notificationsEnabled = true,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.ownedCosmetics = const [],
    this.equippedBackgroundId,
    this.equippedAvatarFrameId,
    this.equippedZillaSkinId,
    this.equippedTitleId,
    this.allowBonusChores = true,
  });

  Member copyWith({
    String? displayName,
    FamilyRole? role,
    String? userUid,
    String? avatarKey,
    String? pinHash,
    int? age,
    int? level,
    int? xp,
    int? coins,
    List<String>? badges,
    DateTime? createdAt,
    bool? active,
    bool? allowanceEnabled,
    int? allowanceFullAmountCents,
    int? allowanceDaysRequired,
    int? allowancePayDay,
    bool? notificationsEnabled, 
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDate,
    List<String>? ownedCosmetics,
    String? equippedBackgroundId,
    String? equippedAvatarFrameId,
    String? equippedZillaSkinId,
    String? equippedTitleId,
    bool? allowBonusChores,
  }) => Member(
    id: id,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    userUid: userUid ?? this.userUid,
    avatarKey: avatarKey ?? this.avatarKey,
    pinHash: pinHash ?? this.pinHash,
    age: age ?? this.age,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    coins: coins ?? this.coins,
    badges: badges ?? this.badges,
    createdAt: createdAt ?? this.createdAt,
    active: active ?? this.active,
    allowanceEnabled: allowanceEnabled ?? this.allowanceEnabled,
    allowanceFullAmountCents:
        allowanceFullAmountCents ?? this.allowanceFullAmountCents,
    allowanceDaysRequired: allowanceDaysRequired ?? this.allowanceDaysRequired,
    allowancePayDay: allowancePayDay ?? this.allowancePayDay,
    notificationsEnabled:
        notificationsEnabled ?? this.notificationsEnabled, 
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    lastActiveDate: lastActiveDate ?? this.lastActiveDate, 
    ownedCosmetics: ownedCosmetics ?? this.ownedCosmetics,
    equippedBackgroundId: equippedBackgroundId ?? this.equippedBackgroundId,
    equippedAvatarFrameId: equippedAvatarFrameId ?? this.equippedAvatarFrameId,
    equippedZillaSkinId: equippedZillaSkinId ?? this.equippedZillaSkinId,
    equippedTitleId: equippedTitleId ?? this.equippedTitleId,
    allowBonusChores: allowBonusChores ?? this.allowBonusChores,
  );

    Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'role': roleToString(role),
    'userUid': userUid,
    'avatarKey': avatarKey,
    'pinHash': pinHash,
    'age': age,
    'level': level,
    'xp': xp,
    'coins': coins,
    'badges': badges,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'active': active,

    // Allowance fields
    'allowanceEnabled': allowanceEnabled,
    'allowanceFullAmountCents': allowanceFullAmountCents,
    'allowanceDaysRequired': allowanceDaysRequired,
    'allowancePayDay': allowancePayDay,
    'notificationsEnabled': notificationsEnabled,

    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActiveDate': lastActiveDate == null
        ? null
        : Timestamp.fromDate(lastActiveDate!), 

    'ownedCosmetics': ownedCosmetics,
    'equippedBackgroundId': equippedBackgroundId,
    'equippedAvatarFrameId': equippedAvatarFrameId,
    'equippedZillaSkinId': equippedZillaSkinId,
    'equippedTitleId': equippedTitleId,
    'allowBonusChores': allowBonusChores,
  };

  factory Member.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawRole = data['role'] as String?;

    return Member(
      id: doc.id,
      displayName: data['displayName'] as String? ?? 'Member',
      role: roleFromString(rawRole ?? 'parent'),
      userUid: data['userUid'] as String?,
      avatarKey: data['avatarKey'] as String?,
      pinHash: data['pinHash'] as String?,
      age: data['age'] as int?,
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      badges:
          (data['badges'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: tsAsDate(data['createdAt']),
      active: (data['active'] as bool?) ?? true,
      allowanceEnabled: data['allowanceEnabled'] as bool? ?? false,
      allowanceFullAmountCents: data['allowanceFullAmountCents'] as int? ?? 0,
      allowanceDaysRequired: data['allowanceDaysRequired'] as int? ?? 7,
      allowancePayDay: data['allowancePayDay'] as int? ?? DateTime.sunday,
      notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      lastActiveDate: tsAsDate(data['lastActiveDate']), // 👈 NEW
      ownedCosmetics:
          (data['ownedCosmetics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      equippedBackgroundId: data['equippedBackgroundId'] as String?,
      equippedAvatarFrameId: data['equippedAvatarFrameId'] as String?,
      equippedZillaSkinId: data['equippedZillaSkinId'] as String?,
      equippedTitleId: data['equippedTitleId'] as String?,
      allowBonusChores: (data['allowBonusChores'] as bool?) ?? true,
    );
  }

    // --- Local cache mapping (no Firestore Timestamp) ---
    Map<String, dynamic> toCacheMap() => {
    'id': id,
    'displayName': displayName,
    'role': roleToString(role),
    'userUid': userUid,
    'avatarKey': avatarKey,
    'pinHash': pinHash,
    'age': age,
    'level': level,
    'xp': xp,
    'coins': coins,
    'badges': badges,
    'createdAt': createdAt?.toIso8601String(),
    'active': active,
    'allowanceEnabled': allowanceEnabled,
    'allowanceFullAmountCents': allowanceFullAmountCents,
    'allowanceDaysRequired': allowanceDaysRequired,
    'allowancePayDay': allowancePayDay,
    'notificationsEnabled': notificationsEnabled,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActiveDate': lastActiveDate?.toIso8601String(), // 👈 NEW
    'ownedCosmetics': ownedCosmetics,
    'equippedBackgroundId': equippedBackgroundId,
    'equippedAvatarFrameId': equippedAvatarFrameId,
    'equippedZillaSkinId': equippedZillaSkinId,
    'equippedTitleId': equippedTitleId,
    'allowBonusChores': allowBonusChores,
  };


    factory Member.fromCacheMap(Map<String, dynamic> data) {
    return Member(
      id: data['id'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Member',
      role: roleFromString(data['role'] as String? ?? 'parent'),
      userUid: data['userUid'] as String?,
      avatarKey: data['avatarKey'] as String?,
      pinHash: data['pinHash'] as String?,
      age: data['age'] as int?,
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      badges:
          (data['badges'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: parseIsoDateTimeOrNull(data['createdAt']),
      active: (data['active'] as bool?) ?? true,
      allowanceEnabled: data['allowanceEnabled'] as bool? ?? false,
      allowanceFullAmountCents:
          (data['allowanceFullAmountCents'] as num?)?.toInt() ?? 0,
      allowanceDaysRequired:
          (data['allowanceDaysRequired'] as num?)?.toInt() ?? 7,
      allowancePayDay:
          (data['allowancePayDay'] as num?)?.toInt() ?? DateTime.sunday,
      notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      lastActiveDate: parseIsoDateTimeOrNull(data['lastActiveDate']), // 👈 NEW
      ownedCosmetics:
          (data['ownedCosmetics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      equippedBackgroundId: data['equippedBackgroundId'] as String?,
      equippedAvatarFrameId: data['equippedAvatarFrameId'] as String?,
      equippedZillaSkinId: data['equippedZillaSkinId'] as String?,
      equippedTitleId: data['equippedTitleId'] as String?,
      allowBonusChores: (data['allowBonusChores'] as bool?) ?? true,
    );
  }

  bool ownsCosmetic(String cosmeticId) => ownedCosmetics.contains(cosmeticId);

  bool hasBadge(String badgeId) => badges.contains(badgeId);

}
