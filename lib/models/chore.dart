import 'package:cloud_firestore/cloud_firestore.dart';

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
    if (data == null) return const Recurrence(type: 'daily');
    return Recurrence(
      type: data['type'] as String? ?? 'daily',
      daysOfWeek: (data['daysOfWeek'] as List?)?.map((e) => (e as num).toInt()).toList(),
      timeOfDay: data['timeOfDay'] as String?,
    );
  }
}

// chore.dart
class Chore {
  final String id;
  final String title;
  final String? description;
  final String? icon;
  final int difficulty;
  final int points;
  final bool active;
  final Recurrence? recurrence;

  // NEW
  final List<String> defaultAssignees;

  Chore({
    required this.id,
    required this.title,
    this.description,
    this.icon,
    required this.difficulty,
    required this.points,
    required this.active,
    this.recurrence,
    this.defaultAssignees = const [],
  });

  factory Chore.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Chore(
      id: d.id,
      title: m['title'] ?? '',
      description: m['description'],
      icon: m['icon'],
      difficulty: (m['difficulty'] as num?)?.toInt() ?? 1,
      points: (m['points'] as num?)?.toInt() ?? 0,
      active: (m['active'] as bool?) ?? true,
      recurrence: m['recurrence'] == null ? null : Recurrence.fromMap(m['recurrence']),
      defaultAssignees: (m['defaultAssignees'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'icon': icon,
    'difficulty': difficulty,
    'points': points,
    'active': active,
    if (recurrence != null) 'recurrence': recurrence!.toMap(),
    // NEW
    'defaultAssignees': defaultAssignees,
  };
}

