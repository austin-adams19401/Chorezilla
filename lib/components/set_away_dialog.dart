import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';

Future<void> showSetAwayDialog(
  BuildContext context, {
  required String memberId,
  required String memberName,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _SetAwayDialog(
      memberId: memberId,
      memberName: memberName,
    ),
  );
}

class _SetAwayDialog extends StatefulWidget {
  const _SetAwayDialog({
    required this.memberId,
    required this.memberName,
  });

  final String memberId;
  final String memberName;

  @override
  State<_SetAwayDialog> createState() => _SetAwayDialogState();
}

class _SetAwayDialogState extends State<_SetAwayDialog> {
  DateTime? _returnDate;
  bool _recurring = false;
  int _intervalDays = 14;
  bool _customInterval = false;
  final _customController = TextEditingController();
  bool _saving = false;

  static const _intervalPresets = [
    (label: 'Every week', days: 7),
    (label: 'Every 2 weeks', days: 14),
    (label: 'Every 3 weeks', days: 21),
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _pickReturnDate() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select return date',
    );
    if (picked != null) {
      setState(() => _returnDate = picked);
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _buildSummary() {
    if (_returnDate == null) return '';
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final until = DateTime(_returnDate!.year, _returnDate!.month, _returnDate!.day);
    final durationDays = until.difference(start).inDays + 1;

    if (!_recurring) {
      return 'Away for $durationDays day${durationDays == 1 ? '' : 's'}, returns ${_formatDate(_returnDate!)}';
    }
    return 'Away $durationDays day${durationDays == 1 ? '' : 's'} every $_intervalDays days';
  }

  Future<void> _confirm() async {
    if (_returnDate == null) return;
    setState(() => _saving = true);

    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);

    try {
      await context.read<AppState>().setMemberAway(
        memberId: widget.memberId,
        startDate: startDate,
        returnDate: _returnDate!,
        recurring: _recurring,
        intervalDays: _recurring ? _intervalDays : null,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final summary = _buildSummary();

    return AlertDialog(
      title: Text('Set ${widget.memberName} Away'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chores will be excused and streaks preserved while away.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Return date picker
            Text('Return date', style: ts.labelLarge),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickReturnDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(
                _returnDate != null
                    ? _formatDate(_returnDate!)
                    : 'Pick a date',
              ),
            ),

            const SizedBox(height: 16),

            // Recurring toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recurring schedule', style: ts.labelLarge),
                      Text(
                        'Repeats on the same pattern',
                        style: ts.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _recurring,
                  onChanged: (v) => setState(() => _recurring = v),
                ),
              ],
            ),

            // Interval picker — only when recurring
            if (_recurring) ...[
              const SizedBox(height: 12),
              Text('Repeat every', style: ts.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._intervalPresets.map(
                    (p) => ChoiceChip(
                      label: Text(p.label),
                      selected: !_customInterval && _intervalDays == p.days,
                      onSelected: (_) => setState(() {
                        _intervalDays = p.days;
                        _customInterval = false;
                      }),
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Custom'),
                    selected: _customInterval,
                    onSelected: (_) => setState(() => _customInterval = true),
                  ),
                ],
              ),
              if (_customInterval) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Days',
                      suffixText: 'days',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) {
                        setState(() => _intervalDays = n);
                      }
                    },
                  ),
                ),
              ],
            ],

            // Summary line
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flight_takeoff_rounded,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary,
                        style: ts.bodySmall?.copyWith(color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_returnDate == null || _saving) ? null : _confirm,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Set Away'),
        ),
      ],
    );
  }
}
