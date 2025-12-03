import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/pages/parent_dashboard/assign_tab.dart';
import 'package:chorezilla/pages/parent_dashboard/approve_tab.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final app = context.read<AppState>();

    return Column(
      children: [
        // ── Tab strip ──────────────────────────────────────────────────────
        Material(
          color: cs.surface,
          elevation: 1,
          child: SafeArea(
            bottom: false,
            child: ValueListenableBuilder<List<Assignment>>(
              valueListenable: app.reviewQueueVN,
              builder: (_, queue, _) {
                final count = queue.length;

                return TabBar(
                  controller: _tabController,
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  indicatorColor: cs.primary,
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

        // ── Tab bodies ─────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [AssignTab(), ApproveTab()],
          ),
        ),
      ],
    );
  }
}
