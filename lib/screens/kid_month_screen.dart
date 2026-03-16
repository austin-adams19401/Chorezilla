// lib/screens/kid_month_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/components/day_detail_sheet.dart';
import 'package:chorezilla/components/premium_upgrade_sheet.dart';
import 'package:chorezilla/models/history.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/services/subscription_service.dart';
import 'package:chorezilla/state/app_state.dart';

class KidMonthScreen extends StatefulWidget {
  final Member member;
  final int avatarIndex;

  const KidMonthScreen({
    super.key,
    required this.member,
    required this.avatarIndex,
  });

  @override
  State<KidMonthScreen> createState() => _KidMonthScreenState();
}

class _KidMonthScreenState extends State<KidMonthScreen> {
  late DateTime _monthStart;
  // Cached to avoid calling context.read in dispose(), which is unsafe.
  late AppState _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonth());
  }

  @override
  void dispose() {
    _appState.stopWatchingMonthRange();
    super.dispose();
  }

  void _loadMonth() {
    if (!mounted) return;
    context.read<AppState>().watchHistoryMonthRange(_monthStart);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _monthStart = DateTime(_monthStart.year, _monthStart.month + delta, 1);
    });
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    final isPremium = app.family?.isPremium ?? false;
    final today = normalizeDate(DateTime.now());
    final cutoffDate = isPremium
        ? null
        : today.subtract(
            const Duration(days: SubscriptionLimits.freeHistoryDays),
          );

    final firstDay = _monthStart;
    final lastDay = DateTime(_monthStart.year, _monthStart.month + 1, 0);
    final isCurrentMonth =
        _monthStart.year == today.year && _monthStart.month == today.month;

    // Month summary stats
    int completed = 0, missed = 0, excused = 0;
    for (
      var d = firstDay;
      !d.isAfter(lastDay);
      d = d.add(const Duration(days: 1))
    ) {
      if (d.isAfter(today)) continue;
      final locked = cutoffDate != null && d.isBefore(cutoffDate);
      if (locked) continue;
      final status = app.dayStatusForRange(widget.member.id, d);
      if (status == DayStatus.completed) {
        completed++;
      } else if (status == DayStatus.missed) {
        missed++;
      } else if (status == DayStatus.excused) {
        excused++;
      }
    }

    return Scaffold(
      backgroundColor: cs.surface,
      // No default AppBar — we draw a custom gradient header instead.
      body: Column(
        children: [
          // ── Gradient header ───────────────────────────────────────────────
          _MonthHeader(
            member: widget.member,
            avatarIndex: widget.avatarIndex,
            monthStart: _monthStart,
            isCurrentMonth: isCurrentMonth,
            topInset: media.padding.top,
            onBack: () => Navigator.of(context).pop(),
            onPrev: () => _shiftMonth(-1),
            onNext: isCurrentMonth ? null : () => _shiftMonth(1),
          ),

          // ── Stats row ─────────────────────────────────────────────────────
          _StatsRow(
            completed: completed,
            missed: missed,
            excused: excused,
          ),

          // ── Calendar grid ─────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _MonthGrid(
                monthStart: firstDay,
                monthEnd: lastDay,
                today: today,
                cutoffDate: cutoffDate,
                getStatus: (date) =>
                    app.dayStatusForRange(widget.member.id, date),
                onDayTap: (date) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) =>
                        DayDetailSheet(member: widget.member, date: date),
                  );
                },
              ),
            ),
          ),

          // ── Free-tier upsell banner ───────────────────────────────────────
          if (!isPremium)
            _UpgradeBanner(
              onTap: () => showPremiumUpgradeSheet(
                context,
                reason: UpgradeReason.history,
              ),
            ),

          SizedBox(height: media.padding.bottom),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient header
