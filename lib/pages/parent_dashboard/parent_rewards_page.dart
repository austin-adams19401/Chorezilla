// lib/pages/parent_dashboard/parent_rewards_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

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
  bool _showDisabled = false;
  bool _pendingExpanded = false;

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


          final isLandscape = constraints.maxWidth > constraints.maxHeight;

          // 1) Decide how many columns based on width
          int gridCrossAxisCount;
          if (constraints.maxWidth >= 1100) {
            gridCrossAxisCount = 4; // large tablet / desktop
          } else if (constraints.maxWidth >= 750) {
            gridCrossAxisCount = 3; // small / medium tablet
          } else {
            gridCrossAxisCount = 2; // phones
          }

          // 2) Compute a childAspectRatio that keeps the card at a reasonable *pixel* height
          const double gridHorizontalPadding =
              4.0; // from your GridView padding (left/right)
          const double gridCrossAxisSpacing = 8.0;

          final double usableWidth =
              constraints.maxWidth -
              (gridHorizontalPadding * 2) -
              gridCrossAxisSpacing * (gridCrossAxisCount - 1);

          final double tileWidth = usableWidth / gridCrossAxisCount;

          // Target physical height for a card (tweak these)
          final double targetCardHeight = isLandscape ? 150.0 : 150.0;

          // childAspectRatio is width / height
          final double childAspectRatio = tileWidth / targetCardHeight;


          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero/header (styled like Today / Chore tabs) ────────────
              _RewardsHero(
                activeCount: activeCount,
                hiddenCount: hiddenCount,
                rewardsBootstrapped: rewardsBootstrapped,
              ),

              // The rest of the content sits on a soft “canvas” card
              Expanded(
                child: Padding(
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
                    // keep padding on the scroll view instead of the column
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(6, 16, 6, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Filters ────────────────────────────────────────
                          _RewardsFilters(
                            categoryFilter: _categoryFilter,
                            showDisabled: _showDisabled,
                            onCategoryChanged: (cat) {
                              setState(() => _categoryFilter = cat);
                            },
                            onShowDisabledChanged: (val) {
                              setState(() => _showDisabled = val);
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
                              if (pending.isEmpty && !kDebugMode) {
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
                          Builder(
                            builder: (context) {
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
                                    await app.repo.seedStarterRewards(familyId);
                                  },
                                  onCreateNew: () => _openNewRewardSheet(context),
                                );
                              }

                              var visible = rewards;
                              if (!_showDisabled) {
                                visible = visible.where((r) => r.active).toList();
                              }
                              if (_categoryFilter != null) {
                                visible = visible
                                    .where((r) => r.category == _categoryFilter)
                                    .toList();
                              }

                              visible.sort((a, b) {
                                final costCmp = a.coinCost.compareTo(b.coinCost);
                                if (costCmp != 0) return costCmp;
                                final catCmp =
                                    a.category.index.compareTo(b.category.index);
                                if (catCmp != 0) return catCmp;
                                return a.title.compareTo(b.title);
                              });

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

                              return GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(4, 8, 4, 16),
                                // IMPORTANT: let the parent scroll view handle scrolling
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridCrossAxisCount,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: childAspectRatio,
                                ),
                                itemCount: visible.length,
                                itemBuilder: (context, i) {
                                  final r = visible[i];
                                  return _RewardCard(
                                    reward: r,
                                    onToggleActive: (active) async {
                                      try {
                                        await app.repo.setRewardActive(
                                          familyId,
                                          rewardId: r.id,
                                          active: active,
                                        );
                                      } catch (_) {
                                        if (!mounted) return;
                                      }
                                    },
                                    onDelete: () async {
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
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton.tonal(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              style: FilledButton.styleFrom(
                                                foregroundColor: Theme.of(
                                                  ctx,
                                                ).colorScheme.error,
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
                                      } catch (e) {
                                        if (!mounted) return;
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 4, 20, 16),
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
              padding: const EdgeInsets.fromLTRB(0,20,0,0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rewards & store',
                    style: ts.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set up the store where kids spend their chore coins.',
                    style: ts.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
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
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onPressed: () => _showStoreHelpDialog(context),
                        icon: const Icon(Icons.help_outline_rounded, size: 18),
                        label: const Text('How it works'),
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
            height: 80,
            width: 80,
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
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showStoreHelpDialog(BuildContext context) {
  final theme = Theme.of(context);
  final ts = theme.textTheme;
  final cs = theme.colorScheme;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('How rewards & coins work'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Use this page to set up the family reward store.',
            style: ts.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '• Kids earn coins by completing chores.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• Active rewards show up in each kid\'s store.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• Disabled rewards are hidden from kids but kept for later.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• Categories and coin cost help you balance fun vs effort.',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            '• When kids buy a reward, it will appear in "Rewards to give".',
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

// ─────────────────────────────────────────────────────────────────────────────
// Filters row
// ─────────────────────────────────────────────────────────────────────────────

class _RewardsFilters extends StatelessWidget {
  const _RewardsFilters({
    required this.categoryFilter,
    required this.showDisabled,
    required this.onCategoryChanged,
    required this.onShowDisabledChanged,
  });

  final RewardCategory? categoryFilter;
  final bool showDisabled;
  final ValueChanged<RewardCategory?> onCategoryChanged;
  final ValueChanged<bool> onShowDisabledChanged;

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
                for (final cat in RewardCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_categoryLabel(cat)),
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
        const SizedBox(height: 8),
        Row(
          children: [
            FilterChip(
              label: const Text('Show disabled rewards'),
              selected: showDisabled,
              onSelected: (val) => onShowDisabledChanged(val),
              avatar: Icon(
                showDisabled
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 16,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reward card (grid tile)
// ─────────────────────────────────────────────────────────────────────────────

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Reward reward;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final iconText = reward.icon?.isNotEmpty == true ? reward.icon! : '🎁';

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: reward.active ? cs.primary : cs.outlineVariant,
          width: 1.3,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon, title/coins, delete X ────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(iconText, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${reward.coinCost} coins',
                        style: ts.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: cs.outline,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  splashRadius: 18,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Flexible description area (uses the spare space) ────────────
            Expanded(
              child:
                  (reward.description != null &&
                      reward.description!.trim().isNotEmpty)
                  ? Text(
                      reward.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 4),

            // ── Bottom row: chips on left, switch on right ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(_categoryLabel(reward.category)),
                        avatar: Icon(_categoryIcon(reward.category), size: 14),
                        backgroundColor: cs.secondaryContainer.withValues(
                          alpha: 0.7,
                        ),
                        labelStyle: ts.labelSmall?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      if (reward.isCustom)
                        Chip(
                          label: const Text('Custom'),
                          backgroundColor: cs.tertiaryContainer.withValues(
                            alpha: 0.7,
                          ),
                          labelStyle: ts.labelSmall?.copyWith(
                            color: cs.onTertiaryContainer,
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (!reward.active)
                        Chip(
                          label: const Text('Disabled'),
                          backgroundColor: cs.errorContainer.withValues(
                            alpha: 0.7,
                          ),
                          labelStyle: ts.labelSmall?.copyWith(
                            color: cs.onErrorContainer,
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: reward.active,
                  onChanged: onToggleActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reward editor bottom sheet (create new)
// ─────────────────────────────────────────────────────────────────────────────

class _RewardEditorSheet extends StatefulWidget {
  const _RewardEditorSheet();

  @override
  State<_RewardEditorSheet> createState() => _RewardEditorSheetState();
}

class _RewardEditorSheetState extends State<_RewardEditorSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _coinCtrl = TextEditingController(text: '5');
  final _iconCtrl = TextEditingController(text: '🎁');

  RewardCategory _category = RewardCategory.experience;
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _coinCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

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
                      'New reward',
                      style: ts.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Reward name',
                    hintText: 'e.g. Pick dessert tonight',
                  ),
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
                          child: Text(_categoryLabel(cat)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _category = v);
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
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
                        : const Text('Create reward'),
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

    setState(() => _busy = true);

    try {
      final app = context.read<AppState>();
      final familyId = app.familyId;
      if (familyId == null) {
        _showSnack('No family loaded.');
        return;
      }

      await app.repo.createReward(
        familyId,
        title: title,
        description: desc.isEmpty ? null : desc,
        icon: icon,
        coinCost: cost,
        category: _category,
        isCustom: true,
        stock: null,
      );

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

class _PendingRewardsCard extends StatelessWidget {
  const _PendingRewardsCard({
    required this.redemptions,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<RewardRedemption> redemptions;
  final bool expanded;
  final VoidCallback onToggleExpanded;

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
    for (final r in redemptions) {
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
                  '${redemptions.length} Pending',
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
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  color: cs.onSecondary,
                  onPressed: onToggleExpanded,
                ),
              ],
            ),

            if (expanded) ...[
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
                  child: SingleChildScrollView(
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  final familyId = app.familyId;
                  if (familyId == null) return;

                  try {
                    await app.repo.markRewardGiven(
                      familyId,
                      redemptionId: redemption.id,
                      parentMemberId: app.currentMember?.id,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Marked "${redemption.rewardName}" as given to $kidName.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
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
