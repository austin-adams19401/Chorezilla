import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Device {
  final String id;
  final List<String> allowedMemberIds;
  final String? nickname;
  final DateTime? lastSeenAt;

  const Device({
    required this.id,
    this.allowedMemberIds = const [],
    this.nickname,
    this.lastSeenAt,
  });

  Map<String, dynamic> toMap() => {
        'allowedMemberIds': allowedMemberIds,
        'nickname': nickname,
        'lastSeenAt': lastSeenAt == null ? null : Timestamp.fromDate(lastSeenAt!),
      };

  factory Device.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Device(
      id: doc.id,
      allowedMemberIds: (data['allowedMemberIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      nickname: data['nickname'] as String?,
      lastSeenAt: tsAsDate(data['lastSeenAt']),
    );
  }
}
