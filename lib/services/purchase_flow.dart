import 'package:chorezilla/screens/paywall_screen.dart';
import 'package:flutter/material.dart';

/// Presents the custom paywall and, on a successful purchase or restore,
/// writes the updated subscription tier to the family's Firestore document.
///
/// Returns true if the user purchased or restored premium.
///
/// Usage:
/// ```dart
/// final upgraded = await showPremiumPaywall(context);
/// ```
Future<bool> showPremiumPaywall(BuildContext context) {
  return showPaywallScreen(context);
}
