import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/chore_models.dart'; // for scheduleLabel


class ChildDashboardPage extends StatelessWidget {
  const ChildDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final kid = app.currentProfile;

    final chores = (kid == null) ? [] : app.choresForMember(kid.id);
    final points = (kid == null) ? 0 : app.pointsForMemberAllTime(kid.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(kid == null ? 'My chores' : 'Hi, ${kid.name}!'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            color: cs.primaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.stars),
              title: const Text('Points'),
              subtitle: Text('$points total'),
            ),
          ),
          const SizedBox(height: 12),
          if (chores.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No chores yet. Check back later!', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final c in chores)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: cs.surfaceContainerHighest,
              title: Text(c.title),
              subtitle: Text('${c.points} pts • ${scheduleLabel(c)}'),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle),
                color: cs.primary,
                onPressed: () {
                  if (kid == null) return;
                  app.completeChore(c.id, kid.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Great job! +${c.points}')),
                  );
                },
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
