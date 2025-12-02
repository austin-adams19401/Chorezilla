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

    // Make sure we're streaming assignments for this week
    app.watchHistoryWeek(_weekStart);

    // Build history based on current assignments + overrides
    final histories = app.buildWeeklyHistory(_weekStart);
    final weekEnd = _weekStart.add(const Duration(days: 6));

    // Fire-and-forget: if this is a *past* week and kids earned
    // allowance, auto-create pending allowance rewards.
    app.ensureAllowanceRewardsForWeekIfEligible(_weekStart);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekHeader(
          weekStart: _weekStart,
          weekEnd: weekEnd,
          onPrevWeek: () => _shiftWeek(-1),
          onNextWeek: () => _shiftWeek(1),
        ),
        const Divider(height: 1),
        Expanded(
          child: histories.isEmpty
              ? const Center(child: Text('No kids to show yet.'))
              : ListView.builder(
                  itemCount: histories.length,
                  itemBuilder: (context, index) {
                    final history = histories[index];
                    return _KidHistoryCard(
                      history: history,
                      weekStart: _weekStart,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _WeekHeader extends StatelessWidget {
  final DateTime weekStart;
  final DateTime weekEnd;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;

  const _WeekHeader({
    required this.weekStart,
    required this.weekEnd,
    required this.onPrevWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd();
    final label = '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevWeek,
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextWeek,
          ),
        ],
      ),
    );
  }
}

class _KidHistoryCard extends StatelessWidget {
  final WeeklyKidHistory history;
  final DateTime weekStart;

  const _KidHistoryCard({required this.history, required this.weekStart});

  @override
  Widget build(BuildContext context) {
    final member = history.member;
    final allowanceConfig = history.allowanceConfig;
    final allowanceResult = history.allowanceResult;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name + help + allowance toggle
            Row(
              children: [
                _MemberAvatar(member: member),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded, size: 20),
                  tooltip: 'How this weekly view works',
                  onPressed: () => _showHistoryHelpDialog(context),
                ),
                _AllowanceToggle(
                  member: member,
                  allowanceConfig: allowanceConfig,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DayRow(history: history, weekStart: weekStart),
            if (allowanceConfig.enabled) ...[
              const SizedBox(height: 8),
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
    // Swap this for your actual avatar widget.
    return CircleAvatar(
      radius: 18,
      child: Text(
        member.displayName.isNotEmpty
            ? member.displayName[0].toUpperCase()
            : '?',
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
    return Row(
      children: List.generate(7, (i) {
        final date = weekStart.add(Duration(days: i));
        final status = history.dayStatuses[i];

        return Expanded(
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) {
                  return _DayDetailSheet(member: history.member, date: date);
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdayShort(date.weekday),
                    style: Theme.of(context).textTheme.labelSmall,
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
            Text(
              '${widget.member.displayName} – ${fmt.format(widget.date)}',
              style: Theme.of(context).textTheme.titleMedium,
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
              child: ElevatedButton(
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
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
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
                style: theme.textTheme.titleMedium,
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
                child: ElevatedButton(
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

    final full = config.fullAmountCents / 100.0;
    final payout = (result?.payoutCents ?? 0) / 100.0;
    final ratio = result?.ratio ?? 0.0;
    final effectiveDays = result?.effectiveDays ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
        const SizedBox(height: 4),
        Text(
          '$effectiveDays/${config.daysRequiredForFull} days '
          '→ \$${payout.toStringAsFixed(2)} of \$${full.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Help dialog for history / allowance
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
