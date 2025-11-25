import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

enum RewardRedemptionStatus { pending, fulfilled, cancelled }

class RewardRedemption {
  final String id;
  final String memberId;
  final String? rewardId; // optional: may be null for dev/test
  final String rewardName;
  final int coinCost;
  final String status; // 'pending' | 'given'
  final DateTime? createdAt;
  final DateTime? givenAt;
  final String? parentMemberId;

  bool get isPending => status == 'pending';

  const RewardRedemption({
    required this.id,
    required this.memberId,
    this.rewardId,
    required this.rewardName,
    required this.coinCost,
    required this.status,
    this.createdAt,
    this.givenAt,
    this.parentMemberId,
  });

  factory RewardRedemption.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RewardRedemption(
      id: doc.id,
      memberId: data['memberId'] as String? ?? '',
      rewardId: data['rewardId'] as String?,
      rewardName: data['rewardName'] as String? ?? 'Reward',
      coinCost: (data['coinCost'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'pending',
      createdAt: tsAsDate(data['createdAt']),
      givenAt: tsAsDate(data['givenAt']),
      parentMemberId: data['parentMemberId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'rewardId': rewardId,
      'rewardName': rewardName,
      'coinCost': coinCost,
      'status': status,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'givenAt': givenAt == null ? null : Timestamp.fromDate(givenAt!),
      'parentMemberId': parentMemberId,
    };
  }
}
