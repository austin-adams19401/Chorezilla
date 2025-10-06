import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../state/app_state.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<String?> _getFamilyId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return (snap.data()?['familyId'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getFamilyId(),
      builder: (context, familySnap) {
        if (familySnap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final familyId = familySnap.data;
        if (familyId == null) {
          return _NoFamilyView(onGoToSetup: () {
            Navigator.of(context).pushNamed('/family-setup');
          });
        }

        final familyDoc = FirebaseFirestore.instance.collection('families').doc(familyId).snapshots();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: familyDoc,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!.data() ?? {};
            final code = (data['code'] ?? '—') as String;
            final familyName = (data['name'] ?? 'Your Family') as String;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Text(familyName, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Settings & tools for your family', style: Theme.of(context).textTheme.bodyMedium),

                const SizedBox(height: 24),

                // Join Code card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Family Join Code', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                code,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 28, letterSpacing: 3, fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy',
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: code));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Code copied to clipboard')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // QR (optional, small but scannable)
                        Center(
                          child: QrImageView(
                            data: code,
                            version: QrVersions.auto,
                            size: 160,
                            backgroundColor: Colors.white, // contrast in dark mode
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kids can tap “Kid Login” and enter or scan this code to join.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Theme toggle
                _ThemeToggleTile(),

                // Manage family
                ListTile(
                  leading: const Icon(Icons.group),
                  title: const Text('Manage Family'),
                  subtitle: const Text('Edit family name and members'),
                  onTap: () async {
                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    final db = FirebaseFirestore.instance;
                    final userDoc = await db.collection('users').doc(uid).get();
                    final familyId = userDoc.data()?['familyId'] as String?;

                    if (familyId == null) {
                      if (context.mounted) {
                        Navigator.of(context).pushNamed('/add-kids'); // create new
                      }
                      return;
                    }

                    final ok = await context.read<AppState>().loadFamilyFromFirestore(familyId);

                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.of(context).pushNamed(
                        '/family-setup',
                        arguments: {'edit': true, 'familyId': familyId},
                      );
                    } else {
                      // Fallback: open create page if load failed
                      Navigator.of(context).pushNamed('/add-kids');
                    }
                  },

                  trailing: const Icon(Icons.chevron_right),
                ),

                // (Optional) Kid Login deep link
                ListTile(
                  leading: const Icon(Icons.vpn_key),
                  title: const Text('Kid Login'),
                  subtitle: const Text('Show the kid join screen on this device'),
                  onTap: () {
                    Navigator.of(context).pushNamed('/kid-join');
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () {
                    Navigator.of(context).pushNamed('/login');
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NoFamilyView extends StatelessWidget {
  final VoidCallback onGoToSetup;
  const _NoFamilyView({required this.onGoToSetup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.family_restroom, size: 64),
          const SizedBox(height: 12),
          const Text('No family linked yet'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onGoToSetup,
            child: const Text('Create or Select Family'),
          )
        ],
      ),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListTile(
      leading: const Icon(Icons.dark_mode),
      title: const Text('Appearance'),
      subtitle: Text(
        switch (app.themeMode) {
          ThemeMode.light => 'Light',
          ThemeMode.dark  => 'Dark',
          _               => 'System',
        },
      ),
      trailing: PopupMenuButton<ThemeMode>(
        onSelected: (m) => context.read<AppState>().setThemeMode(m),
        itemBuilder: (ctx) => const [
          PopupMenuItem(value: ThemeMode.system, child: Text('System')),
          PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
          PopupMenuItem(value: ThemeMode.dark,  child: Text('Dark')),
        ],
        child: const Icon(Icons.tune),
      ),
    );
  }
}
