import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/badge.dart';

class KidBadgesPage extends StatelessWidget {
  const KidBadgesPage({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final member = app.members.firstWhere(
      (m) => m.id == memberId,
      orElse: () => app.currentMember ?? app.members.first,
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final allBadges = BadgeCatalog.items;
    final earnedIds = member.badges.toSet();

    final earned = allBadges.where((b) => earnedIds.contains(b.id)).toList();
    final locked = allBadges.where((b) => !earnedIds.contains(b.id)).toList();

    // Nice sorting: earned first by type, then locked
    int typeOrder(BadgeType t) {
      switch (t) {
        case BadgeType.streak:
          return 0;
        case BadgeType.chores:
          return 1;
        case BadgeType.coins:
          return 2;
        case BadgeType.special:
          return 3;
      }
    }

    earned.sort((a, b) {
      final t = typeOrder(a.type).compareTo(typeOrder(b.type));
      return t != 0 ? t : a.name.compareTo(b.name);
    });

    locked.sort((a, b) {
      final t = typeOrder(a.type).compareTo(typeOrder(b.type));
      return t != 0 ? t : a.name.compareTo(b.name);
    });

    final progressText = '${earned.length} / ${allBadges.length}';

    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / progress card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Text('🏅', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your badges',
                          style: ts.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Keep doing chores to unlock more!',
                          style: ts.bodySmall?.copyWith(
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      progressText,
                      style: ts.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (earned.isNotEmpty) ...[
              Text(
                'Earned',
                style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _BadgeGrid(badges: earned, earned: true),
              const SizedBox(height: 18),
            ],

            Text(
              'Locked',
              style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _BadgeGrid(badges: locked, earned: false),
          ],
        ),
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges, required this.earned});

  final List<BadgeDefinition> badges;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int crossAxisCount;
        if (width < 480) {
          crossAxisCount = 2;
        } else if (width < 800) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, i) {
            final b = badges[i];

            final bgColor = earned ? cs.surface : cs.surfaceContainerHighest;
            final borderColor = earned ? cs.primary : Colors.transparent;

            final iconBg = earned ? cs.primaryContainer : cs.surface;
            final iconOpacity = earned ? 1.0 : 0.45;
            final textOpacity = earned ? 1.0 : 0.65;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  backgroundColor: cs.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (ctx) {
                    final t = Theme.of(ctx);
                    final c = t.colorScheme;
                    final text = earned ? b.description : b.unlockHint;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: c.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              b.icon,
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            b.name,
                            style: t.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text,
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: earned
                                  ? c.primaryContainer
                                  : c.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              earned ? 'Earned ✅' : 'Locked 🔒',
                              style: t.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 2),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // icon bubble
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: iconOpacity,
                        child: Text(
                          b.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: textOpacity,
                      child: Text(
                        b.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: earned ? cs.primaryContainer : cs.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            earned ? 'Earned' : 'Locked',
                            style: ts.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          earned
                              ? Icons.check_circle_rounded
                              : Icons.lock_rounded,
                          size: 18,
                          color: earned ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
