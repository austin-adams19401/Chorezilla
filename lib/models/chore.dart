import 'package:chorezilla/models/recurrance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

// chore.dart

enum ChoreCategory { cleaning, laundry, dishes, trash, petCare, other }

String choreCategoryToString(ChoreCategory c) => c.name;

ChoreCategory choreCategoryFromString(String? s) => ChoreCategory.values
    .firstWhere((e) => e.name == s, orElse: () => ChoreCategory.other);

class Chore {
  final String id;
  final String title;
  final String? description;
  final String? icon;
  final int difficulty;
  final int points;
  final bool active;
  final Recurrence? recurrence;
  final List<String> defaultAssignees;
  final bool requiresApproval;
  final bool bonusOnly;
  final bool isCustom;
  final ChoreCategory category;
  final DateTime? createdAt;

  const Chore({
    required this.id,
    required this.title,
    this.description,
    this.icon,
    required this.difficulty,
    required this.points,
    required this.active,
    this.recurrence,
    this.defaultAssignees = const [],
    this.requiresApproval = false,
    this.bonusOnly = false,
    this.isCustom = true,
    this.category = ChoreCategory.other,
    this.createdAt,
  });

  factory Chore.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return Chore(
      id: d.id,
      title: m['title'] as String? ?? '',
      description: m['description'] as String?,
      icon: m['icon'] as String?,
      difficulty: (m['difficulty'] as num?)?.toInt() ?? 1,
      points: (m['points'] as num?)?.toInt() ?? 0,
      active: (m['active'] as bool?) ?? true,
      recurrence: m['recurrence'] == null
          ? null
          : Recurrence.fromMap(m['recurrence'] as Map<String, dynamic>?),
      defaultAssignees:
          (m['defaultAssignees'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      requiresApproval: (m['requiresApproval'] as bool?) ?? false,
      bonusOnly: (m['bonusOnly'] as bool?) ?? false,
      isCustom: (m['isCustom'] as bool?) ?? true,
      category: choreCategoryFromString(m['category'] as String?),
      createdAt: tsAsDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'icon': icon,
    'difficulty': difficulty,
    'points': points,
    'active': active,
    if (recurrence != null) 'recurrence': recurrence!.toMap(),
    'defaultAssignees': defaultAssignees,
    'requiresApproval': requiresApproval,
    'bonusOnly': bonusOnly,
    'isCustom': isCustom,
    'category': choreCategoryToString(category),
  };

    // --- Local cache mapping ---
  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'difficulty': difficulty,
    'points': points,
    'active': active,
    'recurrence': recurrence?.toMap(),
    'defaultAssignees': defaultAssignees,
    'requiresApproval': requiresApproval,
    'bonusOnly': bonusOnly,
    'category': choreCategoryToString(category),
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Chore.fromCacheMap(Map<String, dynamic> m) {
    return Chore(
      id: m['id'] as String? ?? '',
      title: m['title'] as String? ?? '',
      description: m['description'] as String?,
      icon: m['icon'] as String?,
      difficulty: (m['difficulty'] as num?)?.toInt() ?? 1,
      points: (m['points'] as num?)?.toInt() ?? 0,
      active: (m['active'] as bool?) ?? true,
      recurrence: m['recurrence'] == null
          ? null
          : Recurrence.fromMap(m['recurrence'] as Map<String, dynamic>?),
      defaultAssignees:
          (m['defaultAssignees'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      requiresApproval: (m['requiresApproval'] as bool?) ?? false,
      bonusOnly: (m['bonusOnly'] as bool?) ?? false,
      category: choreCategoryFromString(m['category'] as String?),
      createdAt: parseIsoDateTimeOrNull(m['createdAt']),
    );
  }

}