// ─────────────────────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final Member member;
  final int avatarIndex;
  final DateTime monthStart;
  final bool isCurrentMonth;
  final double topInset;
  final VoidCallback onBack;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  const _MonthHeader({
    required this.member,
    required this.avatarIndex,
    required this.monthStart,
    required this.isCurrentMonth,
    required this.topInset,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final backgrounds = [
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.errorContainer,
    ];
    final foregrounds = [
      cs.onPrimaryContainer,
      cs.onSecondaryContainer,
      cs.onTertiaryContainer,
      cs.onErrorContainer,
    ];
    final avatarBg = backgrounds[avatarIndex % backgrounds.length];
    final avatarFg = foregrounds[avatarIndex % foregrounds.length];
    final initial = member.displayName.isNotEmpty
        ? member.displayName.characters.first.toUpperCase()
        : '?';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(4, topInset + 4, 8, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.secondary, cs.secondary, cs.primary],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: onBack,
              ),
              const Spacer(),
            ],
          ),

          // Avatar + name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarBg,
                  child: Text(
                    initial,
                    style: ts.titleLarge?.copyWith(
                      color: avatarFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: ts.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Monthly history',
                      style: ts.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: Colors.white,
                onPressed: onPrev,
              ),
              Text(
                DateFormat('MMMM yyyy').format(monthStart),
                style: ts.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: onNext != null
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                ),
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int completed;
  final int missed;
  final int excused;

  const _StatsRow({
    required this.completed,
    required this.missed,
    required this.excused,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _StatTile(
            icon: Icons.check_circle_rounded,
            count: completed,
            label: 'Completed',
            color: cs.primary,
          ),
          _VertDivider(),
          _StatTile(
            icon: Icons.cancel_rounded,
            count: missed,
            label: 'Missed',
            color: cs.error,
          ),
          _VertDivider(),
          _StatTile(
            icon: Icons.event_busy_rounded,
            count: excused,
            label: 'Excused',
            color: cs.tertiary,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: ts.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 40,
      color: cs.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month grid
// ─────────────────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final DateTime monthStart;
  final DateTime monthEnd;
  final DateTime today;
  final DateTime? cutoffDate;
  final DayStatus Function(DateTime) getStatus;
  final void Function(DateTime) onDayTap;

  const _MonthGrid({
    required this.monthStart,
    required this.monthEnd,
    required this.today,
    required this.cutoffDate,
    required this.getStatus,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final calStart = weekStartFor(monthStart);
    final calEnd = weekStartFor(monthEnd).add(const Duration(days: 6));

    const dayHeaders = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final rows = <List<DateTime>>[];
    var cursor = calStart;
    while (!cursor.isAfter(calEnd)) {
      final row = <DateTime>[];
      for (var i = 0; i < 7; i++) {
        row.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
      rows.add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Day-of-week header
        Row(
          children: dayHeaders
              .map(
                (h) => Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        h,
                        style: ts.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),

        // Divider below header
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),

        // Week rows
        for (var ri = 0; ri < rows.length; ri++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows[ri].map((date) {
              final inMonth =
                  !date.isBefore(monthStart) && !date.isAfter(monthEnd);
              final isFuture = date.isAfter(today);
              final isToday = date == today;
              final isLocked =
                  cutoffDate != null && date.isBefore(cutoffDate!);

              return Expanded(
                child: _DayCell(
                  date: date,
                  inMonth: inMonth,
                  isToday: isToday,
                  isFuture: isFuture,
                  isLocked: isLocked,
                  status: getStatus(date),
                  onTap: () => onDayTap(date),
                ),
              );
            }).toList(),
          ),
          if (ri < rows.length - 1)
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.2),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day cell
// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isFuture;
  final bool isLocked;
  final DayStatus status;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isFuture,
    required this.isLocked,
    required this.status,
    required this.onTap,
  });

  Color? _bgColor(ColorScheme cs) {
    if (!inMonth || isFuture || isLocked) return null;
    switch (status) {
      case DayStatus.completed:
        return cs.primaryContainer.withValues(alpha: 0.45);
      case DayStatus.missed:
        return cs.errorContainer.withValues(alpha: 0.35);
      case DayStatus.excused:
        return cs.tertiaryContainer.withValues(alpha: 0.35);
      case DayStatus.noChores:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final tappable = inMonth && !isFuture && !isLocked;
    final bg = _bgColor(cs);

    return Material(
      color: bg ?? Colors.transparent,
      child: InkWell(
        onTap: tappable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date circle (highlighted for today)
              Container(
                width: 30,
                height: 30,
                decoration: isToday
                    ? BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: ts.bodyMedium?.copyWith(
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? cs.onPrimary
                          : !inMonth || isFuture
                              ? cs.onSurface.withValues(alpha: 0.25)
                              : cs.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Status dot
              _StatusIndicator(
                status: status,
                inMonth: inMonth,
                isFuture: isFuture,
                isLocked: isLocked,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final DayStatus status;
  final bool inMonth;
  final bool isFuture;
  final bool isLocked;

  const _StatusIndicator({
    required this.status,
    required this.inMonth,
    required this.isFuture,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isLocked) {
      return Icon(
        Icons.lock_rounded,
        size: 12,
        color: cs.onSurface.withValues(alpha: 0.2),
      );
    }

    if (!inMonth || isFuture) return const SizedBox(height: 12);

    switch (status) {
      case DayStatus.completed:
        return _Dot(color: cs.primary);
      case DayStatus.missed:
        return _Dot(color: cs.error);
      case DayStatus.excused:
        return _Dot(color: cs.tertiary);
      case DayStatus.noChores:
        return const SizedBox(height: 12);
    }
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Free-tier upsell banner
// ─────────────────────────────────────────────────────────────────────────────

class _UpgradeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _UpgradeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Material(
      color: cs.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 18,
                color: cs.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upgrade to see your full history beyond 14 days',
                  style: ts.labelMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
