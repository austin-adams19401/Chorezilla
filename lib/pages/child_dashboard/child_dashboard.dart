import 'package:chorezilla/components/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/models/common.dart';

class ChildDashboardPage extends StatefulWidget {
  const ChildDashboardPage({super.key, this.memberId});

  /// If omitted, we’ll fall back to AppState.currentMember.
  final String? memberId;

  @override
  State<ChildDashboardPage> createState() => _ChildDashboardPageState();
}

class _ChildDashboardPageState extends State<ChildDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _busyIds = {}; // assignmentIds being completed
  String? _watchingMemberId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStreamsForCurrentKid());
  }

  @override
  void didUpdateWidget(covariant ChildDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the page was rebuilt with a different memberId, restart streams
    if (oldWidget.memberId != widget.memberId) {
      _restartStreams();
    }
  }

  @override
  void dispose() {
    final app = context.read<AppState>();
    if (_watchingMemberId != null) app.stopKidStreams(_watchingMemberId!);
    super.dispose();
  }

  void _restartStreams() {
    final app = context.read<AppState>();
    if (_watchingMemberId != null) {
      app.stopKidStreams(_watchingMemberId!);
      _watchingMemberId = null;
    }
    _startStreamsForCurrentKid();
  }

  void _startStreamsForCurrentKid() {
    final app = context.read<AppState>();
    final member = _resolveMember(app);
    if (member == null) return;
    _watchingMemberId = member.id;
    app.startKidStreams(member.id);
  }

  Member? _resolveMember(AppState app) {
    if (!app.isReady) return null;
    if (widget.memberId != null) {
      return app.members.where((m) => m.id == widget.memberId).cast<Member?>().firstOrNull;
    }
    return app.currentMember ?? app.members.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();

    if (!app.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final member = _resolveMember(app);
    if (member == null) {
      return const Scaffold(
        body: Center(child: Text('No kid selected')),
      );
    }
    if (member.role != FamilyRole.child) {
      return const Scaffold(
        body: Center(child: Text('This dashboard is for child accounts.')),
      );
    }

    final todos = [...app.assignedForKid(member.id)]..sort(_byDueThenTitle);
    final submitted = [...app.completedForKid(member.id)]..sort(_byCompletedAtDescThenTitle);

    return Scaffold(
      appBar: AppBar(title: const Text('Chorezilla')),
      body: Column(
        children: [
          // Profile header (kid)
          ProfileHeader(member: member, showInviteButton: false, showSwitchButton: false),
          const SizedBox(height: 8),

          // Tabs: To Do / Submitted
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'To Do'),
                      Tab(text: 'Submitted'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _TodoList(
                          memberId: member.id,
                          items: todos,
                          busyIds: _busyIds,
                          onComplete: _completeAssignment,
                        ),
                        _SubmittedList(items: submitted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _completeAssignment(Assignment a) async {
    final app = context.read<AppState>();
    setState(() => _busyIds.add(a.id));
    try {
      final note = await _promptNote(context);
      if (!mounted) return;
      // await app.completeAssignment(a.id, note: note);
      // Streams will update lists automatically
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked complete!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(a.id));
    }
  }

  // ---- Helpers --------------------------------------------------------------

  int _byDueThenTitle(Assignment a, Assignment b) {
    final ad = a.due;
    final bd = b.due;
    if (ad == null && bd == null) {
      return a.choreTitle.compareTo(b.choreTitle);
    } else if (ad == null) {
      return 1;
    } else if (bd == null) {
      return -1;
    } else {
      final cmp = ad.compareTo(bd);
      return cmp != 0 ? cmp : a.choreTitle.compareTo(b.choreTitle);
    }
  }

  int _byCompletedAtDescThenTitle(Assignment a, Assignment b) {
    final ad = a.completedAt;
    final bd = b.completedAt;
    if (ad == null && bd == null) {
      return a.choreTitle.compareTo(b.choreTitle);
    } else if (ad == null) {
      return 1;
    } else if (bd == null) {
      return -1;
    } else {
      final cmp = bd.compareTo(ad); // newest first
      return cmp != 0 ? cmp : a.choreTitle.compareTo(b.choreTitle);
    }
  }

  Future<String?> _promptNote(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a note?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional — anything you want to tell your parent',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Skip')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
    return result?.isEmpty == true ? null : result;
  }

  @override
  bool get wantKeepAlive => true;
}

// ============================================================================
// Widgets
// ============================================================================

class _TodoList extends StatelessWidget {
  const _TodoList({
    required this.memberId,
    required this.items,
    required this.busyIds,
    required this.onComplete,
  });

  final String memberId;
  final List<Assignment> items;
  final Set<String> busyIds;
  final Future<void> Function(Assignment) onComplete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        emoji: '🎉',
        title: 'All caught up!',
        subtitle: 'No chores to do right now.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = items[i];
        return _AssignmentTile(
          assignment: a,
          trailing: FilledButton(
            onPressed: busyIds.contains(a.id) ? null : () => onComplete(a),
            child: busyIds.contains(a.id)
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Mark done'),
          ),
        );
      },
    );
  }
}

