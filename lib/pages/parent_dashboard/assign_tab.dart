import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/assignment.dart';

class AssignTab extends StatefulWidget {
  const AssignTab({super.key});

  @override
  State<AssignTab> createState() => _AssignTabState();
}

class _AssignTabState extends State<AssignTab> {
  String _q = '';
  Timer? _deb;

  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  Future<void> _confirmDeleteChore(Chore chore) async {
    // First async gap: showDialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${chore.title}"?'),
        content: const Text(
          'This will delete the chore and all of its assignments for every kid. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final app = context.read<AppState>();

    try {
      await app.deleteChore(chore.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chore "${chore.title}" deleted.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting chore: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search chores',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) {
                _deb?.cancel();
                _deb = Timer(const Duration(milliseconds: 200), () {
                  if (mounted) setState(() => _q = v);
                });
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<Chore>>(
              valueListenable: app.choresVN,
              builder: (_, choresList, _) {
                final chores = choresList
                    .where((c) => c.active)
                    .where(
                      (c) =>
                          _q.isEmpty ||
                          c.title.toLowerCase().contains(_q.toLowerCase()),
                    )
                    .toList();

                if (chores.isEmpty) {
                  return const Center(child: Text('No chores yet — add one.'));
                }

                final app = context.read<AppState>();

                return ValueListenableBuilder<List<Assignment>>(
                  valueListenable: app.familyAssignedVN,
                  builder: (_, assignedList, _) {
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: chores.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = chores[i];

                        final assignedMembers = app.assignedMembersForChore(
                          c.id,
                        );

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: Text(
                              c.icon?.isNotEmpty == true ? c.icon! : '🧩',
                              style: const TextStyle(fontSize: 30),
                            ),
                            title: Text(c.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_difficultyName(c.difficulty)}'
                                  '${c.recurrence != null ? ' • ${c.recurrence!.type}' : ''}',
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    if (assignedMembers.isEmpty)
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.person_outline, size: 16),
                                          SizedBox(width: 4),
                                          Text('No one assigned yet'),
                                        ],
                                      )
                                    else
                                      ...assignedMembers.map((m) {
                                        final name = m.displayName;
                                        final initial = (name.isNotEmpty)
                                            ? name.substring(0, 1).toUpperCase()
                                            : '?';
                                        return CircleAvatar(
                                          radius: 12,
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => _openAssignSheet(context, c),
                                  child: const Text('Assign'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _openEditChoreSheet(context, c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDeleteChore(c),
                                ),
                              ],
                            ),
                            onTap: () => _openAssignSheet(context, c),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewChoreSheet(context),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New chore'),
      ),
    );
  }

  String _difficultyName(int d) {
    switch (d) {
      case 1:
        return 'Very easy';
      case 2:
        return 'Easy';
      case 3:
        return 'Medium';
      case 4:
        return 'Hard';
      case 5:
        return 'Epic';
      default:
        return 'Custom';
    }
  }

  Future<void> _openNewChoreSheet(BuildContext context) async {
    final app = context.read<AppState>();
    final fam = app.family!;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChoreEditorSheet(family: fam),
    );
    if (!mounted) return;
    if (created == true) {
      setState(() {}); // refresh filters immediately so the new chore appears
    }
  }

  Future<void> _openAssignSheet(BuildContext context, Chore chore) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignSheet(chore: chore),
    );
  }

  Future<void> _openEditChoreSheet(BuildContext context, Chore chore) async {
    final app = context.read<AppState>();
    final fam = app.family!;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ChoreEditorSheet(family: fam, chore: chore), // 👈 pass chore
    );
    if (!mounted) return;
    if (saved == true) {
      setState(() {}); // refresh list
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New chore sheet: emoji picker + readable difficulty names
// ─────────────────────────────────────────────────────────────────────────────

class _ChoreEditorSheet extends StatefulWidget {
  const _ChoreEditorSheet({required this.family, this.chore});
  final Family family;
  final Chore? chore;

  @override
  State<_ChoreEditorSheet> createState() => _ChoreEditorSheetState();
}

class _ChoreEditorSheetState extends State<_ChoreEditorSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _icon = TextEditingController(text: '🧹');
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
                  decoration: const InputDecoration(labelText: 'Title'),
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
    if (_title.text.trim().isEmpty) return;
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
          title: _title.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          iconKey: _icon.text,
          difficulty: _difficulty,
          recurrence: rec,
          requiresApproval: _requiresApproval,
        );
      } else {
        await app.updateChore(
          choreId: widget.chore!.id,
          title: _title.text.trim(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Assign sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.chore});
  final Chore chore;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final Set<String> _kidIds = {};
  late final Set<String> _initialKidIds; // snapshot of assignments when opened
  bool _initialized = false;

  DateTime _due = DateTime.now();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();

    // Seed local state once from existing assignments
    if (!_initialized) {
      final existing = app.assignedMemberIdsForChore(widget.chore.id);
      _initialKidIds = Set<String>.from(existing);
      _kidIds.addAll(existing);
      _initialized = true;
    }

    return ValueListenableBuilder<List<Member>>(
      valueListenable: app.membersVN,
      builder: (_, members, _) {
        final kids = members
            .where((m) => m.role == FamilyRole.child && m.active)
            .toList();
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;

        final hasChanges = !_sameSet(_kidIds, _initialKidIds);

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
                        Text(
                          widget.chore.icon?.isNotEmpty == true
                              ? widget.chore.icon!
                              : '🧩',
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assign "${widget.chore.title}"',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.help_outline_rounded),
                          tooltip: 'How assigning works',
                          onPressed: () => _showAssignHelpDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_difficultyName(widget.chore.difficulty)),
                    ),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: kids.map((k) {
                          final sel = _kidIds.contains(k.id);
                          return FilterChip(
                            label: Text(k.displayName),
                            selected: sel,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _kidIds.add(k.id);
                                } else {
                                  _kidIds.remove(k.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _due,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 3),
                            );
                            if (picked != null) {
                              setState(
                                () => _due = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                ),
                              );
                            }
                          },
                          child: Text('Due: ${_due.month}/${_due.day}'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _busy || !hasChanges
                              ? null
                              : _saveAssignments,
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ],
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

  String _difficultyName(int d) {
    switch (d) {
      case 1:
        return 'Very easy';
      case 2:
        return 'Easy';
      case 3:
        return 'Medium';
      case 4:
        return 'Hard';
      case 5:
        return 'Epic';
      default:
        return 'Custom';
    }
  }

  bool _sameSet(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }

  Future<void> _saveAssignments() async {
    setState(() => _busy = true);
    try {
      final app = context.read<AppState>();

      final toAdd = _kidIds.difference(_initialKidIds);
      final toRemove = _initialKidIds.difference(_kidIds);

      if (toAdd.isNotEmpty) {
        await app.assignChore(
          choreId: widget.chore.id,
          memberIds: toAdd,
          due: _due,
        );
      }

      if (toRemove.isNotEmpty) {
        await app.unassignChore(choreId: widget.chore.id, memberIds: toRemove);
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

  void _showAssignHelpDialog(BuildContext context) {
    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final cs = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assigning chores to kids'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose which kids should see this chore and when it\'s due.',
              style: ts.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '• Tap a kid\'s name to assign or unassign them from this chore.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• The due date is the next day you expect this chore to be done.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• When you tap Save, new kids are assigned and removed kids are unassigned.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '• Assigned chores show up on the kid dashboard based on their due dates and recurrence.',
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
