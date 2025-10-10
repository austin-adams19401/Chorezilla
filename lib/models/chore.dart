import 'package:flutter/material.dart';

enum ChoreSchedule { daily, weeklyAny, customDays }

class Chore {
  Chore({
    required this.id,
    required this.title,
    required this.schedule,  // e.g. ['Mon','Thu']
    this.icon,
    this.requiresPhoto = false,
  });

  final String id;
  final String title;
  final List<String> schedule;
  final String? icon;
  final bool requiresPhoto;

  factory Chore.fromMap(Map<String, dynamic> m, String id) => Chore(
    id: id,
    title: m['title'] as String,
    schedule: List<String>.from(m['schedule'] ?? const []),
    icon: m['icon'] as String?,
    requiresPhoto: (m['requiresPhoto'] as bool?) ?? false,
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'schedule': schedule,
    'icon': icon,
    'requiresPhoto': requiresPhoto,
  };
}

class ChoreCompletion {
  final String id;
  final String choreId;
  final String memberId;
  final DateTime completedAt;

  ChoreCompletion({
    required this.id,
    required this.choreId,
    required this.memberId,
    required this.completedAt,
  });
}

class ChoreTemplate {
  final String title;
  final int points;
  final ChoreSchedule schedule;
  final Set<int> daysOfWeek; // empty unless customDays
  final IconData icon;
  const ChoreTemplate({
    required this.title,
    required this.points,
    required this.schedule,
    this.daysOfWeek = const {},
    required this.icon,
  });
}

const kSuggestedChores = <ChoreTemplate>[
  ChoreTemplate(title: 'Make bed',       points: 5, schedule: ChoreSchedule.daily,      icon: Icons.bed_outlined),
  ChoreTemplate(title: 'Brush teeth',    points: 3, schedule: ChoreSchedule.daily,      icon: Icons.brush),
  ChoreTemplate(title: 'Dishes',         points: 7, schedule: ChoreSchedule.daily,      icon: Icons.local_dining),
  ChoreTemplate(title: 'Take out trash', points: 6, schedule: ChoreSchedule.customDays, daysOfWeek: {1,4}, icon: Icons.delete_outline), // Mon/Thu
  ChoreTemplate(title: 'Vacuum',         points: 8, schedule: ChoreSchedule.customDays, daysOfWeek: {6},   icon: Icons.cleaning_services),
  ChoreTemplate(title: 'Laundry',        points: 8, schedule: ChoreSchedule.customDays, daysOfWeek: {3,6}, icon: Icons.local_laundry_service),
  ChoreTemplate(title: 'Homework',       points: 10, schedule: ChoreSchedule.daily,     icon: Icons.school),
  ChoreTemplate(title: 'Water plants',   points: 4, schedule: ChoreSchedule.customDays, daysOfWeek: {2},   icon: Icons.grass),
];


// String scheduleLabel(Chore c) {
//   const names = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
//   switch (c.schedule) {
//     case ChoreSchedule.daily:
//       return 'Daily';
//     case ChoreSchedule.weeklyAny:
//       if (c.daysOfWeek.isEmpty) return 'Weekly (any day)';
//       final sorted = c.daysOfWeek.toList()..sort();
//       if (sorted.length == 1) return 'Weekly (${names[sorted.first - 1]})';
//       return 'Weekly (${sorted.map((d) => names[d - 1]).join(', ')})';
//     case ChoreSchedule.customDays:
//       final sorted = c.daysOfWeek.toList()..sort();
//       return sorted.isEmpty ? 'Custom (none)'
//                             : sorted.map((d)=>names[d-1]).join(', ');
//   }
// }