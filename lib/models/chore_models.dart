import 'package:flutter/material.dart';

enum ChoreFrequency { once, daily, weekly }

class Chore {
  final String id;
  String title;
  int points;
  ChoreFrequency frequency;

  final Set<String> assigneeIds;

  IconData? icon;
  Color? iconColor;

  Chore({
    required this.id,
    required this.title,
    required this.points,
    required this.frequency,
    Set<String>? assigneeIds,
    this.icon,
    this.iconColor,
  }) : assigneeIds = assigneeIds ?? <String>{};
}

/// Simple completion record (MVP)
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

/// Quick-pick templates (you can tweak this list anytime)
class ChoreTemplate {
  final String title;
  final int points;
  final ChoreFrequency frequency;
  final IconData icon;
  const ChoreTemplate({
    required this.title,
    required this.points,
    required this.frequency,
    required this.icon,
  });
}

const kSuggestedChores = <ChoreTemplate>[
  ChoreTemplate(title: 'Make bed',        points: 5,  frequency: ChoreFrequency.daily,  icon: Icons.bed_outlined),
  ChoreTemplate(title: 'Brush teeth',     points: 3,  frequency: ChoreFrequency.daily,  icon: Icons.brush),
  ChoreTemplate(title: 'Feed pet',        points: 5,  frequency: ChoreFrequency.daily,  icon: Icons.pets),
  ChoreTemplate(title: 'Dishes',          points: 7,  frequency: ChoreFrequency.daily,  icon: Icons.local_dining),
  ChoreTemplate(title: 'Take out trash',  points: 6,  frequency: ChoreFrequency.weekly, icon: Icons.delete_outline),
  ChoreTemplate(title: 'Vacuum',          points: 8,  frequency: ChoreFrequency.weekly, icon: Icons.cleaning_services), // if missing, swap to Icons.cleaning_services
  ChoreTemplate(title: 'Clean room',      points: 8,  frequency: ChoreFrequency.weekly, icon: Icons.home),
  ChoreTemplate(title: 'Laundry',         points: 8,  frequency: ChoreFrequency.weekly, icon: Icons.local_laundry_service),
  ChoreTemplate(title: 'Homework',        points: 10, frequency: ChoreFrequency.daily,  icon: Icons.school),
  ChoreTemplate(title: 'Water plants',    points: 4,  frequency: ChoreFrequency.weekly, icon: Icons.grass),
];
