import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/pages/parent_dashboard/assign_tab.dart';
import 'package:chorezilla/pages/parent_dashboard/approve_tab.dart';

class ParentChoresTab extends StatefulWidget {
  const ParentChoresTab({super.key});

  @override
  State<ParentChoresTab> createState() => _ParentChoresTabState();
}

class _ParentChoresTabState extends State<ParentChoresTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
            controller: _tabController, // 👈 this was missing
            children: const [AssignTab(), ApproveTab()],
          ),
        ),
      ],
    );
  }
}
