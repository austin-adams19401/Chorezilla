import 'package:chorezilla/components/avatar_cosmetic_widgets.dart';
import 'package:chorezilla/components/set_away_dialog.dart';
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

          // Treat null as "not bonus"
          final requiredAssignments = list
              .where((a) => a.bonus != true)
              .toList();

          // Count only explicit bonus=true
          final bonusCount = list.where((a) => a.bonus == true).length;

          int total = requiredAssignments.length;
          int completed = 0;
          int pending = 0;
          int rejected = 0;
          int assigned = 0;

          for (final a in requiredAssignments) {
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
              bonusCount: bonusCount,
              isAway: memberModel?.isAwayOnDate(DateTime.now()) ?? false,
              awayUntil: memberModel?.awayUntil,
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
              'assets/mascot/mascot_no_bg.png',
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
    required this.bonusCount,
    required this.isAway,
    this.awayUntil,
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
  final int bonusCount;
  final bool isAway;
  final DateTime? awayUntil;
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
    final hasRejections = rejected > 0;
    final isAway = summary.isAway;

    final avatarRadius = 26.0;

    // Dynamic gradient + border + shadow based on status
    final List<Color> gradientColors;
    final Color borderColor;
    final double borderWidth;
    final List<BoxShadow> shadows;

    if (isAway) {
      gradientColors = [
        cs.surfaceContainerHigh.withValues(alpha: 0.5),
        cs.surface,
      ];
      borderColor = cs.outline.withValues(alpha: 0.5);
      borderWidth = 1.5;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isAllDone) {
      gradientColors = [
        cs.primary.withValues(alpha: 0.18),
        cs.primaryContainer.withValues(alpha: 0.10),
      ];
      borderColor = cs.primary;
      borderWidth = 2.0;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: cs.primary.withValues(alpha: 0.28),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ];
    } else if (hasRejections) {
      gradientColors = [
        cs.error.withValues(alpha: 0.08),
        cs.surface,
      ];
      borderColor = cs.error.withValues(alpha: 0.5);
      borderWidth = 1.5;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    } else {
      gradientColors = [
        cs.surfaceContainerHigh.withValues(alpha: 0.7),
        cs.surface,
      ];
      borderColor = cs.outlineVariant;
      borderWidth = 1.0;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    }

    // Status pill
    final String statusText;
    final Color statusBg;
    final Color statusFg;
    if (isAway) {
      final awayUntil = summary.awayUntil;
      final returnStr = awayUntil != null ? _formatShortDate(awayUntil) : '';
      statusText = returnStr.isNotEmpty ? '✈ Away – Back $returnStr' : '✈ Away';
      statusBg = cs.surfaceContainerHighest;
      statusFg = cs.onSurfaceVariant;
    } else if (isAllDone) {
      statusText = 'All done!';
      statusBg = cs.primary.withValues(alpha: 0.35);
      statusFg = cs.primary;
    } else if (hasRejections) {
      statusText = 'Needs review';
      statusBg = cs.errorContainer;
      statusFg = cs.onErrorContainer;
    } else {
      statusText = '$remaining left';
      statusBg = cs.secondaryContainer.withValues(alpha: 0.85);
      statusFg = cs.onSecondaryContainer;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showKidDetailsDialog(context, summary),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadows,
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with circular progress ring + name row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar + progress ring
                SizedBox(
                  width: (avatarRadius + 7) * 2,
                  height: (avatarRadius + 7) * 2,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 4.0,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAllDone
                                ? cs.primary
                                : cs.primary.withValues(alpha: 0.75),
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Colors.black,
                        child: buildAvatarContent(
                          (summary.avatarKey ?? '').trim(),
                          avatarRadius * 0.95,
                          _initialsFor(summary.name),
                        ),
                      ),
                      if (isAllDone)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cs.surface,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Name + level/coins
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
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
                          if (!isAway)
                            Tooltip(
                              message: 'Set away',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => showSetAwayDialog(
                                  context,
                                  memberId: summary.memberId,
                                  memberName: summary.name,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.flight_takeoff_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            )
                          else
                            Tooltip(
                              message: 'Cancel away',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => _confirmClearAway(context, summary),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.flight_land_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer.withValues(
                                alpha: 0.75,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Lvl ${summary.level}',
                              style: ts.labelSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('🪙', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 2),
                          Text(
                            '${summary.coins}',
                            style: ts.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Status pill — full width
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: ts.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: statusFg,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isAllDone ? cs.primary : cs.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$completed / $total chores',
                style: ts.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 6),

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
                      ? cs.primary.withValues(alpha: 0.30)
                      : cs.secondaryContainer.withValues(alpha: 0.85),
                  textColor: remaining == 0
                      ? cs.primary
                      : cs.onSecondaryContainer,
                ),
                _StatChip(
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'Pending',
                  value: pending,
                  color: cs.tertiaryContainer,
                  textColor: cs.onTertiaryContainer,
                ),
                _StatChip(
                  icon: Icons.close_rounded,
                  label: 'Rejected',
                  value: rejected,
                  color: rejected > 0
                      ? cs.errorContainer
                      : cs.surfaceContainerHighest,
                  textColor: rejected > 0
                      ? cs.onErrorContainer
                      : cs.onSurfaceVariant,
                ),
                if (summary.bonusCount > 0)
                  _StatChip(
                    icon: Icons.bolt_rounded,
                    label: 'Bonus',
                    value: summary.bonusCount,
                    color: cs.primaryContainer,
                    textColor: cs.onPrimaryContainer,
                  ),
              ],
            ),

            const Spacer(),

            // Footer hint
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Tap to view chores',
                  style: ts.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: cs.primary,
                ),
              ],
            ),
          ],
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
    final maxListHeight = MediaQuery.of(context).size.height * 0.50;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient header
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.secondary,
                      cs.secondary.withValues(alpha: 0.88),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.black,
                          child: buildAvatarContent(
                            (summary.avatarKey ?? '').trim(),
                            28 * 0.95,
                            _initialsFor(summary.name),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${summary.completed} of ${summary.total} chores done',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: summary.total > 0
                            ? summary.completed / summary.total
                            : 0.0,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Chore list
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: assignments.length,
                  itemBuilder: (ctx, i) {
                    final a = assignments[i];
                    final status = a.status;
                    final isCompleted = status == AssignmentStatus.completed;

                    final Color tileColor;
                    final Border? tileBorder;
                    final Color statusLabelColor;

                    switch (status) {
                      case AssignmentStatus.assigned:
                        tileColor = cs.surfaceContainerLow;
                        tileBorder = null;
                        statusLabelColor = cs.onSurfaceVariant;
                        break;
                      case AssignmentStatus.pending:
                        tileColor = cs.tertiaryContainer.withValues(alpha: 0.25);
                        tileBorder = Border(
                          left: BorderSide(color: cs.tertiary, width: 4),
                        );
                        statusLabelColor = cs.tertiary;
                        break;
                      case AssignmentStatus.rejected:
                        tileColor = cs.error.withValues(alpha: 0.10);
                        tileBorder = Border(
                          left: BorderSide(color: cs.error, width: 4),
                        );
                        statusLabelColor = cs.error;
                        break;
                      case AssignmentStatus.completed:
                        tileColor = cs.surfaceContainerLowest;
                        tileBorder = null;
                        statusLabelColor = cs.onSurfaceVariant;
                        break;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(14),
                        border: tileBorder,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (a.choreIcon?.isNotEmpty ?? false)
                                    ? a.choreIcon!
                                    : '🧩',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.choreTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isCompleted
                                          ? cs.onSurfaceVariant
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    a.status.label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: statusLabelColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCompleted)
                              TextButton.icon(
                                onPressed: () async {
                                  await _onUndoPressed(context, a);
                                },
                                icon: const Icon(Icons.undo_rounded, size: 16),
                                label: const Text('Undo'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                          ],
                        ),
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


  Future<void> _confirmClearAway(
    BuildContext context,
    _KidTodaySummary summary,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${summary.name} is back?'),
        content: const Text('This will cancel the away period and resume normal chore tracking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, back home'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await context.read<AppState>().clearMemberAway(summary.memberId);
  }

  String _formatShortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
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
