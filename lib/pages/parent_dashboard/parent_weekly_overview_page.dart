import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/models/chore_member_schedule.dart';
import 'package:chorezilla/models/recurrance.dart';

class ParentWeeklyOverviewPage extends StatefulWidget {
  const ParentWeeklyOverviewPage({super.key});

  @override
  State<ParentWeeklyOverviewPage> createState() =>
      _ParentWeeklyOverviewPageState();
}

class _ParentWeeklyOverviewPageState extends State<ParentWeeklyOverviewPage> {
  int _weekOffset = 0;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  List<DateTime> _getWeekDates() {
    final now = DateTime.now();
    final monday = now
        .subtract(Duration(days: now.weekday - DateTime.monday))
        .add(Duration(days: _weekOffset * 7));
    return List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final familyId = app.familyId;
    if (familyId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final kids = app.members
        .where((m) => m.role == FamilyRole.child && m.active)
        .toList();

    final gradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [cs.secondary, cs.secondaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    if (kids.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(theme, cs),
        body: Container(
          decoration: gradientDecoration,
          child: const Center(child: Text('No kids in this family yet.')),
        ),
      );
    }

    final weekDates = _getWeekDates();
    final weekStart = weekDates.first;
    final weekEnd = weekDates.last.add(const Duration(days: 1));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(theme, cs),
      body: Container(
        decoration: gradientDecoration,
        child: SafeArea(
          child: StreamBuilder<List<ChoreMemberSchedule>>(
            stream: app.watchAllChoreSchedules(),
            builder: (context, schedSnapshot) {
              if (!schedSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final schedules = schedSnapshot.data!;
              final chores = app.chores;
              final gridData = _buildGridData(
                kids: kids,
                schedules: schedules,
                chores: chores,
                weekDates: weekDates,
              );

              return StreamBuilder<List<Assignment>>(
                stream: app.repo.watchAssignmentsDueRange(
                  familyId,
                  start: weekStart,
                  end: weekEnd,
                ),
                builder: (context, assignSnapshot) {
                  final weekAssignments = assignSnapshot.data ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWeekNavHeader(theme, cs, weekDates),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Chores per kid, per day',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onSecondary.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Weekly overview'),
                                  content: const Text(
                                    'This chart shows how many chores each kid has scheduled for every day of the week.\n\n'
                                    'Tap any cell to see the full list of chores for that kid on that day.\n\n'
                                    'Use the arrows at the top to look ahead at future weeks or review past ones.\n\n'
                                    'The "Total" row at the bottom shows the combined chore count across all kids for each day.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Got it'),
                                    ),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.help_outline_rounded,
                                size: 18,
                                color: cs.onSecondary.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildGrid(
                          context,
                          theme,
                          cs,
                          weekDates,
                          gridData,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildDayDetailPanel(
                          theme,
                          cs,
                          _selectedDate,
                          weekDates,
                          gridData,
                          weekAssignments,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme cs) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Weekly overview',
        style: theme.textTheme.titleLarge?.copyWith(
          color: cs.onSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: IconThemeData(color: cs.onSecondary),
    );
  }

  Widget _buildWeekNavHeader(
    ThemeData theme,
    ColorScheme cs,
    List<DateTime> weekDates,
  ) {
    final start = weekDates.first;
    final end = weekDates.last;
    final sameMonth = start.month == end.month;
    final label = sameMonth
        ? '${DateFormat('MMM d').format(start)} – ${DateFormat('d').format(end)}'
        : '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: cs.onSecondary),
            onPressed: () => setState(() => _weekOffset--),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: cs.onSecondary),
            onPressed: () => setState(() => _weekOffset++),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    List<DateTime> weekDates,
    List<_KidRowData> gridData,
  ) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        const nameColWidth = 80.0;
        final dayColWidth = (constraints.maxWidth - nameColWidth) / 7;

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header row
              _buildHeaderRow(
                theme,
                cs,
                weekDates,
                todayNorm,
                nameColWidth,
                dayColWidth,
              ),
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
              // Kid rows
              ...gridData.map((row) {
                return Column(
                  children: [
                    _buildKidRow(
                      context,
                      theme,
                      cs,
                      row,
                      weekDates,
                      todayNorm,
                      nameColWidth,
                      dayColWidth,
                    ),
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ],
                );
              }),
              // Totals footer row
              _buildTotalsRow(theme, cs, weekDates, gridData, todayNorm, nameColWidth, dayColWidth),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(
    ThemeData theme,
    ColorScheme cs,
    List<DateTime> weekDates,
    DateTime todayNorm,
    double nameColWidth,
    double dayColWidth,
  ) {
    return Row(
      children: [
        SizedBox(width: nameColWidth),
        ...weekDates.map((date) {
          final isToday = date == todayNorm;
          final isSelected = date == _selectedDate;
          return _buildDayHeaderCell(
            theme,
            cs,
            date,
            isToday,
            isSelected,
            dayColWidth,
          );
        }),
      ],
    );
  }

  Widget _buildDayHeaderCell(
    ThemeData theme,
    ColorScheme cs,
    DateTime date,
    bool isToday,
    bool isSelected,
    double width,
  ) {
    return InkWell(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.18)
              : isToday
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : null,
        ),
        child: Column(
          children: [
            Text(
              _weekdayLabel(date.weekday),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? cs.primary
                    : isToday
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? cs.primary
                    : isToday
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKidRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    _KidRowData row,
    List<DateTime> weekDates,
    DateTime todayNorm,
    double nameColWidth,
    double dayColWidth,
  ) {
    return Row(
      children: [
        // Kid name cell
        SizedBox(
          width: nameColWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              row.kid.displayName,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),
        // Day cells
        ...weekDates.asMap().entries.map((entry) {
          final dayIdx = entry.key;
          final date = entry.value;
          final isToday = date == todayNorm;
          final chores = row.choresByDay[dayIdx];
          return _buildCountCell(
            context,
            theme,
            cs,
            row.kid,
            date,
            chores,
            isToday,
            dayColWidth,
          );
        }),
      ],
    );
  }

  Widget _buildCountCell(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Member kid,
    DateTime date,
    List<Chore> chores,
    bool isToday,
    double width,
  ) {
    final count = chores.length;
    final isSelected = date == _selectedDate;

    return InkWell(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        width: width,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.12)
              : isToday
                  ? cs.primaryContainer.withValues(alpha: 0.3)
                  : null,
        ),
        alignment: Alignment.center,
        child: count == 0
            ? Text(
                '—',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              )
            : Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primary
                      : isToday
                          ? cs.primary
                          : cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected || isToday ? cs.onPrimary : cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTotalsRow(
    ThemeData theme,
    ColorScheme cs,
    List<DateTime> weekDates,
    List<_KidRowData> gridData,
    DateTime todayNorm,
    double nameColWidth,
    double dayColWidth,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: nameColWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Text(
                'Total',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ...weekDates.asMap().entries.map((entry) {
            final dayIdx = entry.key;
            final date = entry.value;
            final isToday = date == todayNorm;
            final isSelected = date == _selectedDate;
            final total = gridData.fold<int>(
              0,
              (sum, row) => sum + row.choresByDay[dayIdx].length,
            );
            return Container(
              width: dayColWidth,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.12)
                    : isToday
                        ? cs.primaryContainer.withValues(alpha: 0.3)
                        : null,
              ),
              alignment: Alignment.center,
              child: Text(
                total == 0 ? '—' : '$total',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: total == 0
                      ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                      : cs.onSurfaceVariant,
                  fontWeight: total == 0 ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDayDetailPanel(
    ThemeData theme,
    ColorScheme cs,
    DateTime selectedDate,
    List<DateTime> weekDates,
    List<_KidRowData> gridData,
    List<Assignment> weekAssignments,
  ) {
    final dayIndex = weekDates.indexWhere((d) => d == selectedDate);
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final isFuture = selectedDate.isAfter(todayNorm);

    // Assignments for the selected day
    final dayAssignments = weekAssignments.where((a) {
      if (a.due == null) return false;
      final d = a.due!;
      return d.year == selectedDate.year &&
          d.month == selectedDate.month &&
          d.day == selectedDate.day;
    }).toList();

    final dateLabel = DateFormat('EEEE, MMM d').format(selectedDate);

    // Count completed for the day (across all kids)
    final completedCount = dayAssignments
        .where((a) =>
            a.status == AssignmentStatus.completed ||
            a.status == AssignmentStatus.pending)
        .length;
    final totalAssigned = dayAssignments.length;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isFuture && totalAssigned > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: completedCount == totalAssigned
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$completedCount / $totalAssigned done',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: completedCount == totalAssigned
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          // Kid sections
          Expanded(
            child: dayIndex < 0
                ? Center(
                    child: Text(
                      'Select a date above to see details.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                : _buildKidSections(
                    theme,
                    cs,
                    selectedDate,
                    dayIndex,
                    gridData,
                    dayAssignments,
                    isFuture,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKidSections(
    ThemeData theme,
    ColorScheme cs,
    DateTime selectedDate,
    int dayIndex,
    List<_KidRowData> gridData,
    List<Assignment> dayAssignments,
    bool isFuture,
  ) {
    // Only show kids that have chores on this day
    final activeRows = gridData
        .where((row) => row.choresByDay[dayIndex].isNotEmpty)
        .toList();

    if (activeRows.isEmpty) {
      return Center(
        child: Text(
          'No chores scheduled for this day.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: activeRows.length,
      separatorBuilder: (context, i) =>
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
      itemBuilder: (context, i) {
        final row = activeRows[i];
        final chores = row.choresByDay[dayIndex];
        final kidAssignments = dayAssignments
            .where((a) => a.memberId == row.kid.id)
            .toList();

        return _buildKidSection(
            theme, cs, row.kid, chores, kidAssignments, isFuture);
      },
    );
  }

  Widget _buildKidSection(
    ThemeData theme,
    ColorScheme cs,
    Member kid,
    List<Chore> chores,
    List<Assignment> kidAssignments,
    bool isFuture,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kid.displayName,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...chores.map((chore) {
            final assignment = kidAssignments
                .where((a) => a.choreId == chore.id)
                .firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildChoreRow(
                  theme, cs, chore, assignment, isFuture),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChoreRow(
    ThemeData theme,
    ColorScheme cs,
    Chore chore,
    Assignment? assignment,
    bool isFuture,
  ) {
    final status = assignment?.status;

    Color rowBg;
    Color chipBg;
    Color chipFg;
    String chipLabel;
    bool strikethrough = false;

    if (isFuture || assignment == null) {
      rowBg = Colors.transparent;
      chipBg = cs.surfaceContainerHighest;
      chipFg = cs.onSurfaceVariant;
      chipLabel = 'Scheduled';
    } else {
      switch (status) {
        case AssignmentStatus.completed:
          rowBg = cs.surfaceContainerHighest.withValues(alpha: 0.5);
          chipBg = cs.primaryContainer;
          chipFg = cs.onPrimaryContainer;
          chipLabel = assignment.requiresApproval ? 'Needs review' : 'Done';
          strikethrough = !assignment.requiresApproval;
        case AssignmentStatus.pending:
          rowBg = cs.tertiaryContainer.withValues(alpha: 0.4);
          chipBg = cs.tertiaryContainer;
          chipFg = cs.onTertiaryContainer;
          chipLabel = 'Pending';
          strikethrough = false;
        case AssignmentStatus.rejected:
          rowBg = cs.errorContainer.withValues(alpha: 0.3);
          chipBg = cs.errorContainer;
          chipFg = cs.onErrorContainer;
          chipLabel = 'Rejected';
        default:
          rowBg = Colors.transparent;
          chipBg = cs.surfaceContainerHighest;
          chipFg = cs.onSurfaceVariant;
          chipLabel = 'Assigned';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              chore.icon?.isNotEmpty == true ? chore.icon! : '🧩',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              chore.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: strikethrough ? TextDecoration.lineThrough : null,
                color: strikethrough
                    ? cs.onSurface.withValues(alpha: 0.5)
                    : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              chipLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: chipFg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_KidRowData> _buildGridData({
    required List<Member> kids,
    required List<ChoreMemberSchedule> schedules,
    required List<Chore> chores,
    required List<DateTime> weekDates,
  }) {
    final choreById = {for (final c in chores) c.id: c};

    return kids.map((kid) {
      final kidSchedules = schedules
          .where((s) => s.active && s.memberId == kid.id)
          .toList();

      final choresByDay = weekDates.map((date) {
        final List<Chore> dayChores = [];
        for (final s in kidSchedules) {
          if (_scheduleOccursOnDate(s.recurrence, date)) {
            final chore = choreById[s.choreId];
            if (chore != null && chore.active) {
              dayChores.add(chore);
            }
          }
        }
        return dayChores;
      }).toList();

      return _KidRowData(kid: kid, choresByDay: choresByDay);
    }).toList();
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
      default:
        return 'Sun';
    }
  }

  bool _scheduleOccursOnDate(Recurrence r, DateTime date) {
    switch (r.type) {
      case 'daily':
        return true;

      case 'weekly':
        final days = r.daysOfWeek ?? const [];
        return days.contains(date.weekday);

      case 'custom':
        final start = r.startDate ?? date;
        final n = r.intervalDays ?? 1;
        final startDay = DateTime(start.year, start.month, start.day);
        final thisDay = DateTime(date.year, date.month, date.day);
        final diff = thisDay.difference(startDay).inDays;
        return diff >= 0 && diff % n == 0;

      case 'once':
        final start = r.startDate;
        if (start == null) return false;
        final startDay = DateTime(start.year, start.month, start.day);
        final thisDay = DateTime(date.year, date.month, date.day);
        return startDay == thisDay;

      default:
        return false;
    }
  }
}

class _KidRowData {
  final Member kid;
  final List<List<Chore>> choresByDay;

  const _KidRowData({required this.kid, required this.choresByDay});
}
