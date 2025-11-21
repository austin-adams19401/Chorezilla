import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/components/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/models/common.dart';

class ChildDashboardPage extends StatefulWidget {
  const ChildDashboardPage({super.key, this.memberId});

  /// If omitted, we’ll fall back to AppState.currentMember.
  final String? memberId;

  @override
  State<ChildDashboardPage> createState() => _ChildDashboardPageState();
}

class _ChildDashboardPageState extends State<ChildDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _busyIds = {}; // assignmentIds being completed
  String? _watchingMemberId;
  int? _lastSeenLevel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStreamsForCurrentKid());
  }

  @override
  void didUpdateWidget(covariant ChildDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the page was rebuilt with a different memberId, restart streams
    if (oldWidget.memberId != widget.memberId) {
      _restartStreams();
    }
  }

  @override
  void dispose() {
    final app = context.read<AppState>();
    if (_watchingMemberId != null) app.stopKidStreams(_watchingMemberId!);
    super.dispose();
  }

  void _restartStreams() {
    final app = context.read<AppState>();
    if (_watchingMemberId != null) {
      app.stopKidStreams(_watchingMemberId!);
      _watchingMemberId = null;
    }
    _startStreamsForCurrentKid();
  }

void _startStreamsForCurrentKid() {
    final app = context.read<AppState>();
    final member = _resolveMember(app);
    if (member == null) return;

    _watchingMemberId = member.id;

    _lastSeenLevel = null;

    app.startKidStreams(member.id);
  }


  Member? _resolveMember(AppState app) {
    if (!app.isReady) return null;
    if (widget.memberId != null) {
      return app.members.where((m) => m.id == widget.memberId).cast<Member?>().firstOrNull;
    }
    return app.currentMember ?? app.members.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();

    if (!app.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final member = _resolveMember(app);
    if (member == null) {
      return const Scaffold(
        body: Center(child: Text('No kid selected')),
      );
    }
    if (member.role != FamilyRole.child) {
      return const Scaffold(
        body: Center(child: Text('This dashboard is for child accounts.')),
      );
    }

    _handleLevelChange(member);

    final todos = [...app.assignedForKid(member.id)]..sort(_byDueThenTitle);

    // All completed for this kid
    final completedAll = app.completedForKid(member.id);

    // Filter to only "today"
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final completedToday = completedAll.where((a) {
      final t = a.completedAt;
      if (t == null) return false;
      return !t.isBefore(todayStart) && t.isBefore(tomorrowStart);
    }).toList()..sort(_byCompletedAtDescThenTitle);

    final submitted = [...app.pendingForKid(member.id)]..sort(_byDueThenTitle);



    return Scaffold(
      appBar: AppBar(title: const Text('Chorezilla')),
      body: Column(
        children: [
          // Profile header (kid)
          ProfileHeader(member: member, showInviteButton: false, showSwitchButton: false),
          const SizedBox(height: 8),

          // Tabs: To Do / Submitted
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'To Do'),
                      Tab(text: 'Submitted'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
_TodoList(
                          memberId: member.id,
                          items: todos,
                          completedToday: completedToday, // 👈 NEW
                          busyIds: _busyIds,
                          onComplete: _completeAssignment,
                        ),
                        _SubmittedList(items: submitted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

Future<void> _completeAssignment(Assignment a) async {
    final app = context.read<AppState>();
    setState(() => _busyIds.add(a.id));
    try {
      await app.completeAssignment(a.id);

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(a.id));
    }
  }

  void _handleLevelChange(Member member) {
    // Use your helper to compute level from total XP
    final info = levelInfoForXp(member.xp);
    final newLevel = info.level;

    final prev = _lastSeenLevel;

    if (prev == null) {
      // First time seeing this kid on this screen → just record level
      _lastSeenLevel = newLevel;
      return;
    }

    if (newLevel > prev) {
      // LEVEL UP! 🎉
      _lastSeenLevel = newLevel;
      final levelInfo = info;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLevelUpDialog(member, levelInfo);
      });
    } else if (newLevel != prev) {
      // XP went down or we jumped around (e.g., profile reset) → resync
      _lastSeenLevel = newLevel;
    }
  }

  Future<void> _showLevelUpDialog(Member member, LevelInfo info) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: cs.surface,
                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  title: Row(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Level up!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${member.displayName} reached Level ${info.level}!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${info.xpIntoLevel} / ${info.xpNeededThisLevel} XP for this level',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Keep going to earn more coins and unlock rewards!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Awesome!'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }



  // ---- Helpers --------------------------------------------------------------

  int _byDueThenTitle(Assignment a, Assignment b) {
    final ad = a.due;
    final bd = b.due;
    if (ad == null && bd == null) {
      return a.choreTitle.compareTo(b.choreTitle);
    } else if (ad == null) {
      return 1;
    } else if (bd == null) {
      return -1;
    } else {
      final cmp = ad.compareTo(bd);
      return cmp != 0 ? cmp : a.choreTitle.compareTo(b.choreTitle);
    }
  }

  int _byCompletedAtDescThenTitle(Assignment a, Assignment b) {
    final ad = a.completedAt;
    final bd = b.completedAt;
    if (ad == null && bd == null) {
      return a.choreTitle.compareTo(b.choreTitle);
    } else if (ad == null) {
      return 1;
    } else if (bd == null) {
      return -1;
    } else {
      final cmp = bd.compareTo(ad); // newest first
      return cmp != 0 ? cmp : a.choreTitle.compareTo(b.choreTitle);
    }
  }

  @override
  bool get wantKeepAlive => true;
}

// ============================================================================
// Widgets
// ============================================================================

class _TodoList extends StatelessWidget {
  const _TodoList({
    required this.memberId,
    required this.items,
    required this.completedToday,
    required this.busyIds,
    required this.onComplete,
  });

  final String memberId;
  final List<Assignment> items;
  final Set<String> busyIds;
  final Future<void> Function(Assignment) onComplete;  
  final List<Assignment> completedToday;

  @override
  Widget build(BuildContext context) {
    final hasTodos = items.isNotEmpty;
    final hasCompleted = completedToday.isNotEmpty;

    if (!hasTodos && !hasCompleted) {
      return const _EmptyState(
        emoji: '🎉',
        title: 'All caught up!',
        subtitle: 'No chores to do right now.',
      );
    }

    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (hasTodos) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              'To do',
              style: ts.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          ...items.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AssignmentTile(
                assignment: a,
                completed: false,
                trailing: FilledButton(
                  onPressed: busyIds.contains(a.id)
                      ? null
                      : () => onComplete(a),
                  child: busyIds.contains(a.id)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Mark done'),
                ),
              ),
            );
          }),
          if (hasCompleted) const SizedBox(height: 16),
        ],

        if (hasCompleted) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              'Done today',
              style: ts.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          ...completedToday.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AssignmentTile(
                assignment: a,
                completed: true,
                trailing: Icon(Icons.check_circle_rounded, color: cs.primary),
              ),
            );
          }),
        ],
      ],
    );
  }

}

