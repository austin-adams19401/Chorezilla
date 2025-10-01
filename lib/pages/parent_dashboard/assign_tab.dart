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
  final _points = TextEditingController(text: '5');

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
        title: Text('Chores Overview'),
        centerTitle: true,
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
                              _points.text = c.points.toString();
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
