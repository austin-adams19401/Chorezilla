import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/member.dart';

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

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>(); // read (not watch)
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
              builder: (_, choresList, __) {
                final chores = choresList
                    .where((c) => c.active)
                    .where((c) => _q.isEmpty || c.title.toLowerCase().contains(_q.toLowerCase()))
                    .toList();

                if (chores.isEmpty) {
                  return const Center(child: Text('No chores yet — add one.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: chores.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = chores[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: Text(c.icon?.isNotEmpty == true ? c.icon! : '🧩', style: const TextStyle(fontSize: 22)),
                        title: Text(c.title),
                        subtitle: Text('${_difficultyName(c.difficulty)}'
                            '${c.recurrence != null ? ' • ${c.recurrence!.type}' : ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () => _openEditChoreSheet(context, c),
                            ),
                            const SizedBox(width: 4),
                            FilledButton.tonal(
                              onPressed: () => _openAssignSheet(context, c),
                              child: const Text('Assign'),
                            ),
                          ],
                        ),

                        onTap: () => _openAssignSheet(context, c),
                      ),
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
      case 1: return 'Very easy';
      case 2: return 'Easy';
      case 3: return 'Medium';
      case 4: return 'Hard';
      case 5: return 'Epic';
      default: return 'Custom';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chore created')));
    }
  }

  Future<void> _openAssignSheet(BuildContext context, Chore chore) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignSheet(chore: chore),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned!')));
    }
  }

  Future<void> _openEditChoreSheet(BuildContext context, Chore chore) async {
    final app = context.read<AppState>();
    final fam = app.family!;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChoreEditorSheet(family: fam, chore: chore), // 👈 pass chore
    );
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chore updated')),
      );
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

  @override
  void initState() {
    super.initState();
    final c = widget.chore;
    if (c != null) {
      _title.text = c.title;
      _desc.text  = c.description ?? '';
      _icon.text  = c.icon ?? '🧹';
      _difficulty = c.difficulty;
      _recType    = c.recurrence?.type ?? 'once';
      _days
        ..clear()
        ..addAll(c.recurrence?.daysOfWeek ?? const []);
      _timeOfDay  = c.recurrence?.timeOfDay;
    }
  }

  @override
  void dispose() {
    _title.dispose(); _desc.dispose(); _icon.dispose();
    super.dispose();
  }

  int get _xp => widget.family.settings.difficultyToXP[_difficulty] ?? _difficulty * 10;

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
                Row(children: [
                  const Icon(Icons.add_task_rounded),
                  Text(isEdit ? '  Edit chore' : '  New chore', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 12),

                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
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
                        decoration: const InputDecoration(labelText: 'Difficulty'),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final t in const ['once','daily','weekly','custom'])
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
                            label: Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i-1]),
                            selected: _days.contains(i),
                            onSelected: (sel) => setState(() => sel ? _days.add(i) : _days.remove(i)),
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
                    label: Text(_timeOfDay == null ? 'Pick time (optional)' : 'Time: $_timeOfDay'),
                    onPressed: () async {
                      final now = TimeOfDay.now();
                      final picked = await showTimePicker(context: context, initialTime: now);
                      if (picked != null) setState(() => _timeOfDay = picked.format(context));
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
        daysOfWeek: (_recType == 'weekly' || _recType == 'custom') ? _days.toList() : null,
        timeOfDay: _timeOfDay,
      );
      if (widget.chore == null) {
        await app.createChore(
          title: _title.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          iconKey: _icon.text,
          difficulty: _difficulty,
          recurrence: rec,
        );
      } else {
        await app.updateChore(
          choreId: widget.chore!.id,
          title: _title.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          iconKey: _icon.text,
          difficulty: _difficulty,
          recurrence: rec,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker();

  static const _emojis = [
    '🧹','🧼','🧽','🧺','🪣','🧻','🧯','🪥','🪠',
    '🛏️','🪑','🧊','🍽️','🍳','🍞','🧃','🐶','🐱','🌿',
    '📚','🧠','🧩','🎒','👟','🧤','🧢','🧦','🧴',
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
            crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8,
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
  DateTime _due = DateTime.now().add(const Duration(days: 1));
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return ValueListenableBuilder<List<Member>>(
      valueListenable: app.membersVN,
      builder: (_, members, _) {
        final kids = members.where((m) => m.role == FamilyRole.child && m.active).toList();
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
                    Row(children: [
                      Text(widget.chore.icon?.isNotEmpty == true ? widget.chore.icon! : '🧩', style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text('Assign "${widget.chore.title}"', style: Theme.of(context).textTheme.titleLarge),
                    ]),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: Text(_difficultyName(widget.chore.difficulty))),

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
                            onSelected: (v) => setState(() => v ? _kidIds.add(k.id) : _kidIds.remove(k.id)),
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
                              context: context, initialDate: _due,
                              firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 3),
                            );
                            if (picked != null) setState(() => _due = DateTime(picked.year, picked.month, picked.day));
                          },
                          child: Text('Due: ${_due.month}/${_due.day}'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _busy || _kidIds.isEmpty ? null : _assign,
                          child: _busy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Assign to selected'),
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
      case 1: return 'Very easy';
      case 2: return 'Easy';
      case 3: return 'Medium';
      case 4: return 'Hard';
      case 5: return 'Epic';
      default: return 'Custom';
    }
  }

  Future<void> _assign() async {
    setState(() => _busy = true);
    try {
      final app = context.read<AppState>();
      await app.assignChore(
        choreId: widget.chore.id,
        memberIds: _kidIds,
        due: _due,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}


// import 'package:chorezilla/components/icon_picker.dart';
// import 'package:chorezilla/models/chore_models.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:chorezilla/components/difficulty_slider.dart';
// import 'package:chorezilla/z_archive/app_state_old.dart';

// /// Parent assigns chores to kids; supports filters, search, etc.
// class AssignTab extends StatefulWidget {
//   const AssignTab({super.key});

//   @override
//   State<AssignTab> createState() => _AssignTabState();
// }

// class _AssignTabState extends State<AssignTab> {
//   // FORM STATES
//   final _form = GlobalKey<FormState>();

//   // CONTROLLERS
//   final _title = TextEditingController();

//   // VARIABLES
//   final Set<int> _days = {}; // 1..7 for weekly/custom
//   final Set<String> _selected = {};

//   ChoreSchedule _schedule = ChoreSchedule.daily;
//   bool _suggestionsOpen = false; // collapsed by default
//   IconData? _icon;
//   Color? _iconColor;
//   int _difficulty = 3; //default difficulty value

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final app = context.watch<AppState>();

//     final String _choreName = _title.text.trim();

//     final query = _title.text.trim().toLowerCase();
//     final dupes = query.isEmpty
//         ? const <Chore>[]
//         : app.chores
//             .where((c) => c.title.toLowerCase().contains(query))
//             .toList();
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Assign Chores'),
//       ),
//       body: ListView(
//         padding: EdgeInsets.all(15),
//         children: [
//           //SUGGESTIONS COLLAPSED CARD
//           Card(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(15),
//               side: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
//             ),
//             child: Theme(
//               data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//               child: ExpansionTile(
//                 initiallyExpanded: _suggestionsOpen,
//                 maintainState: true,
//                 onExpansionChanged: (v) => setState(() => _suggestionsOpen = v),
//                 tilePadding: const EdgeInsets.all(4),
//                 title: Text('Quick Suggestions', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w700),),
//                 children: [
//                   Padding(
//                     padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
//                     child: Wrap(
//                       spacing: 4,
//                       runSpacing: 4,
//                       children: kSuggestedChores.map((c) {
//                         return ActionChip(
//                           avatar: Icon(c.icon, size: 18),
//                           label: Text(c.title),
//                           onPressed: () {
//                             final cs = Theme.of(context).colorScheme;
//                             setState(() {
//                               _title.text  = c.title;
//                               _difficulty = _difficulty;
//                               _schedule    = c.schedule;
//                               _days
//                                 ..clear()
//                                 ..addAll(c.daysOfWeek);
//                               _icon       = c.icon;
//                               _iconColor  = cs.primary;
//                             });
//                           },
//                         );
//                       }).toList(),
//                     )
//                   )
//                 ],
//               ),                
//             ),     
//           ),
          
//           const SizedBox(height: 12),

//           Card(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//               side: BorderSide(color: cs.surfaceContainerHighest),
//               ),
//               child: Padding(
//                 padding: EdgeInsets.all(12), 
//                 child: Form(
//                   key: _form,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       Text('New Chore',
//                       style: TextStyle(
//                         color: cs.secondary, fontWeight: FontWeight.w700,
//                       )),
//                       const SizedBox(height: 8),

//                       //Title
//                       TextFormField(
//                         controller: _title,
//                         decoration: InputDecoration(
//                           labelText: 'Chore Name..',
//                           filled: true,
//                           fillColor: cs.surfaceContainerHighest,
//                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
//                         ),
//                         onChanged: (_) => setState(() {}),
//                           validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null, //null means no errors, input is valid
//                       ),
                      
//                       const SizedBox(height: 8),

//                       //Schedule dropdown
//                       DropdownButtonFormField<ChoreSchedule>(
//                         initialValue: _schedule,
//                         isExpanded: true,
//                         borderRadius: BorderRadius.circular(12),
//                         dropdownColor: cs.surface,
//                         selectedItemBuilder: (_) => [
//                           _ScheduleOptionTile(icon: Icons.calendar_today_rounded, title: 'Daily', cs: cs, compact: true),
//                           _ScheduleOptionTile(icon: Icons.calendar_view_week_rounded, title: 'Weekly', cs: cs, compact: true),
//                           _ScheduleOptionTile(icon: Icons.tune_rounded, title: 'Custom Days', cs: cs, compact: true),
//                         ],
//                         items: [
//                           DropdownMenuItem(
//                             value: ChoreSchedule.daily,
//                             child: _ScheduleOptionTile(
//                               icon: Icons.calendar_today_rounded, title: 'Daily', subtitle: 'Shows every day', cs: cs),
//                           ),
//                           DropdownMenuItem(
//                             value: ChoreSchedule.weeklyAny,
//                             child: _ScheduleOptionTile(
//                               icon: Icons.calendar_view_week_rounded, title: 'Weekly', subtitle: 'Pick one day or “any”', cs: cs),
//                           ),
//                           DropdownMenuItem(
//                             value: ChoreSchedule.customDays,
//                             child: _ScheduleOptionTile(
//                               icon: Icons.tune_rounded, title: 'Custom Days', subtitle: 'Pick multiple weekdays', cs: cs),
//                           ),
//                         ],
//                         onChanged: (v) {
//                           if (v == null) return;
//                           setState(() {
//                             _schedule = v;
//                             if (_schedule == ChoreSchedule.daily) _days.clear();
//                           });
//                         },decoration: InputDecoration(
//                           labelText: 'Schedule',
//                           filled: true,
//                           fillColor: cs.surfaceContainerHighest,
//                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                         ),
//                       ),

//                       //Weekday row
//                       if (_schedule == ChoreSchedule.weeklyAny || _schedule == ChoreSchedule.customDays) ...[
//                         const SizedBox(height: 8,),
//                         SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: Row(
//                             children: List.generate(7, (i) {
//                             const labels = [
//                               'Mon','Tue','Wed','Thu','Fri','Sat','Sun'
//                             ];
//                             final dayVal = i + 1; //Sets the days from 1-7 rather than 0-6
//                             final selection = _days.contains(dayVal);
//                             return Padding(
//                               padding: const EdgeInsets.all(1),
//                               child: FilterChip(
//                                 label: Text(labels[i]),
//                                 selected: selection,
//                                 onSelected: (v) => setState(() {
//                                   if (_schedule == ChoreSchedule.weeklyAny) {
//                                     // Enforce single selection for weekly
//                                     _days.clear();
//                                     if (v) 
//                                     {
//                                       _days.add(dayVal);
//                                     }
//                                   } else {
//                                     if (v) {
//                                       _days.add(dayVal);
//                                     } else {
//                                       _days.remove(dayVal);
//                                     }
//                                   }                              
//                                 }),
//                               ),
//                             );
//                           }),
//                         ),
//                       ),
//                     ],

//                   const SizedBox(height: 8,),

//                   Consumer<AppState>(
//                     builder: (context, app, _) {
//                       return DifficultySlider(
//                         value: _difficulty,
//                         helperText: "Set expectations: 1 is super quick, 5 is big effort.",
//                         onChanged: (v) => setState(() => _difficulty = v.round()), 
//                       );
//                     },
//                   ),

//                   const SizedBox(height: 8),

//                   OutlinedButton.icon(
//                     icon: Icon(_icon ?? Icons.image_outlined),
//                     label: Text(_icon == null ? 'Pick icon' : 'Change icon',
//                       style: TextStyle(color: cs.onSecondaryContainer)),
//                     onPressed:() async {
//                       final picked = await pickChoreIcon(context, initial: _icon, initialColor: _iconColor);
//                       if(picked != null){
//                         setState(() {
//                           _icon = picked.$1;
//                           _iconColor = picked.$2;
//                         });
//                       }
//                     }, 
//                     ),
//                     if (_icon != null) ...[
//                       const SizedBox(height: 8),
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: CircleAvatar(
//                           backgroundColor: cs.secondaryContainer,
//                           child: Icon(_icon, color: _iconColor ?? cs.onSecondaryContainer),
//                         ),
//                       ),
//                     ],

//                     const SizedBox(height: 8),

//                     Text('Assign to', style: TextStyle(color: cs.onSurfaceVariant)),

//                     const SizedBox(height: 6,),

//                     Wrap(
//                       spacing: 8,
//                       runSpacing: 8,
//                       children: app.members.map((m) {
//                         final selected = _selected.contains(m.id);

//                         return FilterChip(
//                           label: Text(m.name), 
//                           selected: selected,
//                           onSelected: (v) {
//                             setState(() {
//                               if(v) {
//                                 _selected.add(m.id);
//                               } else {
//                                 _selected.remove(m.id);
//                               }
//                             });
//                           },
//                         );
//                       }).toList(),
//                     ),

//                     const SizedBox(height: 12,),

//                     if (dupes.isNotEmpty) ...[
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: cs.tertiaryContainer,
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             Text('Possible duplicates',
//                               style: TextStyle(
//                                 color: cs.onTertiaryContainer,
//                                 fontWeight: FontWeight.w700,
//                               )),
//                             const SizedBox(height: 8,),
//                             ...dupes.map((c) => ListTile(
//                               dense: true,
//                               leading: c.icon != null ? CircleAvatar(
//                                 backgroundColor: cs.secondaryContainer,
//                                 child: Icon(c.icon, color: c.iconColor ?? cs.onSecondaryContainer),
//                               ) : null,
//                             title: Text(c.title, style: TextStyle(color: cs.onTertiaryContainer)),
//                             subtitle: Text('${app.pointsForDifficulty(_difficulty)} pts • ${scheduleLabel(c)}', style: TextStyle(color: cs.onTertiaryContainer),),
//                             trailing: TextButton(
//                                     onPressed: _selected.isEmpty ? null : () {
//                                             app.assignMembersToChore(c.id, _selected);
//                                             ScaffoldMessenger.of(context).showSnackBar(
//                                               SnackBar(content: Text('Assigned to ${_selected.length} member(s)')));
//                                           },
//                                     child: const Text('Assign selected'),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                       ],

//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: FilledButton.icon(
//                         icon: const Icon(Icons.save),
//                         label: const Text('Save chore'),
//                         onPressed: () {
//                           if (!_form.currentState!.validate()) return;
//                           if (_choreName.isEmpty) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                   content:
//                                       Text('Please enter a chore name.')),
//                             );
//                           }
//                           if (_selected.isEmpty) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                   content:
//                                       Text('Select at least one assignee')),
//                             );
//                             return;
//                           }
//                           if (_schedule == ChoreSchedule.customDays &&
//                               _days.isEmpty) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                   content: Text(
//                                       'Pick at least one weekday for custom schedule')),
//                             );
//                             return;
//                           }
//                           app.addChore(
//                             title: _title.text.trim(),
//                             points: app.pointsForDifficulty(_difficulty),
//                             difficulty: _difficulty,
//                             schedule: _schedule,
//                             daysOfWeek:
//                                 (_schedule == ChoreSchedule.customDays ||
//                                         _schedule == ChoreSchedule.weeklyAny)
//                                     ? _days
//                                     : {},
//                             assigneeIds: _selected,
//                             icon: _icon,
//                             iconColor: _iconColor,
//                           );
//                           _title.clear();
//                           _difficulty = 3;
//                           _schedule = ChoreSchedule.daily;
//                           _days.clear();
//                           _selected.clear();
//                           _icon = null;
//                           _iconColor = null;
//                           setState(() {});
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(content: Text('Chore added')),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Existing chores
//           if (app.chores.isNotEmpty)
//             Text('Existing chores',
//                 style: Theme.of(context).textTheme.titleMedium),
//           for (final c in app.chores)
//             Card(
//               elevation: 0,
//               margin: const EdgeInsets.symmetric(vertical: 6),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 side: BorderSide(color: cs.surfaceContainerHighest),
//               ),
//               child: ExpansionTile(
//                 leading: c.icon != null
//                     ? CircleAvatar(
//                         backgroundColor: cs.secondaryContainer,
//                         child: Icon(c.icon,
//                             color: c.iconColor ?? cs.onSecondaryContainer),
//                       )
//                     : null,
//                 title: Text('${c.title} • ${c.points} pts'),
//                 subtitle: Text(scheduleLabel(c)),
//                 childrenPadding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 children: [
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 8,
//                     children: app.members.map((m) {
//                       final assigned = c.assigneeIds.contains(m.id);
//                       return FilterChip(
//                         label: Text(m.name),
//                         selected: assigned,
//                         onSelected: (_) => app.toggleAssignee(c.id, m.id),
//                       );
//                     }).toList(),
//                   ),
//                   const SizedBox(height: 8),
//                   Align(
//                     alignment: Alignment.centerRight,
//                     child: TextButton.icon(
//                       icon: const Icon(Icons.delete_outline),
//                       label: const Text('Delete'),
//                       onPressed: () => app.deleteChore(c.id),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }



//   @override
//   void dispose() {
//     super.dispose();
//   }

// }

// // In assign_tab.dart (below the state class)
// class _ScheduleOptionTile extends StatelessWidget {
//   const _ScheduleOptionTile({
//     required this.icon,
//     required this.title,
//     this.subtitle,
//     required this.cs,
//     this.compact = false, // use compact for selectedItemBuilder
//   });

//   final IconData icon;
//   final String title;
//   final String? subtitle;
//   final ColorScheme cs;
//   final bool compact;

//   @override
//   Widget build(BuildContext context) {
//     final avatar = CircleAvatar(
//       radius: compact ? 12 : 14,
//       backgroundColor: cs.secondaryContainer,
//       child: Icon(icon, size: compact ? 14 : 16, color: cs.onSecondaryContainer),
//     );

//     return Row(
//       children: [
//         avatar,
//         const SizedBox(width: 8),
//         Expanded(
//           child: compact
//               ? Text(title, overflow: TextOverflow.ellipsis)
//               : Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
//                     if (subtitle != null)
//                       Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    
//                   ],
//                 ),
//         ),
//       ],
//     );
//   }
// }

// // ---------- Reusable styling helpers ----------

// class SectionCard extends StatelessWidget {
//   final Widget child;
//   final EdgeInsetsGeometry padding;
//   final EdgeInsetsGeometry margin;
//   final String? title;
//   final Widget? trailing;
//   const SectionCard({
//     super.key,
//     required this.child,
//     this.padding = const EdgeInsets.all(14),
//     this.margin = const EdgeInsets.symmetric(vertical: 8),
//     this.title,
//     this.trailing,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Container(
//       margin: margin,
//       decoration: BoxDecoration(
//         color: cs.surfaceContainerHighest,                 // M3 comfy surface
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: cs.outlineVariant),
//         boxShadow: [
//           BoxShadow(
//             blurRadius: 14,
//             offset: const Offset(0, 6),
//             color: cs.shadow.withOpacity(0.06),
//           ),
//         ],
//       ),
//       child: Padding(
//         padding: padding,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (title != null) ...[
//               Row(
//                 children: [
//                   Text(
//                     title!,
//                     style: TextStyle(
//                       fontWeight: FontWeight.w700,
//                       fontSize: 16,
//                       color: cs.onSurface,
//                     ),
//                   ),
//                   const Spacer(),
//                   if (trailing != null) trailing!,
//                 ],
//               ),
//               const SizedBox(height: 10),
//               Divider(height: 1, color: cs.outlineVariant),
//               const SizedBox(height: 10),
//             ],
//             child,
//           ],
//         ),
//       ),
//     );
//   }
// }

// class FieldLabel extends StatelessWidget {
//   final String text;
//   final String? hint;
//   const FieldLabel(this.text, {super.key, this.hint});

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         children: [
//           Text(text,
//               style: TextStyle(
//                 fontWeight: FontWeight.w600,
//                 color: cs.onSurface,
//               )),
//           if (hint != null) ...[
//             const SizedBox(width: 8),
//             Text(hint!,
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: cs.onSurfaceVariant,
//                 )),
//           ],
//         ],
//       ),
//     );
//   }
// }

// class PillButton extends StatelessWidget {
//   final Widget child;
//   final VoidCallback? onPressed;
//   final bool filled;
//   const PillButton({
//     super.key,
//     required this.child,
//     required this.onPressed,
//     this.filled = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final bg = filled ? cs.primary : cs.surface;
//     final fg = filled ? cs.onPrimary : cs.primary;

//     return InkWell(
//       onTap: onPressed,
//       borderRadius: BorderRadius.circular(999),
//       child: Ink(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(999),
//           border: Border.all(color: filled ? Colors.transparent : cs.primary),
//         ),
//         child: DefaultTextStyle.merge(
//           style: TextStyle(
//             color: fg,
//             fontWeight: FontWeight.w600,
//           ),
//           child: child,
//         ),
//       ),
//     );
//   }
// }
