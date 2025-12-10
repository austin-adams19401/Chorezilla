// lib/pages/parent_dashboard/chore_schedule_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/recurrance.dart';
import 'package:chorezilla/models/chore_member_schedule.dart';

class ChoreSchedulePage extends StatelessWidget {
  final Chore chore;

  const ChoreSchedulePage({super.key, required this.chore});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final familyId = app.familyId;
    if (familyId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // All active kids in this family
    final kids = app.members
        .where((m) => m.role == FamilyRole.child && m.active)
        .toList();

    final schedulesStream = app.watchChoreSchedulesForChore(chore.id);

    // 🔹 Define the gradient once
    final gradient = LinearGradient(
      colors: [cs.secondary, cs.secondary, cs.primary],
      stops: const [0.0, 0.55, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Container(
      decoration: BoxDecoration(gradient: gradient), 
      child: Scaffold(
        backgroundColor:
            Colors.transparent, 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: cs.onSecondary,
          elevation: 0,
          title: Text(
            'Schedule "${chore.title}"',
            style: TextStyle(color: cs.onSecondary),
          ),
        ),
        body: _buildBody(kids, schedulesStream, cs),
      ),
    );
  }


  Widget _buildBody(
    List<Member> kids,
    Stream<List<ChoreMemberSchedule>> schedulesStream,
    ColorScheme cs,
  ) {
    return StreamBuilder<List<ChoreMemberSchedule>>(
      stream: schedulesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedules = snapshot.data!;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              color: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KidScheduleList(
                      chore: chore,
                      kids: kids,
                      schedules: schedules,
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: WeeklyChoreSummary(
                        kids: kids,
                        schedules: schedules,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly summary: which kids are on which weekday
// ─────────────────────────────────────────────────────────────────────────────

class WeeklyChoreSummary extends StatelessWidget {
  final List<Member> kids;
  final List<ChoreMemberSchedule> schedules;

  const WeeklyChoreSummary({
    super.key,
    required this.kids,
    required this.schedules,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // memberId -> Member
    final memberById = {for (final m in kids) m.id: m};

    // memberId -> set of weekdays (1=Mon..7=Sun)
    final Map<String, Set<int>> memberToDays = {};

    for (final s in schedules.where((s) => s.active)) {
      final member = memberById[s.memberId];
      if (member == null) continue;

      final r = s.recurrence;
      final daysSet = memberToDays.putIfAbsent(member.id, () => <int>{});

      switch (r.type) {
        case 'daily':
          for (int d = 1; d <= 7; d++) {
            daysSet.add(d);
          }
          break;
        case 'weekly':
          final days = r.daysOfWeek ?? const [];
          daysSet.addAll(days);
          break;
        // For 'once' and 'custom' we’re not projecting into the weekly grid (yet).
        default:
          break;
      }
    }

    final assignedKids = kids
        .where((m) => (memberToDays[m.id] ?? const <int>{}).isNotEmpty)
        .toList();

    if (assignedKids.isEmpty) {
      return Text(
        'No weekly pattern yet. Assign this chore to a kid to see their week.',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Weekly pattern',
          style: theme.textTheme.titleMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Header row
        Row(
          children: [
            // Kid column header (blank or say "Kid")
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Kid',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < 7; i++)
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    labels[i],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // One row per kid
        for (final kid in assignedKids) ...[
          Row(
            children: [
              // Kid cell
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      child: Text(
                        _initialsFor(kid.displayName),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kid.displayName,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Day cells
              for (var day = 1; day <= 7; day++)
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 28,
                    child: Center(
                      child: (memberToDays[kid.id]?.contains(day) ?? false)
                          ? Icon(
                              Icons.check_circle,
                              size: 16,
                              color: cs.primary,
                            )
                          : Icon(
                              Icons.radio_button_unchecked,
                              size: 14,
                              color: cs.outlineVariant,
                            ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  static String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Kid list + schedule summaries
// ─────────────────────────────────────────────────────────────────────────────

class KidScheduleList extends StatelessWidget {
  final Chore chore;
  final List<Member> kids;
  final List<ChoreMemberSchedule> schedules;

  const KidScheduleList({
    super.key,
    required this.chore,
    required this.kids,
    required this.schedules,
  });

  @override
  Widget build(BuildContext context) {
    // If you later allow multiple schedules per kid, you’ll adapt this.
    final Map<String, ChoreMemberSchedule> scheduleByMember = {
      for (final s in schedules.where((s) => s.active)) s.memberId: s,
    };

    return ListView.separated(
      shrinkWrap: true, 
      physics:
          const NeverScrollableScrollPhysics(), 
      padding: const EdgeInsets.all(16),
      itemCount: kids.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final kid = kids[index];
        final schedule = scheduleByMember[kid.id];

        final summary = schedule == null
            ? 'Not scheduled'
            : _recurrenceSummary(schedule.recurrence);

        final isScheduled = schedule != null;

        return ListTile(
          leading: CircleAvatar(child: Text(_initialsFor(kid.displayName))),
          title: Text(kid.displayName),
          subtitle: Text(summary),
          trailing: TextButton(
            child: Text(isScheduled ? 'Edit' : 'Assign'),
            onPressed: () {
              _openEditorSheet(
                context: context,
                chore: chore,
                kid: kid,
                existing: schedule,
              );
            },
          ),
          onTap: () {
            _openEditorSheet(
              context: context,
              chore: chore,
              kid: kid,
              existing: schedule,
            );
          },
        );
      },
    );
  }

  void _openEditorSheet({
    required BuildContext context,
    required Chore chore,
    required Member kid,
    required ChoreMemberSchedule? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          KidScheduleEditorSheet(chore: chore, kid: kid, existing: existing),
    );
  }

  static String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static String _recurrenceSummary(Recurrence r) {
    switch (r.type) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        final days = r.daysOfWeek ?? const [];
        if (days.isEmpty) return 'Weekly';
        return _formatDaysOfWeek(days);
      case 'once':
        return 'Once';
      case 'custom':
        if (r.intervalDays != null) {
          final n = r.intervalDays!;
          return 'Every $n day${n == 1 ? '' : 's'}';
        }
        return 'Custom schedule';
      default:
        return 'Custom schedule';
    }
  }

  static String _formatDaysOfWeek(List<int> days) {
    // 1=Mon..7=Sun
    const names = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final labels = days
        .where((d) => names.containsKey(d))
        .map((d) => names[d]!)
        .toList();
    return labels.join(', ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule editor bottom sheet (per kid)
// ─────────────────────────────────────────────────────────────────────────────

enum FrequencyOption { once, daily, weekly, custom }

class KidScheduleEditorSheet extends StatefulWidget {
  final Chore chore;
  final Member kid;
  final ChoreMemberSchedule? existing;

  const KidScheduleEditorSheet({
    super.key,
    required this.chore,
    required this.kid,
    this.existing,
  });

  @override
  State<KidScheduleEditorSheet> createState() => _KidScheduleEditorSheetState();
}

class _KidScheduleEditorSheetState extends State<KidScheduleEditorSheet> {
  late FrequencyOption _frequency;
  late Set<int> _daysOfWeek; // 1=Mon..7=Sun
  int _intervalDays = 2;
  DateTime _startDate = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      _frequency = FrequencyOption.daily;
      _daysOfWeek = {1, 2, 3, 4, 5}; // M-F default
    } else {
      final r = existing.recurrence;
      switch (r.type) {
        case 'once':
          _frequency = FrequencyOption.once;
          break;
        case 'daily':
          _frequency = FrequencyOption.daily;
          break;
        case 'weekly':
          _frequency = FrequencyOption.weekly;
          break;
        case 'custom':
          _frequency = FrequencyOption.custom;
          break;
        default:
          _frequency = FrequencyOption.daily;
      }
      _daysOfWeek = (r.daysOfWeek ?? const []).toSet();
      _intervalDays = r.intervalDays ?? 2;
      _startDate = r.startDate ?? DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.kid.displayName, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Schedule for "${widget.chore.title}"',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Frequency radio options
              Column(
                children: [
                  RadioGroup<FrequencyOption>(
                    groupValue: _frequency,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _frequency = value);
                    },
                    child: Column(
                      children: [
                        RadioListTile<FrequencyOption>(
                          title: const Text('Once'),
                          value: FrequencyOption.once,
                          selected: _frequency == FrequencyOption.once,
                        ),
                        RadioListTile<FrequencyOption>(
                          title: const Text('Every day'),
                          value: FrequencyOption.daily,
                          selected: _frequency == FrequencyOption.daily,
                        ),
                        RadioListTile<FrequencyOption>(
                          title: const Text('Specific days each week'),
                          value: FrequencyOption.weekly,
                          selected: _frequency == FrequencyOption.weekly,
                        ),
                        RadioListTile<FrequencyOption>(
                          title: const Text('Every X days'),
                          value: FrequencyOption.custom,
                          selected: _frequency == FrequencyOption.custom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (_frequency == FrequencyOption.once)
                _buildOnceDatePicker(theme),

              if (_frequency == FrequencyOption.weekly)
                _buildWeeklyDayPicker(theme),

              if (_frequency == FrequencyOption.custom)
                _buildCustomIntervalPicker(theme),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.existing != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: _busy ? null : _handleClearSchedule,
                      child: const Text('Remove'),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _busy ? null : _handleSave,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnceDatePicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pick a date', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('On'),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
              child: Text(
                '${_startDate.year}-'
                '${_startDate.month.toString().padLeft(2, '0')}-'
                '${_startDate.day.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyDayPicker(ThemeData theme) {
    const labels = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Days of week', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: labels.entries.map((e) {
            final selected = _daysOfWeek.contains(e.key);
            return ChoiceChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _daysOfWeek.add(e.key);
                  } else {
                    _daysOfWeek.remove(e.key);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomIntervalPicker(ThemeData theme) {
    final controller = TextEditingController(text: _intervalDays.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Every X days', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Every'),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    _intervalDays = parsed;
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('day(s)'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Starting'),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
              child: Text(
                '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Recurrence _buildRecurrence() {
    switch (_frequency) {
      case FrequencyOption.once:
        return Recurrence(type: 'once', startDate: _startDate);

      case FrequencyOption.daily:
        return const Recurrence(type: 'daily');

      case FrequencyOption.weekly:
        return Recurrence(
          type: 'weekly',
          daysOfWeek: _daysOfWeek.toList()..sort(),
        );

      case FrequencyOption.custom:
        return Recurrence(
          type: 'custom',
          intervalDays: _intervalDays,
          startDate: _startDate,
        );
    }
  }

  Future<void> _handleSave() async {
    final app = context.read<AppState>();
    final recurrence = _buildRecurrence();
    final existing = widget.existing;

    setState(() => _busy = true);
    try {
      await app.saveChoreMemberSchedule(
        scheduleId: existing?.id,
        choreId: widget.chore.id,
        memberId: widget.kid.id,
        recurrence: recurrence,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving schedule: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleClearSchedule() async {
    final existing = widget.existing;
    if (existing == null) return;

    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await app.deleteChoreMemberSchedule(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error removing schedule: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
