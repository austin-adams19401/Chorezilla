import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Proof {
  final String? photoUrl;
  final String? note;
  const Proof({this.photoUrl, this.note});

  Map<String, dynamic> toMap() => {'photoUrl': photoUrl, 'note': note};

  factory Proof.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const Proof();
    return Proof(
      photoUrl: data['photoUrl'] as String?,
      note: data['note'] as String?,
    );
  }
}

class Assignment {
  final String id;
  final String familyId;
  final String memberId;
  final String memberName;
  final String choreId;
  final String choreTitle;
  final String? choreIcon;
  final int difficulty;
  final int xp;
  final int coinAward;
  final bool requiresApproval;
  final AssignmentStatus status;
  final DateTime? assignedAt;
  final DateTime? due;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? approvedAt;
  final Proof? proof;
  final bool bonus;

  const Assignment({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.memberName,
    required this.choreId,
    required this.choreTitle,
    required this.difficulty,
    required this.xp,
    required this.coinAward,
    this.requiresApproval = false,
    this.choreIcon,
    this.status = AssignmentStatus.assigned,
    this.assignedAt,
    this.due,
    this.startedAt,
    this.completedAt,
    this.approvedAt,
    this.proof,
    this.bonus = false,
  });

  /// Convenience: does this assignment *currently* need parent review?
  /// (We treat "completed" + requiresApproval as "pending review".)
  bool get pendingReview =>
      requiresApproval && status == AssignmentStatus.completed;

  Map<String, dynamic> toMap() => {
    'familyId': familyId,
    'memberId': memberId,
    'memberName': memberName,
    'choreId': choreId,
    'choreTitle': choreTitle,
    'difficulty': difficulty,
    'choreIcon': choreIcon,
    'xp': xp,
    'coinAward': coinAward,
    'requiresApproval': requiresApproval,
    'status': statusToString(status),
    'assignedAt': assignedAt == null ? null : Timestamp.fromDate(assignedAt!),
    'due': due == null ? null : Timestamp.fromDate(due!),
    'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
    'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
    'proof': proof?.toMap(),
    'bonus': bonus,
  };

  factory Assignment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Assignment(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      memberName: data['memberName'] as String? ?? '',
      choreId: data['choreId'] as String? ?? '',
      choreTitle: data['choreTitle'] as String? ?? '',
      difficulty: (data['difficulty'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      coinAward: (data['coinAward'] as num?)?.toInt() ?? 0,
      choreIcon: data['choreIcon'] as String?,
      requiresApproval: (data['requiresApproval'] as bool?) ?? false,
      status: statusFromString(data['status'] as String? ?? 'assigned'),
      assignedAt: tsAsDate(data['assignedAt']),
      due: tsAsDate(data['due']),
      startedAt: tsAsDate(data['startedAt']),
      completedAt: tsAsDate(data['completedAt']),
      approvedAt: tsAsDate(data['approvedAt']),
      proof: data['proof'] == null
          ? null
          : Proof.fromMap(data['proof'] as Map<String, dynamic>),
      bonus: (data['bonus'] as bool?) ?? false,
    );
  }

    // --- Local cache mapping (no Firestore Timestamp) ---
  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'familyId': familyId,
    'memberId': memberId,
    'memberName': memberName,
    'choreId': choreId,
    'choreTitle': choreTitle,
    'choreIcon': choreIcon,
    'difficulty': difficulty,
    'xp': xp,
    'coinAward': coinAward,
    'requiresApproval': requiresApproval,
    'status': statusToString(status),
    'assignedAt': assignedAt?.toIso8601String(),
    'due': due?.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
    'proof': proof?.toMap(),
    'bonus': bonus,
  };

  factory Assignment.fromCacheMap(Map<String, dynamic> data) {
    return Assignment(
      id: data['id'] as String? ?? '',
      familyId: data['familyId'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      memberName: data['memberName'] as String? ?? '',
      choreId: data['choreId'] as String? ?? '',
      choreTitle: data['choreTitle'] as String? ?? '',
      choreIcon: data['choreIcon'] as String?,
      difficulty: (data['difficulty'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      coinAward: (data['coinAward'] as num?)?.toInt() ?? 0,
      requiresApproval: (data['requiresApproval'] as bool?) ?? false,
      status: statusFromString(data['status'] as String? ?? 'assigned'),
      assignedAt: parseIsoDateTimeOrNull(data['assignedAt']),
      due: parseIsoDateTimeOrNull(data['due']),
      startedAt: parseIsoDateTimeOrNull(data['startedAt']),
      completedAt: parseIsoDateTimeOrNull(data['completedAt']),
      approvedAt: parseIsoDateTimeOrNull(data['approvedAt']),
      proof: data['proof'] == null
          ? null
          : Proof.fromMap(data['proof'] as Map<String, dynamic>),
      bonus: (data['bonus'] as bool?) ?? false,
    );
  }
}
