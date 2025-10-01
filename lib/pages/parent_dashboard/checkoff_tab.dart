import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../state/app_state.dart';
// import '../../models/chore_models.dart';

/// Where completion is allowed. Toggling done/undone lives here.
class CheckOffTab extends StatefulWidget {
  const CheckOffTab({super.key});

  @override
  State<CheckOffTab> createState() => _CheckOffTabState();
}

class _CheckOffTabState extends State<CheckOffTab> {
  @override
  Widget build(BuildContext context) {
    // final app = context.watch<AppState>();
    // final today = app.chores.choreListForToday;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // EXAMPLE of interactive toggle:
          _CheckItem(
            title: 'Example chore (interactive here)',
            isDone: false,
            onToggle: (v) {
              // TODO: call into AppState to mark done/undone
              // context.read<AppState>().chores.setDone(choreId, v);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Toggled to $v')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.title,
    required this.isDone,
    required this.onToggle,
  });

  final String title;
  final bool isDone;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(title),
      value: isDone,
      onChanged: (v) => onToggle(v ?? false),
    );
  }
}
