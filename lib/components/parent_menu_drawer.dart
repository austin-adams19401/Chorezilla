import 'package:chorezilla/pages/family_setup/add_kids_page.dart';
import 'package:chorezilla/pages/family_setup/edit_family_page.dart';
import 'package:chorezilla/pages/parent_dashboard/settings/devices_profiles_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';

class ParentDrawer extends StatelessWidget {
  const ParentDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
            // ── Header: account + family info ────────────────────────────────
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: cs.primaryContainer),
              currentAccountPicture: CircleAvatar(
                backgroundColor: cs.primary,
                child: Text(
                  _initial(displayName),
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              accountName: Text(
                displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              accountEmail: Text(
                email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                ),
              ),
              otherAccountsPictures: [
                if (familyName.isNotEmpty)
                  CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    child: Icon(
                      Icons.home_rounded,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
              ],
            ),

            // ── Appearance / theme (switch) ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Notifications',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Chore notifications'),
              subtitle: const Text(
                'Alerts when kids submit chores for approval',
              ),
              value: notificationsEnabled,
              onChanged: (value) async {
                await app.updateMember(member!.id, {
                  'notificationsEnabled': value,
                });
              },
            ),

            const Divider(height: 24),

            // ── Family & kids ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Family',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom_rounded),
              title: const Text('Edit family'),
              subtitle: Text(familyName),
              onTap: () {
                Navigator.of(context).pop(); // close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditFamilyPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_rounded),
              title: const Text('Manage kids'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AddKidsPage()));
              },
            ),

            const Divider(height: 24),

            // ── Devices & profiles ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Devices & profiles',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.devices_other_rounded),
              title: const Text('Devices & profiles'),
              subtitle: const Text('Manage who can log in on this device'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DevicesProfilesPage(),
                  ),
                );
              },
            ),

            const Divider(height: 24),

            // ── Family join code ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Family code',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_rounded),
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
              leading: const Icon(Icons.link_rounded),
              title: const Text('Join with code'),
              subtitle: const Text('Join an existing family'),
              onTap: () {
                Navigator.of(context).pop();
                _showRedeemCodeDialog(context);
              },
            ),
            const Divider(height: 24),

            // ── Sign out ───────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
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

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  static void _showJoinCodeDialog(BuildContext context, String code) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Family invite code'),
          content: SelectableText(
            code,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          actions: [
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
    final controller = TextEditingController();
    final app = context.read<AppState>();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Join family with code'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Enter code'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final code = controller.text.trim();
                if (code.isEmpty) return;

                try {
                  final famId = await app.redeemJoinCode(code);
                  if (!ctx.mounted) return;
                  if (famId == null) {
                    _showErrorSnack(context, 'Code not valid.');
                  } else {
                    // _showTodoSnack(
                    //   context,
                    //   'Joined family $famId (wire up routing if needed)',
                    // );
                  }
                } catch (e) {
                  if (!ctx.mounted) return;
                  _showErrorSnack(context, 'Failed to join: $e');
                } finally {
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
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