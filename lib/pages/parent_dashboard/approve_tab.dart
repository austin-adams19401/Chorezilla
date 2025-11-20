import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/member.dart';

class ApproveTab extends StatefulWidget {
  const ApproveTab({super.key});

  @override
  State<ApproveTab> createState() => _ApproveTabState();
}

class _ApproveTabState extends State<ApproveTab> {
  // Track which assignment IDs are in-flight (approve/reject)
  final Set<String> _busyIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      body: ValueListenableBuilder<List<Assignment>>(
        valueListenable: app.reviewQueueVN,
        builder: (_, queue, _) {
          // You can add sorting here if you want (e.g., by completion time)
          final items = queue;

          if (items.isEmpty) {
            return const Center(child: Text('No chores waiting for review.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final a = items[i];
              final chore = _findChore(app, a);
              final kid = _findMember(app, a);

              final icon = chore?.icon ?? '🧩';
              final title = chore?.title ?? 'Deleted chore';
              final kidName = kid?.displayName ?? 'Unknown kid';

              final isBusy = _busyIds.contains(a.id);

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey, width: 2),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            icon.isNotEmpty ? icon : '🧩',
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Completed by $kidName',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: isBusy
                                  ? null
                                  : () => _approveAssignment(a),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.redAccent
                              ),
                              onPressed: isBusy
                                  ? null
                                  : () => _rejectAssignment(a),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Chore? _findChore(AppState app, Assignment a) {
    try {
      return app.chores.firstWhere((c) => c.id == a.choreId);
    } catch (_) {
      return null;
    }
  }

  Member? _findMember(AppState app, Assignment a) {
    try {
      return app.members.firstWhere((m) => m.id == a.memberId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _approveAssignment(Assignment a) async {
    if (_busyIds.contains(a.id)) return;
    setState(() => _busyIds.add(a.id));

    final app = context.read<AppState>();

    try {
      await app.approveAssignment(a.id, parentMemberId: app.currentMember?.id);
      if (!mounted) return;
      // reviewQueueVN + kid streams will auto-update via Firestore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approved "${_findChore(app, a)?.title ?? 'chore'}" for '
            '${_findMember(app, a)?.displayName ?? 'kid'}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error approving chore: $e')));
    } finally {
      setState(() => _busyIds.remove(a.id));
    }
  }

  Future<void> _rejectAssignment(Assignment a) async {
    if (_busyIds.contains(a.id)) return;

    // Optional: ask for a reason. You can skip this dialog if you want.
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject chore?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null) return; // user cancelled
    if (!mounted) return;

    setState(() => _busyIds.add(a.id));
    final app = context.read<AppState>();

    try {
      await app.rejectAssignment(a.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rejected "${_findChore(app, a)?.title ?? 'chore'}" '
            'for ${_findMember(app, a)?.displayName ?? 'kid'}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting chore: $e')));
    } finally {
      setState(() => _busyIds.remove(a.id));
    }
  }
}
