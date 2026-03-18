import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Member {
  final String id;
  final String displayName;
  final FamilyRole role;
  final String? userUid;
  final String? avatarKey;
  final String? pinHash;

  /// Birth month/year — day is always 1; used to compute age dynamically.
  final DateTime? birthMonth;

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
  final int totalChoresCompleted;

  final List<String> ownedCosmetics;
  final String? equippedBackgroundId;
  final String? equippedAvatarFrameId;
  final String? equippedZillaSkinId;
  final String? equippedTitleId;
  final List<String> unlockedAnimations;

  // --- Badge counter fields ---
  final int roomChoresCompleted;
  final int laundryChoresCompleted;
  final int dishChoresCompleted;
  final int trashChoresCompleted;
  final int petChoresCompleted;
  final int allTaskDaysCompleted;
  final int activeDays;
  final int peakCoins;
  final DateTime? lastSatCompleted;
  final DateTime? lastSunCompleted;

  /// Up to 3 badge base IDs the kid has chosen to display on their profile card.
  /// Backed by a nullable field so hot-reload and missing Firestore fields
  /// never cause a null-dereference crash.
  final List<String>? _featuredBadgeIds;
  List<String> get featuredBadgeIds => _featuredBadgeIds ?? const [];

  // --- Away / split-custody fields ---
  final DateTime? awayStartDate;
  final DateTime? awayUntil;
  final bool awayRecurring;
  final int? awayIntervalDays;

  /// Achievement title tracking
  /// Set to now when coins first reach 100; cleared if coins drop below 100.
  final DateTime? coinsHoardSince;
  /// Coins spent today (resets on a new calendar day).
  final int dailyCoinsSpent;
  final DateTime? dailyCoinsSpentDate;

  const Member({
    required this.id,
    required this.displayName,
    required this.role,
    this.userUid,
    this.avatarKey,
    this.pinHash,
    this.birthMonth,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.badges = const [],
    List<String>? featuredBadgeIds,
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
    this.totalChoresCompleted = 0,
    this.ownedCosmetics = const [],
    this.equippedBackgroundId,
    this.equippedAvatarFrameId,
    this.equippedZillaSkinId,
    this.equippedTitleId,
    this.unlockedAnimations = const [],
    this.allowBonusChores = true,
    this.awayStartDate,
    this.awayUntil,
    this.awayRecurring = false,
    this.awayIntervalDays,
    this.coinsHoardSince,
    this.dailyCoinsSpent = 0,
    this.dailyCoinsSpentDate,
    this.roomChoresCompleted = 0,
    this.laundryChoresCompleted = 0,
    this.dishChoresCompleted = 0,
    this.trashChoresCompleted = 0,
    this.petChoresCompleted = 0,
    this.allTaskDaysCompleted = 0,
    this.activeDays = 0,
    this.peakCoins = 0,
    this.lastSatCompleted,
    this.lastSunCompleted,
  }) : _featuredBadgeIds = featuredBadgeIds;

  Member copyWith({
    String? displayName,
    FamilyRole? role,
    String? userUid,
    String? avatarKey,
    String? pinHash,
    DateTime? birthMonth,
    int? level,
    int? xp,
    int? coins,
    List<String>? badges,
    List<String>? featuredBadgeIds,
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
    int? totalChoresCompleted,
    List<String>? ownedCosmetics,
    String? equippedBackgroundId,
    String? equippedAvatarFrameId,
    String? equippedZillaSkinId,
    String? equippedTitleId,
    List<String>? unlockedAnimations,
    bool? allowBonusChores,
    DateTime? awayStartDate,
    bool clearAwayStartDate = false,
    DateTime? awayUntil,
    bool clearAwayUntil = false,
    bool? awayRecurring,
    int? awayIntervalDays,
    bool clearAwayIntervalDays = false,
    DateTime? coinsHoardSince,
    bool clearCoinsHoardSince = false,
    int? dailyCoinsSpent,
    DateTime? dailyCoinsSpentDate,
    bool clearDailyCoinsSpentDate = false,
    int? roomChoresCompleted,
    int? laundryChoresCompleted,
    int? dishChoresCompleted,
    int? trashChoresCompleted,
    int? petChoresCompleted,
    int? allTaskDaysCompleted,
    int? activeDays,
    int? peakCoins,
    DateTime? lastSatCompleted,
    bool clearLastSatCompleted = false,
    DateTime? lastSunCompleted,
    bool clearLastSunCompleted = false,
  }) => Member(
    id: id,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    userUid: userUid ?? this.userUid,
    avatarKey: avatarKey ?? this.avatarKey,
    pinHash: pinHash ?? this.pinHash,
    birthMonth: birthMonth ?? this.birthMonth,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    coins: coins ?? this.coins,
    badges: badges ?? this.badges,
    featuredBadgeIds: featuredBadgeIds ?? this.featuredBadgeIds,
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
    totalChoresCompleted: totalChoresCompleted ?? this.totalChoresCompleted,
    ownedCosmetics: ownedCosmetics ?? this.ownedCosmetics,
    equippedBackgroundId: equippedBackgroundId ?? this.equippedBackgroundId,
    equippedAvatarFrameId: equippedAvatarFrameId ?? this.equippedAvatarFrameId,
    equippedZillaSkinId: equippedZillaSkinId ?? this.equippedZillaSkinId,
    equippedTitleId: equippedTitleId ?? this.equippedTitleId,
    unlockedAnimations: unlockedAnimations ?? this.unlockedAnimations,
    allowBonusChores: allowBonusChores ?? this.allowBonusChores,
    awayStartDate: clearAwayStartDate ? null : (awayStartDate ?? this.awayStartDate),
    awayUntil: clearAwayUntil ? null : (awayUntil ?? this.awayUntil),
    awayRecurring: awayRecurring ?? this.awayRecurring,
    awayIntervalDays: clearAwayIntervalDays ? null : (awayIntervalDays ?? this.awayIntervalDays),
    coinsHoardSince: clearCoinsHoardSince ? null : (coinsHoardSince ?? this.coinsHoardSince),
    dailyCoinsSpent: dailyCoinsSpent ?? this.dailyCoinsSpent,
    dailyCoinsSpentDate: clearDailyCoinsSpentDate ? null : (dailyCoinsSpentDate ?? this.dailyCoinsSpentDate),
    roomChoresCompleted: roomChoresCompleted ?? this.roomChoresCompleted,
    laundryChoresCompleted: laundryChoresCompleted ?? this.laundryChoresCompleted,
    dishChoresCompleted: dishChoresCompleted ?? this.dishChoresCompleted,
    trashChoresCompleted: trashChoresCompleted ?? this.trashChoresCompleted,
    petChoresCompleted: petChoresCompleted ?? this.petChoresCompleted,
    allTaskDaysCompleted: allTaskDaysCompleted ?? this.allTaskDaysCompleted,
    activeDays: activeDays ?? this.activeDays,
    peakCoins: peakCoins ?? this.peakCoins,
    lastSatCompleted: clearLastSatCompleted ? null : (lastSatCompleted ?? this.lastSatCompleted),
    lastSunCompleted: clearLastSunCompleted ? null : (lastSunCompleted ?? this.lastSunCompleted),
  );

    Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'role': roleToString(role),
    'userUid': userUid,
    'avatarKey': avatarKey,
    'pinHash': pinHash,
    'birthMonth': birthMonth == null ? null : Timestamp.fromDate(birthMonth!),
    'level': level,
    'xp': xp,
    'coins': coins,
    'badges': badges,
    'featuredBadgeIds': featuredBadgeIds,
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
    'totalChoresCompleted': totalChoresCompleted,

    'ownedCosmetics': ownedCosmetics,
    'equippedBackgroundId': equippedBackgroundId,
    'equippedAvatarFrameId': equippedAvatarFrameId,
    'equippedZillaSkinId': equippedZillaSkinId,
    'equippedTitleId': equippedTitleId,
    'unlockedAnimations': unlockedAnimations,
    'allowBonusChores': allowBonusChores,
    'awayStartDate': awayStartDate == null ? null : Timestamp.fromDate(awayStartDate!),
    'awayUntil': awayUntil == null ? null : Timestamp.fromDate(awayUntil!),
    'awayRecurring': awayRecurring,
    'awayIntervalDays': awayIntervalDays,
    'coinsHoardSince': coinsHoardSince == null ? null : Timestamp.fromDate(coinsHoardSince!),
    'dailyCoinsSpent': dailyCoinsSpent,
    'dailyCoinsSpentDate': dailyCoinsSpentDate == null ? null : Timestamp.fromDate(dailyCoinsSpentDate!),
    'roomChoresCompleted': roomChoresCompleted,
    'laundryChoresCompleted': laundryChoresCompleted,
    'dishChoresCompleted': dishChoresCompleted,
    'trashChoresCompleted': trashChoresCompleted,
    'petChoresCompleted': petChoresCompleted,
    'allTaskDaysCompleted': allTaskDaysCompleted,
    'activeDays': activeDays,
    'peakCoins': peakCoins,
    'lastSatCompleted': lastSatCompleted == null ? null : Timestamp.fromDate(lastSatCompleted!),
    'lastSunCompleted': lastSunCompleted == null ? null : Timestamp.fromDate(lastSunCompleted!),
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
      birthMonth: tsAsDate(data['birthMonth']),
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      badges:
          (data['badges'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      featuredBadgeIds:
          (data['featuredBadgeIds'] as List?)?.map((e) => e.toString()).toList() ??
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
      lastActiveDate: tsAsDate(data['lastActiveDate']),
      totalChoresCompleted: (data['totalChoresCompleted'] as num?)?.toInt() ?? 0,
      ownedCosmetics:
          (data['ownedCosmetics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      equippedBackgroundId: data['equippedBackgroundId'] as String?,
      equippedAvatarFrameId: data['equippedAvatarFrameId'] as String?,
      equippedZillaSkinId: data['equippedZillaSkinId'] as String?,
      equippedTitleId: data['equippedTitleId'] as String?,
      unlockedAnimations:
          (data['unlockedAnimations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      allowBonusChores: (data['allowBonusChores'] as bool?) ?? true,
      awayStartDate: tsAsDate(data['awayStartDate']),
      awayUntil: tsAsDate(data['awayUntil']),
      awayRecurring: (data['awayRecurring'] as bool?) ?? false,
      awayIntervalDays: (data['awayIntervalDays'] as num?)?.toInt(),
      coinsHoardSince: tsAsDate(data['coinsHoardSince']),
      dailyCoinsSpent: (data['dailyCoinsSpent'] as num?)?.toInt() ?? 0,
      dailyCoinsSpentDate: tsAsDate(data['dailyCoinsSpentDate']),
      roomChoresCompleted: (data['roomChoresCompleted'] as num?)?.toInt() ?? 0,
      laundryChoresCompleted: (data['laundryChoresCompleted'] as num?)?.toInt() ?? 0,
      dishChoresCompleted: (data['dishChoresCompleted'] as num?)?.toInt() ?? 0,
      trashChoresCompleted: (data['trashChoresCompleted'] as num?)?.toInt() ?? 0,
      petChoresCompleted: (data['petChoresCompleted'] as num?)?.toInt() ?? 0,
      allTaskDaysCompleted: (data['allTaskDaysCompleted'] as num?)?.toInt() ?? 0,
      activeDays: (data['activeDays'] as num?)?.toInt() ?? 0,
      peakCoins: (data['peakCoins'] as num?)?.toInt() ?? 0,
      lastSatCompleted: tsAsDate(data['lastSatCompleted']),
      lastSunCompleted: tsAsDate(data['lastSunCompleted']),
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
    'birthMonth': birthMonth?.toIso8601String(),
    'level': level,
    'xp': xp,
    'coins': coins,
    'badges': badges,
    'featuredBadgeIds': featuredBadgeIds,
    'createdAt': createdAt?.toIso8601String(),
    'active': active,
    'allowanceEnabled': allowanceEnabled,
    'allowanceFullAmountCents': allowanceFullAmountCents,
    'allowanceDaysRequired': allowanceDaysRequired,
    'allowancePayDay': allowancePayDay,
    'notificationsEnabled': notificationsEnabled,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActiveDate': lastActiveDate?.toIso8601String(),
    'totalChoresCompleted': totalChoresCompleted,
    'ownedCosmetics': ownedCosmetics,
    'equippedBackgroundId': equippedBackgroundId,
    'equippedAvatarFrameId': equippedAvatarFrameId,
    'equippedZillaSkinId': equippedZillaSkinId,
    'equippedTitleId': equippedTitleId,
    'unlockedAnimations': unlockedAnimations,
    'allowBonusChores': allowBonusChores,
    'awayStartDate': awayStartDate?.toIso8601String(),
    'awayUntil': awayUntil?.toIso8601String(),
    'awayRecurring': awayRecurring,
    'awayIntervalDays': awayIntervalDays,
    'coinsHoardSince': coinsHoardSince?.toIso8601String(),
    'dailyCoinsSpent': dailyCoinsSpent,
    'dailyCoinsSpentDate': dailyCoinsSpentDate?.toIso8601String(),
    'roomChoresCompleted': roomChoresCompleted,
    'laundryChoresCompleted': laundryChoresCompleted,
    'dishChoresCompleted': dishChoresCompleted,
    'trashChoresCompleted': trashChoresCompleted,
    'petChoresCompleted': petChoresCompleted,
    'allTaskDaysCompleted': allTaskDaysCompleted,
    'activeDays': activeDays,
    'peakCoins': peakCoins,
    'lastSatCompleted': lastSatCompleted?.toIso8601String(),
    'lastSunCompleted': lastSunCompleted?.toIso8601String(),
  };


    factory Member.fromCacheMap(Map<String, dynamic> data) {
    return Member(
      id: data['id'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Member',
      role: roleFromString(data['role'] as String? ?? 'parent'),
      userUid: data['userUid'] as String?,
      avatarKey: data['avatarKey'] as String?,
      pinHash: data['pinHash'] as String?,
      birthMonth: parseIsoDateTimeOrNull(data['birthMonth']),
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      badges:
          (data['badges'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      featuredBadgeIds:
          (data['featuredBadgeIds'] as List?)?.map((e) => e.toString()).toList() ??
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
      lastActiveDate: parseIsoDateTimeOrNull(data['lastActiveDate']),
      totalChoresCompleted: (data['totalChoresCompleted'] as num?)?.toInt() ?? 0,
      ownedCosmetics:
          (data['ownedCosmetics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      equippedBackgroundId: data['equippedBackgroundId'] as String?,
      equippedAvatarFrameId: data['equippedAvatarFrameId'] as String?,
      equippedZillaSkinId: data['equippedZillaSkinId'] as String?,
      equippedTitleId: data['equippedTitleId'] as String?,
      unlockedAnimations:
          (data['unlockedAnimations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      allowBonusChores: (data['allowBonusChores'] as bool?) ?? true,
      awayStartDate: parseIsoDateTimeOrNull(data['awayStartDate']),
      awayUntil: parseIsoDateTimeOrNull(data['awayUntil']),
      awayRecurring: (data['awayRecurring'] as bool?) ?? false,
      awayIntervalDays: (data['awayIntervalDays'] as num?)?.toInt(),
      coinsHoardSince: parseIsoDateTimeOrNull(data['coinsHoardSince']),
      dailyCoinsSpent: (data['dailyCoinsSpent'] as num?)?.toInt() ?? 0,
      dailyCoinsSpentDate: parseIsoDateTimeOrNull(data['dailyCoinsSpentDate']),
      roomChoresCompleted: (data['roomChoresCompleted'] as num?)?.toInt() ?? 0,
      laundryChoresCompleted: (data['laundryChoresCompleted'] as num?)?.toInt() ?? 0,
      dishChoresCompleted: (data['dishChoresCompleted'] as num?)?.toInt() ?? 0,
      trashChoresCompleted: (data['trashChoresCompleted'] as num?)?.toInt() ?? 0,
      petChoresCompleted: (data['petChoresCompleted'] as num?)?.toInt() ?? 0,
      allTaskDaysCompleted: (data['allTaskDaysCompleted'] as num?)?.toInt() ?? 0,
      activeDays: (data['activeDays'] as num?)?.toInt() ?? 0,
      peakCoins: (data['peakCoins'] as num?)?.toInt() ?? 0,
      lastSatCompleted: parseIsoDateTimeOrNull(data['lastSatCompleted']),
      lastSunCompleted: parseIsoDateTimeOrNull(data['lastSunCompleted']),
    );
  }

  int? get age {
    if (birthMonth == null) return null;
    final now = DateTime.now();
    int a = now.year - birthMonth!.year;
    if (now.month < birthMonth!.month) a--;
    return a;
  }

  bool ownsCosmetic(String cosmeticId) => ownedCosmetics.contains(cosmeticId);

  bool hasBadge(String badgeId) => badges.contains(badgeId);

  bool isAwayOnDate(DateTime date) {
    if (awayUntil == null || awayStartDate == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(awayStartDate!.year, awayStartDate!.month, awayStartDate!.day);
    final until = DateTime(awayUntil!.year, awayUntil!.month, awayUntil!.day);

    if (!awayRecurring || awayIntervalDays == null) {
      return !d.isBefore(start) && !d.isAfter(until);
    }
    // Recurring: compute position within cycle
    final durationDays = until.difference(start).inDays + 1;
    final daysSinceAnchor = d.difference(start).inDays;
    if (daysSinceAnchor < 0) return false;
    final posInCycle = daysSinceAnchor % awayIntervalDays!;
    return posInCycle < durationDays;
  }

}
