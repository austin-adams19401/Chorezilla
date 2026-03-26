import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String kSupportUrl =
    'https://austin-adams19401.github.io/chorezilla-support';
const String kPrivacyPolicyUrl =
    'https://austin-adams19401.github.io/chorezilla-support/privacy.html';

Future<void> openPrivacyPolicy() =>
    launchUrl(Uri.parse(kPrivacyPolicyUrl), mode: LaunchMode.externalApplication);

Future<void> openTermsOfService() =>
    launchUrl(Uri.parse(kSupportUrl), mode: LaunchMode.externalApplication);

/// "By creating an account you agree to our Terms of Service and Privacy Policy"
/// with tappable links. Used on register/login screens.
class LegalConsentText extends StatelessWidget {
  const LegalConsentText({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        );
    final linkStyle = style?.copyWith(
      color: cs.primary,
      decoration: TextDecoration.underline,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = openTermsOfService,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = openPrivacyPolicy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

/// Compact footer row with Privacy Policy and Terms links.
/// Used on paywall and drawer.
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: openTermsOfService,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Terms of Service', style: style),
        ),
        Text(' · ', style: style),
        TextButton(
          onPressed: openPrivacyPolicy,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Privacy Policy', style: style),
        ),
      ],
    );
  }
}
