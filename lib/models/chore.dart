import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class Recurrence {
  final String type; // once | daily | weekly | custom
  final List<int>? daysOfWeek; // 1..7 Mon..Sun
  final String? timeOfDay; // HH:mm

  const Recurrence({required this.type, this.daysOfWeek, this.timeOfDay});

  Map<String, dynamic> toMap() => {
        'type': type,
        'daysOfWeek': daysOfWeek,
        'timeOfDay': timeOfDay,
      };

  factory Recurrence.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const Recurrence(type: 'once');
    return Recurrence(
      type: data['type'] as String? ?? 'once',
      daysOfWeek: (data['daysOfWeek'] as List?)?.map((e) => (e as num).toInt()).toList(),
      timeOfDay: data['timeOfDay'] as String?,
    );
  }
}

class Chore {
  final String id;
  final String title;
  final String? description;
  final String? icon;           
  final int difficulty;          
  final Recurrence? recurrence;
  final String? createdByMemberId;
  final bool requiresApproval;
  final bool active;
  final DateTime? createdAt;

  const Chore({
    required this.id,
    required this.title,
    this.description,
    this.icon,                    // <-- NEW
    required this.difficulty,
    this.recurrence,
    this.createdByMemberId,
    this.requiresApproval = false,
    this.active = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'icon': icon,             // <-- NEW
        'difficulty': difficulty,
        'recurrence': recurrence?.toMap(),
        'createdByMemberId': createdByMemberId,
        'requiresApproval' : requiresApproval,
        'active': active,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      };

  factory Chore.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Chore(
      id: doc.id,
      title: data['title'] as String? ?? 'Chore',
      description: data['description'] as String?,
      icon: data['icon'] as String?,   // <-- NEW
      difficulty: (data['difficulty'] as num?)?.toInt() ?? 1,
      recurrence: data['recurrence'] == null
          ? null
          : Recurrence.fromMap(data['recurrence'] as Map<String, dynamic>),
      createdByMemberId: data['createdByMemberId'] as String?,
      requiresApproval:  (data['requiresApproval'] as bool?) ?? false,
      active: (data['active'] as bool?) ?? true,
      createdAt: tsAsDate(data['createdAt']),
    );
  }
}
