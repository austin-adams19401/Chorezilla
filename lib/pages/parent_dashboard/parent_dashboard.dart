
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';

import 'parent_home_tab.dart';
import 'assign_tab.dart';
import 'review_tab.dart';
import 'settings/settings_tab.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isReady = context.select((AppState s) => s.isReady);
    if (!isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = const [
      ParentHomeTab(),
      AssignTab(),
      ReviewTab(),
      SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Chorezilla')),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.playlist_add_check_rounded), label: 'Assign'),
          NavigationDestination(icon: Icon(Icons.fact_check_rounded), label: 'Review'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'parent_home_tab.dart';
// import 'assign_tab.dart';
// import 'checkoff_tab.dart';
// import 'settings_tab.dart';

// class ParentDashboardPage extends StatefulWidget {
//   const ParentDashboardPage({super.key});

//   @override
//   State<ParentDashboardPage> createState() => _ParentDashboardPageState();
// }

// class _ParentDashboardPageState extends State<ParentDashboardPage> {
//   int _index = 0;

//   @override
//   Widget build(BuildContext context) {
//     final pages = const [
//       ParentHomeTab(),   // <- your home tab class
//       AssignTab(),
//       CheckOffTab(),
//       SettingsTab(),
//     ];

//     // final app = context.watch<AppState>();
//     // final choresToCheckOff = app.chores.where((c) => c.assigneeIds.isNotEmpty).length;

//     // String _numberOfChoresReadyForCheckOff(int n) => n > 99 ? '99+' : '$n';

//     return Scaffold(
//       body: pages[_index],
//       bottomNavigationBar: NavigationBar(
//         selectedIndex: _index,
//         onDestinationSelected: (i) => setState(() => _index = i),
//         destinations: [
//           const NavigationDestination(
//             icon: Icon(Icons.home_outlined),
//             selectedIcon: Icon(Icons.home),
//             label: 'Home',
//           ),
//           const NavigationDestination(
//             icon: Icon(Icons.assignment_outlined),
//             selectedIcon: Icon(Icons.assignment),
//             label: 'Assign',
//           ),
//           NavigationDestination(
//             icon: Badge(
//               isLabelVisible: true,
//               label: Text('2'),
//               child: const Icon(Icons.check_circle_outlined)
//             ),
//             selectedIcon: const Icon(Icons.check_circle),
//             label: 'Check Off',
//           ),
//           const NavigationDestination(
//             icon: Icon(Icons.settings_outlined),
//             selectedIcon: Icon(Icons.settings),
//             label: 'Settings',
//           ),
//         ],
//       ),
//     );
//   }
// }
