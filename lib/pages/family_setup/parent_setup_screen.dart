import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/pages/family_setup/parent_pin_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';

import 'edit_family_page.dart';
import 'add_kids_page.dart';

class ParentSetupPage extends StatelessWidget {
  const ParentSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final family = app.family;

    final kids = app.members.where((m) => m.role == FamilyRole.child).toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Setup'),
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Welcome banner ───────────────────────────────────────────────
            if (family != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to ${family.name}!',
                      style: ts.titleMedium?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Finish setting up your family so everyone can start earning points.',
                      style: ts.bodySmall?.copyWith(color: cs.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Setup cards ──────────────────────────────────────────────────
            Card(
              child: ListTile(
                leading: Icon(Icons.family_restroom_rounded, color: cs.primary),
                title: const Text('Edit family details'),
                subtitle: const Text('Rename your family, get invite code'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditFamilyPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                leading: Icon(Icons.child_care_rounded, color: cs.primary),
                title: Text(kids.isEmpty ? 'Add your kids' : 'Manage kids'),
                subtitle: Text(
                  kids.isEmpty
                      ? 'Create a profile for each child'
                      : 'You have ${kids.length} kid${kids.length == 1 ? "" : "s"} added',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddKidsPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                leading: Icon(
                  app.hasParentPin
                      ? Icons.lock_rounded
                      : Icons.lock_outline_rounded,
                  color: app.hasParentPin ? cs.primary : cs.onSurfaceVariant,
                ),
                title: const Text('Parent PIN'),
                subtitle: Text(
                  app.hasParentPin
                      ? 'PIN set – tap to change'
                      : 'Create a parent PIN to lock kid mode',
                ),
                trailing: app.hasParentPin
                    ? Icon(Icons.check_circle_rounded, color: cs.primary, size: 20)
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const ParentPinSetupPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Current kids ─────────────────────────────────────────────────
            Text(
              'Current Kids',
              style: ts.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: kids.isEmpty
                  ? Center(
                      child: Text(
                        'No kids yet — add one below.',
                        style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      children: kids.map(
                        (m) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.tertiaryContainer,
                              child: Text(
                                (m.avatarKey == null || m.avatarKey!.trim().isEmpty)
                                    ? _initial(m.displayName)
                                    : m.avatarKey!,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(m.displayName),
                            subtitle: Text(
                              'Level ${m.level} • ${m.xp} XP • ${m.coins} coins',
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
            ),

            const SizedBox(height: 12),

            // ── Bottom action ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: kids.isEmpty
                  ? FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddKidsPage()),
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Add a kid to get started'),
                    )
                  : FilledButton.icon(
                      onPressed: () async {
                        final app = context.read<AppState>();
                        final family = app.family;
                        if (family == null) return;

                        if (!app.hasParentPin) {
                          final ok = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const ParentPinSetupPage(),
                            ),
                          );
                          if (ok != true && !app.hasParentPin) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please create a parent PIN before finishing setup.',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        await app.repo.updateFamily(family.id, {
                          'onboardingComplete': true,
                        });
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Finish setup'),
                    ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String _initial(String name) {
  final n = name.trim();
  return n.isEmpty ? '?' : n.characters.first.toUpperCase();
}
