import 'package:chorezilla/data/chorezilla_repo.dart';
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

    final kids =
        app.members
            .where((m) => m.role == FamilyRole.child)
            .toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );

    debugPrint('PARENT SETUP: kids: ${kids.toString()}');

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Family Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (family != null) ...[
              Text('Welcome to ${family.name}!', style: ts.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Let’s finish setting up your family so everyone can start earning points.',
                style: ts.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // Edit family card
            Card(
              child: ListTile(
                leading: const Icon(Icons.family_restroom_rounded),
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
            const SizedBox(height: 12),

            // Add / manage kids card
            Card(
              child: ListTile(
                leading: const Icon(Icons.child_care_rounded),
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
            const SizedBox(height: 24),

            // ---------- Current Kids section (copied layout from AddKidsPage) ----------
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Current Kids', style: ts.titleMedium),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: kids.isEmpty
                  ? Text(
                      'No kids yet — add one above.',
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    )
                  : ListView(
                      children: [
                        ...kids.map(
                          (m) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.tertiaryContainer,
                                child: Text(
                                  (m.avatarKey == null ||
                                          m.avatarKey!.trim().isEmpty)
                                      ? _initial(m.displayName)
                                      : m.avatarKey!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(m.displayName),
                              subtitle: Text(
                                'Level ${m.level} • ${m.xp} XP • ${m.coins} coins',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // ---------- Bottom button: add first kid OR finish setup ----------
            SizedBox(
              width: double.infinity,
              child: kids.isEmpty
                  ? FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddKidsPage(),
                          ),
                        );
                      },
                      child: const Text('Add a kid to get started'),
                    )
                  : FilledButton.icon(
                      onPressed: () async {
                        final app = context.read<AppState>();
                        final familyId = app.family?.id;
                        if (familyId == null) return;

                        await app.repo.updateFamily(familyId, {'onboardingComplete': true});
                      },
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

// Small helper to match AddKidsPage behavior
String _initial(String name) {
  final n = name.trim();
  return n.isEmpty ? '?' : n.characters.first.toUpperCase();
}
