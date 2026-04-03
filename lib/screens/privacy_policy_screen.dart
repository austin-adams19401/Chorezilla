import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chorezilla Privacy Policy',
              style: ts.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Last updated: April 2, 2026',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            _section('1. Introduction',
                'Chorezilla ("the App") is a family chore management app for parents and children ages 4-16. This Privacy Policy explains how we collect, use, and protect your information. We are committed to protecting the privacy of all our users, especially children.'),
            _section('2. Information We Collect',
                'Account information: When you register, we collect your name and email address.\n\n'
                    'Family data: Chore names, reward names, assignments, completion history, and family member nicknames that you create within the App.\n\n'
                    'Photos: If you or your children upload profile photos or photo proof of chore completion, these are stored securely.\n\n'
                    'Device information: Basic device identifiers for crash reporting and analytics.\n\n'
                    'Purchase information: Subscription status is managed through Apple/Google and RevenueCat. We do not directly process payment information.'),
            _section('3. How We Use Information',
                '\u2022 To provide and maintain the App\'s core features\n'
                    '\u2022 To manage your family account and subscriptions\n'
                    '\u2022 To send important service notifications\n'
                    '\u2022 To improve the App through aggregated, anonymized analytics\n'
                    '\u2022 To provide customer support'),
            _section('4. Children\'s Privacy',
                'Chorezilla is designed for use by families, including children ages 4-16. We comply with the Children\'s Online Privacy Protection Act (COPPA) and similar laws.\n\n'
                    '\u2022 Children\'s accounts are created and managed by parents\n'
                    '\u2022 We do not collect personal information directly from children beyond what parents provide\n'
                    '\u2022 Children\'s profiles use nicknames chosen by parents\n'
                    '\u2022 We do not serve advertising to children\n'
                    '\u2022 We do not share children\'s data with third parties for marketing purposes\n'
                    '\u2022 Parents can review, modify, or delete their children\'s data at any time through the App'),
            _section('5. Data Storage and Security',
                'Your data is stored securely using Google Firebase services with encryption in transit and at rest. We use industry-standard security measures to protect your information. However, no method of electronic storage is 100% secure.'),
            _section('6. Data Sharing',
                'We do not sell your personal information. We share data only with:\n\n'
                    '\u2022 Firebase (Google) - for authentication, data storage, and analytics\n'
                    '\u2022 RevenueCat - for subscription management\n'
                    '\u2022 Apple/Google - for in-app purchases\n\n'
                    'These services process data as necessary to provide their services and are bound by their own privacy policies.'),
            _section('7. Your Rights',
                'You have the right to:\n'
                    '\u2022 Access your personal data\n'
                    '\u2022 Correct inaccurate data\n'
                    '\u2022 Delete your account and associated data\n'
                    '\u2022 Export your data\n\n'
                    'To exercise these rights, contact us or use the account deletion feature in the App.'),
            _section('8. Data Retention',
                'We retain your data for as long as your account is active. When you delete your account, we delete your personal data within 30 days. Anonymized analytics data may be retained longer.'),
            _section('9. Changes to This Policy',
                'We may update this Privacy Policy from time to time. We will notify you of material changes through the App. Continued use after changes constitutes acceptance.'),
            _section('10. Contact Us',
                'If you have questions about this Privacy Policy or your data, contact us at:\nchorezilla.app@gmail.com'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static Widget _section(String title, String body) {
    return Builder(
      builder: (context) {
        final ts = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(body, style: ts.bodyMedium),
            ],
          ),
        );
      },
    );
  }
}
