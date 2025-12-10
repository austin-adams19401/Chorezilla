import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_weekly_overview_page.dart';
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
    if (_boundFamilyId != app.familyId && app.familyId != null) {
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
    final cs = Theme.of(context).colorScheme;
    final membersById = {for (final m in app.members) m.id: m};

    return StreamBuilder<List<Assignment>>(
      stream: _todayStream,
      builder: (context, snap) {
        final items = snap.data ?? const <Assignment>[];

        // 🔍 Extra debug so we can see what's really happening
        debugPrint(
          'ParentTodayTab: state=${snap.connectionState} '
          'hasError=${snap.hasError} items=${items.length}',
        );

        if (snap.hasError) {
          // If Firestore is complaining about indexes / rules, show it.
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading today\'s assignments:\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

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

          final level = memberModel?.level ?? 1;
          final coins = memberModel?.coins ?? 0;

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
              level: level,
              coins: coins,
            ),
          );
        });

        summaries.sort((a, b) => a.name.compareTo(b.name));

        // Global stats for the hero bar
        final totalAssignments = summaries.fold<int>(
          0,
          (sum, s) => sum + s.total,
        );
        final completedAssignments = summaries.fold<int>(
          0,
          (sum, s) => sum + s.completed,
        );

        return Column(
          children: [
            // Hero stays at the top (still draws behind the AppBar via topInset)
            _TodayHero(
              kidCount: summaries.length,
              completed: completedAssignments,
              total: totalAssignments,
              onWeeklyOverviewPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ParentWeeklyOverviewPage(),
                  ),
                );
              },
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Approximate how tall the grid wants to be
                  double estimateGridHeight() {
                    const double maxCrossAxisExtent = 260;
                    const double mainAxisSpacing = 12;
                    const double childAspectRatio = 0.8;

                    final itemCount = summaries.length;
                    if (itemCount == 0) return 0;

                    // How many columns will we get at this width?
                    int columns = (constraints.maxWidth / maxCrossAxisExtent)
                        .floor();
                    if (columns < 1) columns = 1;
                    if (columns > itemCount) columns = itemCount;

                    final tileWidth = constraints.maxWidth / columns;
                    final tileHeight = tileWidth / childAspectRatio;

                    final rows = (itemCount / columns).ceil();
                    final totalHeight =
                        rows * tileHeight + (rows - 1) * mainAxisSpacing;

                    return totalHeight;
                  }

                  final gridHeight = estimateGridHeight();
                  final availableHeight = constraints.maxHeight;
                  final shouldCenter =
                      gridHeight > 0 && gridHeight < availableHeight;

                  final grid = GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: summaries.length,
                    itemBuilder: (context, index) {
                      final s = summaries[index];
                      return _KidTodayCard(summary: s);
                    },
                  );

                  return Padding(
                    padding: const EdgeInsets.all(0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.secondary, cs.secondary, cs.primary],
                          stops: const [0.0, 0.55, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 30, 10, 12),
                      child: shouldCenter
                          ? Align(
                              alignment: Alignment.center,
                              child: SizedBox(height: gridHeight, child: grid),
                            )
                          : grid,
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
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({
    required this.kidCount,
    required this.completed,
    required this.total,
    this.onWeeklyOverviewPressed,
  });

  final int kidCount;
  final int completed;
  final int total;
  final VoidCallback? onWeeklyOverviewPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final media = MediaQuery.of(context);
    final double topInset =
        media.padding.top; // + kToolbarHeight; // status + appbar

    final kidsLabel = kidCount == 1 ? '1 kid' : '$kidCount kids';
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.secondary, // deep navy
            cs.secondary,
            cs.secondary, // brand green on the right
          ],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text + stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Today at a glance',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (onWeeklyOverviewPressed != null)
                      TextButton.icon(
                        onPressed: onWeeklyOverviewPressed,
                        
                        icon: const Icon(
                          Icons.calendar_view_week_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Weekly View',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white, width: 1.4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Check how chores are going for your crew.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        kidsLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (total > 0)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(
                                alpha: .2,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completed of $total chores done today',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              color: cs.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/icons/mascot/mascot_no_bg.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
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
    required this.level,
    required this.coins,
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

  final int level;
  final int coins;
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
    final isAllDone = total > 0 && completed == total;

    final avatarRadius = 22.0;
    final emojiSize = avatarRadius * 1.2;

    final Color statusColor = isAllDone
        ? cs.primary.withValues(alpha: 0.14)
        : cs.secondaryContainer.withValues(alpha: 0.35);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        _showKidDetailsDialog(context, summary);
      },
      child: Card(
        elevation: isAllDone ? 2 : 0,
        margin: EdgeInsets.zero,
        color: isAllDone
            ? cs.primaryContainer.withValues(alpha: 0.25)
            : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isAllDone ? cs.primary : cs.outlineVariant,
            width: isAllDone ? 2 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            // subtle top-to-bottom tint so it feels less flat
            gradient: LinearGradient(
              colors: [
                cs.surfaceContainerHighest.withValues(alpha: 0.24),
                cs.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: avatar + name/level/coins + status pill
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Lvl ${summary.level}',
                              style: ts.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Text('🪙',
                                  style: ts.labelMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${summary.coins}',
                                  style: ts.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    // child: Row(
                    //   mainAxisSize: MainAxisSize.min,
                    //   children: [
                    //     Icon(
                    //       isAllDone
                    //           ? Icons.check_circle_rounded
                    //           : Icons.list_alt_rounded,
                    //       size: 14,
                    //       color: statusTextColor,
                    //     ),
                    //     const SizedBox(width: 4),
                    //     // Text(
                    //     //   statusText,
                    //     //   style: ts.labelSmall?.copyWith(
                    //     //     fontWeight: FontWeight.w600,
                    //     //     color: statusTextColor,
                    //     //   ),
                    //     // ),
                    //   ],
                    // ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress bar + count
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed / $total',
                    style: ts.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Chips row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _StatChip(
                    icon: Icons.checklist_rtl_rounded,
                    label: 'Left',
                    value: remaining,
                    color: remaining == 0
                        ? cs.primary.withValues(alpha: 0.16)
                        : cs.secondaryContainer.withValues(alpha: 0.6),
                    textColor: remaining == 0
                        ? cs.primary
                        : cs.onSecondaryContainer,
                  ),
                  _StatChip(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'Pending',
                    value: pending,
                    color: cs.tertiaryContainer.withValues(alpha: 0.8),
                    textColor: cs.onTertiaryContainer,
                  ),
                  _StatChip(
                    icon: Icons.close_rounded,
                    label: 'Rejected',
                    value: rejected,
                    color: rejected > 0
                        ? cs.errorContainer.withValues(alpha: 0.9)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.7),
                    textColor: rejected > 0
                        ? cs.onErrorContainer
                        : cs.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 6),
              const Spacer(),

              // Footer hint
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View today',
                    style: ts.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKidDetailsDialog(BuildContext context, _KidTodaySummary summary) {
    final assignments = [...summary.assignments];
    assignments.sort(
      (a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)),
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxListHeight = MediaQuery.of(context).size.height * 0.6;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '${summary.name} – today',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${summary.completed}/${summary.total} done',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // 🔧 THIS PART CHANGED
          content: SizedBox(
            width: double.maxFinite,
            height: maxListHeight,
            child: ListView.separated(
              // ❌ remove shrinkWrap: true
              itemCount: assignments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
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
                    (a.choreIcon?.isNotEmpty ?? false) ? a.choreIcon! : '🧩',
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
                  trailing: status == AssignmentStatus.completed
                      ? TextButton.icon(
                          onPressed: () async {
                            await _onUndoPressed(context, a);
                          },
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('Undo'),
                        )
                      : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onUndoPressed(
    BuildContext context,
    Assignment assignment,
  ) async {
    // 1) Confirm with the parent first
    final shouldUndo = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Undo this chore?'),
          content: Text(
            'This will mark "${assignment.choreTitle}" as not done and '
            'remove the XP and coins that were awarded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Undo'),
            ),
          ],
        );
      },
    );

    // User cancelled or dismissed
    if (shouldUndo != true) return;

    // 2) Actually perform the undo
    if(!context.mounted) return;
    final app = context.read<AppState>();
    final familyId = app.familyId;

    if (familyId == null) {
      return;
    }

    try {
      await app.repo.undoAssignmentCompletion(familyId, assignment.id);

      // Close the kid-details dialog so they see the updated state on reopen
      if(!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('undoAssignmentCompletion failed: $e\n$st');
    }
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
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: ts.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: ts.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
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
