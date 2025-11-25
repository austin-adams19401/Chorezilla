import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/models/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';

class ParentTodayTab extends StatefulWidget {
  const ParentTodayTab({super.key});

  @override
  State<ParentTodayTab> createState() => _ParentTodayTabState();
}

class _ParentTodayTabState extends State<ParentTodayTab> {
  // Keeping this in case we want to bring back a setting later
  static const _prefsKey = 'homeGroupBy'; // unused for now

  Stream<List<Assignment>>? _todayStream;
  String? _boundFamilyId;
  bool _loadedPref = false;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    // Placeholder if we want to reintroduce preferences later
    final p = await SharedPreferences.getInstance();
    p.getString(_prefsKey); // read once so we don't re-load every build
    setState(() {
      _loadedPref = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    if (!app.isReady) return;

    if (!_loadedPref) {
      _loadPref();
    }
    if (_boundFamilyId != app.familyId) {
      _boundFamilyId = app.familyId;
      _todayStream = app.repo.watchAssignmentsDueToday(_boundFamilyId!);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final appReady = context.select((AppState s) => s.isReady);
    if (!appReady || _todayStream == null || !_loadedPref) {
      return const Center(child: CircularProgressIndicator());
    }

    final app = context.watch<AppState>();
    final membersById = {for (final m in app.members) m.id: m};

    return StreamBuilder<List<Assignment>>(
      stream: _todayStream,
      builder: (context, snap) {
        final items = snap.data ?? const <Assignment>[];

        debugPrint(
          'TODAY ASSIGNMENTS: ${items.map((a) => '${a.memberName} / ${a.choreTitle} @ ${a.due}').toList()}',
        );

        if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (items.isEmpty) {
          return const _EmptyToday();
        }

        // Group assignments by memberId → kid summaries
        final byMember = <String, List<Assignment>>{};
        for (final a in items) {
          final id = a.memberId;
          if (id.isEmpty) continue;
          byMember.putIfAbsent(id, () => <Assignment>[]).add(a);
        }

        final summaries = <_KidTodaySummary>[];
        byMember.forEach((memberId, list) {
          final memberModel = membersById[memberId];
          final name =
              memberModel?.displayName ??
              (list.isNotEmpty && list.first.memberName.isNotEmpty
                  ? list.first.memberName
                  : 'Kid');
          final avatarKey = memberModel?.avatarKey;

          int total = list.length;
          int completed = 0;
          int pending = 0;
          int rejected = 0;
          int assigned = 0;

          for (final a in list) {
            switch (a.status) {
              case AssignmentStatus.completed:
                completed++;
                break;
              case AssignmentStatus.pending:
                pending++;
                break;
              case AssignmentStatus.rejected:
                rejected++;
                break;
              case AssignmentStatus.assigned:
                assigned++;
                break;
            }
          }

          summaries.add(
            _KidTodaySummary(
              memberId: memberId,
              name: name,
              avatarKey: avatarKey,
              total: total,
              completed: completed,
              pending: pending,
              rejected: rejected,
              assigned: assigned,
              assignments: list,
            ),
          );
        });

        summaries.sort((a, b) => a.name.compareTo(b.name));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Today at a glance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '${summaries.length} kids',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {

                  // How wide each kid card can be; this controls how many columns we get.
                  // With maxCrossAxisExtent, Flutter chooses the number of columns.
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260, // ~3–4 per row on tablets
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        // width / height; < 1.0 ⇒ taller tiles
                        childAspectRatio: 0.8,
                      ),
                    itemCount: summaries.length,
                    itemBuilder: (context, index) {
                      final s = summaries[index];
                      return _KidTodayCard(summary: s);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KidTodaySummary {
  _KidTodaySummary({
    required this.memberId,
    required this.name,
    required this.avatarKey,
    required this.total,
    required this.completed,
    required this.pending,
    required this.rejected,
    required this.assigned,
    required this.assignments,
  });

  final String memberId;
  final String name;
  final String? avatarKey;
  final int total;
  final int completed;
  final int pending;
  final int rejected;
  final int assigned;
  final List<Assignment> assignments;
}

class _KidTodayCard extends StatelessWidget {
  const _KidTodayCard({required this.summary});

  final _KidTodaySummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final total = summary.total;
    final completed = summary.completed;
    final pending = summary.pending;
    final rejected = summary.rejected;
    final remaining = total - completed;

    final progress = total > 0 ? completed / total : 0.0;

    final avatarRadius = 22.0;
    final emojiSize = avatarRadius * 1.2;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        _showKidDetailsBottomSheet(context, summary);
      },
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: completed == total && total > 0
            ? cs.primaryContainer.withValues(alpha: 0.18)
            : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: completed == total && total > 0
                ? cs.primary
                : cs.outlineVariant,
            width: completed == total && total > 0 ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: avatar + name + X/Y
              Row(
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: cs.primaryContainer,
                    child:
                        (summary.avatarKey != null &&
                            summary.avatarKey!.isNotEmpty)
                        ? Text(
                            summary.avatarKey!,
                            style: TextStyle(
                              fontSize: emojiSize,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : Text(
                            _initialsFor(summary.name),
                            style: TextStyle(
                              fontSize: avatarRadius,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$completed / $total',
                    style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
              const SizedBox(height: 6),
              // Chips row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _StatChip(
                    label: 'Left',
                    value: remaining,
                    color: remaining == 0
                        ? cs.primary.withValues(alpha: 0.18)
                        : cs.secondaryContainer.withValues(alpha: 0.6),
                    textColor: remaining == 0
                        ? cs.primary
                        : cs.onSecondaryContainer,
                  ),
                  _StatChip(
                    label: 'Pending',
                    value: pending,
                    color: cs.tertiaryContainer.withValues(alpha: 0.7),
                    textColor: cs.onTertiaryContainer,
                  ),
                  _StatChip(
                    label: 'Rejected',
                    value: rejected,
                    color: rejected > 0
                        ? cs.errorContainer.withValues(alpha: 0.8)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.7),
                    textColor: rejected > 0
                        ? cs.onErrorContainer
                        : cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  'Tap for details',
                  style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKidDetailsBottomSheet(
    BuildContext context,
    _KidTodaySummary summary,
  ) {
    final assignments = [...summary.assignments];
    assignments.sort(
      (a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)),
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final maxListHeight = MediaQuery.of(ctx).size.height * 0.6;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Header row
              Row(
                children: [
                  Text(
                    '${summary.name} – today',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.completed}/${summary.total} done',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Scrollable list, but only up to 60% of screen height.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (ctx, i) {
                    final a = assignments[i];
                    final status = a.status;
                    Color? tileColor;
                    BorderSide? side;

                    switch (status) {
                      case AssignmentStatus.assigned:
                        tileColor = null;
                        side = null;
                        break;
                      case AssignmentStatus.pending:
                        tileColor = cs.tertiaryContainer.withValues(alpha: 0.3);
                        side = BorderSide(color: cs.tertiary, width: 2);
                        break;
                      case AssignmentStatus.rejected:
                        tileColor = cs.error.withValues(alpha: 0.12);
                        side = BorderSide(color: cs.error, width: 1.5);
                        break;
                      case AssignmentStatus.completed:
                        tileColor = cs.surfaceContainerHighest.withValues(
                          alpha: 0.2,
                        );
                        side = null;
                        break;
                    }

                    final titleStyle = theme.textTheme.titleMedium?.copyWith(
                      decoration: status == AssignmentStatus.completed
                          ? TextDecoration.lineThrough
                          : null,
                    );

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        (a.choreIcon?.isNotEmpty ?? false)
                            ? a.choreIcon!
                            : '🧩',
                        style: const TextStyle(fontSize: 26),
                      ),
                      title: Text(
                        a.choreTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      subtitle: Text(
                        a.status.label,
                        style: theme.textTheme.bodySmall,
                      ),
                      tileColor: tileColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: side ?? BorderSide.none,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final String label;
  final int value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: ts.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: ts.labelSmall?.copyWith(color: textColor)),
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

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
            Text(
              'Everyone is caught up!',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
