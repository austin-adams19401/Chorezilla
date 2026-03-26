import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around Firebase Analytics for key funnel events.
class AnalyticsService {
  AnalyticsService._();
  static final _analytics = FirebaseAnalytics.instance;

  static Future<void> logAccountCreated() =>
      _analytics.logEvent(name: 'account_created');

  static Future<void> logLogin({String? method}) =>
      _analytics.logLogin(loginMethod: method ?? 'email');

  static Future<void> logFamilySetupComplete() =>
      _analytics.logEvent(name: 'family_setup_complete');

  static Future<void> logChoreAssigned() =>
      _analytics.logEvent(name: 'chore_assigned');

  static Future<void> logChoreCompleted() =>
      _analytics.logEvent(name: 'chore_completed');

  static Future<void> logRewardRedeemed() =>
      _analytics.logEvent(name: 'reward_redeemed');

  static Future<void> logPremiumPurchaseStarted() =>
      _analytics.logEvent(name: 'premium_purchase_started');

  static Future<void> logPremiumPurchaseCompleted() =>
      _analytics.logEvent(name: 'premium_purchase_completed');

  static Future<void> logAccountDeleted() =>
      _analytics.logEvent(name: 'account_deleted');
}
