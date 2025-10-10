import 'package:flutter/material.dart';

/// When is the chore due?
enum ChoreSchedule { daily, weeklyAny, customDays }

class Chore {
  final String id;
  String title;
  int points;
  int difficulty;

  /// Daily, Weekly (any day once per week), or specific weekdays.
  ChoreSchedule schedule;

  /// For customDays: 1=Mon … 7=Sun (DateTime.weekday)
  final Set<int> daysOfWeek;

  /// Member IDs assigned to this chore (multi-assignee)
  final Set<String> assigneeIds;

  /// Visuals
  IconData? icon;
  Color? iconColor;

  Chore({
    required this.id,
    required this.title,
    required this.points,
    required this.difficulty,
    required this.schedule,
    Set<int>? daysOfWeek,
    Set<String>? assigneeIds,
    this.icon,
    this.iconColor,
  })  : daysOfWeek  = {...?daysOfWeek},     // <-- copy to a new Set
        assigneeIds = {...?assigneeIds};    // <-- copy to a new Set
}

/// Completion record
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
  final int difficulty;
  final ChoreSchedule schedule;
  final Set<int> daysOfWeek; // empty unless customDays
  final IconData icon;
  const ChoreTemplate({
    required this.title,
    required this.points,
    required this.difficulty,
    required this.schedule,
    this.daysOfWeek = const {},
    required this.icon,
  });
}

    // case 1: return 5;
    // case 2: return 10;
    // case 3: return 20;
    // case 4: return 35;
    // case 5: return 55;

const kSuggestedChores = <ChoreTemplate>[
  ChoreTemplate(title: 'Make bed',       points: 5, difficulty: 1,schedule: ChoreSchedule.daily,      icon: Icons.bed_outlined),
  ChoreTemplate(title: 'Brush teeth',    points: 5, difficulty: 1,schedule: ChoreSchedule.daily,      icon: Icons.brush),
  ChoreTemplate(title: 'Dishes',         points: 35, difficulty: 4,schedule: ChoreSchedule.daily,      icon: Icons.local_dining),
  ChoreTemplate(title: 'Take out trash', points: 10, difficulty: 2,schedule: ChoreSchedule.customDays, daysOfWeek: {1,4}, icon: Icons.delete_outline), // Mon/Thu
  ChoreTemplate(title: 'Vacuum',         points: 20, difficulty: 3,schedule: ChoreSchedule.customDays, daysOfWeek: {6},   icon: Icons.cleaning_services),
  ChoreTemplate(title: 'Laundry',        points: 20, difficulty: 3,schedule: ChoreSchedule.customDays, daysOfWeek: {3,6}, icon: Icons.local_laundry_service),
  ChoreTemplate(title: 'Homework',       points: 10, difficulty: 2,schedule: ChoreSchedule.daily,     icon: Icons.school),
  ChoreTemplate(title: 'Water plants',   points: 10, difficulty: 2,schedule: ChoreSchedule.customDays, daysOfWeek: {2},   icon: Icons.grass),
];


String scheduleLabel(Chore c) {
  const names = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  switch (c.schedule) {
    case ChoreSchedule.daily:
      return 'Daily';
    case ChoreSchedule.weeklyAny:
      if (c.daysOfWeek.isEmpty) return 'Weekly (any day)';
      final sorted = c.daysOfWeek.toList()..sort();
      if (sorted.length == 1) return 'Weekly (${names[sorted.first - 1]})';
      return 'Weekly (${sorted.map((d) => names[d - 1]).join(', ')})';
    case ChoreSchedule.customDays:
      final sorted = c.daysOfWeek.toList()..sort();
      return sorted.isEmpty ? 'Custom (none)'
                            : sorted.map((d)=>names[d-1]).join(', ');
  }
}
