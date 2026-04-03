import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Use')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chorezilla Terms of Use',
              style: ts.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Last updated: April 2, 2026',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            _section('1. Acceptance of Terms',
                'By downloading, installing, or using Chorezilla ("the App"), you agree to be bound by these Terms of Use. If you do not agree, do not use the App.'),
            _section('2. Description of Service',
                'Chorezilla is a family chore management app designed for parents and children. Parents create accounts, manage families, assign chores, and set up rewards. Children interact with assigned chores and earn rewards within their family group.'),
            _section('3. Account Registration',
                'You must provide accurate information when creating an account. You are responsible for maintaining the security of your account credentials. Parents are responsible for all activity under their family account, including activity by children using the App.'),
            _section('4. Subscriptions and Payments',
                'Chorezilla offers optional auto-renewable subscriptions ("Chorezilla Premium") that unlock additional features.\n\n'
                    'Subscription options:\n'
                    '\u2022 Monthly subscription\n'
                    '\u2022 Yearly subscription (includes a 7-day free trial)\n'
                    '\u2022 Lifetime one-time purchase\n\n'
                    'Payment is charged to your Apple ID or Google Play account at confirmation of purchase. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current billing period. Your account will be charged for renewal within 24 hours prior to the end of the current period at the same price.\n\n'
                    'You can manage and cancel your subscriptions by going to your device\'s account settings after purchase. Any unused portion of a free trial period will be forfeited when you purchase a subscription.'),
            _section('5. Children\'s Privacy',
                'Chorezilla is designed for families with children ages 4-16. We comply with applicable children\'s privacy laws. Please review our Privacy Policy for details on how we handle children\'s data. Parents are responsible for supervising their children\'s use of the App.'),
            _section('6. Acceptable Use',
                'You agree not to:\n'
                    '\u2022 Use the App for any unlawful purpose\n'
                    '\u2022 Attempt to gain unauthorized access to the App or its systems\n'
                    '\u2022 Upload harmful, offensive, or inappropriate content\n'
                    '\u2022 Interfere with other users\' use of the App'),
            _section('7. Content and Data',
                'You retain ownership of content you create in the App (family names, chore names, photos, etc.). You grant Chorezilla a limited license to store and display this content as needed to provide the service. We may delete your data if you close your account.'),
            _section('8. Disclaimer of Warranties',
                'The App is provided "as is" without warranties of any kind, either express or implied. We do not guarantee that the App will be uninterrupted, error-free, or free of harmful components.'),
            _section('9. Limitation of Liability',
                'To the maximum extent permitted by law, Chorezilla and its developers shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App.'),
            _section('10. Changes to Terms',
                'We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the updated Terms. We will notify users of material changes through the App.'),
            _section('11. Termination',
                'We reserve the right to suspend or terminate your access to the App at any time for violation of these Terms or for any other reason at our discretion.'),
            _section('12. Contact',
                'If you have questions about these Terms, contact us at:\nchorezilla.app@gmail.com'),
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
