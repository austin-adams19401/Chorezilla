import 'package:chorezilla/components/inputs.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/pages/family_setup/add_kids_page.dart';
import 'package:chorezilla/pages/family_setup/edit_family_page.dart';
import 'package:chorezilla/pages/parent_dashboard/settings/coin_economy_page.dart';
import 'package:chorezilla/pages/parent_dashboard/settings/devices_profiles_page.dart';
import 'package:chorezilla/pages/parent_dashboard/settings/level_rewards_page.dart';
import 'package:chorezilla/services/purchase_flow.dart';
import 'package:chorezilla/services/purchase_service.dart';
import 'package:chorezilla/themes/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/services/legal_links.dart';
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
            ListTile(
              leading: Icon(Icons.monetization_on_outlined, color: cs.primary),
              title: const Text('Coin economy'),
              subtitle: const Text('XP and coin rewards per difficulty'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CoinEconomyPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.military_tech_rounded, color: cs.primary),
              title: const Text('Level-up rewards'),
              subtitle: const Text('Set what kids earn at each level'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LevelRewardsPage()),
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
                final famId = app.familyId;
                if (famId == null) {
                  Navigator.of(context).pop();
                  _showErrorSnack(context, 'No family loaded yet.');
                  return;
                }
                try {
                  final code = await app.ensureJoinCode();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  _showJoinCodeDialog(context, code);
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
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

            // ── Legal ────────────────────────────────────────────────────────
            const _SectionLabel('Legal'),
            ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.of(context).pop();
                openPrivacyPolicy(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: cs.primary),
              title: const Text('Terms of Use'),
              onTap: () {
                Navigator.of(context).pop();
                openTermsOfUse(context);
              },
            ),

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
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: cs.error),
              title: Text('Delete account',
                  style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.of(context).pop();
                _showDeleteAccountDialog(context);
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

  static void _showDeleteAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _DeleteAccountDialog(),
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
          const Flexible(child: Text('Manage subscription', overflow: TextOverflow.ellipsis)),
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

// ── Delete account dialog ────────────────────────────────────────────────────

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _busy = false;
  String? _error;
  final _passwordController = TextEditingController();
  bool _needsPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final app = context.read<AppState>();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final familyId = app.familyId;
      bool isLastParent = false;

      if (familyId != null) {
        final parentCount = await app.repo.countParents(familyId);
        isLastParent = parentCount <= 1;
      }

      // Show a second confirmation if they're the last parent
      if (isLastParent && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete family data?'),
            content: const Text(
              'You are the only parent in this family. '
              'Deleting your account will also permanently delete all '
              'family data including kids, chores, rewards, and history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Delete everything',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error)),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          if (mounted) setState(() => _busy = false);
          return;
        }
      }

      await app.repo.deleteAccount(
        uid: user.uid,
        familyId: familyId,
        isLastParent: isLastParent,
      );

      // Account deleted successfully - auth listener will handle nav
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        setState(() {
          _needsPassword = true;
          _busy = false;
        });
      } else {
        setState(() {
          _error = e.message ?? 'Failed to delete account.';
          _busy = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _reauthAndDelete() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Now retry deletion
      final app = context.read<AppState>();
      final familyId = app.familyId;
      bool isLastParent = false;
      if (familyId != null) {
        final parentCount = await app.repo.countParents(familyId);
        isLastParent = parentCount <= 1;
      }

      await app.repo.deleteAccount(
        uid: user.uid,
        familyId: familyId,
        isLastParent: isLastParent,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Re-authentication failed.';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_needsPassword) {
      return AlertDialog(
        title: const Text('Confirm your password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For security, please re-enter your password to delete your account.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              autofocus: true,
              onSubmitted: (_) => _reauthAndDelete(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _busy ? null : _reauthAndDelete,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Delete',
                    style: TextStyle(color: cs.error)),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Delete account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This will permanently delete your account and all associated data. '
            'This action cannot be undone.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _deleteAccount,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Delete account',
                  style: TextStyle(color: cs.error)),
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
