// lib/pages/parent_dashboard/parent_rewards_page.dart
import 'package:chorezilla/models/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';



import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/reward.dart';
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & filters ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rewards & Store',
                  style: ts.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose what your kids can spend coins on.',
                  style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
                      onSelected: (val) => setState(() => _showDisabled = val),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── NEW: Pending rewards strip ───────────────────────────────────
          StreamBuilder<List<RewardRedemption>>(
            stream: app.repo.watchPendingRewardRedemptions(familyId),
            builder: (context, pendingSnap) {
              // While loading, don't flash anything
              if (pendingSnap.connectionState == ConnectionState.waiting &&
                  !pendingSnap.hasData) {
                return const SizedBox.shrink();
              }

              final pending = pendingSnap.data ?? const <RewardRedemption>[];

              // In release: only show card if there are items.
              // In debug: always show it (so you can use the dev button).
              if (pending.isEmpty && !kDebugMode) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _PendingRewardsCard(redemptions: pending),
              );
            },
          ),


                    const SizedBox(height: 4),

          // ── Rewards list ────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Reward>>(
              stream: app.repo.watchRewards(familyId, activeOnly: false),
              builder: (context, snap) {
                final rewards = snap.data ?? const <Reward>[];
                final pending = snap.data ?? const <RewardRedemption>[];
                if (pending.isEmpty) return const SizedBox.shrink();

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
                  final catCmp = a.category.index.compareTo(b.category.index);
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

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
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
                        } catch (e) {
                          if (!mounted) return;
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎁', style: ts.displaySmall),
                  const SizedBox(height: 8),
                  Text(
                    'No rewards yet',
                    style: ts.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reward card
// ─────────────────────────────────────────────────────────────────────────────

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.onToggleActive});

  final Reward reward;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ts = theme.textTheme;

    final iconText = reward.icon?.isNotEmpty == true ? reward.icon! : '🎁';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: reward.active ? cs.primary : cs.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon, title, coins, switch
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(iconText, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.title,
                        style: ts.titleMedium?.copyWith(
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
                Switch(value: reward.active, onChanged: onToggleActive),
              ],
            ),
            const SizedBox(height: 6),
            if (reward.description != null &&
                reward.description!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  reward.description!,
                  style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(_categoryLabel(reward.category)),
                  avatar: Icon(_categoryIcon(reward.category), size: 16),
                  backgroundColor: cs.secondaryContainer.withValues(alpha: 0.7),
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (!reward.active)
                  Chip(
                    label: const Text('Disabled'),
                    backgroundColor: cs.errorContainer.withValues(alpha: .7),
                    labelStyle: ts.labelSmall?.copyWith(
                      color: cs.onErrorContainer,
                    ),
                    visualDensity: VisualDensity.compact,
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
// Pending rewards card
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

    return Card(
      elevation: 0,
      color: cs.secondaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ...redemptions.map((r) {
              final kidName = namesById[r.memberId] ?? 'Kid';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$kidName — ${r.rewardName} (${r.coinCost} coins)',
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
              );
            }),
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
      final id = await app.repo.createRewardRedemption(
        familyId,
        memberId: kid.id,
        rewardId: null,
        rewardName: 'Dev test reward',
        coinCost: 5,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating dev reward: $e')));
    }
  }
}