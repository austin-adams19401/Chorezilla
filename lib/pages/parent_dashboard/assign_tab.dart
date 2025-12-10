// lib/pages/parent_dashboard/assign_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/pages/parent_dashboard/chore_editor_sheet.dart';
import 'package:chorezilla/pages/parent_dashboard/chore_schedule_page.dart';

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.secondary,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: cs.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    color: cs.onSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage chores',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Create chores once, then schedule them for each kid.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSecondary.withValues(alpha: .9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              elevation: 0,
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: cs.surface,
                  hintText: 'Search chores',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(
                      color: cs.outlineVariant,
                      width: 1.4,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) {
                  _deb?.cancel();
                  _deb = Timer(const Duration(milliseconds: 200), () {
                    if (mounted) setState(() => _q = v);
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            // Main panel
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.secondary, cs.secondary, cs.primary],
                    stops: const [0.0, 0.55, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ValueListenableBuilder<List<Chore>>(
                    valueListenable: app.choresVN,
                    builder: (_, choresList, _) {
                      final chores = choresList
                          .where((c) => c.active)
                          .where(
                            (c) =>
                                _q.isEmpty ||
                                c.title.toLowerCase().contains(
                                  _q.toLowerCase(),
                                ),
                          )
                          .toList();

                      if (chores.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🧹',
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No chores yet',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap “New chore” to start your list.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ValueListenableBuilder<List<Assignment>>(
                        valueListenable: app.familyAssignedVN,
                        builder: (_, assignedList, _) {
                          final theme = Theme.of(context);
                          final cs = theme.colorScheme;

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                            itemCount: chores.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final c = chores[i];

                              final assignedMembers = app
                                  .assignedMembersForChore(c.id);

                              return Card(
                                elevation: 0,
                                color: cs.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: cs.outlineVariant,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      height: 60,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        c.icon?.isNotEmpty == true
                                            ? c.icon!
                                            : '🧩',
                                        style: const TextStyle(fontSize: 35),
                                      ),
                                    ),
                                    title: Text(
                                      c.title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(height: 2),
                                        Text(
                                          _difficultyName(c.difficulty),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 2,
                                          children: [
                                            if (assignedMembers.isEmpty)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.person_outline,
                                                    size: 16,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'No one scheduled yet',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: cs
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              )
                                            else
                                              ...assignedMembers.map((m) {
                                                final name = m.displayName;
                                                final initial =
                                                    (name.isNotEmpty)
                                                    ? name
                                                          .substring(0, 1)
                                                          .toUpperCase()
                                                    : '?';
                                                return CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor:
                                                      cs.primaryContainer,
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
                                            backgroundColor:
                                                cs.primaryContainer,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _openSchedulePage(context, c),
                                          child: const Text('Schedule'),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: 'Edit',
                                          onPressed: () =>
                                              _openEditChoreSheet(context, c),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                          ),
                                          tooltip: 'Delete',
                                          onPressed: () =>
                                              _confirmDeleteChore(c),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _openSchedulePage(context, c),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'parent-assign-fab',
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
      builder: (_) => ChoreEditorSheet(family: fam),
    );
    if (!mounted) return;
    if (created == true) {
      setState(() {}); // refresh filters immediately so the new chore appears
    }
  }

  Future<void> _openEditChoreSheet(BuildContext context, Chore chore) async {
    final app = context.read<AppState>();
    final fam = app.family!;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChoreEditorSheet(family: fam, chore: chore),
    );
    if (!mounted) return;
    if (saved == true) {
      setState(() {}); // refresh list
    }
  }

  void _openSchedulePage(BuildContext context, Chore chore) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChoreSchedulePage(chore: chore)));
  }
}
