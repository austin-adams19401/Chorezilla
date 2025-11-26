// lib/pages/parent_dashboard/parent_rewards_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/reward.dart';
import 'package:chorezilla/models/reward_redemption.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/data/chorezilla_repo.dart';

class ParentRewardsPage extends StatefulWidget {
  const ParentRewardsPage({super.key});

  @override
  State<ParentRewardsPage> createState() => _ParentRewardsPageState();
}

class _ParentRewardsPageState extends State<ParentRewardsPage> {
  RewardCategory? _categoryFilter; // null = All
  bool _showDisabled = false;

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
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header & filters ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rewards & Store',
                          style: ts.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose what your kids can spend coins on.',
                          style: ts.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: const Text('All'),
                                  selected: _categoryFilter == null,
                                  onSelected: (_) =>
                                      setState(() => _categoryFilter = null),
                                ),
                              ),
                              for (final cat in RewardCategory.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(_categoryLabel(cat)),
                                    selected: _categoryFilter == cat,
                                    onSelected: (_) =>
                                        setState(() => _categoryFilter = cat),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilterChip(
                              label: const Text('Show disabled'),
                              selected: _showDisabled,
                              onSelected: (val) =>
                                  setState(() => _showDisabled = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ── Pending rewards strip ───────────────────────────────
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: _PendingRewardsCard(redemptions: pending),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // ── Rewards grid ────────────────────────────────────────
                  StreamBuilder<List<Reward>>(
                    stream: app.repo.watchRewards(familyId, activeOnly: false),
                    builder: (context, snap) {
                      final rewards = snap.data ?? const <Reward>[];

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

                      // Sort by category, then coin cost, then title
                      visible.sort((a, b) {
                        final catCmp = a.category.index.compareTo(
                          b.category.index,
                        );
                        if (catCmp != 0) return catCmp;
                        final costCmp = a.coinCost.compareTo(b.coinCost);
                        if (costCmp != 0) return costCmp;
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
                      final isLandscape = constraints.maxWidth > constraints.maxHeight;
                      final childAspectRatio = isLandscape ? 3.8 : 2.4;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
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
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
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
                Text(iconText, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.title,
                        maxLines: 1,
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

            const SizedBox(height: 2),

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
                            alpha: .7,
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
    case RewardCategory.other:
      return Icons.star_border_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending rewards card – grouped by kid
// ─────────────────────────────────────────────────────────────────────────────

class _PendingRewardsCard extends StatelessWidget {
  const _PendingRewardsCard({required this.redemptions});

  final List<RewardRedemption> redemptions;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final members = app.members;
    final namesById = {for (final m in members) m.id: m.displayName};

    // Group by kid
    final Map<String, List<RewardRedemption>> byKid = {};
    for (final r in redemptions) {
      byKid.putIfAbsent(r.memberId, () => []).add(r);
    }

    return Card(
      elevation: 0,
      color: cs.secondaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  color: cs.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rewards to give',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (kDebugMode)
                  TextButton(
                    onPressed: () => _createDevPendingReward(context),
                    child: const Text('Add fake'),
                  ),
                const SizedBox(width: 4),
                Text(
                  '${redemptions.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in byKid.entries) ...[
              const SizedBox(height: 4),
              _KidGroupRow(
                kidName: namesById[entry.key] ?? 'Kid',
                rewards: entry.value,
              ),
              const SizedBox(height: 4),
              if (entry.key != byKid.keys.last) const Divider(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _createDevPendingReward(BuildContext context) async {
    final app = context.read<AppState>();
    final familyId = app.familyId;
    if (familyId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No family loaded.')));
      return;
    }

    final kids = app.members.where((m) => m.role == FamilyRole.child).toList();
    if (kids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No kids to assign dev reward to.')),
      );
      return;
    }

    final kid = kids.first;

    try {
      await app.repo.createRewardRedemption(
        familyId,
        memberId: kid.id,
        rewardId: null,
        rewardName: 'Dev test reward',
        coinCost: 5,
      );
    } catch (e) {
      debugPrint("Error creating dev reward");
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-kid group row
// ─────────────────────────────────────────────────────────────────────────────

class _KidGroupRow extends StatelessWidget {
  const _KidGroupRow({required this.kidName, required this.rewards});

  final String kidName;
  final List<RewardRedemption> rewards;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final initial = kidName.trim().isEmpty
        ? '?'
        : kidName.trim().characters.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Text(
                initial.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kidName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${rewards.length} reward${rewards.length == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final r in rewards)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.rewardName} (${r.coinCost} coins)',
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final familyId = app.familyId;
                    if (familyId == null) return;

                    try {
                      await app.repo.markRewardGiven(
                        familyId,
                        redemptionId: r.id,
                        parentMemberId: app.currentMember?.id,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Marked "${r.rewardName}" as given to $kidName.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error marking reward given: $e'),
                        ),
                      );
                    }
                  },
                  child: const Text('Mark given'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
