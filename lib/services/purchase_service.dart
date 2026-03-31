import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

// TODO: Replace with your platform-specific production API keys before release.
// Settings → API Keys → Public App-Specific Keys in the RevenueCat dashboard.
const _kAppleApiKey = 'test_WKCbVvsMVCagogCbOhdLAGtVhQP';
const _kGoogleApiKey = 'test_WKCbVvsMVCagogCbOhdLAGtVhQP';

/// RevenueCat entitlement that unlocks all premium features.
const kPremiumEntitlement = 'Chorezilla Unlimited';

class PurchaseService {
  const PurchaseService._();

  /// Call once in main() after Firebase.initializeApp().
  /// Optionally pass a [userId] (e.g., Firebase UID) to link purchases to the
  /// user's account in RevenueCat.
  static Future<void> init({String? userId}) async {
    final apiKey = Platform.isIOS ? _kAppleApiKey : _kGoogleApiKey;
    final config = PurchasesConfiguration(apiKey);
    if (userId != null) config.appUserID = userId;
    await Purchases.configure(config);
  }

  /// Log in to RevenueCat with a Firebase UID so purchases are linked cross-device.
  static Future<void> logIn(String firebaseUid) async {
    await Purchases.logIn(firebaseUid);
  }

  /// Log out (call on sign-out).
  static Future<void> logOut() async {
    await Purchases.logOut();
  }

  /// Restore purchases (reinstall / device switch). Returns whether premium is active.
  static Future<({CustomerInfo info, bool hasPremium})> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    final hasPremium = info.entitlements.active.containsKey(kPremiumEntitlement);
    return (info: info, hasPremium: hasPremium);
  }

  /// Check current cached subscription status.
  static Future<bool> hasPremiumEntitlement() async {
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(kPremiumEntitlement);
  }

  /// Show the RevenueCat Customer Center (subscription management UI).
  static Future<void> presentCustomerCenter() async {
    await RevenueCatUI.presentCustomerCenter();
  }
}

/// Extracts subscription tier and expiry from a [CustomerInfo] object.
/// Used to write back to Firestore after a successful purchase.
({String tier, DateTime? expiresAt}) subscriptionFromCustomerInfo(
  CustomerInfo info,
) {
  final entitlement = info.entitlements.active[kPremiumEntitlement];
  if (entitlement == null) return (tier: 'free', expiresAt: null);

  final productId = entitlement.productIdentifier.toLowerCase();
  final isLifetime = productId.contains('lifetime');

  final expiresAt = entitlement.expirationDate != null
      ? DateTime.tryParse(entitlement.expirationDate!)
      : null;

  return (
    tier: isLifetime ? 'lifetime' : 'premium',
    expiresAt: isLifetime ? null : expiresAt,
  );
}

/// Result of syncing subscription status with RevenueCat.
class SubscriptionSyncResult {
  final String tier;
  final DateTime? expiresAt;
  final DateTime? billingIssueDetectedAt;
  final bool changed;

  const SubscriptionSyncResult({
    required this.tier,
    this.expiresAt,
    this.billingIssueDetectedAt,
    required this.changed,
  });
}

/// Checks RevenueCat for the current subscription status and determines
/// what (if anything) needs to be updated in Firestore.
///
/// [currentTier], [currentExpiresAt], and [currentBillingIssue] are the
/// values currently stored in Firestore.
Future<SubscriptionSyncResult> syncSubscriptionWithRevenueCat({
  required String currentTier,
  required DateTime? currentExpiresAt,
  required DateTime? currentBillingIssue,
}) async {
  final info = await Purchases.getCustomerInfo();
  final sub = subscriptionFromCustomerInfo(info);

  // Check for billing issues on the premium entitlement.
  final entitlement = info.entitlements.all[kPremiumEntitlement];
  final hasBillingIssue = entitlement?.billingIssueDetectedAt != null;

  DateTime? newBillingIssue = currentBillingIssue;

  if (hasBillingIssue && currentBillingIssue == null) {
    // First time detecting a billing issue -- start the grace clock.
    newBillingIssue = DateTime.now();
  } else if (!hasBillingIssue && currentBillingIssue != null) {
    // Billing issue resolved -- clear the grace clock.
    newBillingIssue = null;
  }

  // If the grace period has expired, force downgrade to free.
  String newTier = sub.tier;
  DateTime? newExpiresAt = sub.expiresAt;
  if (newBillingIssue != null &&
      DateTime.now().difference(newBillingIssue) >= const Duration(days: 14)) {
    newTier = 'free';
    newExpiresAt = null;
  }

  final changed = newTier != currentTier ||
      newExpiresAt != currentExpiresAt ||
      newBillingIssue != currentBillingIssue;

  return SubscriptionSyncResult(
    tier: newTier,
    expiresAt: newExpiresAt,
    billingIssueDetectedAt: newBillingIssue,
    changed: changed,
  );
}
