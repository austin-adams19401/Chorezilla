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
  Widget build(BuildContext context) {
    final isReady = context.select((AppState s) => s.isReady);
    if (!isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;
    final navTarget = context.select((AppState s) => s.pendingNavTarget);

    if (navTarget == 'parent_approve' && _index != 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _index = 1);
      });
    }

    final pages = [
      const ParentTodayTab(),
      ParentChoresTab(
        initialTabIndex: navTarget == 'parent_approve' ? 1 : 0,
      ),
      const ParentRewardsPage(),
      const ParentHistoryTab(),
    ];

    final isToday = _index == 0;
    final Color appBarTextColor = cs.onSecondary;

    return Scaffold(
      extendBodyBehindAppBar: isToday,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: appBarTextColor),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'Chorezilla',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: appBarTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: appBarTextColor),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: appBarTextColor),
            onPressed: () async {
              final app = context.read<AppState>();
              await app.setViewMode(AppViewMode.kid);
            },
            icon: const Icon(Icons.family_restroom_rounded),
            label: const Text(
              'Kid view',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      drawer: const ParentDrawer(),
      body: Column(
        children: [
          const ParentNotificationRegistrar(),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(
            color: Colors.grey, width: 2.0 ))
        ),
        child: NavigationBar(
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
      ),
    );
  }
}
