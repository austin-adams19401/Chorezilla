import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/chore_member_schedule.dart';
import 'package:chorezilla/models/recurrance.dart';

class ParentWeeklyOverviewPage extends StatefulWidget {
  const ParentWeeklyOverviewPage({super.key});

  @override
  State<ParentWeeklyOverviewPage> createState() =>
      _ParentWeeklyOverviewPageState();
}

class _ParentWeeklyOverviewPageState extends State<ParentWeeklyOverviewPage> {
  String? _selectedKidId; // null = first kid by default

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

    if (kids.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
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
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.secondaryContainer, cs.secondary, cs.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(child: Text('No kids in this family yet.')),
        ),
      );
    }

    final selectedKid = kids.firstWhere(
      (k) => k.id == _selectedKidId,
      orElse: () => kids[0],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.secondary, cs.secondaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<ChoreMemberSchedule>>(
            stream: app.watchAllChoreSchedules(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final schedules = snapshot.data!;
              final chores = app.chores;
              final week = _buildWeekForKid(
                kid: selectedKid,
                schedules: schedules,
                chores: chores,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kid selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: kids.map((kid) {
                        final selected = kid.id == selectedKid.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(kid.displayName),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedKidId = kid.id);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      'This week for ${selectedKid.displayName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: week.length,
                      itemBuilder: (context, index) {
                        final dayInfo = week[index];
                        final choresForDay = dayInfo.chores;
                        final date = dayInfo.date;

                        final weekdayLabel = _weekdayLabel(
                          date.weekday,
                        ); // Mon, Tue...
                        final dateLabel = '${date.month}/${date.day}'; // 12/10

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: .6),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      weekdayLabel,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      dateLabel,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '${choresForDay.length} chore${choresForDay.length == 1 ? '' : 's'}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: cs.onPrimaryContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (choresForDay.isEmpty)
                                  Text(
                                    'No chores scheduled.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  )
                                else
                                  Column(
                                    children: choresForDay.map((c) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: cs.primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                c.icon?.isNotEmpty == true
                                                    ? c.icon!
                                                    : '🧩',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                c.title,
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
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
        ),
      ),
    );
  }

  // Build Mon–Sun for the current week for this kid
  List<_DayChoreInfo> _buildWeekForKid({
    required Member kid,
    required List<ChoreMemberSchedule> schedules,
    required List<Chore> chores,
  }) {
    final choreById = {for (final c in chores) c.id: c};

    final now = DateTime.now();
    // Start of week: Monday
    final startOfWeek = now.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    final days = List.generate(
      7,
      (i) => DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i),
    );

    final kidSchedules = schedules
        .where((s) => s.active && s.memberId == kid.id)
        .toList();

    final result = <_DayChoreInfo>[];

    for (final d in days) {
      final List<Chore> choresForDay = [];
      for (final s in kidSchedules) {
        if (_scheduleOccursOnDate(s.recurrence, d)) {
          final chore = choreById[s.choreId];
          if (chore != null && chore.active) {
            choresForDay.add(chore);
          }
        }
      }
      result.add(_DayChoreInfo(date: d, chores: choresForDay));
    }

    return result;
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

class _DayChoreInfo {
  final DateTime date;
  final List<Chore> chores;
  const _DayChoreInfo({required this.date, required this.chores});
}
