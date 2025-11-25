import 'package:flutter/foundation.dart';

enum RewardRedemptionStatus { pending, fulfilled, cancelled }

@immutable
class RewardRedemption {
  final String id;
  final String rewardId;
  final String memberId;
  final int coinsSpent;

  final RewardRedemptionStatus status;
  final DateTime requestedAt;
  final DateTime? fulfilledAt;

  final String? note; 

  const RewardRedemption({
    required this.id,
    required this.rewardId,
    required this.memberId,
    required this.coinsSpent,
    required this.status,
    required this.requestedAt,
    this.fulfilledAt,
    this.note,
  });

  RewardRedemption copyWith({
    String? id,
    String? rewardId,
    String? memberId,
    int? coinsSpent,
    RewardRedemptionStatus? status,
    DateTime? requestedAt,
    DateTime? fulfilledAt,
    String? note,
  }) {
    return RewardRedemption(
      id: id ?? this.id,
      rewardId: rewardId ?? this.rewardId,
      memberId: memberId ?? this.memberId,
      coinsSpent: coinsSpent ?? this.coinsSpent,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      fulfilledAt: fulfilledAt ?? this.fulfilledAt,
      note: note ?? this.note,
    );
  }
}
