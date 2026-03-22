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
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      primary: false,
      body: ValueListenableBuilder<List<Assignment>>(
        valueListenable: app.reviewQueueVN,
        builder: (_, queue, _) {
          final items = queue;

          if (items.isEmpty) {
            return const CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyReview(),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              // ── Header info card — scrolls with content ─────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fact_check_rounded,
                          color: cs.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chores to review',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Check photos and notes, then approve or reject in one tap.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onPrimaryContainer.withValues(
                                    alpha: .85,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Review cards ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                sliver: SliverList.separated(
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

                          final ts = theme.textTheme;

                          final proof = a.proof;
                          final hasPhoto =
                              proof?.photoUrl != null &&
                              proof!.photoUrl!.trim().isNotEmpty;
                          final hasNote =
                              proof?.note != null &&
                              proof!.note!.trim().isNotEmpty;

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: cs.outlineVariant,
                                width: 1.5,
                              ),
                            ),
                            elevation: 0,
                            color: cs.surface,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row: icon + title + help icon
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
                                          style: ts.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.help_outline_rounded,
                                          size: 20,
                                        ),
                                        tooltip: 'How review & approval works',
                                        onPressed: () =>
                                            _showApproveHelpDialog(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    chore == null
                                        ? 'This chore no longer exists.'
                                        : 'Completed by $kidName',
                                    style: ts.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Photo proof (thumbnail)
                                  if (hasPhoto) ...[
                                    Text(
                                      'Photo proof',
                                      style: ts.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () => _showProofDialog(context, a),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AspectRatio(
                                          aspectRatio: 4 / 3,
                                          child: Image.network(
                                            proof.photoUrl!,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (
                                                  context,
                                                  child,
                                                  loadingProgress,
                                                ) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return const Center(
                                                    child: Padding(
                                                      padding: EdgeInsets.all(
                                                        16,
                                                      ),
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  );
                                                },
                                            errorBuilder: (_, _, _) =>
                                                Container(
                                                  color: cs
                                                      .surfaceContainerHighest,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'Could not load photo',
                                                    style: ts.bodySmall
                                                        ?.copyWith(
                                                          color: cs
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],

                                  // Optional note
                                  if (hasNote) ...[
                                    Text(
                                      '"${proof.note!.trim()}"',
                                      style: ts.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],

                                  const SizedBox(height: 4),
                                  if (chore == null)
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.tonal(
                                        onPressed: isBusy
                                            ? null
                                            : () => _rejectAssignment(a),
                                        child: isBusy
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('Dismiss'),
                                      ),
                                    )
                                  else
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
                                                    child:
                                                        CircularProgressIndicator(
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
                                              backgroundColor:
                                                  cs.errorContainer,
                                              foregroundColor:
                                                  cs.onErrorContainer,
                                            ),
                                            onPressed: isBusy
                                                ? null
                                                : () => _rejectAssignment(a),
                                            child: isBusy
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
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
                ),
              ),
            ],
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

    final app = context.read<AppState>();

    // Optimistic update — remove card immediately
    final previousQueue = List<Assignment>.from(app.reviewQueueVN.value);
    app.reviewQueueVN.value =
        previousQueue.where((x) => x.id != a.id).toList();

    setState(() => _busyIds.add(a.id));
    try {
      await app.approveAssignment(a.id, parentMemberId: app.currentMember?.id);
      if (!mounted) return;
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
      // Revert optimistic update on failure
      app.reviewQueueVN.value = previousQueue;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error approving chore: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(a.id));
    }
  }

  Future<void> _rejectAssignment(Assignment a) async {
    if (_busyIds.contains(a.id)) return;

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

    final app = context.read<AppState>();

    // Optimistic update — remove card immediately after dialog confirms
    final previousQueue = List<Assignment>.from(app.reviewQueueVN.value);
    app.reviewQueueVN.value =
        previousQueue.where((x) => x.id != a.id).toList();

    setState(() => _busyIds.add(a.id));
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
      // Revert optimistic update on failure
      app.reviewQueueVN.value = previousQueue;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting chore: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(a.id));
    }
  }

  void _showApproveHelpDialog(BuildContext context) {
    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final cs = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reviewing chores'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This tab is for chores that need a parent check before they\'re fully done.',
              style: ts.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '• Chores appear here when a kid marks a “requires approval” chore as done.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Approve to award coins/XP and clear the chore from the review queue.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Reject to mark it as not approved without awarding coins/XP.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• The optional reason field is for your own notes or to help guide future conversations with your kid.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showProofDialog(BuildContext context, Assignment a) {
    final proof = a.proof;
    final url = proof?.photoUrl;
    if (url == null || url.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final ts = theme.textTheme;
        final cs = theme.colorScheme;

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => Container(
                      color: cs.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Text(
                        'Could not load photo',
                        style: ts.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (proof?.note != null && proof!.note!.trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('"${proof.note!.trim()}"', style: ts.bodyMedium),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyReview extends StatelessWidget {
  const _EmptyReview();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✅', style: ts.displaySmall),
            const SizedBox(height: 8),
            const Text(
              'Nothing to review right now',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Kids\' approved chores will land here when they need your check.',
              style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
