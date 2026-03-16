import 'package:chorezilla/components/inputs.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/pages/family_setup/add_kids_page.dart';
import 'package:chorezilla/pages/family_setup/edit_family_page.dart';
import 'package:chorezilla/pages/parent_dashboard/settings/devices_profiles_page.dart';
import 'package:chorezilla/services/purchase_flow.dart';
import 'package:chorezilla/services/purchase_service.dart';
import 'package:chorezilla/themes/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:chorezilla/state/app_state.dart';

class ParentDrawer extends StatelessWidget {
  const ParentDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final user = app.user;
    final family = app.family;

    final displayName = user?.displayName ?? 'Parent';
    final email = user?.email ?? '';
    final familyName = family?.name ?? 'Your family';

    final member = app.currentMember;
    final notificationsEnabled = member?.notificationsEnabled ?? true;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _DrawerHeader(
              displayName: displayName,
              email: email,
              familyName: familyName,
            ),

            // ── Notifications ────────────────────────────────────────────────
            SwitchListTile(
              secondary: Icon(Icons.notifications_outlined, color: cs.primary),
              title: const Text('Chore notifications'),
              subtitle: const Text('Alerts when kids submit chores for approval'),
              value: notificationsEnabled,
              onChanged: (value) async {
                await app.updateMember(member!.id, {
                  'notificationsEnabled': value,
                });
              },
            ),

            const Divider(height: 24),

            // ── Family & kids ───────────────────────────────────────────────
            const _SectionLabel('Family'),
            ListTile(
              leading: Icon(Icons.family_restroom_rounded, color: cs.primary),
              title: const Text('Edit family'),
              subtitle: Text(familyName),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditFamilyPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.group_rounded, color: cs.primary),
              title: const Text('Manage kids'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddKidsPage()),
                );
              },
            ),

            const Divider(height: 24),

            // ── Devices & profiles ──────────────────────────────────────────
            const _SectionLabel('Devices & profiles'),
            ListTile(
              leading: Icon(Icons.devices_other_rounded, color: cs.primary),
              title: const Text('Manage devices'),
              subtitle: const Text('Control who can log in on this device'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DevicesProfilesPage()),
                );
              },
            ),

            const Divider(height: 24),

            // ── Family join code ────────────────────────────────────────────
            const _SectionLabel('Family code'),
            ListTile(
              leading: Icon(Icons.qr_code_rounded, color: cs.primary),
              title: const Text('Share family code'),
              subtitle: const Text('Invite another parent or device'),
              onTap: () async {
                Navigator.of(context).pop();
                final famId = app.familyId;
                if (famId == null) {
                  _showErrorSnack(context, 'No family loaded yet.');
                  return;
                }
                try {
                  final code = await app.ensureJoinCode();
                  if (!context.mounted) return;
                  _showJoinCodeDialog(context, code);
                } catch (e) {
                  if (!context.mounted) return;
                  _showErrorSnack(context, 'Failed to generate code: $e');
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.link_rounded, color: cs.primary),
              title: const Text('Join with code'),
              subtitle: const Text('Join an existing family'),
              onTap: () {
                Navigator.of(context).pop();
                _showRedeemCodeDialog(context);
              },
            ),

            const Divider(height: 24),

            // ── Subscription ────────────────────────────────────────────────
            const _SectionLabel('Subscription'),
            _SubscriptionTile(family: family),

            const Divider(height: 24),

            // ── Sign out ────────────────────────────────────────────────────
            ListTile(
              leading: Icon(Icons.logout_rounded, color: cs.error),
              title: Text('Sign out', style: TextStyle(color: cs.error)),
              onTap: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showJoinCodeDialog(BuildContext context, String code) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Family invite code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied to clipboard')),
                );
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static void _showRedeemCodeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _RedeemCodeDialog(),
    );
  }

  static void _showErrorSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

// ── Subscription tile ─────────────────────────────────────────────────────────

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.family});

  final Family? family;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final isPremium = family?.isPremium ?? false;
    final tier = family?.subscriptionTier ?? SubscriptionTier.free;

    if (!isPremium) {
      // Upgrade prompt
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            Navigator.of(context).pop();
            await showPremiumPaywall(context);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.zillaGreen.withAlpha(30),
                  AppTheme.deepNavy.withAlpha(20),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.zillaGreen.withAlpha(80),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.zillaGreen.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Premium',
                        style: ts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.zillaGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unlimited kids, chores & rewards',
                        style: ts.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.zillaGreen, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    // Already subscribed
    final planLabel = tier == SubscriptionTier.lifetime ? 'Lifetime' : 'Premium';
    final expiresAt = family?.subscriptionExpiresAt;
    String subtitle = 'View, change, or cancel your plan';
    if (tier == SubscriptionTier.lifetime) {
      subtitle = 'Never expires';
    } else if (expiresAt != null) {
      final diff = expiresAt.difference(DateTime.now()).inDays;
      subtitle = diff > 0 ? 'Renews in $diff days' : 'Expires soon';
    }

    return ListTile(
      leading: const Text('👑', style: TextStyle(fontSize: 22)),
      title: Row(
        children: [
          const Text('Manage subscription'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.zillaGreen.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.zillaGreen.withAlpha(80), width: 1),
            ),
            child: Text(
              planLabel,
              style: TextStyle(
                color: AppTheme.zillaGreen,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(subtitle),
      onTap: () async {
        Navigator.of(context).pop();
        await PurchaseService.presentCustomerCenter();
      },
    );
  }
}

// ── Custom drawer header ─────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.displayName,
    required this.email,
    required this.familyName,
  });

  final String displayName;
  final String email;
  final String familyName;

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(color: cs.secondary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: cs.primaryContainer,
            child: Text(
              _initial(displayName),
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: tt.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (email.isNotEmpty)
            Text(
              email,
              style: tt.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.home_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text(
                familyName,
                style: tt.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Redeem code dialog ────────────────────────────────────────────────────────

class _RedeemCodeDialog extends StatefulWidget {
  const _RedeemCodeDialog();

  @override
  State<_RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends State<_RedeemCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return AlertDialog(
      title: const Text('Join family with code'),
      content: TextField(
        controller: _controller,
        decoration: themedInput(context, 'Enter code'),
        textCapitalization: TextCapitalization.characters,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final code = _controller.text.trim();
            if (code.isEmpty) return;
            try {
              final famId = await app.redeemJoinCode(code);
              if (!mounted) return;
              Navigator.of(context).pop();
              if (famId == null && mounted) {
                ParentDrawer._showErrorSnack(context, 'Code not valid.');
              }
            } catch (e) {
              if (!mounted) return;
              Navigator.of(context).pop();
              if (mounted) {
                ParentDrawer._showErrorSnack(context, 'Failed to join: $e');
              }
            }
          },
          child: const Text('Join'),
        ),
      ],
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
