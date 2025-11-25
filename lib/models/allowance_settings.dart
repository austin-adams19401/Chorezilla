import 'package:flutter/foundation.dart';

@immutable
class AllowanceSettings {
  final bool enabled;
  final int amountCents; 
  final int payoutWeekday; 

  const AllowanceSettings({
    required this.enabled,
    required this.amountCents,
    required this.payoutWeekday,
  });

  AllowanceSettings copyWith({
    bool? enabled,
    int? amountCents,
    int? payoutWeekday,
  }) {
    return AllowanceSettings(
      enabled: enabled ?? this.enabled,
      amountCents: amountCents ?? this.amountCents,
      payoutWeekday: payoutWeekday ?? this.payoutWeekday,
    );
  }
}
