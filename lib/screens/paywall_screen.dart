import 'package:chorezilla/services/purchase_service.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/themes/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Custom paywall screen. Call [showPaywallScreen] to present it as a
/// full-screen modal.
Future<bool> showPaywallScreen(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PaywallScreen(),
    ),
  );
  return result ?? false;
}

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { monthly, yearly, lifetime }

class _PaywallScreenState extends State<PaywallScreen> {
  _Plan _selected = _Plan.yearly;
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  Package? _monthlyPkg;
  Package? _yearlyPkg;
  Package? _lifetimePkg;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current != null) {
        for (final pkg in current.availablePackages) {
          switch (pkg.packageType) {
            case PackageType.monthly:
              _monthlyPkg = pkg;
            case PackageType.annual:
              _yearlyPkg = pkg;
            case PackageType.lifetime:
              _lifetimePkg = pkg;
            default:
              break;
          }
        }
      }
    } catch (_) {
      // If offerings fail to load we fall back to static prices.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase() async {
    final pkg = switch (_selected) {
      _Plan.monthly => _monthlyPkg,
      _Plan.yearly => _yearlyPkg,
      _Plan.lifetime => _lifetimePkg,
    };

    setState(() => _purchasing = true);

    try {
      late CustomerInfo info;
      if (pkg != null) {
        final result = await Purchases.purchasePackage(pkg);
        info = result;
      } else {
        // Fallback: restore in case products aren't loaded.
        info = await Purchases.restorePurchases();
      }

      final hasPremium =
          info.entitlements.active.containsKey(kPremiumEntitlement);

      if (!hasPremium || !mounted) return;

      final app = context.read<AppState>();
      final familyId = app.familyId;
      if (familyId != null) {
        final sub = subscriptionFromCustomerInfo(info);
        await FirebaseFirestore.instance.doc('families/$familyId').set(
          {
            'subscriptionTier': sub.tier,
            'subscriptionExpiresAt': sub.expiresAt == null
                ? null
                : Timestamp.fromDate(sub.expiresAt!),
          },
          SetOptions(merge: true),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Premium! 🎉'),
            backgroundColor: AppTheme.zillaGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — do nothing.
      } else {
        setState(() => _error = e.toString());
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    try {
      final info = await Purchases.restorePurchases();
      final hasPremium =
          info.entitlements.active.containsKey(kPremiumEntitlement);

      if (!mounted) return;

      if (hasPremium) {
        final app = context.read<AppState>();
        final familyId = app.familyId;
        if (familyId != null) {
          final sub = subscriptionFromCustomerInfo(info);
          await FirebaseFirestore.instance.doc('families/$familyId').set(
            {
              'subscriptionTier': sub.tier,
              'subscriptionExpiresAt': sub.expiresAt == null
                  ? null
                  : Timestamp.fromDate(sub.expiresAt!),
            },
            SetOptions(merge: true),
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase restored!')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No previous purchase found.')),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.deepNavy, const Color(0xFF0D3060)]
                : [const Color(0xFFEAF9F0), cs.surface],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // ── Top bar ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          children: [
                            // ── Header ───────────────────────────────────
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.zillaGreen,
                                    AppTheme.zillaGreen.withAlpha(180),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.zillaGreen.withAlpha(80),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('👑',
                                    style: TextStyle(fontSize: 34)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chorezilla Premium',
                              style: ts.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Unlock everything for your whole crew.',
                              style: ts.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),

                            // ── Monthly / Yearly columns ──────────────────
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _PlanCard(
                                      label: 'Monthly',
                                      price: '\$3.99',
                                      period: '/mo',
                                      badge: 'Flexible',
                                      badgeColor: const Color(0xFF6B7280),
                                      subtext: 'Cancel anytime',
                                      selected: _selected == _Plan.monthly,
                                      onTap: () =>
                                          setState(() => _selected = _Plan.monthly),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _PlanCard(
                                      label: 'Yearly',
                                      price: '\$29.99',
                                      period: '/yr',
                                      subtext: '7-day free trial',
                                      badge: 'Best Value',
                                      savingsLabel: '\$2.50/mo · Save 37%',
                                      selected: _selected == _Plan.yearly,
                                      onTap: () =>
                                          setState(() => _selected = _Plan.yearly),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ── Lifetime ──────────────────────────────────
                            _LifetimeCard(
                              selected: _selected == _Plan.lifetime,
                              onTap: () =>
                                  setState(() => _selected = _Plan.lifetime),
                            ),
                            const SizedBox(height: 28),

                            // ── Feature list ─────────────────────────────
                            const _FeatureSummary(),
                            const SizedBox(height: 28),

                            // ── Error ─────────────────────────────────────
                            if (_error != null) ...[
                              Text(
                                _error!,
                                style: ts.bodySmall
                                    ?.copyWith(color: cs.error),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ── Sticky bottom CTA ─────────────────────────────────
                    _BottomCta(
                      selected: _selected,
                      purchasing: _purchasing,
                      onPurchase: _purchase,
                      onRestore: _restore,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan card (monthly / yearly)
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.price,
    required this.period,
    required this.selected,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.subtext,
    this.savingsLabel,
  });

  final String label;
  final String price;
  final String period;
  final String? badge;
  final Color? badgeColor;
  final String? subtext;
  final String? savingsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.zillaGreen.withAlpha(20)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.zillaGreen : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.zillaGreen.withAlpha(40),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            // ── Selection indicator (top-right) ──────────────────────────
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppTheme.zillaGreen : cs.outlineVariant,
                    width: 2,
                  ),
                  color: selected ? AppTheme.zillaGreen : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ),

            // ── Card content ─────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge row — reserve consistent space whether or not badge exists
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppTheme.zillaGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: ts.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 26),

                Text(
                  label,
                  style: ts.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: ts.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selected ? AppTheme.zillaGreen : cs.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      period,
                      style:
                          ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtext!,
                    style: ts.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                if (savingsLabel != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.zillaGreen.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      savingsLabel!,
                      style: ts.labelSmall?.copyWith(
                        color: AppTheme.zillaGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lifetime card (full-width row)
// ─────────────────────────────────────────────────────────────────────────────

class _LifetimeCard extends StatelessWidget {
  const _LifetimeCard({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.zillaGreen.withAlpha(20)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.zillaGreen : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.zillaGreen.withAlpha(40),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Left: label + one-time copy
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Lifetime',
                        style: ts.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected ? AppTheme.zillaGreen : cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.deepNavy.withAlpha(
                              Theme.of(context).brightness == Brightness.dark
                                  ? 120
                                  : 30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'One-time',
                          style: ts.labelSmall?.copyWith(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.white70
                                : AppTheme.deepNavy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pay once, Premium forever.',
                    style: ts.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // Right: price + selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$54.99',
                  style: ts.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? AppTheme.zillaGreen : cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppTheme.zillaGreen
                          : cs.outlineVariant,
                      width: 2,
                    ),
                    color:
                        selected ? AppTheme.zillaGreen : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature summary (compact icon list)
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureSummary extends StatelessWidget {
  const _FeatureSummary();

  static const _features = [
    ('Unlimited kids', '👨‍👩‍👧‍👦'),
    ('Unlimited custom chores & rewards', '✅'),
    ('Custom level-up rewards', '🎁'),
    ('Allowance tracking', '💵'),
    ('Full assignment history', '📅'),
    ('Adds Zilla skins, frames & titles', '🦎'),
    ('2+ parent accounts', '👪'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: _features
            .map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(f.$2, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Text(
                      f.$1,
                      style: ts.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
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

// ─────────────────────────────────────────────────────────────────────────────
// Sticky bottom CTA bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.selected,
    required this.purchasing,
    required this.onPurchase,
    required this.onRestore,
  });

  final _Plan selected;
  final bool purchasing;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  String get _ctaLabel => switch (selected) {
        _Plan.monthly => 'Start Monthly — \$3.99/mo',
        _Plan.yearly => 'Try Free for 7 Days',
        _Plan.lifetime => 'Get Lifetime — \$54.99',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: purchasing ? null : onPurchase,
              child: purchasing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _ctaLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: purchasing ? null : onRestore,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Restore purchase',
                  style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Text(' · ',
                  style:
                      ts.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(
                selected == _Plan.yearly
                    ? 'Then \$29.99/yr · Cancel anytime'
                    : 'Cancel anytime',
                style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
