import 'package:chorezilla/models/recurrance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class ChoreMemberSchedule {
  final String id;

  /// For querying by family when needed (mirrors Assignment).
  final String familyId;

  /// Chore this schedule applies to (template).
  final String choreId;

  /// Kid this schedule applies to.
  final String memberId;

  /// Recurrence rule for this (chore, kid) pair.
  final Recurrence recurrence;

  /// For enabling/disabling a schedule without deleting.
  final bool active;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChoreMemberSchedule({
    required this.id,
    required this.familyId,
    required this.choreId,
    required this.memberId,
    required this.recurrence,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  ChoreMemberSchedule copyWith({
    String? familyId,
    String? choreId,
    String? memberId,
    Recurrence? recurrence,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChoreMemberSchedule(
      id: id,
      familyId: familyId ?? this.familyId,
      choreId: choreId ?? this.choreId,
      memberId: memberId ?? this.memberId,
      recurrence: recurrence ?? this.recurrence,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'familyId': familyId,
    'choreId': choreId,
    'memberId': memberId,
    'recurrence': recurrence.toMap(),
    'active': active,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };

  factory ChoreMemberSchedule.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChoreMemberSchedule(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      choreId: data['choreId'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      recurrence: Recurrence.fromMap(
        data['recurrence'] as Map<String, dynamic>?,
      ),
      active: (data['active'] as bool?) ?? true,
      createdAt: tsAsDate(data['createdAt']),
      updatedAt: tsAsDate(data['updatedAt']),
    );
  }

  // --- Local cache mapping (no Firestore Timestamp) ---
  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'familyId': familyId,
    'choreId': choreId,
    'memberId': memberId,
    'recurrence': recurrence.toMap(),
    'active': active,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory ChoreMemberSchedule.fromCacheMap(Map<String, dynamic> data) {
    return ChoreMemberSchedule(
      id: data['id'] as String? ?? '',
      familyId: data['familyId'] as String? ?? '',
      choreId: data['choreId'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      recurrence: Recurrence.fromMap(
        data['recurrence'] as Map<String, dynamic>?,
      ),
      active: (data['active'] as bool?) ?? true,
      createdAt: parseIsoDateTimeOrNull(data['createdAt']),
      updatedAt: parseIsoDateTimeOrNull(data['updatedAt']),
    );
  }
}