class _SubmittedList extends StatelessWidget {
  const _SubmittedList({required this.items});
  final List<Assignment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        emoji: '⌛',
        title: 'Nothing submitted yet',
        subtitle: 'Pending chores will show up here until a parent reviews them.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = items[i];
        return _AssignmentTile(
          assignment: a,
          trailing: const _StatusPill(text: 'Pending review'),
        );
      },
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.trailing,
    this.completed = false,
  });

  final Assignment assignment;
  final Widget trailing;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final icon = assignment.choreIcon?.trim();
    final due = assignment.due;
    final dueText = _formatDue(due);
    final overdue = due != null && due.isBefore(DateTime.now());


    const double iconBoxSize = 50; // size of the colored square
    final double emojiSize = iconBoxSize * 0.65; // scale text with box

    // Style variants when completed
    final baseTitleStyle = ts.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final titleStyle = completed
        ? baseTitleStyle?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: cs.onSurfaceVariant,
          )
        : baseTitleStyle;

    final xpStyle = completed
        ? ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant)
        : ts.bodyMedium;

    return Card(
      elevation: 0,
      color: completed ? cs.surfaceContainerHighest : null, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Text(
                    icon == null || icon.isEmpty ? '🧩' : icon,
                    style: TextStyle(
                      fontSize: emojiSize, 
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.choreTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.add,
                        size: 16,
                        color: cs.secondary,
                      ),
                      const SizedBox(width: 1),
                      Text('${assignment.xp} pts', style: xpStyle),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }

  String? _formatDue(DateTime? due) {
    if (due == null) return null;
    final now = DateTime.now();
    final dDate = DateTime(due.year, due.month, due.day);
    final nDate = DateTime(now.year, now.month, now.day);
    final diff = dDate.difference(nDate).inDays;

    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff == -1) return 'Due yesterday';
    if (diff > 1 && diff <= 7) return 'Due in $diff days';
    if (diff < -1 && diff >= -7) return '${diff.abs()} days overdue';
    // Fallback date
    return '${due.month}/${due.day}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
    );
  }
}

// Simple empty-state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.emoji, required this.title, required this.subtitle});
  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text(title, style: ts.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// handy extension
extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
