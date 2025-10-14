import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Proof {
  final String? photoUrl;
  final String? note;
  const Proof({this.photoUrl, this.note});

  Map<String, dynamic> toMap() => {
        'photoUrl': photoUrl,
        'note': note,
      };

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
  final String memberId;
  final String memberName;
  final String choreId;
  final String choreTitle;
  final String? choreIcon;
  final int difficulty;
  final int points;
  final AssignmentStatus status;
  final DateTime? assignedAt;
  final DateTime? due;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? approvedAt;
  final Proof? proof;

  const Assignment({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.choreId,
    required this.choreTitle,
    required this.difficulty,
    required this.points,
    this.choreIcon,
    this.status = AssignmentStatus.assigned,
    this.assignedAt,
    this.due,
    this.startedAt,
    this.completedAt,
    this.approvedAt,
    this.proof,
  });

  Map<String, dynamic> toMap() => {
        'memberId': memberId,
        'memberName': memberName,
        'choreId': choreId,
        'choreTitle': choreTitle,
        'difficulty': difficulty,
        'choreIcon' : choreIcon,
        'points': points,
        'status': statusToString(status),
        'assignedAt': assignedAt == null ? null : Timestamp.fromDate(assignedAt!),
        'due': due == null ? null : Timestamp.fromDate(due!),
        'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
        'completedAt': completedAt == null ? null : Timestamp.fromDate(completedAt!),
        'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
        'proof': proof?.toMap(),
      };

  factory Assignment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Assignment(
      id: doc.id,
      memberId: data['memberId'] as String? ?? '',
      memberName: data['memberName'] as String? ?? '',
      choreId: data['choreId'] as String? ?? '',
      choreTitle: data['choreTitle'] as String? ?? '',
      difficulty: (data['difficulty'] as num?)?.toInt() ?? 1,
      points: (data['points'] as num?)?.toInt() ?? 0,
      choreIcon: data['choreIcon'] as String?,
      status: statusFromString(data['status'] as String? ?? 'assigned'),
      assignedAt: tsAsDate(data['assignedAt']),
      due: tsAsDate(data['due']),
      startedAt: tsAsDate(data['startedAt']),
      completedAt: tsAsDate(data['completedAt']),
      approvedAt: tsAsDate(data['approvedAt']),
      proof: data['proof'] == null ? null : Proof.fromMap(data['proof'] as Map<String, dynamic>),
    );
  }
}
