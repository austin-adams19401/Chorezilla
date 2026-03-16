// lib/components/day_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/models/history.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/state/app_state.dart';

/// Bottom sheet for viewing/overriding the day status for a single kid + date.
/// Used by both the weekly history tab and the per-kid month screen.
class DayDetailSheet extends StatefulWidget {
  final Member member;
  final DateTime date;

  const DayDetailSheet({super.key, required this.member, required this.date});

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  late DayStatus _status;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _status = app.dayStatusFor(widget.member.id, widget.date);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMEd();
    final ts = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 4,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.member.displayName} – ${fmt.format(widget.date)}',
              style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            RadioGroup<DayStatus>(
              groupValue: _status,
              onChanged: (DayStatus? value) {
                if (value != null) setState(() => _status = value);
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
                  RadioListTile<DayStatus>(
                    value: DayStatus.noChores,
                    title: const Text('Auto (based on chores completed)'),
                    subtitle: const Text('Removes any manual override'),
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
                  try {
                    await app.setDayStatus(
                      memberId: widget.member.id,
                      date: widget.date,
                      status: _status,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not save. Check your connection.'),
                      ),
                    );
                  }
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
