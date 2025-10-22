import 'package:chorezilla/pages/parent_dashboard/parent_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';

import 'edit_family_page.dart';
import 'add_kids_page.dart';

class ParentSetupPage extends StatefulWidget {
  const ParentSetupPage({super.key});

  @override
  State<ParentSetupPage> createState() => _ParentSetupPageState();
}

class _ParentSetupPageState extends State<ParentSetupPage> {
  final String _displayName = "";
  final String _familyName = "";
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Safe to "read" in initState (no listening).
    final pre = context.read<AppState>().pendingSetupPrefill;
    _nameCtrl.text  = pre?.displayName ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final family = app.family;
    final kids = app.members.where((m) => m.role == FamilyRole.child && m.active).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Family Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (family != null) ...[
              Text('Welcome to ${family.name}!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Let’s finish setting up your family so everyone can start earning points.'),
              const SizedBox(height: 16),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.family_restroom_rounded),
                title: const Text('Edit family details'),
                subtitle: const Text('Rename your family, get invite code'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditFamilyPage()));
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.child_care_rounded),
                title: Text(kids.isEmpty ? 'Add your kids' : 'Manage kids'),
                subtitle: Text(kids.isEmpty
                    ? 'Create a profile for each child'
                    : 'You have ${kids.length} kid${kids.length == 1 ? "" : "s"} added'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddKidsPage()));
                },
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentDashboardPage()));
              },
              child: Text(
                kids.isEmpty 
              ? 'Add a kid to get started'
              : 'Assign chores'),
            ),
          ],
        ),
      ),
    );
  }
}
