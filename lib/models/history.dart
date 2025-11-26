// lib/models/history.dart
import 'package:flutter/foundation.dart';

/// Status of a kid's chores for a single calendar day.
enum DayStatus {
  noChores, // No chores assigned / not counted
  completed, // All assigned chores done
  missed, // One or more required chores not done
  excused, // Parent excused the day (no penalty)
}

@immutable
class AllowanceConfig {
  final bool enabled;

  /// Full weekly amount in cents (to avoid floating point weirdness).
  final int fullAmountCents;

  /// Days required to earn 100% allowance.
  final int daysRequiredForFull;

  /// Pay day: DateTime.monday..DateTime.sunday.
  final int payDay;

  const AllowanceConfig({
    required this.enabled,
    required this.fullAmountCents,
    required this.daysRequiredForFull,
    required this.payDay,
  });

  factory AllowanceConfig.disabled() => const AllowanceConfig(
    enabled: false,
    fullAmountCents: 0,
    daysRequiredForFull: 7,
    payDay: DateTime.sunday,
  );

  AllowanceConfig copyWith({
    bool? enabled,
    int? fullAmountCents,
    int? daysRequiredForFull,
    int? payDay,
  }) {
    return AllowanceConfig(
      enabled: enabled ?? this.enabled,
      fullAmountCents: fullAmountCents ?? this.fullAmountCents,
      daysRequiredForFull: daysRequiredForFull ?? this.daysRequiredForFull,
      payDay: payDay ?? this.payDay,
    );
  }
}

@immutable
class AllowanceResult {
  final int completedDays;
  final int excusedDays;
  final int missedDays;
  final int daysRequiredForFull;
  final int effectiveDays;
  final int fullAmountCents;
  final int payoutCents;
  final double ratio;

  const AllowanceResult({
    required this.completedDays,
    required this.excusedDays,
    required this.missedDays,
    required this.daysRequiredForFull,
    required this.effectiveDays,
    required this.fullAmountCents,
    required this.payoutCents,
    required this.ratio,
  });
}

/// Core math: completed + excused count toward the goal.
/// Missed days reduce the ratio. Payout is capped at 100%.
AllowanceResult computeAllowance({
  required AllowanceConfig config,
  required int completedDays,
  required int excusedDays,
  required int missedDays,
}) {
  final effective = completedDays + excusedDays;
  final cappedEffective = effective.clamp(
    0,
    config.daysRequiredForFull,
  ); // int clamp

  final ratio = config.daysRequiredForFull == 0
      ? 0.0
      : cappedEffective / config.daysRequiredForFull;

  final payout = (config.fullAmountCents * ratio).round();

  return AllowanceResult(
    completedDays: completedDays,
    excusedDays: excusedDays,
    missedDays: missedDays,
    daysRequiredForFull: config.daysRequiredForFull,
    effectiveDays: effective,
    fullAmountCents: config.fullAmountCents,
    payoutCents: payout,
    ratio: ratio,
  );
}

/// Normalize to midnight local.
DateTime normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Get start of week (e.g. Monday) for any date.
DateTime weekStartFor(DateTime date, {int firstWeekday = DateTime.monday}) {
  final normalized = normalizeDate(date);
  var diff = normalized.weekday - firstWeekday;
  if (diff < 0) diff += 7;
  return normalized.subtract(Duration(days: diff));
}
