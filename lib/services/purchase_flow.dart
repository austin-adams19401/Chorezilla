import 'package:chorezilla/components/parental_gate.dart';
import 'package:chorezilla/screens/paywall_screen.dart';
import 'package:flutter/material.dart';

/// Presents the custom paywall and, on a successful purchase or restore,
/// writes the updated subscription tier to the family's Firestore document.
///
/// Returns true if the user purchased or restored premium.
///
/// When [requiresParentalGate] is true, a parent PIN dialog is shown first.
/// If the PIN check fails or is cancelled, the paywall is not shown and
/// this returns false.
///
/// Usage:
/// ```dart
/// final upgraded = await showPremiumPaywall(context);
/// ```
Future<bool> showPremiumPaywall(
  BuildContext context, {
  bool requiresParentalGate = false,
}) async {
  if (requiresParentalGate) {
    final allowed = await showParentPinGate(context);
    if (!allowed || !context.mounted) return false;
  }
  return showPaywallScreen(context);
}
