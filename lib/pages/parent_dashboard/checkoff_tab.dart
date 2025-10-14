import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';

class CheckoffTab extends StatefulWidget {
  const CheckoffTab({super.key});

  @override
  State<CheckoffTab> createState() => _CheckoffTabState();
}

class _CheckoffTabState extends State<CheckoffTab> {
  final Set<String> _busyApprove = {};
  final Set<String> _busyReject = {};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.reviewQueue;

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No completed chores waiting for review.'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = items[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.choreIcon?.isNotEmpty == true ? a.choreIcon! : '🧩', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.choreTitle, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('From: ${a.memberName} • ${a.points} pts'),
                      if (a.proof?.note?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text('Note: ${a.proof!.note!}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    FilledButton.icon(
                      icon: _busyApprove.contains(a.id)
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.thumb_up_alt_rounded),
                      label: const Text('Approve'),
                      onPressed: _busyApprove.contains(a.id) ? null : () => _approve(a),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: _busyReject.contains(a.id)
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.thumb_down_alt_rounded),
                      label: const Text('Reject'),
                      onPressed: _busyReject.contains(a.id) ? null : () => _reject(a),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approve(Assignment a) async {
    final app = context.read<AppState>();
    setState(() => _busyApprove.add(a.id));
    try {
      final parentMemberId = app.parents.isNotEmpty ? app.parents.first.id : null;
      await app.approveAssignment(a.id, parentMemberId: parentMemberId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved ✨')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyApprove.remove(a.id));
    }
  }

  Future<void> _reject(Assignment a) async {
    final app = context.read<AppState>();
    setState(() => _busyReject.add(a.id));
    try {
      final reason = await _promptReason();
      if (!mounted) return;
      await app.rejectAssignment(a.id, reason: reason ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyReject.remove(a.id));
    }
  }

  Future<String?> _promptReason() async {
    final c = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reason (optional)'),
        content: TextField(controller: c, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Skip')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';
// // import '../../state/app_state.dart';
// // import '../../models/chore_models.dart';

// /// Where completion is allowed. Toggling done/undone lives here.
// class CheckOffTab extends StatefulWidget {
//   const CheckOffTab({super.key});

//   @override
//   State<CheckOffTab> createState() => _CheckOffTabState();
// }

// class _CheckOffTabState extends State<CheckOffTab> {
//   @override
//   Widget build(BuildContext context) {
//     // final app = context.watch<AppState>();
//     // final today = app.chores.choreListForToday;

//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: ListView(
//         children: [
//           // EXAMPLE of interactive toggle:
//           _CheckItem(
//             title: 'Example chore (interactive here)',
//             isDone: false,
//             onToggle: (v) {
//               // TODO: call into AppState to mark done/undone
//               // context.read<AppState>().chores.setDone(choreId, v);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Toggled to $v')),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _CheckItem extends StatelessWidget {
//   const _CheckItem({
//     required this.title,
//     required this.isDone,
//     required this.onToggle,
//   });

//   final String title;
//   final bool isDone;
//   final ValueChanged<bool> onToggle;

//   @override
//   Widget build(BuildContext context) {
//     return CheckboxListTile(
//       title: Text(title),
//       value: isDone,
//       onChanged: (v) => onToggle(v ?? false),
//     );
//   }
// }
