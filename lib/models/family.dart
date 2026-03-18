import 'package:chorezilla/components/leveling.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

enum SubscriptionTier { free, premium, lifetime }

SubscriptionTier _tierFromString(String? value) {
  switch (value) {
    case 'premium':
      return SubscriptionTier.premium;
    case 'lifetime':
      return SubscriptionTier.lifetime;
    default:
      return SubscriptionTier.free;
  }
}

class FamilySettings {
  final Map<int, int> difficultyToXP; // 1..5 -> points
  final int dayStartHour; // 0-23
  final double coinPerPoint; // e.g., 0.2 means 5 points -> 1 coin
  /// Per-family custom level-up rewards (premium only).
  /// Keys are level numbers; values are ordered reward lists for that level.
  /// When null, the app falls back to [kDefaultLevelRewards].
  final Map<int, List<LevelRewardDefinition>>? customLevelRewards;

  const FamilySettings({
    this.difficultyToXP = const {1: 10, 2: 20, 3: 30, 4: 50, 5: 80},
    this.dayStartHour = 0,
    this.coinPerPoint = 0.1,
    this.customLevelRewards,
  });

  FamilySettings copyWith({
    Map<int, int>? difficultyToXP,
    int? dayStartHour,
    double? coinPerPoint,
    Map<int, List<LevelRewardDefinition>>? customLevelRewards,
  }) =>
      FamilySettings(
        difficultyToXP: difficultyToXP ?? this.difficultyToXP,
        dayStartHour: dayStartHour ?? this.dayStartHour,
        coinPerPoint: coinPerPoint ?? this.coinPerPoint,
        customLevelRewards: customLevelRewards ?? this.customLevelRewards,
      );

  Map<String, dynamic> toMap() => {
        'xpPerDifficulty': mapIntIntToStringInt(difficultyToXP),
        'dayStartHour': dayStartHour,
        'coinPerPoint': coinPerPoint,
        if (customLevelRewards != null)
          'customLevelRewards': customLevelRewards!.map(
            (k, v) => MapEntry('$k', v.map((r) => r.toMap()).toList()),
          ),
      };

  factory FamilySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const FamilySettings();
    final rawCustom = data['customLevelRewards'] as Map<String, dynamic>?;
    return FamilySettings(
      difficultyToXP: mapStringIntToIntInt(data['xpPerDifficulty'] as Map<String, dynamic>?),
      dayStartHour: (data['dayStartHour'] as num?)?.toInt() ?? 0,
      coinPerPoint: (data['coinPerPoint'] as num?)?.toDouble() ?? 0.1,
      customLevelRewards: rawCustom?.map(
        (k, v) => MapEntry(
          int.parse(k),
          (v as List)
              .map((e) => LevelRewardDefinition.fromMap(
                    int.parse(k),
                    e as Map<String, dynamic>,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class FamilyStats {
  final int totalXP;
  final int totalCoins;
  const FamilyStats({this.totalXP = 0, this.totalCoins = 0});

  Map<String, dynamic> toMap() => {
        'totalXP': totalXP,
        'totalCoins': totalCoins,
      };

  factory FamilyStats.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const FamilyStats();
    return FamilyStats(
      totalXP: (data['totalXP'] as num?)?.toInt() ?? 0,
      totalCoins: (data['totalCoins'] as num?)?.toInt() ?? 0,
    );
  }
}

class Family {
  final String id;
  final String name;
  final String ownerUid;
  final String? joinCode;
  final FamilySettings settings;
  final FamilyStats stats;
  final DateTime? createdAt;
  final bool onboardingComplete;
  final String? parentPinHash;
  final SubscriptionTier subscriptionTier;
  final DateTime? subscriptionExpiresAt;
  final DateTime? trialExpiresAt;

  const Family({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.onboardingComplete,
    this.joinCode,
    this.settings = const FamilySettings(),
    this.stats = const FamilyStats(),
    this.createdAt,
    this.parentPinHash,
    this.subscriptionTier = SubscriptionTier.free,
    this.subscriptionExpiresAt,
    this.trialExpiresAt,
  });

  bool get isPremium {
    if (subscriptionTier == SubscriptionTier.lifetime) return true;
    if (subscriptionTier == SubscriptionTier.premium) {
      return subscriptionExpiresAt == null ||
          subscriptionExpiresAt!.isAfter(DateTime.now());
    }
    if (trialExpiresAt != null && trialExpiresAt!.isAfter(DateTime.now())) {
      return true;
    }
    return false;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'ownerUid': ownerUid,
        'onboardingComplete': onboardingComplete,
        'joinCode': joinCode,
        'settings': settings.toMap(),
        'stats': stats.toMap(),
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
        'parentPinHash': parentPinHash,
        'subscriptionTier': subscriptionTier.name,
        'subscriptionExpiresAt': subscriptionExpiresAt == null
            ? null
            : Timestamp.fromDate(subscriptionExpiresAt!),
        'trialExpiresAt':
            trialExpiresAt == null ? null : Timestamp.fromDate(trialExpiresAt!),
      };

  factory Family.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Family(
      id: doc.id,
      name: data['name'] as String? ?? 'Family',
      ownerUid: data['ownerUid'] as String? ?? '',
      onboardingComplete: (data['onboardingComplete'] as bool?) ?? false,
      joinCode: data['joinCode'] as String?,
      settings: FamilySettings.fromMap(data['settings'] as Map<String, dynamic>?),
      stats: FamilyStats.fromMap(data['stats'] as Map<String, dynamic>?),
      createdAt: tsAsDate(data['createdAt']),
      parentPinHash: data['parentPinHash'] as String?,
      subscriptionTier: _tierFromString(data['subscriptionTier'] as String?),
      subscriptionExpiresAt: tsAsDate(data['subscriptionExpiresAt']),
      trialExpiresAt: tsAsDate(data['trialExpiresAt']),
    );
  }

    // --- Local cache mapping (no Firestore Timestamp) ---
  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'name': name,
    'ownerUid': ownerUid,
    'onboardingComplete': onboardingComplete,
    'joinCode': joinCode,
    'settings': settings.toMap(),
    'stats': stats.toMap(),
    'createdAt': createdAt?.toIso8601String(),
    'subscriptionTier': subscriptionTier.name,
    'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
    'trialExpiresAt': trialExpiresAt?.toIso8601String(),
  };

  factory Family.fromCacheMap(Map<String, dynamic> data) {
    return Family(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Family',
      ownerUid: data['ownerUid'] as String? ?? '',
      onboardingComplete: (data['onboardingComplete'] as bool?) ?? false,
      joinCode: data['joinCode'] as String?,
      settings: FamilySettings.fromMap(
        data['settings'] as Map<String, dynamic>?,
      ),
      stats: FamilyStats.fromMap(data['stats'] as Map<String, dynamic>?),
      createdAt: parseIsoDateTimeOrNull(data['createdAt']),
      subscriptionTier: _tierFromString(data['subscriptionTier'] as String?),
      subscriptionExpiresAt: parseIsoDateTimeOrNull(data['subscriptionExpiresAt']),
      trialExpiresAt: parseIsoDateTimeOrNull(data['trialExpiresAt']),
    );
  }

}
