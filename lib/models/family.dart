import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class FamilySettings {
  final Map<int, int> pointsPerDifficulty; // 1..5 -> points
  final int dayStartHour; // 0-23
  final double coinPerPoint; // e.g., 0.2 means 5 points -> 1 coin

  const FamilySettings({
    this.pointsPerDifficulty = const {1: 10, 2: 20, 3: 35, 4: 55, 5: 80},
    this.dayStartHour = 4,
    this.coinPerPoint = 0.2,
  });

  Map<String, dynamic> toMap() => {
        'pointsPerDifficulty': mapIntIntToStringInt(pointsPerDifficulty),
        'dayStartHour': dayStartHour,
        'coinPerPoint': coinPerPoint,
      };

  factory FamilySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const FamilySettings();
    return FamilySettings(
      pointsPerDifficulty: mapStringIntToIntInt(data['pointsPerDifficulty'] as Map<String, dynamic>?),
      dayStartHour: (data['dayStartHour'] as num?)?.toInt() ?? 4,
      coinPerPoint: (data['coinPerPoint'] as num?)?.toDouble() ?? 0.2,
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

  const Family({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.joinCode,
    this.settings = const FamilySettings(),
    this.stats = const FamilyStats(),
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'ownerUid': ownerUid,
        'joinCode': joinCode,
        'settings': settings.toMap(),
        'stats': stats.toMap(),
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      };

  factory Family.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Family(
      id: doc.id,
      name: data['name'] as String? ?? 'Family',
      ownerUid: data['ownerUid'] as String? ?? '',
      joinCode: data['joinCode'] as String?,
      settings: FamilySettings.fromMap(data['settings'] as Map<String, dynamic>?),
      stats: FamilyStats.fromMap(data['stats'] as Map<String, dynamic>?),
      createdAt: tsAsDate(data['createdAt']),
    );
  }
}
