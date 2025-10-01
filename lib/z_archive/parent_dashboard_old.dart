// // lib/pages/parent_dashboard.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import 'package:chorezilla/state/app_state.dart';
// import 'package:chorezilla/models/chore_models.dart';
// import 'package:chorezilla/components/icon_picker.dart';

// class ParentDashboardPage extends StatefulWidget {
//   const ParentDashboardPage({super.key});

//   @override
//   State<ParentDashboardPage> createState() => _ParentDashboardPageState();
// }

// class _ParentDashboardPageState extends State<ParentDashboardPage> {
//   int _index = 0;

//   @override
//   Widget build(BuildContext context) {
//     final pages = [
//       const _HomeTab(),
//       const _AssignTab(),
//       const _CheckOffTab(),
//       const _SettingsTab(),
//     ];

//     return Scaffold(
//       body: pages[_index],
//       bottomNavigationBar: NavigationBar(
//         selectedIndex: _index,
//         onDestinationSelected: (i) => setState(() => _index = i),
//         destinations: const [
//           NavigationDestination(
//               icon: Icon(Icons.home_outlined),
//               selectedIcon: Icon(Icons.home),
//               label: 'Home'),
//           NavigationDestination(
//               icon: Icon(Icons.assignment_outlined),
//               selectedIcon: Icon(Icons.assignment),
//               label: 'Assign'),
//           NavigationDestination(
//               icon: Icon(Icons.check_circle_outlined),
//               selectedIcon: Icon(Icons.check_circle),
//               label: 'Check off'),
//           NavigationDestination(
//               icon: Icon(Icons.settings_outlined),
//               selectedIcon: Icon(Icons.settings),
//               label: 'Settings'),
//         ],
//       ),
//     );
//   }
// }

// // ----------------------------------------------------------------------
// // HOME (weekly grid per kid; no profile switching here)
// // ----------------------------------------------------------------------
// class _HomeTab extends StatelessWidget {
//   const _HomeTab();

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final cs = Theme.of(context).colorScheme;

//     final members = app.members;
//     final now = DateTime.now();
//     final weekStart = _startOfWeek(now);
//     final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
//     const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Chore overview'),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//         elevation: 0,
//       ),
//       body: members.isEmpty
//           ? Center(
//               child: Text('No family members yet.',
//                   style: TextStyle(color: cs.onSurfaceVariant)))
//           : ListView.builder(
//               padding: const EdgeInsets.all(12),
//               itemCount: members.length,
//               itemBuilder: (_, mIndex) {
//                 final member = members[mIndex];
//                 final chores = app.choresForMember(member.id);

//                 return Card(
//                   elevation: 0,
//                   margin: const EdgeInsets.only(bottom: 12),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     side: BorderSide(color: cs.surfaceContainerHighest),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.stretch,
//                       children: [
//                         Row(
//                           children: [
//                             Expanded(
//                               child: Text(
//                                 member.name,
//                                 style: Theme.of(context)
//                                     .textTheme
//                                     .titleMedium
//                                     ?.copyWith(
//                                       color: cs.secondary,
//                                       fontWeight: FontWeight.w700,
//                                     ),
//                               ),
//                             ),
//                             ...List.generate(
//                               7,
//                               (i) => SizedBox(
//                                 width: 40,
//                                 child: Center(
//                                   child: Text(
//                                     weekdayShort[i],
//                                     style: TextStyle(color: cs.onSurfaceVariant),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),

//                         if (chores.isEmpty)
//                           Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                             child: Text('No chores assigned',
//                                 style: TextStyle(color: cs.onSurfaceVariant)),
//                           ),

//                         ...chores.map((chore) {
//                           final weeklyDone = (chore.schedule == ChoreSchedule.weeklyAny)
//                               ? app.wasCompletedInWeek(chore.id, member.id, now)
//                               : false;

//                           return Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 6),
//                             child: Row(
//                               children: [
//                                 // Chore label + points + (icon)
//                                 Expanded(
//                                   child: Row(
//                                     children: [
//                                       if (chore.icon != null)
//                                         Padding(
//                                           padding: const EdgeInsets.only(right: 8),
//                                           child: Icon(
//                                             chore.icon,
//                                             size: 20,
//                                             color: chore.iconColor ?? cs.onSurfaceVariant,
//                                           ),
//                                         ),
//                                       Flexible(
//                                         child: Text(
//                                           chore.title,
//                                           overflow: TextOverflow.ellipsis,
//                                           style: const TextStyle(fontWeight: FontWeight.w600),
//                                         ),
//                                       ),
//                                       const SizedBox(width: 6),
//                                       Text('• ${chore.points} pts',
//                                           style: TextStyle(
//                                               color: cs.onSurfaceVariant,
//                                               fontSize: 12)),
//                                     ],
//                                   ),
//                                 ),

