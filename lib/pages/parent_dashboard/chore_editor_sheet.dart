import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/recurrance.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChoreEditorSheet extends StatefulWidget {
  const ChoreEditorSheet({super.key, required this.family, this.chore});
  final Family family;
  final Chore? chore;

  @override
  State<ChoreEditorSheet> createState() => _ChoreEditorSheetState();
}

class _ChoreEditorSheetState extends State<ChoreEditorSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _icon = TextEditingController(text: '🧹');
  final int kMaxChoreTitleLength = 30;
  int _difficulty = 3;
  String _recType = 'daily'; // once | daily | weekly | custom
  final Set<int> _days = {}; // 1..7
  String? _timeOfDay;
  bool _busy = false;
  bool _requiresApproval = false;

  @override
  void initState() {
    super.initState();
    final c = widget.chore;
    if (c != null) {
      _title.text = c.title;
      _desc.text = c.description ?? '';
      _icon.text = c.icon ?? '🧹';
      _difficulty = c.difficulty;
      _recType = c.recurrence?.type ?? 'once';
      _days
        ..clear()
        ..addAll(c.recurrence?.daysOfWeek ?? const []);
      _timeOfDay = c.recurrence?.timeOfDay;
      _requiresApproval = c.requiresApproval;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _icon.dispose();
    super.dispose();
  }

  int get _xp =>
      widget.family.settings.difficultyToXP[_difficulty] ?? _difficulty * 10;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.chore != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_task_rounded),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit chore' : 'New chore',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded),
                      tooltip: 'How chores work',
                      onPressed: () => _showChoreHelpDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  maxLength: kMaxChoreTitleLength,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    helperText: 'max 40 characters',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _desc,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _icon,
                        decoration: InputDecoration(
                          labelText: 'Icon (emoji)',
                          suffixIcon: IconButton(
                            tooltip: 'Pick',
                            icon: const Icon(Icons.emoji_emotions_rounded),
                            onPressed: _openEmojiPicker,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _difficulty,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Very easy')),
                          DropdownMenuItem(value: 2, child: Text('Easy')),
                          DropdownMenuItem(value: 3, child: Text('Medium')),
                          DropdownMenuItem(value: 4, child: Text('Hard')),
                          DropdownMenuItem(value: 5, child: Text('Epic')),
                        ],
                        onChanged: (v) => setState(() => _difficulty = v ?? 2),
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Worth $_xp XP'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Requires parent approval'),
                  subtitle: const Text(
                    'Chore will need to be checked by a parent before it\'s marked complete.',
                  ),
                  value: _requiresApproval,
                  onChanged: (v) => setState(() => _requiresApproval = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final t in const [
                        'once',
                        'daily',
                        'weekly',
                        'custom',
                      ])
                        ChoiceChip(
                          label: Text(t[0].toUpperCase() + t.substring(1)),
                          selected: _recType == t,
                          onSelected: (_) => setState(() => _recType = t),
                        ),
                    ],
                  ),
                ),
                if (_recType == 'weekly' || _recType == 'custom') ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (var i = 1; i <= 7; i++)
                          FilterChip(
                            label: Text(
                              [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun',
                              ][i - 1],
                            ),
                            selected: _days.contains(i),
                            onSelected: (sel) => setState(
                              () => sel ? _days.add(i) : _days.remove(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      _timeOfDay == null
                          ? 'Pick time (optional)'
                          : 'Time: $_timeOfDay',
                    ),
                    onPressed: () async {
                      final now = TimeOfDay.now();
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: now,
                      );
                      if (picked != null) {
                        setState(() => _timeOfDay = picked.format(context));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Update chore' : 'Create chore'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEmojiPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _EmojiPicker(),
    );
    if (picked != null && mounted) {
      setState(() => _icon.text = picked);
    }
  }

  Future<void> _save() async {
    final rawTitle = _title.text.trim();
    if (rawTitle.isEmpty) return;

    final title = rawTitle.length > kMaxChoreTitleLength
        ? rawTitle.substring(0, kMaxChoreTitleLength)
        : rawTitle;

    setState(() => _busy = true);
    try {
      final app = context.read<AppState>();
      final rec = Recurrence(
        type: _recType,
        daysOfWeek: (_recType == 'weekly' || _recType == 'custom')
            ? _days.toList()
            : null,
        timeOfDay: _timeOfDay,
      );
      if (widget.chore == null) {
        await app.createChore(
          title: title,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          iconKey: _icon.text,
          difficulty: _difficulty,
          recurrence: rec,
          requiresApproval: _requiresApproval,
        );
      } else {
        await app.updateChore(
          choreId: widget.chore!.id,
          title: title,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          iconKey: _icon.text,
          difficulty: _difficulty,
          recurrence: rec,
          requiresApproval: _requiresApproval,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showChoreHelpDialog(BuildContext context) {
    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final cs = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chore details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is where you define what a chore is and how it works.',
              style: ts.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '• Title & description are what kids see in their list.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Icon (emoji) helps kids quickly recognize the chore.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Difficulty controls how many XP points the chore is worth.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• "Requires parent approval" sends completed chores to the Approve tab before coins/XP are awarded.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Recurrence (once/daily/weekly/custom) and days of the week describe how often the chore should be done.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Time is optional and mainly a reference for when you expect the chore to be finished.',
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
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker();

  static const _emojis = [
    '🧹',
    '🧼',
    '🧽',
    '🧺',
    '🪣',
    '🧻',
    '🧯',
    '🪥',
    '🪠',
    '🛏️',
    '🪑',
    '🧊',
    '🍽️',
    '🍳',
    '🍞',
    '🧃',
    '🐶',
    '🐱',
    '🌿',
    '📚',
    '🧠',
    '🧩',
    '🎒',
    '👟',
    '🧤',
    '🧢',
    '🧦',
    '🧴',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        height: 280,
        child: GridView.builder(
          itemCount: _emojis.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (_, i) {
            final e = _emojis[i];
            return InkWell(
              onTap: () => Navigator.of(context).pop(e),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            );
          },
        ),
      ),
    );
  }
}
