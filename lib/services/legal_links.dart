import 'package:chorezilla/screens/privacy_policy_screen.dart';
import 'package:chorezilla/screens/terms_of_use_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// URLs kept for App Store Connect metadata references.
const String kSupportUrl =
    'https://austin-adams19401.github.io/chorezilla-support';
const String kPrivacyPolicyUrl =
    'https://austin-adams19401.github.io/chorezilla-support/privacy.html';
const String kTermsOfUseUrl =
    'https://austin-adams19401.github.io/chorezilla-support/terms.html';

void openPrivacyPolicy(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
  );
}

void openTermsOfUse(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
  );
}

/// "By continuing, you agree to our Terms of Use and Privacy Policy"
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
            text: 'Terms of Use',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openTermsOfUse(context),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openPrivacyPolicy(context),
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
          onPressed: () => openTermsOfUse(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Terms of Use', style: style),
        ),
        Text(' \u00b7 ', style: style),
        TextButton(
          onPressed: () => openPrivacyPolicy(context),
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
