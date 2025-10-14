import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class EventLog {
  final String id;
  final String type; // e.g., assignment_approved
  final String? actorMemberId;
  final String? targetMemberId;
  final Map<String, dynamic>? payload;
  final DateTime? createdAt;

  const EventLog({
    required this.id,
    required this.type,
    this.actorMemberId,
    this.targetMemberId,
    this.payload,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'actorMemberId': actorMemberId,
        'targetMemberId': targetMemberId,
        'payload': payload,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      };

  factory EventLog.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EventLog(
      id: doc.id,
      type: data['type'] as String? ?? 'event',
      actorMemberId: data['actorMemberId'] as String?,
      targetMemberId: data['targetMemberId'] as String?,
      payload: data['payload'] as Map<String, dynamic>?,
      createdAt: tsAsDate(data['createdAt']),
    );
  }
}
