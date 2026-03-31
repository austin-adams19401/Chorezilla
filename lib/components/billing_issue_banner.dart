import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/services/purchase_service.dart';
import 'package:flutter/material.dart';

/// A persistent warning banner shown on the parent dashboard when a billing
/// issue is detected during the 2-week grace period.
class BillingIssueBanner extends StatelessWidget {
  const BillingIssueBanner({super.key, required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    if (!family.hasBillingIssue) return const SizedBox.shrink();

    final daysLeft = Family.gracePeriodDuration.inDays -
        DateTime.now().difference(family.billingIssueDetectedAt!).inDays;

    return Material(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Payment issue detected',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Update your payment method to keep premium features. '
                    '${daysLeft > 0 ? '$daysLeft day${daysLeft == 1 ? '' : 's'} remaining.' : 'Grace period ending soon.'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => PurchaseService.presentCustomerCenter(),
              child: const Text('Fix'),
            ),
          ],
        ),
      ),
    );
  }
}