class _SubmittedList extends StatelessWidget {
  const _SubmittedList({required this.items});
  final List<Assignment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        emoji: '⌛',
        title: 'Nothing submitted yet',
        subtitle: 'Completed chores will show up here until a parent reviews them.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = items[i];
        return _AssignmentTile(
          assignment: a,
          trailing: const _StatusPill(text: 'Pending review'),
        );
      },
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.trailing,
  });

  final Assignment assignment;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final icon = assignment.choreIcon?.trim();
    final due = assignment.due;
    final dueText = _formatDue(due);
    final overdue = due != null && due.isBefore(DateTime.now());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(icon == null || icon.isEmpty ? '🧩' : icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assignment.choreTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.monetization_on_rounded, size: 16, color: cs.secondary),
                      const SizedBox(width: 4),
                      Text('${assignment.xp} pts', style: ts.bodySmall),
                      if (dueText != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.schedule_rounded, size: 16, color: overdue ? cs.error : cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          dueText,
                          style: ts.bodySmall?.copyWith(color: overdue ? cs.error : cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }

  String? _formatDue(DateTime? due) {
    if (due == null) return null;
    final now = DateTime.now();
    final dDate = DateTime(due.year, due.month, due.day);
    final nDate = DateTime(now.year, now.month, now.day);
    final diff = dDate.difference(nDate).inDays;

    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff == -1) return 'Due yesterday';
    if (diff > 1 && diff <= 7) return 'Due in $diff days';
    if (diff < -1 && diff >= -7) return '${diff.abs()} days overdue';
    // Fallback date
    return '${due.month}/${due.day}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
    );
  }
}

// Simple empty-state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.emoji, required this.title, required this.subtitle});
  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text(title, style: ts.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// handy extension
extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}


// import 'package:chorezilla/state/app_state.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';


// class ChildDashboardPage extends StatelessWidget {
//   const ChildDashboardPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final cs = Theme.of(context).colorScheme;
//     final kid = app.currentProfile;
//     if (kid == null) {
//       return const Center(child: CircularProgressIndicator());
//     }


//     final chores = app.choresForMember(kid.id);
//     final points = app.pointsForMemberAllTime(kid.id);

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Hi, ${kid.name}!'),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//         elevation: 0,
//         leading: IconButton(
//           icon: Icon(Icons.switch_account),
//           onPressed: () async {
//             try { await FirebaseAuth.instance.signOut(); } catch (_) {}
//             if (!context.mounted) return;
//             Navigator.of(context).pushReplacementNamed('/kid-join');
//           },
//         ),
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(12),
//         children: [
//           Card(
//             elevation: 0,
//             color: cs.primaryContainer,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: ListTile(
//               leading: const Icon(Icons.stars),
//               title: const Text('Points'),
//               subtitle: Text('$points total'),
//             ),
//           ),
//           const SizedBox(height: 12),
//           if (chores.isEmpty)
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Text('No chores yet. Check back later!', style: TextStyle(color: cs.onSurfaceVariant)),
//             ),
//           for (final c in chores)
//             ListTile(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               tileColor: cs.surfaceContainerHighest,
//               title: Text(c.title),
//               subtitle: Text('${c.points} pts • ${scheduleLabel(c)}'),
//               trailing: IconButton(
//                 icon: const Icon(Icons.check_circle),
//                 color: cs.primary,
//                 onPressed: () {
//                   app.completeChore(c.id, kid.id);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Great job! +${c.points}')),
//                   );
//                 },
//               ),
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//               visualDensity: VisualDensity.compact,
//             ),
//         ],
//       ),
//     );
//   }
// }