//                                 // 7 read-only day cells
//                                 ...List.generate(7, (i) {
//                                   final day = days[i];
//                                   final scheduled = app.isScheduledOnDate(chore, day);
//                                   final checked = app.wasCompletedOnDay(
//                                       chore.id, member.id, day);

//                                   bool applicable;
//                                   if (chore.schedule == ChoreSchedule.weeklyAny) {
//                                     // If "weekly any", show only until one day this week is done.
//                                     applicable = !weeklyDone || checked;
//                                     if (chore.daysOfWeek.isNotEmpty) {
//                                       // If weekly with a specific weekday(s), show only those days.
//                                       applicable = scheduled;
//                                     }
//                                   } else {
//                                     // Daily/custom → show only on scheduled days.
//                                     applicable = scheduled;
//                                   }

//                                   Widget cellChild;
//                                   if (!applicable) {
//                                     cellChild = Text('/', style: TextStyle(color: cs.outline));
//                                   } else if (checked) {
//                                     cellChild = Icon(Icons.check_circle, size: 22, color: cs.primary);
//                                   } else {
//                                     cellChild = Icon(Icons.radio_button_unchecked, size: 22, color: cs.onSurfaceVariant);
//                                   }

//                                   return SizedBox(
//                                     width: 40,
//                                     child: Padding(
//                                       padding: const EdgeInsets.symmetric(vertical: 6),
//                                       child: Center(child: cellChild),
//                                     ),
//                                   );
//                                 }),
//                               ],
//                             ),
//                           );
//                         }),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }


// DateTime _startOfWeek(DateTime d) {
//   final dateOnly = DateTime(d.year, d.month, d.day);
//   final diff = dateOnly.weekday - DateTime.monday; // 0..6
//   return dateOnly.subtract(Duration(days: diff));
// }

// // ----------------------------------------------------------------------
// // ASSIGN (dropdown schedule + single-row weekday selector + icon/color)
// // ----------------------------------------------------------------------

// class _AssignTab extends StatefulWidget {
//   const _AssignTab();
//   @override
//   State<_AssignTab> createState() => _AssignTabState();
// }

// class _AssignTabState extends State<_AssignTab> {
//   final _form = GlobalKey<FormState>();
//   final _title = TextEditingController();
//   final _points = TextEditingController(text: '5');

//   ChoreSchedule _schedule = ChoreSchedule.daily;
//   final Set<int> _days = {}; // 1..7 for weekly/custom
//   bool _suggestionsOpen = false; // collapsed by default
//   final Set<String> _selected = {};
//   IconData? _icon;
//   Color? _iconColor;

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final cs = Theme.of(context).colorScheme;

//     final query = _title.text.trim().toLowerCase();
//     final dupes = query.isEmpty
//         ? const <Chore>[]
//         : app.chores
//             .where((c) => c.title.toLowerCase().contains(query))
//             .toList();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Assign chores'),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//         elevation: 0,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(12),
//         children: [
//           // Suggestions
//           Card(
//             elevation: 0,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//               side: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
//             ),
//             child: Theme( // hide the ExpansionTile divider
//               data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//               child: ExpansionTile(
//                 initiallyExpanded: _suggestionsOpen,
//                 maintainState: true,
//                 onExpansionChanged: (v) => setState(() => _suggestionsOpen = v),
//                 tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 title: Text(
//                   'Quick suggestions',
//                   style: TextStyle(
//                     color: Theme.of(context).colorScheme.secondary,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
//                     child: Wrap(
//                       spacing: 8,
//                       runSpacing: 8,
//                       children: kSuggestedChores.map((t) {
//                         return ActionChip(
//                           avatar: Icon(t.icon, size: 18),
//                           label: Text(t.title),
//                           onPressed: () {
//                             final cs = Theme.of(context).colorScheme;
//                             setState(() {
//                               _title.text  = t.title;
//                               _points.text = t.points.toString();
//                               _schedule    = t.schedule;
//                               _days
//                                 ..clear()
//                                 ..addAll(t.daysOfWeek);
//                               _icon       = t.icon;
//                               _iconColor  = cs.primary;
//                             });
//                           },
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),

//           // Create form
//           Card(
//             elevation: 0,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//               side: BorderSide(color: cs.surfaceContainerHighest),
//             ),
//             child: Padding(
//               padding: const EdgeInsets.all(12),
//               child: Form(
//                 key: _form,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Text('New chore',
//                         style: TextStyle(
//                             color: cs.secondary, fontWeight: FontWeight.w700)),
//                     const SizedBox(height: 8),

