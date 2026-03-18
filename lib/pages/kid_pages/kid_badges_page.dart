import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/badge.dart';
import 'package:chorezilla/models/member.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

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
    final earnedBadges = <BadgeDefinition>[];
    final lockedBadges = <BadgeDefinition>[];

    for (final b in allBadges) {
      final earned = b.isTiered
          ? b.currentTierForMember(member.badges) != BadgeTier.locked
          : member.badges.contains(b.id);
      (earned ? earnedBadges : lockedBadges).add(b);
    }

    Future<void> saveFeatured(List<String> ids) async {
      await context.read<AppState>().updateMember(
        memberId,
        {'featuredBadgeIds': ids},
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header count ──────────────────────────────────────────────
            Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  '${earnedBadges.length} of ${allBadges.length} badges earned',
                  style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Featured slots ────────────────────────────────────────────
            _SectionLabel(text: 'FEATURED', cs: cs, ts: ts),
            const SizedBox(height: 4),
            Text(
              'Choose up to 3 to show on your profile card.',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(3, (i) {
                final ids = member.featuredBadgeIds;
                final badgeId = i < ids.length ? ids[i] : null;
                final def = badgeId != null ? BadgeCatalog.byId(badgeId) : null;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                    child: _FeaturedSlot(
                      slotIndex: i,
                      badge: def,
                      member: member,
                      earnedBadges: earnedBadges,
                      onSave: saveFeatured,
                    ),
                  ),
                );
              }),
            ),

            // ── Earned ───────────────────────────────────────────────────
            if (earnedBadges.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionLabel(text: 'EARNED', cs: cs, ts: ts),
              const SizedBox(height: 10),
              _CompactBadgeGrid(
                badges: earnedBadges,
                member: member,
                dimmed: false,
                onSaveFeatured: saveFeatured,
              ),
            ],

            // ── Locked ───────────────────────────────────────────────────
            if (lockedBadges.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionLabel(text: 'LOCKED', cs: cs, ts: ts),
              const SizedBox(height: 10),
              _CompactBadgeGrid(
                badges: lockedBadges,
                member: member,
                dimmed: true,
                onSaveFeatured: null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.cs,
    required this.ts,
  });

  final String text;
  final ColorScheme cs;
  final TextTheme ts;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ts.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured slot
// ─────────────────────────────────────────────────────────────────────────────

class _PickerResult {
  const _PickerResult({this.badge, this.cleared = false});
  final BadgeDefinition? badge;
  final bool cleared;
}

class _FeaturedSlot extends StatelessWidget {
  const _FeaturedSlot({
    required this.slotIndex,
    required this.badge,
    required this.member,
    required this.earnedBadges,
    required this.onSave,
  });

  final int slotIndex;
  final BadgeDefinition? badge;
  final Member member;
  final List<BadgeDefinition> earnedBadges;
  final Future<void> Function(List<String>) onSave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge == null
              ? _EmptySlot(cs: cs)
              : _FilledSlotBadge(badge: badge!, member: member, cs: cs),
          const SizedBox(height: 6),
          Text(
            badge?.name ?? 'Tap to add',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ts.labelSmall?.copyWith(
              color: badge == null ? cs.onSurfaceVariant : cs.onSurface,
              fontStyle: badge == null ? FontStyle.italic : FontStyle.normal,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.62,
        child: _BadgePickerSheet(
          earnedBadges: earnedBadges,
          currentBadge: badge,
          member: member,
        ),
      ),
    );

    if (!context.mounted || result == null) return;

    // Build a 3-slot array to preserve slot positions
    final current = member.featuredBadgeIds;
    final slots = List<String?>.filled(3, null);
    for (int i = 0; i < current.length && i < 3; i++) {
      slots[i] = current[i];
    }

    if (result.cleared) {
      slots[slotIndex] = null;
    } else if (result.badge != null) {
      final newId = result.badge!.id;
      for (int i = 0; i < 3; i++) {
        if (slots[i] == newId && i != slotIndex) slots[i] = null;
      }
      slots[slotIndex] = newId;
    }

