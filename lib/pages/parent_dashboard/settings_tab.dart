import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final famName = app.family?.name ?? '(unnamed family)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('Manage Family'),
            subtitle: Text(famName),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Chorezilla'),
            subtitle: const Text('v1.0.0'),
          ),
        ],
      ),
    );
  }
}