//                     // Title
//                     TextFormField(
//                       controller: _title,
//                       decoration: InputDecoration(
//                         labelText: 'Title',
//                         filled: true,
//                         fillColor: cs.surfaceContainerHighest,
//                         border:
//                             OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                       ),
//                       onChanged: (_) => setState(() {}),
//                       validator: (v) =>
//                           (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
//                     ),
//                     const SizedBox(height: 8),

//                     // Schedule dropdown
//                     DropdownButtonFormField<ChoreSchedule>(
//                       initialValue: _schedule,
//                       items: const [
//                         DropdownMenuItem(
//                             value: ChoreSchedule.daily, child: Text('Daily')),
//                         DropdownMenuItem(
//                             value: ChoreSchedule.weeklyAny, child: Text('Weekly')),
//                         DropdownMenuItem(
//                             value: ChoreSchedule.customDays, child: Text('Custom days')),
//                       ],
//                       onChanged: (v) {
//                         if (v == null) return;
//                         setState(() {
//                           _schedule = v;
//                           if (_schedule == ChoreSchedule.daily) _days.clear();
//                         });
//                       },
//                       decoration: InputDecoration(
//                         labelText: 'Schedule',
//                         filled: true,
//                         fillColor: cs.surfaceContainerHighest,

//                         border:
//                             OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                       ),
//                     ),

//                     // Weekday row (single horizontal row; scrolls if needed)
//                     if (_schedule == ChoreSchedule.weeklyAny ||
//                         _schedule == ChoreSchedule.customDays) ...[
//                       const SizedBox(height: 8),
//                       Text(
//                         _schedule == ChoreSchedule.weeklyAny
//                             ? 'Pick one day (optional). Leave empty for “any day”.'
//                             : 'Pick one or more days.',
//                         style: TextStyle(color: cs.onSurfaceVariant),
//                       ),
//                       const SizedBox(height: 6),
//                       SingleChildScrollView(
//                         scrollDirection: Axis.horizontal,
//                         child: Row(
//                           children: List.generate(7, (i) {
//                             const labels = [
//                               'Mon','Tue','Wed','Thu','Fri','Sat','Sun'
//                             ];
//                             final dayVal = i + 1; // 1..7
//                             final sel = _days.contains(dayVal);
//                             return Padding(
//                               padding: const EdgeInsets.only(right: 6),
//                               child: FilterChip(
//                                 label: Text(labels[i]),
//                                 selected: sel,
//                                 onSelected: (v) => setState(() {
//                                   if (_schedule == ChoreSchedule.weeklyAny) {
//                                     // Enforce single selection for weekly
//                                     _days.clear();
//                                     if (v) _days.add(dayVal);
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

//                     const SizedBox(height: 8),

//                     // Points (full width)
//                     TextFormField(
//                       controller: _points,
//                       keyboardType: TextInputType.number,
//                       decoration: InputDecoration(
//                         labelText: 'Points',
//                         filled: true,
//                         fillColor: cs.surfaceContainerHighest,
//                         border:
//                             OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                       ),
//                       validator: (v) {
//                         final n = int.tryParse(v ?? '');
//                         if (n == null || n < 0) return 'Enter a valid number';
//                         return null;
//                       },
//                     ),

//                     const SizedBox(height: 8),