    await onSave(slots.whereType<String>().toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty slot (dashed circle)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 72,
        height: 72,
        child: CustomPaint(
          painter: _DashedCirclePainter(color: cs.outlineVariant),
          child: Center(
            child: Icon(Icons.add_rounded, color: cs.outlineVariant, size: 26),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filled slot badge
// ─────────────────────────────────────────────────────────────────────────────

class _FilledSlotBadge extends StatelessWidget {
  const _FilledSlotBadge({
    required this.badge,
    required this.member,
    required this.cs,
  });

  final BadgeDefinition badge;
  final Member member;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final currentTier = badge.currentTierForMember(member.badges);
    final progress = badge.progressForMember(member);
    final ringColor = _tierRingColor(currentTier);
    final assetPath = badge.isTiered
        ? badge.assetPathForTier(
            currentTier == BadgeTier.locked ? BadgeTier.bronze : currentTier)
        : badge.assetPath;

    return Center(
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  color: ringColor,
                  trackColor: cs.outlineVariant.withValues(alpha: 0.3),
                  strokeWidth: 5,
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: 50,
                height: 50,
                child: assetPath != null
                    ? Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            _EmojiIcon(badge.icon, size: 28),
                      )
                    : _EmojiIcon(badge.icon, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact badge grid
// ─────────────────────────────────────────────────────────────────────────────

class _CompactBadgeGrid extends StatelessWidget {
  const _CompactBadgeGrid({
    required this.badges,
    required this.member,
    required this.dimmed,
    this.onSaveFeatured,
  });

  final List<BadgeDefinition> badges;
  final Member member;
  final bool dimmed;
  final Future<void> Function(List<String>)? onSaveFeatured;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 300 ? 3 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, i) => _CompactBadgeItem(
            badge: badges[i],
            member: member,
            dimmed: dimmed,
            onSaveFeatured: onSaveFeatured,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact badge item
// ─────────────────────────────────────────────────────────────────────────────

class _CompactBadgeItem extends StatelessWidget {
  const _CompactBadgeItem({
    required this.badge,
    required this.member,
    required this.dimmed,
    this.onSaveFeatured,
  });

  final BadgeDefinition badge;
  final Member member;
  final bool dimmed;
  final Future<void> Function(List<String>)? onSaveFeatured;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final currentTier = badge.currentTierForMember(member.badges);
    final progress = badge.progressForMember(member);
    final ringColor = _tierRingColor(currentTier);
    final assetPath = badge.isTiered
        ? badge.assetPathForTier(
            currentTier == BadgeTier.locked ? BadgeTier.bronze : currentTier)
        : badge.assetPath;
    final isFeatured = member.featuredBadgeIds.contains(badge.id);

    return GestureDetector(
      onTap: () => _showDetail(context, currentTier, progress),
      child: Opacity(
        opacity: dimmed ? 0.45 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: dimmed ? 0 : progress,
                          color: ringColor,
                          trackColor: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: assetPath != null
                            ? Image.asset(
                                assetPath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    _EmojiIcon(badge.icon, size: 22),
                              )
                            : _EmojiIcon(badge.icon, size: 22),
                      ),
                    ),
                    if (isFeatured && !dimmed)
                      Positioned(
                        top: 0,
                        right: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ts.labelSmall?.copyWith(
                fontSize: 10,
                height: 1.2,
                color: dimmed ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(
      BuildContext context, BadgeTier currentTier, double progress) {
    final isFeatured = member.featuredBadgeIds.contains(badge.id);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BadgeDetailSheet(
        badge: badge,
        member: member,
        currentTier: currentTier,
        progress: progress,
        isEarned: !dimmed,
        isFeatured: isFeatured,
        onFeaturedToggle: onSaveFeatured == null
            ? null
            : () async {
                final current = List<String>.from(member.featuredBadgeIds);
                if (isFeatured) {
                  current.remove(badge.id);
                } else if (current.length < 3) {
                  current.add(badge.id);
                } else {
                  current.removeAt(0);
                  current.add(badge.id);
                }
                Navigator.of(ctx).pop();
                await onSaveFeatured!(current);
              },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge detail sheet
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeDetailSheet extends StatelessWidget {
  const _BadgeDetailSheet({
    required this.badge,
    required this.member,
    required this.currentTier,
    required this.progress,
    required this.isEarned,
    required this.isFeatured,
    this.onFeaturedToggle,
  });

  final BadgeDefinition badge;
  final Member member;
  final BadgeTier currentTier;
  final double progress;
  final bool isEarned;
  final bool isFeatured;
  final Future<void> Function()? onFeaturedToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final t = theme.textTheme;

    final assetPath = badge.isTiered
        ? badge.assetPathForTier(
            currentTier == BadgeTier.locked ? BadgeTier.bronze : currentTier)
        : badge.assetPath;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: isEarned ? progress : 0,
                      color: _tierRingColor(currentTier),
                      trackColor: c.outlineVariant.withValues(alpha: 0.25),
                      strokeWidth: 6,
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: isEarned ? 1.0 : 0.45,
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: assetPath != null
                          ? Image.asset(
                              assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  _EmojiIcon(badge.icon, size: 42),
                            )
                          : _EmojiIcon(badge.icon, size: 42),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _TierChip(tier: currentTier, cs: c, ts: t),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isEarned ? badge.description : badge.unlockHint,
            style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (badge.isTiered) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: c.outlineVariant.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                    _tierRingColor(currentTier)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _progressLabel(badge, member, currentTier),
              style: t.labelSmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
          if (isEarned && onFeaturedToggle != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(
                  isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                ),
                label: Text(
                    isFeatured ? 'Remove from Featured' : 'Add to Featured'),
                onPressed: onFeaturedToggle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge picker sheet (for featured slots)
// ─────────────────────────────────────────────────────────────────────────────

class _BadgePickerSheet extends StatelessWidget {
  const _BadgePickerSheet({
    required this.earnedBadges,
    required this.currentBadge,
    required this.member,
  });

  final List<BadgeDefinition> earnedBadges;
  final BadgeDefinition? currentBadge;
  final Member member;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose a badge',
                    style:
                        ts.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (currentBadge != null)
                  TextButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Clear slot'),
                    onPressed: () => Navigator.of(context)
                        .pop(const _PickerResult(cleared: true)),
                  ),
              ],
            ),
          ),
          if (earnedBadges.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Earn some badges first!',
                  style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: earnedBadges.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, i) {
                  final b = earnedBadges[i];
                  final isSelected = currentBadge?.id == b.id;
                  final currentTier = b.currentTierForMember(member.badges);
                  final progress = b.progressForMember(member);
                  final assetPath = b.isTiered
                      ? b.assetPathForTier(currentTier == BadgeTier.locked
                          ? BadgeTier.bronze
                          : currentTier)
                      : b.assetPath;

                  return GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pop(_PickerResult(badge: b)),
                    child: Opacity(
                      opacity: isSelected ? 0.4 : 1.0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _RingPainter(
                                      progress: progress,
                                      color: _tierRingColor(currentTier),
                                      trackColor: cs.outlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: assetPath != null
                                        ? Image.asset(
                                            assetPath,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) =>
                                                _EmojiIcon(b.icon, size: 22),
                                          )
                                        : _EmojiIcon(b.icon, size: 22),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ts.labelSmall
                                ?.copyWith(fontSize: 10, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tier chip
// ─────────────────────────────────────────────────────────────────────────────

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.tier,
    required this.cs,
    required this.ts,
  });

  final BadgeTier tier;
  final ColorScheme cs;
  final TextTheme ts;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (tier) {
      case BadgeTier.bronze:
        bg = const Color(0xFFCD7F32);
        fg = Colors.white;
      case BadgeTier.silver:
        bg = const Color(0xFF9E9E9E);
        fg = Colors.white;
      case BadgeTier.gold:
        bg = const Color(0xFFFFB300);
        fg = Colors.white;
      case BadgeTier.locked:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tier == BadgeTier.locked ? 'Locked 🔒' : BadgeCatalog.tierName(tier),
        style: ts.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring painter
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 4.5,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed circle painter (empty featured slots)
// ─────────────────────────────────────────────────────────────────────────────

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashCount = 14;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;
    const sweepPerDash = 2 * math.pi / dashCount;
    const dashSweep = sweepPerDash * 0.6;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * sweepPerDash - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Emoji icon helper
// ─────────────────────────────────────────────────────────────────────────────

class _EmojiIcon extends StatelessWidget {
  const _EmojiIcon(this.emoji, {this.size = 24});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _tierRingColor(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.bronze:
      return const Color(0xFFCD7F32);
    case BadgeTier.silver:
      return const Color(0xFF9E9E9E);
    case BadgeTier.gold:
      return const Color(0xFFFFB300);
    case BadgeTier.locked:
      return const Color(0xFFBDBDBD);
  }
}

String _progressLabel(BadgeDefinition b, Member m, BadgeTier tier) {
  if (!b.isTiered) return '';
  final count = b.counterForMember(m);
  final next = b.nextThresholdForMember(m);
  if (next == null) return '$count (Maxed out!)';
  return '$count / $next';
}
