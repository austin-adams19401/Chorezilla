import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/models/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';

enum HomeGroupBy { kid, chore }

class ParentHomeTab extends StatefulWidget {
  const ParentHomeTab({super.key});

  @override
  State<ParentHomeTab> createState() => _ParentHomeTabState();
}

class _ParentHomeTabState extends State<ParentHomeTab> {
  static const _prefsKey = 'homeGroupBy';
  HomeGroupBy _groupBy = HomeGroupBy.kid;

  Stream<List<Assignment>>? _todayStream;
  String? _boundFamilyId;
  bool _loadedPref = false;

  @override
  void initState() {
    super.initState();
    _loadGroupingPref(); 
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    if (!app.isReady) return;

    if (!_loadedPref) {
      _loadGroupingPref();
    }
    if (_boundFamilyId != app.familyId) {
      _boundFamilyId = app.familyId;
      _todayStream = app.repo.watchAssignmentsDueToday(_boundFamilyId!);
      setState(() { });
    }
  }

  Future<void> _loadGroupingPref() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_prefsKey);
    setState(() {
      _groupBy = s == 'chore' ? HomeGroupBy.chore : HomeGroupBy.kid;
      _loadedPref = true;
    });
  }

  Future<void> _saveGroupingPref(HomeGroupBy g) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, g == HomeGroupBy.chore ? 'chore' : 'kid');
  }

  @override
  Widget build(BuildContext context) {
    final appReady = context.select((AppState s) => s.isReady);
    if (!appReady || _todayStream == null || !_loadedPref) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Assignment>>(
      stream: _todayStream,
      builder: (context, snap) {
        final items = snap.data ?? const <Assignment>[];

        if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return _EmptyToday(onToggle: _toggleGroup);
        }

        final groups = _groupBy == HomeGroupBy.kid
            ? _groupByKey(items, (a) => (a.memberName.isNotEmpty ? a.memberName : 'Kid'), key: (a) => a.memberId)
            : _groupByKey(items, (a) => a.choreTitle, key: (a) => a.choreId);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('Due today', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  SegmentedButton<HomeGroupBy>(
                    segments: const [
                      ButtonSegment(value: HomeGroupBy.kid, label: Text('By Kid')),
                      ButtonSegment(value: HomeGroupBy.chore, label: Text('By Chore')),
                    ],
                    selected: {_groupBy},
                    onSelectionChanged: (s) async {
                      final g = s.first;
                      setState(() => _groupBy = g);
                      await _saveGroupingPref(g);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: groups.length,
                itemBuilder: (_, i) {
                  final g = groups[i];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side:BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                      ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),                              
                          ),
                          const SizedBox(height: 6),                          
                          ...g.items.map((a) {
                            final done = a.status.isDone; // uses the extension above
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Text(
                                (a.choreIcon?.isNotEmpty ?? false) ? a.choreIcon! : '🧩',
                                style: const TextStyle(fontSize: 30),
                              ),
                              title: Text(
                                a.choreTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                                  // optional: dim completed items a bit
                                  color: done ? Theme.of(context).hintColor : null,
                                ),
                              ),
                              subtitle: Text(a.status.label), // ← no cast; display-friendly text
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleGroup() {
    final next = _groupBy == HomeGroupBy.kid ? HomeGroupBy.chore : HomeGroupBy.kid;
    setState(() => _groupBy = next);
    _saveGroupingPref(next);
  }

  List<_Group> _groupByKey(
    List<Assignment> src,
    String Function(Assignment) titleOf, {
    required String Function(Assignment) key,
  }) {
    final map = <String, _Group>{};
    for (final a in src) {
      final k = key(a);
      map.putIfAbsent(k, () => _Group(title: titleOf(a), items: []));
      map[k]!.items.add(a);
    }
    final out = map.values.toList();
    out.sort((a, b) => a.title.compareTo(b.title));
    for (final g in out) {
      g.items.sort((a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)));
    }
    return out;
  }
}

class _Group {
  _Group({required this.title, required this.items});
  final String title;
  final List<Assignment> items;
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.onToggle});
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            const Text('Nothing due today'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onToggle,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Switch grouping'),
              style: TextButton.styleFrom(foregroundColor: cs.primary),
            ),
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
