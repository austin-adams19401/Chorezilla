import 'package:chorezilla/models/family.dart';
import 'package:flutter_test/flutter_test.dart';

Family _family({
  SubscriptionTier tier = SubscriptionTier.free,
  DateTime? subscriptionExpiresAt,
  DateTime? trialExpiresAt,
  DateTime? billingIssueDetectedAt,
}) {
  return Family(
    id: 'fam',
    name: 'Test',
    ownerUid: 'owner',
    onboardingComplete: true,
    subscriptionTier: tier,
    subscriptionExpiresAt: subscriptionExpiresAt,
    trialExpiresAt: trialExpiresAt,
    billingIssueDetectedAt: billingIssueDetectedAt,
  );
}

void main() {
  test('a future trialExpiresAt does not make a free family premium', () {
    final family = _family(
      trialExpiresAt: DateTime.now().add(const Duration(days: 5)),
    );
    expect(family.isPremium, isFalse);
  });

  test('premium with a future expiry is premium', () {
    final family = _family(
      tier: SubscriptionTier.premium,
      subscriptionExpiresAt: DateTime.now().add(const Duration(days: 10)),
    );
    expect(family.isPremium, isTrue);
  });

  test('an expired premium subscription is not premium', () {
    final family = _family(
      tier: SubscriptionTier.premium,
      subscriptionExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(family.isPremium, isFalse);
  });

  test('lifetime stays premium', () {
    expect(_family(tier: SubscriptionTier.lifetime).isPremium, isTrue);
  });

  test('billing grace keeps premium, then drops it', () {
    final inside = _family(
      tier: SubscriptionTier.premium,
      billingIssueDetectedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    final expired = _family(
      tier: SubscriptionTier.premium,
      billingIssueDetectedAt: DateTime.now().subtract(const Duration(days: 15)),
    );
    expect(inside.isPremium, isTrue);
    expect(expired.isPremium, isFalse);
  });
}
