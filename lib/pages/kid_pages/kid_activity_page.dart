import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/common.dart';

class KidActivityPage extends StatelessWidget {
  const KidActivityPage({super.key, this.memberId});

  final String? memberId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final member = _resolveMember(app);
    if (member == null) {
      return const Scaffold(body: Center(child: Text('No kid selected')));
    }
    if (member.role != FamilyRole.child) {
      return const Scaffold(
        body: Center(child: Text('Activity is for child accounts.')),
      );
    }

    // Data sources
    final completed = app.completedForKid(member.id);
    final redemptions = app.rewardRedemptionsForKid(member.id);

    final items = <_ActivityItem>[];

    // Completed chores → XP earned
    for (final a in completed) {
      final dt = a.completedAt ?? DateTime.now();
      items.add(
        _ActivityItem(
          time: dt,
          type: _ActivityType.choreCompleted,
          title: a.choreTitle,
          xpDelta: a.xp,
          coinDelta: null,
        ),
      );
    }

    // Reward redemptions → coins spent
    for (final r in redemptions) {
      final dt = r.givenAt ?? r.createdAt ?? DateTime.now();
      items.add(
        _ActivityItem(
          time: dt,
          type: _ActivityType.rewardPurchase,
          title: r.rewardName,
          xpDelta: null,
          coinDelta: -r.coinCost,
          status: r.status,
        ),
      );
    }

    // Sort newest first
    items.sort((a, b) => b.time.compareTo(a.time));

    return Scaffold(
      appBar: AppBar(title: Text('${member.displayName}’s activity')),
      body: items.isEmpty
          ? const _EmptyStateActivity(
              emoji: '✨',
              title: 'No activity yet',
              subtitle:
                  'When you finish chores or buy rewards, they’ll show up here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _ActivityTile(item: item);
              },
            ),
    );
  }

  Member? _resolveMember(AppState app) {
    if (!app.isReady) return null;

    if (memberId != null) {
      try {
        return app.members.firstWhere((m) => m.id == memberId);
      } catch (_) {
        // fall through
      }
    }

    if (app.currentMember != null) {
      return app.currentMember;
    }

    return app.members.isNotEmpty ? app.members.first : null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity model (UI-only)
// ─────────────────────────────────────────────────────────────────────────────

enum _ActivityType { choreCompleted, rewardPurchase }

class _ActivityItem {
  _ActivityItem({
    required this.time,
    required this.type,
    required this.title,
    this.xpDelta,
    this.coinDelta,
    this.status,
  });

  final DateTime time;
  final _ActivityType type;
  final String title;
  final int? xpDelta;
  final int? coinDelta;
  final String? status;
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity tile
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    IconData icon;
    Color iconColor;
    String subtitle;

    switch (item.type) {
      case _ActivityType.choreCompleted:
        icon = Icons.check_circle_rounded;
        iconColor = cs.primary;
        subtitle = 'Completed a chore';
        break;
      case _ActivityType.rewardPurchase:
        icon = Icons.card_giftcard_rounded;
        iconColor = cs.secondary;
        final statusText = _friendlyStatus(item.status);
        subtitle = 'Bought a reward • $statusText';
        break;
    }

    final chips = <Widget>[];

    if (item.xpDelta != null && item.xpDelta! > 0) {
      chips.add(
        _DeltaChip(
          label: '+${item.xpDelta} XP',
          color: cs.primaryContainer,
          textColor: cs.onPrimaryContainer,
        ),
      );
    }

    if (item.coinDelta != null && item.coinDelta != 0) {
      final isNegative = item.coinDelta! < 0;
      final abs = item.coinDelta!.abs();
      chips.add(
        _DeltaChip(
          label: '${isNegative ? '-' : '+'}$abs coins',
          color: isNegative ? cs.errorContainer : cs.secondaryContainer,
          textColor: isNegative ? cs.onErrorContainer : cs.onSecondaryContainer,
        ),
      );
    }

    final dateText = _formatDate(item.time);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (chips.isNotEmpty) ...chips,
                      _DeltaChip(
                        label: dateText,
                        color: cs.surfaceContainerHighest,
                        textColor: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyStatus(String? status) {
    switch (status) {
      case 'pending':
        return 'waiting for parent';
      case 'given':
      case 'fulfilled':
        return 'given';
      case 'cancelled':
        return 'cancelled';
      default:
        return status ?? '';
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDate = DateTime(dt.year, dt.month, dt.day);

    final isToday = dDate == today;
    final isYesterday = dDate == today.subtract(const Duration(days: 1));

    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timePart = '$hh:$mm $ampm';

    if (isToday) return 'Today · $timePart';
    if (isYesterday) return 'Yesterday · $timePart';

    return '${dt.month}/${dt.day}/${dt.year} · $timePart';
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Simple empty state
class _EmptyStateActivity extends StatelessWidget {
  const _EmptyStateActivity({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

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
            Text(
              subtitle,
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
