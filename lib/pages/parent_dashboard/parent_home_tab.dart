import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/member.dart';

class ParentHomeTab extends StatelessWidget {
  const ParentHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final kids = app.members.where((m) => m.role == FamilyRole.child && m.active).toList();
    final reviewCount = app.reviewQueue.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _QuickStatsRow(
          kids: kids.length,
          chores: app.chores.length,
          pending: reviewCount,
        ),
        const SizedBox(height: 16),

        Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_rounded),
            title: const Text('Review completed chores'),
            subtitle: Text(reviewCount == 0 ? 'Nothing to review' : '$reviewCount waiting'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DefaultTabController.of(context).animateTo(2),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: const Icon(Icons.playlist_add_check_rounded),
            title: const Text('Assign chores'),
            subtitle: const Text('Pick kids, choose chores, set due date'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DefaultTabController.of(context).animateTo(1),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: const Icon(Icons.person_add_alt_1_rounded),
            title: const Text('Invite another parent'),
            subtitle: const Text('Share a one-time join code'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DefaultTabController.of(context).animateTo(3),
          ),
        ),
      ],
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.kids, required this.chores, required this.pending});
  final int kids;
  final int chores;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _StatCard(label: 'Kids', value: kids.toString(), color: cs.tertiaryContainer, onColor: cs.onTertiaryContainer),
        const SizedBox(width: 12),
        _StatCard(label: 'Chores', value: chores.toString(), color: cs.secondaryContainer, onColor: cs.onSecondaryContainer),
        const SizedBox(width: 12),
        _StatCard(label: 'Pending', value: pending.toString(), color: cs.primaryContainer, onColor: cs.onPrimaryContainer),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, required this.onColor});
  final String label;
  final String value;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts.labelMedium?.copyWith(color: onColor)),
            const SizedBox(height: 4),
            Text(value, style: ts.titleLarge?.copyWith(color: onColor, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}


// import 'package:chorezilla/z_archive/app_state_old.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// /// Shows an overview for today/week. Read-only check indicators.
// class ParentHomeTab extends StatefulWidget {
//   const ParentHomeTab({super.key});

//   @override
//   State<ParentHomeTab> createState() => _HomeTabState();
// }

// class _HomeTabState extends State<ParentHomeTab> {
//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final cs = Theme.of(context).colorScheme;
//     //final chores = app.chores.choreListForToday; // example if you split state

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Chore overview'),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//         elevation: 0,
//       ),
//       body: Container(
//         color: Colors.grey.shade100,
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             _Header(title: "Today's Chores"),
//             const SizedBox(height: 12),
//             _StatsRow(), // replace with your own small summary widget
      
//             const SizedBox(height: 12),
      
//             // TODO: Replace with your grid/list of chores/day cells.
//             // NOTE: Home tab is view-only; completion happens in the Check Off tab.
//             Expanded(
//               child: ListView(
//                 children: const [
//                   _ReadOnlyChoreRow(
//                     title: 'Example chore',
//                     isScheduled: true,
//                     isCompleted: false,
//                   ),
//                   _ReadOnlyChoreRow(
//                     title: 'Example chore 2',
//                     isScheduled: true,
//                     isCompleted: true,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Private helper widgets stay in the same file and start with underscore.
// class _Header extends StatelessWidget {
//   const _Header({required this.title});
//   final String title;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.green.shade50,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
//     );
//   }
// }

// class _StatsRow extends StatelessWidget {
//   const _StatsRow();

//   @override
//   Widget build(BuildContext context) {
//     // TODO: replace with your own stat chips (e.g., total, done, remaining)
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.indigo.shade50,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: const Row(
//         children: [
//           Expanded(child: Text('Stats here')),
//         ],
//       ),
//     );
//   }
// }

// class _ReadOnlyChoreRow extends StatelessWidget {
//   const _ReadOnlyChoreRow({
//     required this.title,
//     required this.isScheduled,
//     required this.isCompleted,
//   });

//   final String title;
//   final bool isScheduled;
//   final bool isCompleted;

//   @override
//   Widget build(BuildContext context) {
//     final icon = isScheduled
//         ? (isCompleted ? Icons.check_circle : Icons.radio_button_unchecked)
//         : Icons.remove_circle_outline;

//     final color = isCompleted
//         ? Colors.green
//         : (isScheduled ? Colors.grey : Colors.redAccent);

//     return ListTile(
//       title: Text(title),
//       // NOTE: This is read-only. No onTap / onChanged handlers here.
//       trailing: Icon(icon, size: 20, color: color),
//     );
//   }
// }
