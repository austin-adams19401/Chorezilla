import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/services/purchase_flow.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The reason a premium gate was hit — drives the headline copy.
enum UpgradeReason {
  customChores,
  customRewards,
  addKid,
  history,
  cosmetics,
  allowance,
  parentAccount,
  levelRewards,
  editDefaultChores,
  editDefaultRewards,
}

extension _UpgradeReasonCopy on UpgradeReason {
  String get headline {
    switch (this) {
      case UpgradeReason.customChores:
        return 'Unlock unlimited custom chores';
      case UpgradeReason.customRewards:
        return 'Unlock unlimited custom rewards';
      case UpgradeReason.addKid:
        return 'Add more kids to your family';
      case UpgradeReason.history:
        return 'See your full chore history';
      case UpgradeReason.cosmetics:
        return 'Unlock all Zilla skins & more';
      case UpgradeReason.allowance:
        return 'Track allowances for every kid';
      case UpgradeReason.parentAccount:
        return 'Add a co-parent to your family';
      case UpgradeReason.levelRewards:
        return 'Customize your level-up rewards';
      case UpgradeReason.editDefaultChores:
        return 'Customize built-in chores';
      case UpgradeReason.editDefaultRewards:
        return 'Customize built-in rewards';
    }
  }

  String get subtext {
    switch (this) {
      case UpgradeReason.customChores:
        return 'Free families can create up to 3 custom chores. Go Premium for unlimited.';
      case UpgradeReason.customRewards:
        return 'Free families can create up to 3 custom rewards. Go Premium for unlimited.';
      case UpgradeReason.addKid:
        return 'Free families can add up to 2 kids. Go Premium to add your whole crew.';
      case UpgradeReason.history:
        return 'Free families see the last 2 weeks. Go Premium to view your full history.';
      case UpgradeReason.cosmetics:
        return 'Free families can customize backgrounds. Go Premium to unlock all skins, frames, titles, and more Zilla animations.';
      case UpgradeReason.allowance:
        return 'Allowance tracking is a Premium feature. Set payday, work day requirements, and auto-calculate earnings.';
      case UpgradeReason.parentAccount:
        return 'Free families support one parent account. Go Premium to invite a co-parent.';
      case UpgradeReason.levelRewards:
        return 'Free families use built-in rewards. Go Premium to set your own rewards for every level.';
      case UpgradeReason.editDefaultChores:
        return 'Editing built-in chores is a Premium feature. Go Premium to personalize them, or create up to 3 of your own.';
      case UpgradeReason.editDefaultRewards:
        return 'Editing built-in rewards is a Premium feature. Go Premium to personalize them, or create up to 3 of your own.';
    }
  }
}

/// Shows a context-aware premium upsell sheet, then launches the RevenueCat
/// Paywall if the user taps "See Plans" / "Renew".
///
/// Automatically detects whether the family previously had premium and shows
/// renewal-focused copy instead of discovery copy when appropriate.
Future<void> showPremiumUpgradeSheet(
  BuildContext context, {
  required UpgradeReason reason,
}) async {
  final family = context.read<AppState>().family;
  final isRenewal = family?.wasFormerlyPremium ?? false;

  final shouldShowPaywall = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PremiumUpgradeSheet(
      reason: reason,
      isRenewal: isRenewal,
    ),
  );

  if (shouldShowPaywall == true && context.mounted) {
    final isKidMode = context.read<AppState>().viewMode == AppViewMode.kid;
    await showPremiumPaywall(context, requiresParentalGate: isKidMode);
  }
}

class _PremiumUpgradeSheet extends StatelessWidget {
  const _PremiumUpgradeSheet({
    required this.reason,
    this.isRenewal = false,
  });
  final UpgradeReason reason;
  final bool isRenewal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final headline = isRenewal
        ? 'Your subscription has expired'
        : reason.headline;
    final subtext = isRenewal
        ? 'Renew to restore your custom chores, rewards, and all premium features.'
        : reason.subtext;
    final ctaLabel = isRenewal ? 'Renew Premium' : 'See Plans';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Crown icon ───────────────────────────────────────────────
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.zillaGreen.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👑', style: TextStyle(fontSize: 28)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Headline ─────────────────────────────────────────────────
            Center(
              child: Text(
                headline,
                style: ts.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                subtext,
                style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // ── Feature list ─────────────────────────────────────────────
            _FeatureList(),
            const SizedBox(height: 24),

            // ── CTA ──────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  ctaLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Cancel anytime. No commitment.',
                style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  static const _features = [
    ('Unlimited kids', '👨‍👩‍👧‍👦'),
    ('Unlimited custom chores & rewards', '✅'),
    ('Custom level-up rewards', '🎁'),
    ('Full assignment history', '📅'),
    ('Allowance tracking', '💵'),
    ('All Zilla skins, frames & titles', '🦎'),
    ('Level-up animations unlocked', '🎉'),
    ('2 parent accounts', '👪'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _features
            .map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(f.$2, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Text(
                      f.$1,
                      style: ts.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
