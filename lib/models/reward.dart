// lib/models/reward.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'common.dart';

/// High-level buckets for rewards.
enum RewardCategory {
  snack, // Snacks & treats
  time, // Screen time / bedtime shifts
  experience, // Outings, family activities
  digital, // In-app cosmetics / perks
  money, // Allowance / cash
  other, // Catch-all / backwards-compat
}

class Reward {
  final String id;

  /// Display name (what kids see in the store).
  final String title;

  /// Optional longer explanation for parents/kids.
  final String? description;

  /// Emoji or short icon string.
  final String? icon;

  /// Coin cost in your coins system.
  final int coinCost;

  /// Category bucket (snack, time, etc.).
  final RewardCategory category;

  /// If true, kid purchases create a request
  /// that a parent has to fulfill.
  final bool requiresApproval;

  /// True if parent created it (vs built-in starter rewards).
  final bool isCustom;

  /// Optional stock; null = unlimited.
  final int? stock;

  /// Whether this is visible to kids in the store.
  final bool active;

  final DateTime? createdAt;

  const Reward({
    required this.id,
    required this.title,
    required this.coinCost,
    required this.category,
    this.description,
    this.icon,
    this.requiresApproval = false,
    this.isCustom = true,
    this.stock,
    this.active = true,
    this.createdAt,
  });

  Reward copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    int? coinCost,
    RewardCategory? category,
    bool? requiresApproval,
    bool? isCustom,
    int? stock,
    bool? active,
    DateTime? createdAt,
  }) {
    return Reward(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      coinCost: coinCost ?? this.coinCost,
      category: category ?? this.category,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      isCustom: isCustom ?? this.isCustom,
      stock: stock ?? this.stock,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    // New field names
    'title': title,
    'description': description,
    'icon': icon,
    'coinCost': coinCost,
    'category': category.name,
    'requiresApproval': requiresApproval,
    'isCustom': isCustom,
    'stock': stock,
    'active': active,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),

    // Backwards-compat fields (for old data)
    'name': title,
    'priceCoins': coinCost,
  };

  factory Reward.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Backwards-compat: support old 'name' / 'priceCoins'
    final title =
        (data['title'] as String?) ?? (data['name'] as String?) ?? 'Reward';

    final coinCost =
        (data['coinCost'] as num?)?.toInt() ??
        (data['priceCoins'] as num?)?.toInt() ??
        0;

    final catStr = (data['category'] as String?) ?? 'other';
    final category = RewardCategory.values.firstWhere(
      (c) => c.name == catStr,
      orElse: () => RewardCategory.other,
    );

    return Reward(
      id: doc.id,
      title: title,
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      coinCost: coinCost,
      category: category,
      requiresApproval: (data['requiresApproval'] as bool?) ?? false,
      isCustom: (data['isCustom'] as bool?) ?? false,
      stock: (data['stock'] as num?)?.toInt(),
      active: (data['active'] as bool?) ?? true,
      createdAt: tsAsDate(data['createdAt']),
    );
  }
}
