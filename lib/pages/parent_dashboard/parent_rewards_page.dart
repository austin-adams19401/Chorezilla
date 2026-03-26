// lib/pages/parent_dashboard/parent_rewards_page.dart
import 'package:chorezilla/components/premium_upgrade_sheet.dart';
import 'package:chorezilla/constants/default_rewards.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/reward.dart';
import 'package:chorezilla/models/reward_redemption.dart';
import 'package:chorezilla/data/chorezilla_repo.dart';

class ParentRewardsPage extends StatefulWidget {
  const ParentRewardsPage({super.key});

  @override
  State<ParentRewardsPage> createState() => _ParentRewardsPageState();
}

class _ParentRewardsPageState extends State<ParentRewardsPage> {
  RewardCategory? _categoryFilter; // null = All
  bool _stockFilter = false;
  bool _pendingExpanded = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final familyId = app.familyId;

    if (familyId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    return Scaffold(
      backgroundColor: cs.secondary.withValues(alpha: 0.10),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final rewards = app.rewards;
          final rewardsBootstrapped = app.rewardsBootstrapped;

          final activeCount = rewardsBootstrapped
              ? rewards.where((r) => r.active).length
              : 0;
          final hiddenCount = rewardsBootstrapped
              ? rewards.where((r) => !r.active).length
              : 0;


          // 1) Decide how many columns based on width
          int gridCrossAxisCount;
          if (constraints.maxWidth >= 1100) {
            gridCrossAxisCount = 4;
          } else if (constraints.maxWidth >= 750) {
            gridCrossAxisCount = 3;
          } else {
            gridCrossAxisCount = 2;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero/header scrolls with content ───────────────────────
                _RewardsHero(
                  activeCount: activeCount,
                  hiddenCount: hiddenCount,
                  rewardsBootstrapped: rewardsBootstrapped,
                ),

                // The rest of the content sits on a soft “canvas” card
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(6, 16, 6, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          // ── Filters ────────────────────────────────────────
                          _RewardsFilters(
                            categoryFilter: _categoryFilter,
                            onCategoryChanged: (cat) {
                              setState(() => _categoryFilter = cat);
                            },
                            stockFilter: _stockFilter,
                            onStockFilterChanged: (val) {
                              setState(() => _stockFilter = val);
                            },
                          ),

                          const SizedBox(height: 8),

                          // ── Pending redemptions card ───────────────────────
                          StreamBuilder<List<RewardRedemption>>(
                            stream: app.repo.watchPendingRewardRedemptions(familyId),
                            builder: (context, pendingSnap) {
                              if (pendingSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !pendingSnap.hasData) {
                                return const SizedBox.shrink();
                              }

                              final pending =
                                  pendingSnap.data ?? const <RewardRedemption>[];

                              // In release: only show if there are items.
                              if (pending.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                                child: _PendingRewardsCard(
                                  redemptions: pending,
                                  expanded: _pendingExpanded,
                                  onToggleExpanded: () {
                                    setState(
                                      () => _pendingExpanded = !_pendingExpanded,
                                    );
                                  },
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 8),

                          // ── Rewards grid (non-scrollable, inside scroll view) ─────────
                          StreamBuilder<List<RewardRedemption>>(
                            stream: app.repo.watchAllRewardRedemptionsForFamily(familyId),
                            builder: (context, redemptionSnap) {
                              // Group all family redemptions by memberId for out-of-stock lookups.
                              final allRedemptions = redemptionSnap.data ?? const <RewardRedemption>[];
                              final redemptionsByMember = <String, List<RewardRedemption>>{};
                              for (final rd in allRedemptions) {
                                redemptionsByMember
                                    .putIfAbsent(rd.memberId, () => [])
                                    .add(rd);
                              }

                              final rewards = app.rewards;

                              if (!app.rewardsBootstrapped) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (rewards.isEmpty) {
                                return _EmptyRewards(
                                  onSeedStarter: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      await app.repo.seedStarterRewards(familyId);
                                    } catch (_) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not load starter rewards. Check your connection.'),
                                        ),
                                      );
                                    }
                                  },
                                  onCreateNew: () => _openNewRewardSheet(context),
                                );
                              }

                              var visible = rewards;
                              if (_categoryFilter != null) {
                                visible = visible
                                    .where((r) => r.category == _categoryFilter)
                                    .toList();
                              }
                              if (_stockFilter) {
                                visible = visible
                                    .where((r) => r.stock != null)
                                    .toList();
                              }

                              if (visible.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'No rewards match your filters.\n'
                                      'Try changing category or showing disabled.',
                                      textAlign: TextAlign.center,
                                      style: ts.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final kids = app.members
                                  .where((m) => m.role == FamilyRole.child)
                                  .toList();

                              // Helper to build a single reward card with all callbacks.
                              Widget buildCard(Reward r) {
                                // Mirror the kid's store logic exactly: count non-cancelled
                                // redemptions per kid for this reward, respecting restockedAt.
                                final outOfStockKids = r.stock == null
                                    ? <({String id, String name})>[]
                                    : kids.where((k) {
                                        final count = (redemptionsByMember[k.id] ?? [])
                                            .where((rd) {
                                              if (rd.status == 'cancelled') return false;
                                              if (rd.rewardId != r.id) return false;
                                              final restockedAt = r.restockedAt;
                                              if (restockedAt != null &&
                                                  rd.createdAt != null &&
                                                  !rd.createdAt!.isAfter(restockedAt)) {
                                                return false;
                                              }
                                              return true;
                                            })
                                            .length;
                                        return count >= r.stock!;
                                      })
                                        .map((k) => (id: k.id, name: k.displayName))
                                        .toList();
                                return _RewardCard(
                                  reward: r,
                                  outOfStockKids: outOfStockKids,
                                  onEdit: () => _openEditRewardSheet(context, r),
                                  onRestock: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      await app.repo.restockReward(
                                        familyId,
                                        rewardId: r.id,
                                      );
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('"${r.title}" restocked for all kids!')),
                                      );
                                    } catch (_) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not restock. Check your connection.'),
                                        ),
                                      );
                                    }
                                  },
                                  onRestockKid: (memberId) async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final kidName = outOfStockKids
                                        .firstWhere((k) => k.id == memberId,
                                            orElse: () => (id: memberId, name: 'Kid'))
                                        .name;
                                    try {
                                      await app.repo.restockRewardForKid(
                                        familyId,
                                        rewardId: r.id,
                                        memberId: memberId,
                                      );
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('"${r.title}" restocked for $kidName!')),
                                      );
                                    } catch (_) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not restock. Check your connection.'),
                                        ),
                                      );
                                    }
                                  },
                                  onToggleActive: (active) async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      await app.repo.setRewardActive(
                                        familyId,
                                        rewardId: r.id,
                                        active: active,
                                      );
                                    } catch (_) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not update reward. Check your connection.'),
                                        ),
                                      );
                                    }
                                  },
                                  onDelete: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete reward?'),
                                        content: Text(
                                          'Delete "${r.title}" permanently? '
                                          "Kids won't see it in the store anymore.",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton.tonal(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            style: FilledButton.styleFrom(
                                              foregroundColor: Theme.of(ctx).colorScheme.error,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await app.repo.deleteReward(
                                        familyId,
                                        rewardId: r.id,
                                      );
                                    } catch (_) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not delete reward. Check your connection.'),
                                        ),
                                      );
                                    }
                                  },
                                );
                              }

                              // Build one section per category that has rewards.
                              final categoriesToShow = _categoryFilter != null
                                  ? [_categoryFilter!]
                                  : RewardCategory.values;

                              final sections = <Widget>[];
                              for (final cat in categoriesToShow) {
                                final catRewards = visible
                                    .where((r) => r.category == cat)
                                    .toList()
                                  ..sort((a, b) => a.coinCost.compareTo(b.coinCost));
                                if (catRewards.isEmpty) continue;

                                sections.add(
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _categoryIcon(cat),
                                          size: 16,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _categoryLabel(cat),
                                          style: ts.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                const wrapSpacing = 8.0;
                                sections.add(
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                                    child: LayoutBuilder(
                                      builder: (context, wrapConstraints) {
                                        final cardWidth = (wrapConstraints.maxWidth - (wrapSpacing * (gridCrossAxisCount - 1))) / gridCrossAxisCount;
                                        return Wrap(
                                          spacing: wrapSpacing,
                                          runSpacing: wrapSpacing,
                                          children: catRewards
                                              .map((r) => SizedBox(width: cardWidth, child: buildCard(r)))
                                              .toList(),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: sections,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'parent-reward-fab',
        onPressed: () => _openNewRewardSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New reward'),
      ),
    );
  }

  Future<void> _openNewRewardSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _RewardEditorSheet(),
    );
  }

  Future<void> _openEditRewardSheet(BuildContext context, Reward reward) async {
    if (!reward.isCustom) {
      final app = context.read<AppState>();
      if (!SubscriptionService.isPremium(app.family)) {
        await showPremiumUpgradeSheet(context, reason: UpgradeReason.editDefaultRewards);
        return;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _RewardEditorSheet(existing: reward),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header
// ─────────────────────────────────────────────────────────────────────────────

class _RewardsHero extends StatelessWidget {
  const _RewardsHero({
    required this.activeCount,
    required this.hiddenCount,
    required this.rewardsBootstrapped,
  });

  final int activeCount;
  final int hiddenCount;
  final bool rewardsBootstrapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final media = MediaQuery.of(context);
    final double topInset = media.padding.top;
    final bool isLandscape = media.orientation == Orientation.landscape;
    final bool isCompact = media.size.height < 680;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        isLandscape ? topInset + 2 : topInset + 4,
        20,
        (isLandscape || isCompact) ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.secondary, cs.secondary, cs.secondary],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text + stats
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, isLandscape ? 4 : 6, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rewards & store',
                    style: ((isLandscape || isCompact) ? ts.titleMedium : ts.headlineSmall)
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          rewardsBootstrapped
                              ? '$activeCount active · $hiddenCount hidden'
                              : 'Loading rewards…',
                          style: ts.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Rounded gift icon “badge”
          Container(
            height: (isLandscape || isCompact) ? 48 : 64,
            width: (isLandscape || isCompact) ? 48 : 64,
            decoration: BoxDecoration(
              color: cs.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: (isLandscape || isCompact) ? 24 : 32,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filters row
// ─────────────────────────────────────────────────────────────────────────────

class _RewardsFilters extends StatelessWidget {
  const _RewardsFilters({
    required this.categoryFilter,
    required this.onCategoryChanged,
    required this.stockFilter,
    required this.onStockFilterChanged,
  });

  final RewardCategory? categoryFilter;
  final ValueChanged<RewardCategory?> onCategoryChanged;
  final bool stockFilter;
  final ValueChanged<bool> onStockFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category chips in a subtle pill row
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: categoryFilter == null,
                    onSelected: (_) => onCategoryChanged(null),
                    selectedColor: cs.primaryContainer,
                    labelStyle: ts.labelMedium?.copyWith(
                      color: categoryFilter == null
                          ? cs.onSurface
                          : cs.onSurface,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Stock limit'),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 14),
                    selected: stockFilter,
                    onSelected: onStockFilterChanged,
                    selectedColor: cs.tertiaryContainer,
                    labelStyle: ts.labelMedium?.copyWith(
                      color: stockFilter ? cs.onTertiaryContainer : cs.onSurface,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                for (final cat in RewardCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_categoryLabel(cat)),
                      avatar: Icon(_categoryIcon(cat), size: 14),
                      selected: categoryFilter == cat,
                      onSelected: (_) => onCategoryChanged(cat),
                      selectedColor: cs.secondary,
                      labelStyle: ts.labelMedium?.copyWith(
                        color: categoryFilter == cat
                            ? cs.onSecondary
                            : cs.onSurface,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyRewards extends StatelessWidget {
  const _EmptyRewards({required this.onSeedStarter, required this.onCreateNew});

  final VoidCallback onSeedStarter;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    return Center(
      child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('🎁', style: ts.displaySmall),
          const SizedBox(height: 8),
          Text(
            'No rewards yet',
            style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Load a starter set of family-friendly rewards,\n'
            'or create your own custom reward.',
            textAlign: TextAlign.center,
            style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSeedStarter,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Load starter rewards'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onCreateNew,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create custom reward'),
          ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reward card (grid tile)
// ─────────────────────────────────────────────────────────────────────────────

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.outOfStockKids,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onRestock,
    required this.onRestockKid,
  });

  final Reward reward;
  final List<({String id, String name})> outOfStockKids;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onRestock;
  final ValueChanged<String> onRestockKid;

  void _openDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RewardDetailSheet(
        reward: reward,
        outOfStockKids: outOfStockKids,
        onEdit: onEdit,
        onToggleActive: onToggleActive,
        onDelete: onDelete,
        onRestock: onRestock,
        onRestockKid: onRestockKid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final iconText = reward.icon?.isNotEmpty == true ? reward.icon! : '🎁';
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = _categoryCardColor(reward.category, dark: isDark);
    final accentColor = _categoryAccentColor(reward.category);
    final gradientEnd = isDark
        ? Color.lerp(baseColor, Colors.black, 0.3)!
        : Color.lerp(baseColor, Colors.white, 0.5)!;
    final hasOutOfStock = outOfStockKids.isNotEmpty;

    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [baseColor, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: reward.active
                  ? accentColor.withValues(alpha: isDark ? 0.55 : 0.45)
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: reward.active
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isDark ? 0.25 : 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top row: icon | out-of-stock badge | menu ─────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(iconText, style: const TextStyle(fontSize: 22)),
                    ),
                    const Spacer(),
                    if (hasOutOfStock) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 11, color: cs.onErrorContainer),
                            const SizedBox(width: 3),
                            Text(
                              '${outOfStockKids.length}',
                              style: ts.labelSmall?.copyWith(
                                color: cs.onErrorContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<RewardMenuAction>(
                        tooltip: 'Reward options',
                        icon: Icon(Icons.more_vert_rounded, size: 18, color: cs.onSurfaceVariant),
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                        onSelected: (action) {
                          switch (action) {
                            case RewardMenuAction.edit:
                              onEdit();
                              break;
                            case RewardMenuAction.restock:
                              onRestock();
                              break;
                            case RewardMenuAction.delete:
                              onDelete();
                              break;
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: RewardMenuAction.edit,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.edit_rounded),
                              title: Text('Edit'),
                            ),
                          ),
                          if (reward.stock != null && reward.memberPurchaseCounts.isNotEmpty)
                            const PopupMenuItem(
                              value: RewardMenuAction.restock,
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.refresh_rounded),
                                title: Text('Restock all'),
                              ),
                            ),
                          PopupMenuItem(
                            value: RewardMenuAction.delete,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.delete_outline_rounded),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ── Title ─────────────────────────────────────────────────
                Text(
                  reward.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 3),
                    Text(
                      '${reward.coinCost} coins',
                      style: ts.bodySmall?.copyWith(
                        color: accentColor.withValues(alpha: isDark ? 0.9 : 1.0),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ── Bottom row: chip + toggle ──────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _SmallChip(
                            label: _categoryLabel(reward.category),
                            color: accentColor.withValues(alpha: isDark ? 0.22 : 0.13),
                            textColor: isDark ? accentColor.withValues(alpha: 0.9) : accentColor,
                          ),
                          if (!reward.active)
                            _SmallChip(
                              label: 'Off',
                              color: cs.errorContainer.withValues(alpha: 0.7),
                              textColor: cs.onErrorContainer,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: reward.active,
                      onChanged: onToggleActive,
                      activeThumbColor: Colors.white,
                      activeTrackColor: cs.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reward detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RewardDetailSheet extends StatelessWidget {
  const _RewardDetailSheet({
    required this.reward,
    required this.outOfStockKids,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onRestock,
    required this.onRestockKid,
  });

  final Reward reward;
  final List<({String id, String name})> outOfStockKids;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback onRestock;
  final ValueChanged<String> onRestockKid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = _categoryAccentColor(reward.category);
    final hasDesc = reward.description?.isNotEmpty == true;
    final hasOutOfStock = outOfStockKids.isNotEmpty;
    final iconText = reward.icon?.isNotEmpty == true ? reward.icon! : '🎁';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: icon + title + coins ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(iconText, style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.title,
                          style: ts.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              '${reward.coinCost} coins',
                              style: ts.bodyMedium?.copyWith(
                                color: accentColor.withValues(alpha: isDark ? 0.9 : 1.0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _SmallChip(
                          label: _categoryLabel(reward.category),
                          color: accentColor.withValues(alpha: isDark ? 0.22 : 0.13),
                          textColor: isDark ? accentColor.withValues(alpha: 0.9) : accentColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (hasDesc) ...[
                const SizedBox(height: 16),
                Text(
                  reward.description!,
                  style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                ),
              ],

              if (reward.stock != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Limit per kid: ${reward.stock}',
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],

              // ── Out-of-stock section ───────────────────────────────────
              if (hasOutOfStock) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: cs.error),
                    const SizedBox(width: 6),
                    Text(
                      'Out of stock for:',
                      style: ts.titleSmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final kid in outOfStockKids)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            kid.name,
                            style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            onRestockKid(kid.id);
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('Restock'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onRestock();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Restock all'),
                  ),
                ),
              ],

              // ── Actions ───────────────────────────────────────────────
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEdit();
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onDelete();
                      },
                      icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                      label: Text('Delete', style: TextStyle(color: cs.error)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    reward.active ? 'Visible to kids' : 'Hidden from kids',
                    style: ts.bodyMedium,
                  ),
                  const Spacer(),
                  Switch(
                    value: reward.active,
                    onChanged: onToggleActive,
                    activeThumbColor: Colors.white,
                    activeTrackColor: cs.primary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.color, required this.textColor});
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

// ─────────────────────────────────────────────────────────────────────────────
// Reward editor bottom sheet (create new)
// ─────────────────────────────────────────────────────────────────────────────

class _RewardEditorSheet extends StatefulWidget {
  const _RewardEditorSheet({this.existing});

  final Reward? existing;

  @override
  State<_RewardEditorSheet> createState() => _RewardEditorSheetState();
}

class _RewardEditorSheetState extends State<_RewardEditorSheet> {
  var _titleCtrl = TextEditingController();
  final _titleFocusNode = FocusNode();
  var _descCtrl = TextEditingController();
  var _coinCtrl = TextEditingController(text: '5');
  var _iconCtrl = TextEditingController(text: '🎁');

  RewardCategory _category = RewardCategory.experience;
  bool _limitStock = false;
  var _stockCtrl = TextEditingController(text: '1');
  bool _busy = false;
  bool _isFromTemplate = false;

    @override
  void initState() {
    super.initState();
    final r = widget.existing;

    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _coinCtrl = TextEditingController(text: (r?.coinCost ?? 5).toString());
    _iconCtrl = TextEditingController(
      text: (r?.icon?.trim().isNotEmpty == true) ? r!.icon! : '🎁',
    );
    _stockCtrl = TextEditingController(text: (r?.stock ?? 1).toString());

    _category = r?.category ?? RewardCategory.experience;
    _limitStock = r?.stock != null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocusNode.dispose();
    _descCtrl.dispose();
    _coinCtrl.dispose();
    _iconCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existing != null;


    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_giftcard_rounded),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'Edit reward' : 'New reward',
                      style: ts.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RawAutocomplete<DefaultReward>(
                  textEditingController: _titleCtrl,
                  focusNode: _titleFocusNode,
                  displayStringForOption: (option) => option.title,
                  optionsBuilder: (textEditingValue) {
                    final input = textEditingValue.text.toLowerCase();
                    if (input.length < 2) return const Iterable.empty();
                    final existingTitles = context
                        .read<AppState>()
                        .rewards
                        .map((r) => r.title.toLowerCase())
                        .toSet();
                    return kDefaultRewards.where(
                      (r) =>
                          r.title.toLowerCase().contains(input) &&
                          !existingTitles.contains(r.title.toLowerCase()),
                    );
                  },
                  onSelected: (DefaultReward template) {
                    setState(() {
                      _titleCtrl.text = template.title;
                      _descCtrl.text = template.description;
                      _iconCtrl.text = template.icon;
                      _coinCtrl.text = template.coinCost.toString();
                      _category = template.category;
                      _isFromTemplate = true;
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Reward name',
                        hintText: 'e.g. Pick dessert tonight',
                      ),
                      onSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    final cs = Theme.of(context).colorScheme;
                    final ts = Theme.of(context).textTheme;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        color: cs.surface,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        option.icon,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          option.title,
                                          style: ts.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What does this reward actually give?',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _iconCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Icon (emoji)',
                          hintText: '🎁',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _coinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cost (coins)',
                          hintText: '5',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RewardCategory>(
                  initialValue: _category,
                  items: RewardCategory.values
                      .map(
                        (cat) => DropdownMenuItem<RewardCategory>(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(_categoryIcon(cat), size: 18),
                              const SizedBox(width: 8),
                              Text(_categoryLabel(cat)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _category = v);
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Limit quantity',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Switch(
                      value: _limitStock,
                      onChanged: (v) => setState(() => _limitStock = v),
                    ),
                  ],
                ),
                if (_limitStock) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max per kid',
                      hintText: '1',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Save changes' : 'Create reward'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final icon = _iconCtrl.text.trim().isEmpty ? null : _iconCtrl.text.trim();
    final cost = int.tryParse(_coinCtrl.text.trim());

    if (title.isEmpty) {
      _showSnack('Please enter a reward name.');
      return;
    }
    if (cost == null || cost <= 0) {
      _showSnack('Enter a valid positive coin cost.');
      return;
    }

    int? stock;
    if (_limitStock) {
      stock = int.tryParse(_stockCtrl.text.trim());
      if (stock == null || stock <= 0) {
        _showSnack('Enter a valid quantity (must be at least 1).');
        return;
      }
    }

    // Gate: block free users from editing default rewards
    if (widget.existing != null && !widget.existing!.isCustom) {
      final app = context.read<AppState>();
      if (!SubscriptionService.isPremium(app.family)) {
        if (!mounted) return;
        await showPremiumUpgradeSheet(context, reason: UpgradeReason.editDefaultRewards);
        return;
      }
    }

    // Gate: check custom reward limit for new rewards
    if (widget.existing == null) {
      final app = context.read<AppState>();
      final customRewardCount = app.rewards.where((r) => r.isCustom).length;
      if (!SubscriptionService.canAddCustomReward(app.family, customRewardCount)) {
        if (!mounted) return;
        await showPremiumUpgradeSheet(
          context,
          reason: UpgradeReason.customRewards,
        );
        return;
      }
    }

    setState(() => _busy = true);

    try {
      final app = context.read<AppState>();
      final familyId = app.familyId;
      if (familyId == null) {
        _showSnack('No family loaded.');
        return;
      }

      final existing = widget.existing;

      if (existing == null) {
        await app.repo.createReward(
          familyId,
          title: title,
          description: desc.isEmpty ? null : desc,
          icon: icon,
          coinCost: cost,
          category: _category,
          isCustom: true,
          stock: stock,
        );
      } else {
        await app.repo.updateReward(
          familyId,
          rewardId: existing.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          icon: icon,
          coinCost: cost,
          category: _category,
          stock: stock,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save reward: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

Color _categoryCardColor(RewardCategory cat, {bool dark = false}) {
  if (dark) {
    switch (cat) {
      case RewardCategory.snack:      return const Color(0xFF183818); // forest green
      case RewardCategory.time:       return const Color(0xFF0A2040);
      case RewardCategory.experience: return const Color(0xFF1E1040);
      case RewardCategory.digital:    return const Color(0xFF083830);
      case RewardCategory.money:      return const Color(0xFF062030);
      case RewardCategory.toy:        return const Color(0xFF181A48); // deep indigo
      case RewardCategory.other:      return const Color(0xFF141618);
    }
  }
  switch (cat) {
    case RewardCategory.snack:      return const Color(0xFFECFDF0);
    case RewardCategory.time:       return const Color(0xFFE8F4FF);
    case RewardCategory.experience: return const Color(0xFFF2EAFF);
    case RewardCategory.digital:    return const Color(0xFFE0F9F8);
    case RewardCategory.money:      return const Color(0xFFE0F7FA);
    case RewardCategory.toy:        return const Color(0xFFEEF0FF);
    case RewardCategory.other:      return const Color(0xFFF0F2F6);
  }
}

Color _categoryAccentColor(RewardCategory cat) {
  switch (cat) {
    case RewardCategory.snack:      return const Color(0xFF16A34A); // forest green
    case RewardCategory.time:       return const Color(0xFF2563EB); // blue
    case RewardCategory.experience: return const Color(0xFF7C3AED); // violet
    case RewardCategory.digital:    return const Color(0xFF0D9488); // teal
    case RewardCategory.money:      return const Color(0xFF0891B2); // cyan
    case RewardCategory.toy:        return const Color(0xFF4F46E5); // indigo
    case RewardCategory.other:      return const Color(0xFF475569); // slate
  }
}

String _categoryLabel(RewardCategory cat) {
  switch (cat) {
    case RewardCategory.snack:
      return 'Snacks & treats';
    case RewardCategory.time:
      return 'Time & screen';
    case RewardCategory.experience:
      return 'Experiences';
    case RewardCategory.digital:
      return 'In-app / digital';
    case RewardCategory.money:
      return 'Money / allowance';
    case RewardCategory.other:
      return 'Other';
    case RewardCategory.toy:
      return 'Toy';
  }
}

IconData _categoryIcon(RewardCategory cat) {
  switch (cat) {
    case RewardCategory.snack:
      return Icons.fastfood_rounded;
    case RewardCategory.time:
      return Icons.access_time_rounded;
    case RewardCategory.experience:
      return Icons.celebration_rounded;
    case RewardCategory.digital:
      return Icons.videogame_asset_rounded;
    case RewardCategory.money:
      return Icons.attach_money_rounded;
    case RewardCategory.toy:
      return Icons.toys_rounded;
    case RewardCategory.other:
      return Icons.star_border_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending rewards card – grouped by kid (restyled)
// ─────────────────────────────────────────────────────────────────────────────

class _PendingRewardsCard extends StatefulWidget {
  const _PendingRewardsCard({
    required this.redemptions,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<RewardRedemption> redemptions;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  State<_PendingRewardsCard> createState() => _PendingRewardsCardState();
}

class _PendingRewardsCardState extends State<_PendingRewardsCard> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final members = app.members;
    final namesById = {for (final m in members) m.id: m.displayName};

    // Group by kid
    final Map<String, List<RewardRedemption>> byKid = {};
    for (final r in widget.redemptions) {
      byKid.putIfAbsent(r.memberId, () => []).add(r);
    }
    final entries = byKid.entries.toList()
      ..sort((a, b) {
        final nameA = namesById[a.key] ?? '';
        final nameB = namesById[b.key] ?? '';
        return nameA.compareTo(nameB);
      });

    // Cap the inner list to ~40% of screen height so it doesn't eat the page
    final maxListHeight = (MediaQuery.of(context).size.height * 0.4).clamp(
      180.0,
      360.0,
    );

    return Card(
      elevation: 0,
      color: cs.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Rewards to give   (5)  ?  ˅
            Row(
              children: [
                Text(
                  'Rewards to give',
                  style: ts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.redemptions.length} Pending',
                  style: ts.labelMedium?.copyWith(
                    color: cs.onSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded, size: 20),
                  color: cs.onSecondary,
                  tooltip: 'What is this?',
                  onPressed: () => _showPendingRewardsHelpDialog(context),
                ),
                IconButton(
                  icon: Icon(
                    widget.expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  color: cs.onSecondary,
                  onPressed: widget.onToggleExpanded,
                ),
              ],
            ),

            if (widget.expanded) ...[
              const SizedBox(height: 4),
              Text(
                'Kids have already paid for these. Mark them given once you deliver, or refund to return coins.',
                style: ts.bodySmall?.copyWith(color: cs.onSecondary),
              ),
              Divider(height: 16, color: cs.surface.withValues(alpha: 0.8)),
              const SizedBox(height: 10),

              // 👇 Scrollable area for kid groups with always-visible scrollbar
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxListHeight.toDouble(),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  radius: const Radius.circular(999),
                  thickness: 3,
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      children: [
                        for (var i = 0; i < entries.length; i++) ...[
                          _KidGroupRow(
                            kidName: namesById[entries[i].key] ?? 'Kid',
                            rewards: entries[i].value,
                          ),
                          if (i != entries.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Divider(
                                height: 16,
                                color: cs.surface.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Subtle hint only if there's actually enough kids to scroll
              if (entries.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_up_rounded,
                        size: 16,
                        color: cs.onSecondary.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Scroll to see all rewards',
                        style: ts.labelSmall?.copyWith(
                          color: cs.onSecondary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-kid group row (restyled rewards)
// ─────────────────────────────────────────────────────────────────────────────

class _KidGroupRow extends StatelessWidget {
  const _KidGroupRow({required this.kidName, required this.rewards});

  final String kidName;
  final List<RewardRedemption> rewards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final initial = kidName.trim().isEmpty
        ? '?'
        : kidName.trim().characters.first;

    const maxCardWidth = 200.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kid header
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Text(
                initial.toUpperCase(),
                style: ts.labelMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kidName,
                style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSecondary,),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${rewards.length} reward${rewards.length == 1 ? '' : 's'}',
                style: ts.labelSmall?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (rewards.length > 1) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: () async {
                  final app = context.read<AppState>();
                  final familyId = app.familyId;
                  if (familyId == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  for (final r in rewards) {
                    try {
                      await app.repo.markRewardGiven(
                        familyId,
                        redemptionId: r.id,
                        parentMemberId: app.currentMember?.id,
                      );
                    } catch (_) {}
                  }
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('All rewards marked as given for $kidName.'),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 28),
                ),
                child: const Text('Give all'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Grid-like layout of reward tiles using Wrap
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < maxCardWidth * 2
                ? (constraints.maxWidth - 8) / 2
                : maxCardWidth;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in rewards)
                  SizedBox(
                    width: cardWidth,
                    child: _PendingRewardTile(kidName: kidName, redemption: r),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PendingRewardTile extends StatelessWidget {
  const _PendingRewardTile({required this.kidName, required this.redemption});

  final String kidName;
  final RewardRedemption redemption;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainerHighest.withValues(alpha: 0.95),
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            redemption.rewardName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${redemption.coinCost} coins',
            style: ts.labelSmall?.copyWith(
              color: cs.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (redemption.createdAt != null) ...[
            const SizedBox(height: 2),
            Text(
              _formatRelativeTime(redemption.createdAt!),
              style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  final app = context.read<AppState>();
                  final familyId = app.familyId;
                  if (familyId == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await app.repo.markRewardGiven(
                      familyId,
                      redemptionId: redemption.id,
                      parentMemberId: app.currentMember?.id,
                    );
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${redemption.rewardName}" marked as given to $kidName.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error marking reward given: $e')),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Given'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () async {
                  final familyId = app.familyId;
                  if (familyId == null) return;

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Refund reward?'),
                      content: Text(
                        'Refund "${redemption.rewardName}" for $kidName?\n'
                        'Coins will be returned and this reward will be removed from the list.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Refund'),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  try {
                    await app.repo.refundRewardRedemption(
                      familyId,
                      redemption: redemption,
                      parentMemberId: app.currentMember?.id,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Refunded "${redemption.rewardName}" for $kidName.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error refunding reward: $e')),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Refund'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Help dialog for pending rewards
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showPendingRewardsHelpDialog(BuildContext context) {
  final theme = Theme.of(context);
  final ts = theme.textTheme;
  final cs = theme.colorScheme;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('What are "Rewards to give"?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This list shows rewards your kids have already paid for with coins, but haven\'t received yet.',
            style: ts.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '• Kids spend coins in their store to request rewards.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• Those requests show up here, grouped by kid.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• When you\'ve actually given the reward in real life, tap "Mark given".',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• Marking a reward as given removes it from this list (coins are not refunded).',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• Level-up rewards and weekly allowance rewards also appear here.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
