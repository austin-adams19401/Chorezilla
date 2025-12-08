// lib/pages/parent_dashboard/parent_history_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/history.dart';
import 'package:chorezilla/models/member.dart';

class ParentHistoryTab extends StatefulWidget {
  const ParentHistoryTab({super.key});

  @override
  State<ParentHistoryTab> createState() => _ParentHistoryTabState();
}

class _ParentHistoryTabState extends State<ParentHistoryTab> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = weekStartFor(DateTime.now());
  }

  void _shiftWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    // Make sure we're streaming assignments for this week
    app.watchHistoryWeek(_weekStart);

    // Build history based on current assignments + overrides
    final histories = app.buildWeeklyHistory(_weekStart);
    final weekEnd = _weekStart.add(const Duration(days: 6));

    // Fire-and-forget: if this is a *past* week and kids earned
    // allowance, auto-create pending allowance rewards.
    app.ensureAllowanceRewardsForWeekIfEligible(_weekStart);

    // Summary stats for hero
    final kidCount = histories.length;
    final totalDays = histories.fold<int>(
      0,
      (sum, h) => sum + h.dayStatuses.length,
    );
    final completedDays = histories.fold<int>(
      0,
      (sum, h) =>
          sum + h.dayStatuses.where((s) => s == DayStatus.completed).length,
    );
    final completionRatio = totalDays > 0 ? completedDays / totalDays : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HistoryHero(
          weekStart: _weekStart,
          weekEnd: weekEnd,
          kidCount: kidCount,
          completedDays: completedDays,
          totalDays: totalDays,
          completionRatio: completionRatio,
          onPrevWeek: () => _shiftWeek(-1),
          onNextWeek: () => _shiftWeek(1),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
            child: Container(
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: histories.isEmpty
                  ? const _EmptyHistory()
                  : ListView.separated(
                      itemCount: histories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final history = histories[index];
                        return _KidHistoryCard(
                          history: history,
                          weekStart: _weekStart,
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header (gradient, like Today / Rewards)
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryHero extends StatelessWidget {
  const _HistoryHero({
    required this.weekStart,
    required this.weekEnd,
    required this.kidCount,
    required this.completedDays,
    required this.totalDays,
    required this.completionRatio,
    required this.onPrevWeek,
    required this.onNextWeek,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final int kidCount;
  final int completedDays;
  final int totalDays;
  final double completionRatio;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final media = MediaQuery.of(context);
    final double topInset = media.padding.top;

    final fmt = DateFormat.MMMd();
    final weekLabel = '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}';
    final kidsLabel = kidCount == 0
        ? 'No kids yet'
        : kidCount == 1
        ? '1 kid'
        : '$kidCount kids';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 4, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.secondary, cs.secondary, cs.primary],
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
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly check-in',
                    style: ts.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See how the week went and what each kid earned.',
                    style: ts.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),

                  // Week selector row
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        color: Colors.white,
                        onPressed: onPrevWeek,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            weekLabel,
                            style: ts.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        color: Colors.white,
                        onPressed: onNextWeek,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Kids + weekly completion bar
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
                          style: ts.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (totalDays > 0)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(
                                value: completionRatio.clamp(0.0, 1.0),
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
                                '$completedDays of $totalDays good days',
                                style: ts.labelSmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: () => _showHistoryHelpDialog(context),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: const Text('How this works'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

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
            Text('📅', style: ts.displaySmall),
            const SizedBox(height: 8),
            Text(
              'No kids to show yet',
              style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Once you add kids and start assigning chores,\n'
              'you\'ll see their weekly history here.',
              textAlign: TextAlign.center,
              style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kid history card
// ─────────────────────────────────────────────────────────────────────────────

class _KidHistoryCard extends StatelessWidget {
  final WeeklyKidHistory history;
  final DateTime weekStart;

  const _KidHistoryCard({required this.history, required this.weekStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final member = history.member;
    final allowanceConfig = history.allowanceConfig;
    final allowanceResult = history.allowanceResult;

    final completedDays = history.dayStatuses
        .where((s) => s == DayStatus.completed)
        .length;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      color: cs.surface,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.surfaceContainerHighest.withValues(alpha: 0.18),
              cs.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name + allowance toggle
            Row(
              children: [
                _MemberAvatar(member: member),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: ts.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$completedDays of 7 good days',
                        style: ts.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _AllowanceToggle(
                  member: member,
                  allowanceConfig: allowanceConfig,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Day row
            _DayRow(history: history, weekStart: weekStart),

            // Allowance summary (if enabled)
            if (allowanceConfig.enabled) ...[
              const SizedBox(height: 10),
              _AllowanceSummary(
                config: allowanceConfig,
                result: allowanceResult,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final Member member;
  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final initial = member.displayName.isNotEmpty
        ? member.displayName.characters.first.toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 18,
      backgroundColor: cs.primaryContainer,
      child: Text(
        initial,
        style: ts.titleMedium?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final WeeklyKidHistory history;
  final DateTime weekStart;

  const _DayRow({required this.history, required this.weekStart});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(7, (i) {
        final date = weekStart.add(Duration(days: i));
        final status = history.dayStatuses[i];

        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) {
                  return _DayDetailSheet(member: history.member, date: date);
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdayShort(date.weekday),
                    style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  _DayStatusIcon(status: status),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

String _weekdayShort(int weekday) {
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
      return 'Sun';
    default:
      return '';
  }
}

class _DayStatusIcon extends StatelessWidget {
  final DayStatus status;

  const _DayStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    IconData icon;
    Color color;

    switch (status) {
      case DayStatus.completed:
        icon = Icons.check_circle;
        color = scheme.primary;
        break;
      case DayStatus.missed:
        icon = Icons.cancel;
        color = scheme.error;
        break;
      case DayStatus.excused:
        icon = Icons.event_busy;
        color = scheme.tertiary;
        break;
      case DayStatus.noChores:
        icon = Icons.remove_circle_outline;
        color = scheme.onSurface.withValues(alpha: .3);
        break;
    }

    return Icon(icon, size: 20, color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day detail sheet (status picker)
// ─────────────────────────────────────────────────────────────────────────────

class _DayDetailSheet extends StatefulWidget {
  final Member member;
  final DateTime date;

  const _DayDetailSheet({required this.member, required this.date});

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  late DayStatus _status;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final current = app.dayStatusFor(widget.member.id, widget.date);
    // Default to "completed" if there's no status yet.
    _status = current == DayStatus.noChores ? DayStatus.completed : current;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMEd();
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              '${widget.member.displayName} – ${fmt.format(widget.date)}',
              style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            /// RadioGroup manages groupValue & onChanged
            RadioGroup<DayStatus>(
              groupValue: _status,
              onChanged: (DayStatus? value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<DayStatus>(
                    value: DayStatus.completed,
                    title: const Text('Completed (all chores done)'),
                  ),
                  RadioListTile<DayStatus>(
                    value: DayStatus.missed,
                    title: const Text('Missed (chores not completed)'),
                  ),
                  RadioListTile<DayStatus>(
                    value: DayStatus.excused,
                    title: const Text('Excused (doesn\'t count against them)'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final app = context.read<AppState>();
                  await app.setDayStatus(
                    memberId: widget.member.id,
                    date: widget.date,
                    status: _status,
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Allowance controls
// ─────────────────────────────────────────────────────────────────────────────

class _AllowanceToggle extends StatelessWidget {
  final Member member;
  final AllowanceConfig allowanceConfig;

  const _AllowanceToggle({required this.member, required this.allowanceConfig});

  @override
  Widget build(BuildContext context) {
    final enabled = allowanceConfig.enabled;
    final amount = allowanceConfig.fullAmountCents > 0
        ? allowanceConfig.fullAmountCents / 100.0
        : 0.0;

    final label = enabled
        ? '\$${amount.toStringAsFixed(2)}/wk'
        : 'No allowance';

    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Switch: OFF = disable immediately, ON = open config sheet
        Switch(
          value: enabled,
          onChanged: (value) {
            if (!value) {
              // Turning OFF → just disable, no sheet
              final app = context.read<AppState>();
              app.updateAllowanceForMember(
                member.id,
                allowanceConfig.copyWith(enabled: false),
              );
            } else {
              // Turning ON → open config sheet
              _showConfigSheet(context);
            }
          },
        ),
        const SizedBox(width: 4),
        // Tap the label to edit config any time
        InkWell(
          onTap: () => _showConfigSheet(context),
          child: Text(
            label,
            style: ts.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _AllowanceConfigSheet(
          member: member,
          initialConfig: allowanceConfig,
        );
      },
    );
  }
}

class _AllowanceConfigSheet extends StatefulWidget {
  final Member member;
  final AllowanceConfig initialConfig;

  const _AllowanceConfigSheet({
    required this.member,
    required this.initialConfig,
  });

  @override
  State<_AllowanceConfigSheet> createState() => _AllowanceConfigSheetState();
}

class _AllowanceConfigSheetState extends State<_AllowanceConfigSheet> {
  late TextEditingController _amountController;
  late TextEditingController _daysRequiredController;
  late int _payDay;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialConfig.fullAmountCents > 0
          ? (widget.initialConfig.fullAmountCents / 100.0).toStringAsFixed(2)
          : '',
    );
    _daysRequiredController = TextEditingController(
      text: widget.initialConfig.daysRequiredForFull.toString(),
    );
    _payDay = widget.initialConfig.payDay;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _daysRequiredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Allowance for ${widget.member.displayName}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Full weekly amount',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _daysRequiredController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Days required for full allowance',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _payDay,
                decoration: const InputDecoration(labelText: 'Pay day'),
                items: const [
                  DropdownMenuItem(
                    value: DateTime.monday,
                    child: Text('Monday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.tuesday,
                    child: Text('Tuesday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.wednesday,
                    child: Text('Wednesday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.thursday,
                    child: Text('Thursday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.friday,
                    child: Text('Friday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.saturday,
                    child: Text('Saturday'),
                  ),
                  DropdownMenuItem(
                    value: DateTime.sunday,
                    child: Text('Sunday'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _payDay = v);
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final app = context.read<AppState>();

                    final amountStr = _amountController.text.trim();
                    final parsedAmount = double.tryParse(amountStr);
                    final amountCents = parsedAmount != null
                        ? (parsedAmount * 100).round()
                        : 0;

                    final daysRequired =
                        int.tryParse(_daysRequiredController.text.trim()) ?? 7;

                    // Saving from this sheet always ENABLES allowance.
                    final config = widget.initialConfig.copyWith(
                      enabled: true,
                      fullAmountCents: amountCents,
                      daysRequiredForFull: daysRequired,
                      payDay: _payDay,
                    );

                    app.updateAllowanceForMember(widget.member.id, config);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllowanceSummary extends StatelessWidget {
  final AllowanceConfig config;
  final AllowanceResult? result;

  const _AllowanceSummary({required this.config, required this.result});

  @override
  Widget build(BuildContext context) {
    if (!config.enabled) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final full = config.fullAmountCents / 100.0;
    final payout = (result?.payoutCents ?? 0) / 100.0;
    final ratio = result?.ratio ?? 0.0;
    final effectiveDays = result?.effectiveDays ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.8),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$effectiveDays/${config.daysRequiredForFull} days '
          '→ \$${payout.toStringAsFixed(2)} of \$${full.toStringAsFixed(2)}',
          style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Help dialog for history / allowance (unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showHistoryHelpDialog(BuildContext context) {
  final theme = Theme.of(context);
  final ts = theme.textTheme;
  final cs = theme.colorScheme;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Weekly history & allowance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Each card shows one kid’s week at a glance.',
            style: ts.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '• Tap a day to mark it as completed, missed, or excused.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• Icons: check = good day, X = missed, calendar with dash = excused, hollow circle = no chores.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• The green bar at the bottom shows how much allowance they earned for this week.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• Turn allowance on/off and edit the rules with the toggle on the right.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• For past weeks where allowance is enabled, the app can create a “weekly allowance” reward in the Rewards tab.',
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
