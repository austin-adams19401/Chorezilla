import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/chore.dart';

class AssignTab extends StatefulWidget {
  const AssignTab({super.key});

  @override
  State<AssignTab> createState() => _AssignTabState();
}

class _AssignTabState extends State<AssignTab> {
  final Set<String> _selectedKidIds = {};
  final Set<String> _selectedChoreIds = {};
  DateTime _due = DateTime.now().add(const Duration(days: 1));
  bool _busy = false;
  String _searchChore = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final kids = app.members.where((m) => m.role == FamilyRole.child && m.active).toList();
    final chores = app.chores
        .where((c) => c.active)
        .where((c) => _searchChore.isEmpty || c.title.toLowerCase().contains(_searchChore.toLowerCase()))
        .toList();

    final canAssign = _selectedKidIds.isNotEmpty && _selectedChoreIds.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search chores',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setState(() => _searchChore = v),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _busy || !canAssign ? null : () => _assign(context),
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: const Text('Assign'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _DuePicker(
                  initial: _due,
                  onChanged: (d) => setState(() => _due = d),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_selectedKidIds.length} kid(s) • ${_selectedChoreIds.length} chore(s)'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _Pane(
                title: 'Kids',
                child: _KidList(
                  kids: kids,
                  selectedIds: _selectedKidIds,
                  onToggle: (id) => setState(() {
                    if (_selectedKidIds.contains(id)) {
                      _selectedKidIds.remove(id);
                    } else {
                      _selectedKidIds.add(id);
                    }
                  }),
                ),
              ),
              _Pane(
                title: 'Chores',
                child: _ChoreList(
                  chores: chores,
                  selectedIds: _selectedChoreIds,
                  onToggle: (id) => setState(() {
                    if (_selectedChoreIds.contains(id)) {
                      _selectedChoreIds.remove(id);
                    } else {
                      _selectedChoreIds.add(id);
                    }
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _assign(BuildContext context) async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final members = _selectedKidIds.toList();
      for (final choreId in _selectedChoreIds) {
        await app.assignChore(choreId: choreId, memberIds: members, due: _due);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned!')));
      setState(() {
        _selectedKidIds.clear();
        _selectedChoreIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _KidList extends StatelessWidget {
  const _KidList({required this.kids, required this.selectedIds, required this.onToggle});
  final List<Member> kids;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    if (kids.isEmpty) {
      return const Center(child: Text('No kids yet'));
    }
    return ListView.builder(
      itemCount: kids.length,
      itemBuilder: (_, i) {
        final k = kids[i];
        final selected = selectedIds.contains(k.id);
        return CheckboxListTile(
          value: selected,
          onChanged: (_) => onToggle(k.id),
          title: Text(k.displayName),
          subtitle: Text('Level ${k.level} • ${k.xp} XP • ${k.coins} coins'),
        );
      },
    );
  }
}

class _ChoreList extends StatelessWidget {
  const _ChoreList({required this.chores, required this.selectedIds, required this.onToggle});
  final List<Chore> chores;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    if (chores.isEmpty) {
      return const Center(child: Text('No chores yet'));
    }
    return ListView.builder(
      itemCount: chores.length,
      itemBuilder: (_, i) {
        final c = chores[i];
        final selected = selectedIds.contains(c.id);
        return CheckboxListTile(
          value: selected,
          onChanged: (_) => onToggle(c.id),
          title: Text(c.title),
          subtitle: Text('${c.points} pts • difficulty ${c.difficulty}'),
          secondary: Text(c.icon?.isNotEmpty == true ? c.icon! : '🧩', style: const TextStyle(fontSize: 18)),
        );
      },
    );
  }
}

class _DuePicker extends StatelessWidget {
  const _DuePicker({required this.initial, required this.onChanged});
  final DateTime initial;
  final void Function(DateTime) onChanged;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 3),
          initialDate: initial,
        );
        if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day));
      },
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded),
          const SizedBox(width: 8),
          Text('Due: ${initial.month}/${initial.day}', style: ts.bodyMedium),
        ],
      ),
    );
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
