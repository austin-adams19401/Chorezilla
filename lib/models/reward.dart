import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Reward {
  final String id;
  final String name;
  final int priceCoins;
  final int? stock; // null = unlimited
  final bool active;
  final DateTime? createdAt;

  const Reward({
    required this.id,
    required this.name,
    required this.priceCoins,
    this.stock,
    this.active = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'priceCoins': priceCoins,
        'stock': stock,
        'active': active,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      };

  factory Reward.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Reward(
      id: doc.id,
      name: data['name'] as String? ?? 'Reward',
      priceCoins: (data['priceCoins'] as num?)?.toInt() ?? 0,
      stock: (data['stock'] as num?)?.toInt(),
      active: (data['active'] as bool?) ?? true,
      createdAt: tsAsDate(data['createdAt']),
    );
  }
}
