import 'package:cloud_firestore/cloud_firestore.dart';

class Recurrence {
  /// 'once' | 'daily' | 'weekly' | 'custom'
  ///
  /// - 'daily'  → every day
  /// - 'weekly' → use [daysOfWeek] (1 = Mon ... 7 = Sun)
  /// - 'custom' → use [intervalDays] + [startDate]
  final String type;

  /// 1 = Monday ... 7 = Sunday (same as DateTime.weekday)
  final List<int>? daysOfWeek;

  /// 'HH:mm' – not heavily used yet, but kept for future.
  final String? timeOfDay;

  /// For 'custom' (e.g. every 2 days).
  final int? intervalDays;

  /// When this recurrence starts. Used especially for 'custom'.
  final DateTime? startDate;

  const Recurrence({
    required this.type,
    this.daysOfWeek,
    this.timeOfDay,
    this.intervalDays,
    this.startDate,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'daysOfWeek': daysOfWeek,
    'timeOfDay': timeOfDay,
    'intervalDays': intervalDays,
    'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
  };

  factory Recurrence.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const Recurrence(type: 'daily');

    final rawStart = data['startDate'];
    DateTime? startDate;
    if (rawStart is Timestamp) {
      startDate = rawStart.toDate();
    }

    return Recurrence(
      type: data['type'] as String? ?? 'daily',
      daysOfWeek: (data['daysOfWeek'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      timeOfDay: data['timeOfDay'] as String?,
      intervalDays: (data['intervalDays'] as num?)?.toInt(),
      startDate: startDate,
    );
  }
}
