import 'package:chorezilla/pages/startup/parent_join_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:chorezilla/state/app_state.dart';

import 'package:chorezilla/pages/family_setup/edit_family_page.dart';
import 'package:chorezilla/pages/family_setup/add_kids_page.dart';
import 'package:chorezilla/pages/parent_dashboard/settings/devices_profiles_page.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select((AppState s) => s.themeMode);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1) THEME TOGGLE at the top
        Card(
          child: SwitchListTile.adaptive(
            value: themeMode == ThemeMode.dark,
            onChanged: (val) =>
                context.read<AppState>().setThemeMode(val ? ThemeMode.dark : ThemeMode.light),
            title: const Text('Dark mode'),
            subtitle: const Text('Toggle app theme'),
          ),
        ),
        const SizedBox(height: 6),

        // 2) Edit family
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Edit family'),
            subtitle: const Text('Rename & get invite code'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditFamilyPage()),
            ),
          ),
        ),
        const SizedBox(height: 3),

        // 3) Manage kids — add a subtle subtitle to keep tile heights consistent
        Card(
          child: ListTile(
            leading: const Icon(Icons.child_care_rounded),
            title: const Text('Manage kids'),
            subtitle: const Text('Add or remove kids'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddKidsPage()),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Card(
          child: ListTile(
            leading: const Icon(Icons.devices_other_rounded),
            title: const Text('Devices & Profiles'),
            subtitle: const Text('Choose which profiles can use each device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DevicesProfilesPage()),
            ),
          ),
        ),
        const SizedBox(height: 3),

        // 4) Join using a code
        Card(
          child: ListTile(
            leading: const Icon(Icons.group_add_rounded),
            title: const Text('Join using a code'),
            subtitle: const Text('If someone invited YOU to their family'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ParentJoinPage()),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 6) Sign out
        Center(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            onPressed: () async => FirebaseAuth.instance.signOut(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}