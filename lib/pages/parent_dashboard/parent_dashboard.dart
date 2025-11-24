
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/pages/kid_pages/kids_home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';

import 'parent_home_tab.dart';
import 'assign_tab.dart';
import 'approve_tab.dart';
import 'settings/settings_tab.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle changes (resumed, paused, etc.)
    WidgetsBinding.instance.addObserver(this);

    // After the first frame, once we know AppState is ready,
    // ensure today's assignments exist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.ensureAssignmentsForToday();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When the app returns to foreground (e.g., phone wakes up),
      // make sure today's assignments exist.
      final app = context.read<AppState>();
      app.ensureAssignmentsForToday();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = context.select((AppState s) => s.isReady);
    if (!isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = const [
      ParentHomeTab(),
      AssignTab(),
      ApproveTab(),
      SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chorezilla'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final app = context.read<AppState>();

              // 1) Persist kid mode
              await app.setViewMode(AppViewMode.kid);
            },
            icon: const Icon(Icons.family_restroom_rounded),
            label: const Text('Kid view'),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.playlist_add_check_rounded), label: 'Assign'),
          NavigationDestination(icon: Icon(Icons.fact_check_rounded), label: 'Approve'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
