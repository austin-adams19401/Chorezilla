import 'package:chorezilla/components/difficulty_slider.dart';
import 'package:chorezilla/components/inputs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../models/chore_models.dart';
import '../../models/family_models.dart';

/// Parent assigns chores to kids; supports filters, search, etc.
class AssignTab extends StatefulWidget {
  const AssignTab({super.key});

  @override
  State<AssignTab> createState() => _AssignTabState();
}

class _AssignTabState extends State<AssignTab> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _difficultyLvl = TextEditingController(text: '5');

  ChoreSchedule _schedule = ChoreSchedule.daily;
  final Set<int> _days = {}; // 1..7 for weekly/custom
  bool _suggestionsOpen = false; // collapsed by default
  final Set<String> _selected = {};
  IconData? _icon;
  Color? _iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Chores'),
      ),
      body: ListView(
        padding: EdgeInsets.all(15),
        children: [
          //SUGGESTIONS COLLAPSED CARD
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _suggestionsOpen,
                maintainState: true,
                onExpansionChanged: (v) => setState(() => _suggestionsOpen = v),
                tilePadding: const EdgeInsets.all(4),
                title: Text('Quick Suggestions', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w700),),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: kSuggestedChores.map((c) {
                        return ActionChip(
                          avatar: Icon(c.icon, size: 18),
                          label: Text(c.title),
                          onPressed: () {
                            final cs = Theme.of(context).colorScheme;
                            setState(() {
                              _title.text  = c.title;
                              _difficultyLvl.text = c.points.toString();
                              _schedule    = c.schedule;
                              _days
                                ..clear()
                                ..addAll(c.daysOfWeek);
                              _icon       = c.icon;
                              _iconColor  = cs.primary;
                            });
                          },
                        );
                      }).toList(),
                    )
                  )
                ],
              ),                
            ),     
          ),
          
          const SizedBox(height: 12),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.surfaceContainerHighest),
              ),
              child: Padding(
                padding: EdgeInsets.all(12), 
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('New Chore',
                      style: TextStyle(
                        color: cs.secondary, fontWeight: FontWeight.w700,
                      )),
                      const SizedBox(height: 8),

                      //Title
                      TextFormField(
                        controller: _title,
                        decoration: InputDecoration(
                          labelText: 'Chore Name..',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onChanged: (_) => setState(() {}),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null, //null means no errors, input is valid
                      ),
                      
                      const SizedBox(height: 8),

                      //Schedule dropdown
                      DropdownButtonFormField<ChoreSchedule>(
                        initialValue: _schedule,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(12),
                        dropdownColor: cs.surface,
                        selectedItemBuilder: (_) => [
                          _ScheduleOptionTile(icon: Icons.calendar_today_rounded, title: 'Daily', cs: cs, compact: true),
                          _ScheduleOptionTile(icon: Icons.calendar_view_week_rounded, title: 'Weekly', cs: cs, compact: true),
                          _ScheduleOptionTile(icon: Icons.tune_rounded, title: 'Custom Days', cs: cs, compact: true),
                        ],
                        items: [
                          DropdownMenuItem(
                            value: ChoreSchedule.daily,
                            child: _ScheduleOptionTile(
                              icon: Icons.calendar_today_rounded, title: 'Daily', subtitle: 'Shows every day', cs: cs),
                          ),
                          DropdownMenuItem(
                            value: ChoreSchedule.weeklyAny,
                            child: _ScheduleOptionTile(
                              icon: Icons.calendar_view_week_rounded, title: 'Weekly', subtitle: 'Pick one day or “any”', cs: cs),
                          ),
                          DropdownMenuItem(
                            value: ChoreSchedule.customDays,
                            child: _ScheduleOptionTile(
                              icon: Icons.tune_rounded, title: 'Custom Days', subtitle: 'Pick multiple weekdays', cs: cs),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _schedule = v;
                            if (_schedule == ChoreSchedule.daily) _days.clear();
                          });
                        },decoration: InputDecoration(
                          labelText: 'Schedule',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      //Weekday row
                      if (_schedule == ChoreSchedule.weeklyAny || _schedule == ChoreSchedule.customDays) ...[
                        const SizedBox(height: 8,),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(7, (i) {
                            const labels = [
                              'Mon','Tue','Wed','Thu','Fri','Sat','Sun'
                            ];
                            final dayVal = i + 1; //Sets the days from 1-7 rather than 0-6
                            final selection = _days.contains(dayVal);
                            return Padding(
                              padding: const EdgeInsets.all(1),
                              child: FilterChip(
                                label: Text(labels[i]),
                                selected: selection,
                                onSelected: (v) => setState(() {
                                  if (_schedule == ChoreSchedule.weeklyAny) {
                                    // Enforce single selection for weekly
                                    _days.clear();
                                    if (v) 
                                    {
                                      _days.add(dayVal);
                                    }
                                  } else {
                                    if (v) {
                                      _days.add(dayVal);
                                    } else {
                                      _days.remove(dayVal);
                                    }
                                  }                              
                                }),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],

                  const SizedBox(height: 8,),

                  Consumer<AppState>(
                    builder: (context, app, _) {
                      //final draft = app.choreDraft; // however you store your current draft
                      //final difficulty = draft.difficulty ?? 3;

                      return DifficultySlider(
                        value: 3,//difficulty,
                        helperText: "Set expectations: 1 is super quick, 5 is big effort.",
                        onChanged: (value) => {},
                        //onChanged: (v) => app.updateChoreDraft(difficulty: v), // implement this
                      );
                    },
                  )
                  ],
                ))
              ),
            ),
        ],
      ),
    );    
  }
  @override
  void dispose() {
    super.dispose();
  }

}

// In assign_tab.dart (below the state class)
class _ScheduleOptionTile extends StatelessWidget {
  const _ScheduleOptionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.cs,
    this.compact = false, // use compact for selectedItemBuilder
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final ColorScheme cs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: compact ? 12 : 14,
      backgroundColor: cs.secondaryContainer,
      child: Icon(icon, size: compact ? 14 : 16, color: cs.onSecondaryContainer),
    );

    return Row(
      children: [
        avatar,
        const SizedBox(width: 8),
        Expanded(
          child: compact
              ? Text(title, overflow: TextOverflow.ellipsis)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
        ),
      ],
    );
  }
}
