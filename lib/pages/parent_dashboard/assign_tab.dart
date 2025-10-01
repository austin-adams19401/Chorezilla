import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../state/app_state.dart';
// import '../../models/chore_models.dart';

/// Parent assigns chores to kids; supports filters, search, etc.
/// Keep state local unless multiple tabs/screens need to share it.
class AssignTab extends StatefulWidget {
  const AssignTab({super.key});

  @override
  State<AssignTab> createState() => _AssignTabState();
}

class _AssignTabState extends State<AssignTab> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final app = context.watch<AppState>();
    // final members = app.family.members; // example

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search chores or members',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              children: const [
                // TODO: render chores grouped by member, with add/remove assign actions
                ListTile(title: Text('Assignment UI placeholder')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
