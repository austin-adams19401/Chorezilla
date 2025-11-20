import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/models/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';

enum HomeGroupBy { kid, chore }

class ParentHomeTab extends StatefulWidget {
  const ParentHomeTab({super.key});

  @override
  State<ParentHomeTab> createState() => _ParentHomeTabState();
}

class _ParentHomeTabState extends State<ParentHomeTab> {
  static const _prefsKey = 'homeGroupBy';
  HomeGroupBy _groupBy = HomeGroupBy.kid;

  Stream<List<Assignment>>? _todayStream;
  String? _boundFamilyId;
  bool _loadedPref = false;

  @override
  void initState() {
    super.initState();
    _loadGroupingPref();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    if (!app.isReady) return;

    if (!_loadedPref) {
      _loadGroupingPref();
    }
    if (_boundFamilyId != app.familyId) {
      _boundFamilyId = app.familyId;
      _todayStream = app.repo.watchAssignmentsDueToday(_boundFamilyId!);
      setState(() {});
    }
  }

  Future<void> _loadGroupingPref() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_prefsKey);
    setState(() {
      _groupBy = s == 'chore' ? HomeGroupBy.chore : HomeGroupBy.kid;
      _loadedPref = true;
    });
  }

  Future<void> _saveGroupingPref(HomeGroupBy g) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, g == HomeGroupBy.chore ? 'chore' : 'kid');
  }

  @override
  Widget build(BuildContext context) {
    final appReady = context.select((AppState s) => s.isReady);
    if (!appReady || _todayStream == null || !_loadedPref) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Assignment>>(
      stream: _todayStream,
      builder: (context, snap) {
        final items = snap.data ?? const <Assignment>[];

        debugPrint(
          'TODAY ASSIGNMENTS: ${items.map((a) => '${a.choreTitle} @ ${a.due}').toList()}',
        );

        if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return _EmptyToday(onToggle: _toggleGroup);
        }

        final groups = _groupBy == HomeGroupBy.kid
            ? _groupByKey(
                items,
                (a) => (a.memberName.isNotEmpty ? a.memberName : 'Kid'),
                key: (a) => a.memberId,
              )
            : _groupByKey(items, (a) => a.choreTitle, key: (a) => a.choreId);

        final isGroupedByKid = _groupBy == HomeGroupBy.kid;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Due today',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  SegmentedButton<HomeGroupBy>(
                    segments: const [
                      ButtonSegment(
                        value: HomeGroupBy.kid,
                        label: Text('By Kid'),
                      ),
                      ButtonSegment(
                        value: HomeGroupBy.chore,
                        label: Text('By Chore'),
                      ),
                    ],
                    selected: {_groupBy},
                    onSelectionChanged: (s) async {
                      final g = s.first;
                      setState(() => _groupBy = g);
                      await _saveGroupingPref(g);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: groups.length,
                itemBuilder: (_, i) {
                  final g = groups[i];
                  final theme = Theme.of(context);
                  final cs = theme.colorScheme;
                  final ts = theme.textTheme;

                  final allDone =
                      isGroupedByKid &&
                      g.items.isNotEmpty &&
                      g.items.every(
                        (a) => a.status == AssignmentStatus.completed,
                      );

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    color: allDone
                        ? cs.primaryContainer.withValues(alpha: .18)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: allDone ? cs.primary : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                g.title,
                                style: ts.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .2,
                                ),
                              ),
                              const Spacer(),
                              if (allDone)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'All done',
                                        style: ts.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...g.items.map((a) {
                            final status = a.status;
                            final theme = Theme.of(context);
                            final cs = theme.colorScheme;

                            Color? tileColor;
                            BorderSide? side;
                            TextStyle titleStyle = const TextStyle(
                              fontSize: 20,
                            );
                            TextStyle subtitleStyle =
                                theme.textTheme.bodySmall ?? const TextStyle();

                            switch (status) {
                              case AssignmentStatus.assigned:
                                tileColor = null;
                                side = null;
                                break;
                              case AssignmentStatus.pending:
                                tileColor = cs.tertiaryContainer.withValues(alpha: 0.25);
                                side = BorderSide(color: cs.tertiary, width: 2);
                                break;
                              case AssignmentStatus.rejected:
                                tileColor = cs.error.withValues(alpha: 0.15);
                                break;
                              case AssignmentStatus.completed:
                                tileColor = cs.surfaceContainerHighest
                                    .withValues(alpha: 0.2);
                                side = null;
                                titleStyle = titleStyle.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                );
                                break;
                            }

                            final tile = ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Text(
                                (a.choreIcon?.isNotEmpty ?? false)
                                    ? a.choreIcon!
                                    : '🧩',
                                style: const TextStyle(fontSize: 30),
                              ),
                              title: Text(
                                isGroupedByKid
                                    ? a.choreTitle
                                    : (a.memberName.isNotEmpty
                                          ? a.memberName
                                          : 'Kid'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                              subtitle: Text(
                                status.label,
                                style: subtitleStyle,
                              ),
                              tileColor: tileColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: side ?? BorderSide.none,
                              ),
                            );

                            if (status == AssignmentStatus.completed) {
                              return Opacity(opacity: 0.45, child: tile);
                            }
                            return tile;
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleGroup() {
    final next = _groupBy == HomeGroupBy.kid
        ? HomeGroupBy.chore
        : HomeGroupBy.kid;
    setState(() => _groupBy = next);
    _saveGroupingPref(next);
  }

  List<_Group> _groupByKey(
    List<Assignment> src,
    String Function(Assignment) titleOf, {
    required String Function(Assignment) key,
  }) {
    final map = <String, _Group>{};
    for (final a in src) {
      final k = key(a);
      map.putIfAbsent(k, () => _Group(title: titleOf(a), items: []));
      map[k]!.items.add(a);
    }
    final out = map.values.toList();
    out.sort((a, b) => a.title.compareTo(b.title));
    for (final g in out) {
      g.items.sort(
        (a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)),
      );
    }
    return out;
  }
}

class _Group {
  _Group({required this.title, required this.items});
  final String title;
  final List<Assignment> items;
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.onToggle});
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            const Text('Nothing due today'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onToggle,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Switch grouping'),
              style: TextButton.styleFrom(foregroundColor: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}
