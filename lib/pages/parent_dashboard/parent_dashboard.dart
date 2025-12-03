import 'package:chorezilla/components/chores_nav_icon.dart';
import 'package:chorezilla/components/parent_menu_drawer.dart';
import 'package:chorezilla/components/rewards_nav_icon.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/pages/parent_dashboard/manage_chores_tab.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_history_tab.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_notifications.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';

import 'parent_today_tab.dart';


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

    final navTarget = context.select((AppState s) => s.pendingNavTarget);

    // If a notification asked us to go to the Approve tab, switch bottom nav to "Chores".
    if (navTarget == 'parent_approve' && _index != 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _index = 1);
      });
    }
    // ── Bottom-nav pages ───────────────────────────────────────────────────
    // 0: Today
    // 1: Chores (Assign + Review tabs)
    // 2: Rewards
    // 3: History
    final pages = [
      const ParentTodayTab(),
      ParentChoresTab(initialTabIndex: navTarget == 'parent_approve' ? 1 : 0),
      const ParentRewardsPage(),
      const ParentHistoryTab(), 
    ];

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Chorezilla'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final app = context.read<AppState>();
              // Persist kid mode; AuthGate should react and route to kid flow
              await app.setViewMode(AppViewMode.kid);
            },
            icon: const Icon(Icons.family_restroom_rounded),
            label: const Text('Kid view'),
          ),
        ],
      ),
      drawer: const ParentDrawer(),
      body: Column(
        children: [
          const ParentNotificationRegistrar(), // 🔔 registers tokens for this device
          Expanded(child: pages[_index]),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: ChoresNavIcon(selected: false),
            selectedIcon: ChoresNavIcon(selected: true),
            label: 'Chores',
          ),
          NavigationDestination(
            icon: RewardsNavIcon(selected: false),
            selectedIcon: RewardsNavIcon(selected: true),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'History',
          ),
        ],
      ),

    );
  }
}
