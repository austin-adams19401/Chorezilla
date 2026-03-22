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
  const AssignTab({super.key, this.onNewChore});

  /// Called when the "New chore" FAB is tapped. Provided by the parent
  /// so the FAB can live in manage_chores_tab.dart.
  final VoidCallback? onNewChore;

  @override
  State<AssignTab> createState() => _AssignTabState();
}

class _AssignTabState extends State<AssignTab> {
  String _q = '';
  Timer? _deb;
  final _searchCtrl = TextEditingController();
  final Set<int> _selectedDifficulties = {};

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtrl.dispose();
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
      primary: false,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.secondary, cs.secondary, cs.primary],
            stops: const [0.0, 0.55, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // ── Search bar ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  elevation: 0,
                  child: TextField(
                    controller: _searchCtrl,
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
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Difficulty filter chips ──────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedDifficulties.isEmpty,
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _selectedDifficulties.clear()),
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(6, (d) {
                      final color = _difficultyColor(d, cs);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(_difficultyName(d)),
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                          selected: _selectedDifficulties.contains(d),
                          showCheckmark: false,
                          onSelected: (on) => setState(() {
                            if (on) {
                              _selectedDifficulties.add(d);
                            } else {
                              _selectedDifficulties.remove(d);
                            }
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Chore list / empty states ────────────────────────────────────
            _buildChoreListSliver(context, app, theme, cs),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'parent-assign-fab',
        onPressed: widget.onNewChore,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New chore'),
      ),
    );
  }

  Widget _buildChoreListSliver(
    BuildContext context,
    AppState app,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return ValueListenableBuilder<List<Chore>>(
      valueListenable: app.choresVN,
      builder: (_, choresList, _) {
        final chores = choresList
            .where((c) => c.active)
            .where(
              (c) =>
                  _q.isEmpty ||
                  c.title.toLowerCase().contains(_q.toLowerCase()),
            )
            .where(
              (c) =>
                  _selectedDifficulties.isEmpty ||
                  _selectedDifficulties.contains(c.difficulty),
            )
            .toList();

        final hasAnyChores = choresList.any((c) => c.active);

        if (!hasAnyChores) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
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
                      'Tap "New chore" to start your list.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (chores.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _q.isNotEmpty
                          ? 'No results for "$_q"'
                          : 'No chores match the selected filters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _q = '';
                        _searchCtrl.clear();
                        _selectedDifficulties.clear();
                      }),
                      child: const Text(
                        'Clear filters',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ValueListenableBuilder<List<Assignment>>(
          valueListenable: app.familyAssignedVN,
          builder: (_, assignedList, _) {
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
              sliver: SliverList.separated(
                itemCount: chores.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = chores[i];
                  final assignedMembers = app.assignedMembersForChore(c.id);

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
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                            c.icon?.isNotEmpty == true ? c.icon! : '🧩',
                            style: const TextStyle(fontSize: 35),
                          ),
                        ),
                        title: Text(
                          c.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _difficultyColor(c.difficulty, cs),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _difficultyName(c.difficulty),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  )
                                else
                                  ...assignedMembers.map((m) {
                                    final name = m.displayName;
                                    final initial =
                                        (name.isNotEmpty)
                                        ? name.substring(0, 1).toUpperCase()
                                        : '?';
                                    return CircleAvatar(
                                      radius: 12,
                                      backgroundColor: cs.primaryContainer,
                                      child: Text(
                                        initial,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }),
                                if (c.requiresApproval)
                                  Tooltip(
                                    message: 'Requires approval',
                                    child: Icon(
                                      Icons.fact_check_outlined,
                                      size: 14,
                                      color: cs.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                              onPressed: () => _confirmDeleteChore(c),
                            ),
                          ],
                        ),
                        onTap: () => _openSchedulePage(context, c),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Color _difficultyColor(int d, ColorScheme cs) => switch (d) {
    0 => cs.outline,
    1 => Colors.green.shade300,
    2 => Colors.green,
    3 => Colors.orange,
    4 => Colors.deepOrange,
    5 => cs.error,
    _ => cs.outline,
  };

  String _difficultyName(int d) {
    switch (d) {
      case 0:
        return 'Reminder';
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

  Future<void> _openEditChoreSheet(BuildContext context, Chore chore) async {
    final app = context.read<AppState>();
    final fam = app.family!;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChoreEditorSheet(family: fam, chore: chore),
    );
  }

  void _openSchedulePage(BuildContext context, Chore chore) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChoreSchedulePage(chore: chore)));
  }
}