//                     // Icon picker
//                     OutlinedButton.icon(
//                       icon: Icon(_icon ?? Icons.image_outlined),
//                       label: Text(_icon == null ? 'Pick icon' : 'Change icon'),
//                       onPressed: () async {
//                         final picked = await pickChoreIcon(
//                           context, initial: _icon, initialColor: _iconColor);
//                         if (picked != null) {
//                           setState(() {
//                             _icon = picked.$1;
//                             _iconColor = picked.$2;
//                           });
//                         }
//                       },
//                     ),
//                     if (_icon != null) ...[
//                       const SizedBox(height: 8),
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: CircleAvatar(
//                           backgroundColor: cs.secondaryContainer,
//                           child: Icon(_icon,
//                               color: _iconColor ?? cs.onSecondaryContainer),
//                         ),
//                       ),
//                     ],

//                     const SizedBox(height: 8),
//                     Text('Assign to',
//                         style: TextStyle(color: cs.onSurfaceVariant)),
//                     const SizedBox(height: 6),
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
//                               if (v) {
//                                 _selected.add(m.id);
//                               } else {
//                                 _selected.remove(m.id);
//                               }
//                             });
//                           },
//                         );
//                       }).toList(),
//                     ),

//                     const SizedBox(height: 12),

//                     // Duplicates
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
//                                 style: TextStyle(
//                                     color: cs.onTertiaryContainer,
//                                     fontWeight: FontWeight.w700)),
//                             const SizedBox(height: 8),
//                             ...dupes.map((c) => ListTile(
//                                   dense: true,
//                                   leading: c.icon != null
//                                       ? CircleAvatar(
//                                           backgroundColor:
//                                               cs.secondaryContainer,
//                                           child: Icon(c.icon,
//                                               color: c.iconColor ??
//                                                   cs.onSecondaryContainer),
//                                         )
//                                       : null,
//                                   title: Text(c.title,
//                                       style: TextStyle(
//                                           color: cs.onTertiaryContainer)),
//                                   subtitle: Text(
//                                     '${c.points} pts • ${scheduleLabel(c)}',
//                                     style: TextStyle(
//                                         color: cs.onTertiaryContainer
//                                             // ignore: deprecated_member_use
//                                             .withOpacity(0.9)),
//                                   ),
//                                   trailing: TextButton(
//                                     onPressed: _selected.isEmpty
//                                         ? null
//                                         : () {
//                                             app.assignMembersToChore(
//                                                 c.id, _selected);
//                                             ScaffoldMessenger.of(context)
//                                                 .showSnackBar(SnackBar(
//                                                     content: Text(
//                                                         'Assigned to ${_selected.length} member(s)')));
//                                           },
//                                     child: const Text('Assign selected'),
//                                   ),
//                                 )),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                     ],

//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: FilledButton.icon(
//                         icon: const Icon(Icons.save),
//                         label: const Text('Save chore'),
//                         onPressed: () {
//                           if (!_form.currentState!.validate()) return;
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
//                             points: int.parse(_points.text),
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
//                           _points.text = '5';
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
// }

// // ----------------------------------------------------------------------
// // CHECK OFF (pick a kid → show today's applicable chores)
// // ----------------------------------------------------------------------

// class _CheckOffTab extends StatefulWidget {
//   const _CheckOffTab();

//   @override
//   State<_CheckOffTab> createState() => _CheckOffTabState();
// }

// class _CheckOffTabState extends State<_CheckOffTab> {
//   String? _selectedMemberId;

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final cs = Theme.of(context).colorScheme;

//     final members = app.members;
//     _selectedMemberId ??= members.firstOrNull?.id;

//     final today = DateTime.now();
//     final chores = (_selectedMemberId == null)
//         ? <Chore>[]
//         : app
//             .choresForMember(_selectedMemberId!)
//             .where((c) =>
//                 app.isApplicableForMemberOnDate(c, _selectedMemberId!, today))
//             .toList();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Check off chores'),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//         elevation: 0,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(12),
//         children: [
//           Wrap(
//             spacing: 8,
//             children: members.map((m) {
//               final isSelected = m.id == _selectedMemberId;
//               return ChoiceChip(
//                 label: Text(m.name),
//                 selected: isSelected,
//                 onSelected: (_) => setState(() => _selectedMemberId = m.id),
//               );
//             }).toList(),
//           ),
//           const SizedBox(height: 12),
//           if (chores.isEmpty)
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Text('No chores scheduled today.',
//                   style: TextStyle(color: cs.onSurfaceVariant)),
//             ),
//           for (final c in chores)
//             ListTile(
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12)),
//               tileColor: cs.surfaceContainerHighest,
//               leading: c.icon != null
//                   ? CircleAvatar(
//                       backgroundColor: cs.secondaryContainer,
//                       child: Icon(c.icon,
//                           color: c.iconColor ?? cs.onSecondaryContainer),
//                     )
//                   : null,
//               title: Text(c.title),
//               subtitle: Text('${c.points} pts • ${scheduleLabel(c)}'),
//               trailing: IconButton(
//                 icon: const Icon(Icons.check_circle, size: 28),
//                 color: cs.primary,
//                 onPressed: () {
//                   if (_selectedMemberId == null) return;
//                   app.completeChoreOn(c.id, _selectedMemberId!, today);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Marked "${c.title}" complete')),
//                   );
//                 },
//               ),
//               contentPadding:
//                   const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//               visualDensity: VisualDensity.compact,
//             ),
//         ],
//       ),
//     );
//   }
// }

// // ----------------------------------------------------------------------
// // SETTINGS (placeholder)
// // ----------------------------------------------------------------------

// class _SettingsTab extends StatelessWidget {
//   const _SettingsTab();

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final cs = Theme.of(context).colorScheme;
//     final famName = app.family?.name ?? '(unnamed family)';

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Settings'),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//         elevation: 0,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           ListTile(
//             leading: const Icon(Icons.family_restroom),
//             title: const Text('Family'),
//             subtitle: Text(famName),
//           ),
//           ListTile(
//             leading: const Icon(Icons.info_outline),
//             title: const Text('About Chorezilla'),
//             subtitle: const Text('v1.0.0'),
//           ),
//         ],
//       ),
//     );
//   }
// }
