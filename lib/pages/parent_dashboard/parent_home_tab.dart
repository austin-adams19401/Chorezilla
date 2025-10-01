import 'package:chorezilla/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shows an overview for today/week. Read-only check indicators.
/// Public widget (no underscore) so it can be imported by the shell.
class ParentHomeTab extends StatefulWidget {
  const ParentHomeTab({super.key});

  @override
  State<ParentHomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<ParentHomeTab> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    // final chores = app.chores.choreListForToday; // example if you split state

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chore overview'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(title: "Today's Chores"),
            const SizedBox(height: 12),
            _StatsRow(), // replace with your own small summary widget
      
            const SizedBox(height: 12),
      
            // TODO: Replace with your grid/list of chores/day cells.
            // NOTE: Home tab is view-only; completion happens in the Check Off tab.
            Expanded(
              child: ListView(
                children: const [
                  _ReadOnlyChoreRow(
                    title: 'Example chore',
                    isScheduled: true,
                    isCompleted: false,
                  ),
                  _ReadOnlyChoreRow(
                    title: 'Example chore 2',
                    isScheduled: true,
                    isCompleted: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Private helper widgets stay in the same file and start with underscore.
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    // TODO: replace with your own stat chips (e.g., total, done, remaining)
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(child: Text('Stats here')),
        ],
      ),
    );
  }
}

class _ReadOnlyChoreRow extends StatelessWidget {
  const _ReadOnlyChoreRow({
    required this.title,
    required this.isScheduled,
    required this.isCompleted,
  });

  final String title;
  final bool isScheduled;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final icon = isScheduled
        ? (isCompleted ? Icons.check_circle : Icons.radio_button_unchecked)
        : Icons.remove_circle_outline;

    final color = isCompleted
        ? Colors.green
        : (isScheduled ? Colors.grey : Colors.redAccent);

    return ListTile(
      title: Text(title),
      // NOTE: This is read-only. No onTap / onChanged handlers here.
      trailing: Icon(icon, size: 20, color: color),
    );
  }
}
