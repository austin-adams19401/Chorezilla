import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/pages/parent_dashboard/assign_tab.dart';
import 'package:chorezilla/pages/parent_dashboard/approve_tab.dart';
import 'package:chorezilla/pages/parent_dashboard/chore_editor_sheet.dart';

class ParentChoresTab extends StatefulWidget {
  const ParentChoresTab({
    super.key,
    this.initialTabIndex = 0, // 0 = Assign, 1 = Review
  });

  final int initialTabIndex;

  @override
  State<ParentChoresTab> createState() => _ParentChoresTabState();
}

class _ParentChoresTabState extends State<ParentChoresTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _clearedIntent = false;

  @override
  void initState() {
    super.initState();

    // Clamp initial index to [0, 1] for safety
    int initial = widget.initialTabIndex;
    if (initial < 0) initial = 0;
    if (initial > 1) initial = 1;

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initial,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Clear nav intent (if any) once this tab has been built the first time
    if (!_clearedIntent) {
      _clearedIntent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final app = context.read<AppState>();
        if (app.pendingNavTarget == 'parent_approve') {
          app.clearNavIntent();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openNewChoreSheet() async {
    final app = context.read<AppState>();
    final fam = app.family!;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChoreEditorSheet(family: fam),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final app = context.read<AppState>();

    return NestedScrollView(
      headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
        // ── Floating title — scrolls away on scroll, snaps back on flick ──
        SliverAppBar(
          floating: true,
          snap: true,
          automaticallyImplyLeading: false,
          toolbarHeight: 40,
          expandedHeight: 40,
          backgroundColor: cs.secondary,
          foregroundColor: Colors.white,
          elevation: 0,
          forceElevated: innerBoxIsScrolled,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            titlePadding: EdgeInsets.zero,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Chores',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        // ── Pinned pill TabBar — always visible ────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            tabController: _tabController,
            reviewQueueVN: app.reviewQueueVN,
            colorScheme: cs,
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          AssignTab(onNewChore: _openNewChoreSheet),
          const ApproveTab(),
        ],
      ),
    );
  }
}

// ── Pinned pill TabBar delegate ─────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({
    required this.tabController,
    required this.reviewQueueVN,
    required this.colorScheme,
  });

  final TabController tabController;
  final ValueListenable<List<Assignment>> reviewQueueVN;
  final ColorScheme colorScheme;

  // Tab with icon-above-text ≈ 72px + 4px pill padding (top+bottom) + 12px bottom = 88px
  static const double _height = 88.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabController != tabController ||
      old.reviewQueueVN != reviewQueueVN ||
      old.colorScheme != colorScheme;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final cs = colorScheme;

    return Material(
      color: cs.secondary,
      elevation: overlapsContent ? 2 : 0,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.all(4),
          child: ValueListenableBuilder<List<Assignment>>(
            valueListenable: reviewQueueVN,
            builder: (_, queue, _) {
              final count = queue.length;

              return TabBar(
                controller: tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: cs.secondary,
                unselectedLabelColor: Colors.white70,
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.assignment_outlined),
                    text: 'Assign',
                  ),
                  Tab(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.rate_review_outlined),
                        if (count > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: cs.error,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 16,
                              ),
                              child: Center(
                                child: Text(
                                  count > 9 ? '9+' : '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    text: 'Review',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
