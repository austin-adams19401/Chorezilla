// lib/pages/parent_dashboard/settings/level_rewards_page.dart

import 'dart:math' as math;

import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/components/premium_upgrade_sheet.dart';
import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/cosmetics.dart';
import 'package:chorezilla/services/subscription_service.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kGold = Color(0xFFFFB300);
const _kGoldLight = Color(0xFFFFE082);
const _kTeal = Color(0xFF00897B);
const _kEpicPurple = Color(0xFF9C27B0);
const _kRareBlue = Color(0xFF1565C0);
const _kCommonGreen = Color(0xFF2E7D32);

// ─────────────────────────────────────────────────────────────────────────────
// Page entry point
// ─────────────────────────────────────────────────────────────────────────────

class LevelRewardsPage extends StatefulWidget {
  const LevelRewardsPage({super.key});

  @override
  State<LevelRewardsPage> createState() => _LevelRewardsPageState();
}

class _LevelRewardsPageState extends State<LevelRewardsPage> {
  late Map<int, List<LevelRewardDefinition>> _pending;
  int _maxLevel = 20;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final family = context.read<AppState>().family;
    final existing = family?.settings.customLevelRewards;
    _pending = existing != null
        ? Map<int, List<LevelRewardDefinition>>.from(
            existing.map((k, v) => MapEntry(k, List.of(v))),
          )
        : {};
    if (_pending.isNotEmpty) {
      final highest = _pending.keys.reduce(math.max);
      if (highest > _maxLevel) _maxLevel = highest;
    }
  }

  Future<void> _save() async {
    if (SubscriptionService.guardCoParentReadOnly(context)) return;
    final app = context.read<AppState>();
    final famId = app.familyId;
    final family = app.family;
    if (famId == null || family == null) return;
    setState(() => _saving = true);
    try {
      final newSettings = family.settings.copyWith(customLevelRewards: _pending);
      await app.repo.updateFamily(famId, {'settings': newSettings.toMap()});
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Level-up rewards saved!'),
          backgroundColor: AppTheme.zillaGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _upsertReward(int level, LevelRewardDefinition reward,
      {int? replaceIndex}) {
    setState(() {
      final list = List<LevelRewardDefinition>.from(_pending[level] ?? []);
      if (replaceIndex != null) {
        list[replaceIndex] = reward;
      } else {
        list.add(reward);
      }
      _pending[level] = list;
      _dirty = true;
    });
  }

  void _deleteReward(int level, int index) {
    setState(() {
      final list = List<LevelRewardDefinition>.from(_pending[level] ?? []);
      list.removeAt(index);
      if (list.isEmpty) {
        _pending.remove(level);
      } else {
        _pending[level] = list;
      }
      _dirty = true;
    });
  }

  void _resetLevel(int level) {
    setState(() {
      _pending.remove(level);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium =
        context.select((AppState s) => s.family?.isPremium ?? false);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Level-up Rewards',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (isPremium && _dirty)
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGold,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.deepNavy, const Color(0xFF0D1B2A)]
                : [const Color(0xFF0B2545), const Color(0xFF1A3A5C)],
            stops: const [0.0, 0.35],
          ),
        ),
        child: isPremium
            ? _buildPremiumBody(cs, isDark)
            : _buildUpgradeBanner(),
      ),
    );
  }

  Widget _buildPremiumBody(ColorScheme cs, bool isDark) {
    final bgColor =
        isDark ? const Color(0xFF0D1B2A) : Theme.of(context).colorScheme.surface;

    return CustomScrollView(
      slivers: [
        // ── Hero header ──────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _buildHeroHeader()),

        // ── Timeline body ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Top drag handle aesthetic
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant.withAlpha(100),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sub-label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded,
                          size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Tap any reward to edit · Hold default cards to override',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // ── Level rows ───────────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, idx) {
              final bgColor = isDark
                  ? const Color(0xFF0D1B2A)
                  : Theme.of(context).colorScheme.surface;

              if (idx == _maxLevel - 1) {
                return Container(
                  color: bgColor,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
                  child: _buildAddLevelButton(),
                );
              }
              final level = idx + 2;
              return Container(
                color: bgColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _LevelRow(
                  level: level,
                  isLast: level == _maxLevel,
                  customRewards: _pending[level],
                  defaultRewards: levelRewardsForLevel(level),
                  onAddReward: () => _showEditSheet(context, level, null, null),
                  onEditReward: (i, r) =>
                      _showEditSheet(context, level, i, r),
                  onDeleteReward: (i) => _deleteReward(level, i),
                  onResetLevel: _pending.containsKey(level)
                      ? () => _resetLevel(level)
                      : null,
                ),
              );
            },
            childCount: _maxLevel,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader() {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // Mascot image faded in the background
          Positioned(
            right: -10,
            bottom: 0,
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/mascot/mascot_no_bg.png',
                height: 180,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kGold.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _kGold.withAlpha(100), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('👑', style: TextStyle(fontSize: 13)),
                          SizedBox(width: 5),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: _kGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Customize every milestone',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddLevelButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 56),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
        label: Text('Add Level ${_maxLevel + 1}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.zillaGreen,
          side: BorderSide(color: AppTheme.zillaGreen.withAlpha(120), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        onPressed: () => setState(() => _maxLevel++),
      ),
    );
  }

  // ── Free-tier upsell ──────────────────────────────────────────────────────

  Widget _buildUpgradeBanner() {
    final ts = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Image.asset(
              'assets/mascot/mascot_no_bg.png',
              height: 160,
            ),
            const SizedBox(height: 24),
            const Text(
              'Custom Level-up\nRewards',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Set exactly what your kids earn at every level — real-world prizes, in-game cosmetics, or both.',
              style: ts.bodyMedium?.copyWith(
                color: Colors.white.withAlpha(180),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Features preview
            _UpsellFeatureRow(
                icon: Icons.emoji_events_rounded,
                color: _kGold,
                label: 'Milestone rewards for every level'),
            const SizedBox(height: 12),
            _UpsellFeatureRow(
                icon: Icons.palette_rounded,
                color: _kTeal,
                label: 'Auto-grant cosmetics on level-up'),
            const SizedBox(height: 12),
            _UpsellFeatureRow(
                icon: Icons.add_circle_rounded,
                color: AppTheme.zillaGreen,
                label: 'Add custom levels beyond 20'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => showPremiumUpgradeSheet(
                  context,
                  reason: UpgradeReason.levelRewards,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('👑', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Text(
                      'Upgrade to Premium',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSheet(
    BuildContext context,
    int level,
    int? rewardIndex,
    LevelRewardDefinition? existing,
  ) async {
    final result = await showModalBottomSheet<LevelRewardDefinition>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditRewardSheet(level: level, existing: existing),
    );
    if (result != null) {
      _upsertReward(level, result, replaceIndex: rewardIndex);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upsell feature row
// ─────────────────────────────────────────────────────────────────────────────

class _UpsellFeatureRow extends StatelessWidget {
  const _UpsellFeatureRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level row (timeline node + reward cards)
// ─────────────────────────────────────────────────────────────────────────────

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.isLast,
    required this.customRewards,
    required this.defaultRewards,
    required this.onAddReward,
    required this.onEditReward,
    required this.onDeleteReward,
    this.onResetLevel,
  });

  final int level;
  final bool isLast;
  final List<LevelRewardDefinition>? customRewards;
  final List<LevelRewardDefinition> defaultRewards;
  final VoidCallback onAddReward;
  final void Function(int index, LevelRewardDefinition reward) onEditReward;
  final void Function(int index) onDeleteReward;
  final VoidCallback? onResetLevel;

  bool get _isMilestone => level % 5 == 0;
  bool get _isCustomised => customRewards != null && customRewards!.isNotEmpty;

  List<LevelRewardDefinition> get _displayRewards =>
      _isCustomised ? customRewards! : defaultRewards;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left column: node + connecting line ───────────────────────────
          SizedBox(
            width: 52,
            child: Column(
              children: [
                _LevelNode(level: level, isMilestone: _isMilestone),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: _isMilestone
                                ? [_kGold.withAlpha(200), _kGold.withAlpha(60)]
                                : [
                                    AppTheme.zillaGreen.withAlpha(200),
                                    AppTheme.zillaGreen.withAlpha(60),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Right column: reward cards ────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // Milestone group divider label
                  if (_isMilestone && level > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MilestoneDivider(level: level),
                    ),

                  if (_displayRewards.isEmpty)
                    _NoRewardCard(level: level, onAdd: onAddReward)
                  else ...[
                    for (var i = 0; i < _displayRewards.length; i++)
                      _RewardCard(
                        reward: _displayRewards[i],
                        isDefault: !_isCustomised,
                        showDelete:
                            _isCustomised && _displayRewards.length > 1,
                        onEdit: () => onEditReward(i, _displayRewards[i]),
                        onDelete: () => onDeleteReward(i),
                        onLongPress:
                            !_isCustomised ? onAddReward : null,
                      ),
                    if (_isCustomised)
                      _AddRewardButton(level: level, onTap: onAddReward),
                  ],

                  // Reset link
                  if (_isCustomised && onResetLevel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 4, bottom: 2),
                      child: GestureDetector(
                        onTap: onResetLevel,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restore_rounded,
                                size: 12,
                                color: cs.onSurfaceVariant.withAlpha(140)),
                            const SizedBox(width: 4),
                            Text(
                              'Reset to default',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant.withAlpha(140),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Milestone section divider
// ─────────────────────────────────────────────────────────────────────────────

class _MilestoneDivider extends StatelessWidget {
  const _MilestoneDivider({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGold.withAlpha(30), _kGold.withAlpha(10)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kGold.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            'Level $level Milestone',
            style: const TextStyle(
              color: _kGold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level node circle
// ─────────────────────────────────────────────────────────────────────────────

class _LevelNode extends StatelessWidget {
  const _LevelNode({required this.level, required this.isMilestone});

  final int level;
  final bool isMilestone;

  @override
  Widget build(BuildContext context) {
    final size = isMilestone ? 48.0 : 38.0;

    if (isMilestone) {
      return _MilestoneLevelNode(level: level, size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppTheme.zillaGreen,
            AppTheme.zillaGreen.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.zillaGreen.withAlpha(60),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$level',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _MilestoneLevelNode extends StatelessWidget {
  const _MilestoneLevelNode({required this.level, required this.size});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: size + 10,
          height: size + 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kGold.withAlpha(60), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _kGold.withAlpha(80),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        // Inner node
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_kGoldLight, _kGold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x80FFB300),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$level',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reward card
// ─────────────────────────────────────────────────────────────────────────────

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.isDefault,
    required this.showDelete,
    required this.onEdit,
    required this.onDelete,
    this.onLongPress,
  });

  final LevelRewardDefinition reward;
  final bool isDefault;
  final bool showDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  bool get _hasCosmetic => reward.cosmeticId != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final cosmetic =
        _hasCosmetic ? _cosmeticById(reward.cosmeticId!) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: isDefault ? onLongPress : onEdit,
        onLongPress: isDefault ? onLongPress : null,
        child: Container(
          decoration: BoxDecoration(
            color: isDefault
                ? cs.surfaceContainerHighest.withAlpha(180)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: _hasCosmetic && !isDefault
                ? Border.all(
                    color: _kTeal.withAlpha(80),
                    width: 1.5,
                  )
                : isDefault
                    ? Border.all(
                        color: cs.outlineVariant.withAlpha(80),
                        width: 1,
                      )
                    : null,
            boxShadow: isDefault
                ? null
                : [
                    BoxShadow(
                      color: _hasCosmetic
                          ? _kTeal.withAlpha(20)
                          : Colors.black.withAlpha(16),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left accent strip + cosmetic preview ──────────────────
                if (_hasCosmetic && !isDefault)
                  _CosmeticPreviewStrip(cosmetic: cosmetic),

                // ── Card body ──────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emoji
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDefault
                                ? cs.surface.withAlpha(180)
                                : cs.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              reward.emoji,
                              style: TextStyle(
                                fontSize: 24,
                                color: isDefault
                                    ? null
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      reward.title,
                                      style: ts.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isDefault
                                            ? cs.onSurface
                                                .withAlpha(160)
                                            : cs.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (isDefault)
                                    Container(
                                      margin: const EdgeInsets.only(
                                          left: 6, top: 1),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.outlineVariant
                                            .withAlpha(50),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: ts.labelSmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                reward.description,
                                style: ts.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant
                                      .withAlpha(isDefault ? 140 : 200),
                                ),
                              ),
                              if (cosmetic != null) ...[
                                const SizedBox(height: 7),
                                _CosmeticChip(
                                    cosmetic: cosmetic,
                                    isDefault: isDefault),
                              ],
                            ],
                          ),
                        ),

                        // Action buttons
                        if (!isDefault)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _IconBtn(
                                icon: Icons.edit_rounded,
                                tooltip: 'Edit',
                                onTap: onEdit,
                              ),
                              if (showDelete)
                                _IconBtn(
                                  icon: Icons.delete_outline_rounded,
                                  tooltip: 'Delete',
                                  onTap: onDelete,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error,
                                ),
                            ],
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 8, right: 8),
                            child: Icon(
                              Icons.touch_app_rounded,
                              size: 16,
                              color: cs.onSurfaceVariant.withAlpha(80),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Left accent strip for cosmetic rewards
class _CosmeticPreviewStrip extends StatelessWidget {
  const _CosmeticPreviewStrip({required this.cosmetic});

  final CosmeticItem? cosmetic;

  @override
  Widget build(BuildContext context) {
    if (cosmetic == null) {
      return Container(
        width: 6,
        decoration: BoxDecoration(
          color: _kTeal,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            bottomLeft: Radius.circular(18),
          ),
        ),
      );
    }

    final c = cosmetic!;

    // Background cosmetics: show thumbnail
    if (c.type == CosmeticType.background && c.assetKey.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          bottomLeft: Radius.circular(18),
        ),
        child: SizedBox(
          width: 52,
          child: Image.asset(
            c.assetKey,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Skin cosmetics: color swatch
    if (c.type == CosmeticType.zillaSkin && c.colorValue != null) {
      return Container(
        width: 10,
        decoration: BoxDecoration(
          color: Color(c.colorValue!),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            bottomLeft: Radius.circular(18),
          ),
        ),
      );
    }

    // Frame cosmetics: teal strip
    return Container(
      width: 10,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kTeal, Color(0xFF004D40)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          bottomLeft: Radius.circular(18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cosmetic chip
// ─────────────────────────────────────────────────────────────────────────────

class _CosmeticChip extends StatelessWidget {
  const _CosmeticChip({required this.cosmetic, this.isDefault = false});

  final CosmeticItem cosmetic;
  final bool isDefault;

  String get _typeLabel {
    switch (cosmetic.type) {
      case CosmeticType.zillaSkin:
        return 'Zilla Skin';
      case CosmeticType.background:
        return 'Background';
      case CosmeticType.avatarFrame:
        return 'Frame';
      case CosmeticType.title:
        return 'Title';
      case CosmeticType.avatar:
        return 'Avatar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = isDefault ? const Color(0xFF607D8B) : _kTeal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(70), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Skin color dot
          if (cosmetic.type == CosmeticType.zillaSkin &&
              cosmetic.colorValue != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(cosmetic.colorValue!),
              ),
            )
          else if (cosmetic.type == CosmeticType.background &&
              cosmetic.assetKey.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                width: 14,
                height: 14,
                child: Image.asset(cosmetic.assetKey, fit: BoxFit.cover),
              ),
            )
          else if (cosmetic.type == CosmeticType.avatarFrame)
            Image.asset(
              'assets/frames/frame-icon.png',
              width: 14,
              height: 14,
            )
          else
            const Text('🎨', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 5),
          Text(
            '${cosmetic.name} · $_typeLabel · Auto-unlock',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No reward placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _NoRewardCard extends StatelessWidget {
  const _NoRewardCard({required this.level, required this.onAdd});

  final int level;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withAlpha(80),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.add_rounded, size: 18, color: AppTheme.zillaGreen),
            const SizedBox(width: 10),
            Text(
              'Add reward for level $level',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add-another reward button
// ─────────────────────────────────────────────────────────────────────────────

class _AddRewardButton extends StatelessWidget {
  const _AddRewardButton({required this.level, required this.onTap});

  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.zillaGreen.withAlpha(100),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: AppTheme.zillaGreen),
              const SizedBox(width: 6),
              Text(
                'Add another reward',
                style: TextStyle(
                  color: AppTheme.zillaGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon button
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color ?? cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit reward bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditRewardSheet extends StatefulWidget {
  const _EditRewardSheet({required this.level, this.existing});

  final int level;
  final LevelRewardDefinition? existing;

  @override
  State<_EditRewardSheet> createState() => _EditRewardSheetState();
}

// Preset reward suggestions (emoji, title, description)
typedef _Suggestion = ({String emoji, String title, String description});

const _kRewardSuggestions = <_Suggestion>[
  (emoji: '🍬', title: 'Small Treat', description: 'Pick any small treat or snack'),
  (emoji: '🍦', title: 'Ice Cream Trip', description: 'Go out for ice cream together'),
  (emoji: '🍕', title: 'Pick Dinner', description: 'Choose what the family has for dinner'),
  (emoji: '🎬', title: 'Movie Night', description: 'Pick a movie for the whole family'),
  (emoji: '🎮', title: 'Extra Screen Time', description: '30 extra minutes of screen time'),
  (emoji: '🛋️', title: 'Late Bedtime', description: 'Stay up 30 minutes past bedtime'),
  (emoji: '💰', title: '\$5 to Spend', description: 'Five dollars to spend however you want'),
  (emoji: '💵', title: '\$10 to Spend', description: 'Ten dollars to spend however you want'),
  (emoji: '🎲', title: 'Game Night', description: 'Pick a board game for the whole family'),
  (emoji: '🏊', title: 'Pool Day', description: 'A day at the pool or splash pad'),
  (emoji: '🧁', title: 'Bake Together', description: 'Bake your favorite treat with a parent'),
  (emoji: '🎨', title: 'Art Supplies', description: 'Pick out some new art supplies'),
  (emoji: '📚', title: 'New Book', description: 'Choose a new book from the store'),
  (emoji: '🧸', title: 'New Toy', description: 'Pick out a small toy'),
  (emoji: '🎖️', title: 'Treasure Box Prize', description: 'Pick something from the treasure box'),
  (emoji: '👫', title: 'Parent Date', description: 'One-on-one outing with mom or dad'),
  (emoji: '🌮', title: 'Taco Night', description: 'Taco night — your way!'),
  (emoji: '🎪', title: 'Special Outing', description: 'A special trip or outing of your choice'),
  (emoji: '👑', title: 'Parents Do Your Chores', description: 'Mom or dad does your chores for a day'),
  (emoji: '🏖️', title: 'Beach Day', description: 'A fun day at the beach or park'),
  (emoji: '🎁', title: 'Mystery Prize', description: 'A surprise reward chosen by a parent'),
  (emoji: '🍿', title: 'Popcorn & Movie', description: 'Movie night with your favorite snacks'),
  (emoji: '🛒', title: 'Shopping Trip', description: 'A small shopping trip with a parent'),
];

class _EditRewardSheetState extends State<_EditRewardSheet> {
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  bool _grantCosmetic = false;
  CosmeticItem? _selectedCosmetic;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _emojiCtrl = TextEditingController(text: e?.emoji ?? '🎁');
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    if (e?.cosmeticId != null) {
      _grantCosmetic = true;
      _selectedCosmetic = _cosmeticById(e!.cosmeticId!);
    }
  }

  @override
  void dispose() {
    _emojiCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _emojiCtrl.text.trim().isNotEmpty &&
      (!_grantCosmetic || _selectedCosmetic != null);

  List<_Suggestion> get _filteredSuggestions {
    final q = _titleCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _kRewardSuggestions;
    return _kRewardSuggestions
        .where((s) => s.title.toLowerCase().contains(q))
        .toList();
  }

  void _applySuggestion(_Suggestion s) {
    _emojiCtrl.text = s.emoji;
    _titleCtrl.text = s.title;
    _descCtrl.text = s.description;
    setState(() {});
  }

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(LevelRewardDefinition(
      level: widget.level,
      emoji: _emojiCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      cosmeticId: _grantCosmetic ? _selectedCosmetic?.id : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final isNew = widget.existing == null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text(
                  isNew
                      ? 'New Reward — Level ${widget.level}'
                      : 'Edit Reward',
                  style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  isNew
                      ? 'What does your kid earn at this level?'
                      : 'Update the reward details below',
                  style:
                      ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Emoji + Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _emojiCtrl,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28),
                  decoration: InputDecoration(
                    labelText: 'Emoji',
                    counterText: '',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Reward Title',
                    counterText: '',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Suggestion chips
          if (_filteredSuggestions.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: _filteredSuggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final s = _filteredSuggestions[i];
                  final active = _titleCtrl.text.trim() == s.title;
                  return ActionChip(
                    avatar: Text(s.emoji,
                        style: const TextStyle(fontSize: 14)),
                    label: Text(s.title,
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        active ? _kTeal.withAlpha(30) : null,
                    side: active
                        ? BorderSide(color: _kTeal.withAlpha(120))
                        : null,
                    onPressed: () => _applySuggestion(s),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),

          // Description
          TextField(
            controller: _descCtrl,
            maxLength: 100,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              counterText: '',
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cosmetic section
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: _grantCosmetic
                  ? Border.all(color: _kTeal.withAlpha(80), width: 1.5)
                  : null,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _grantCosmetic,
                  activeThumbColor: _kTeal,
                  onChanged: (v) => setState(() {
                    _grantCosmetic = v;
                    if (!v) _selectedCosmetic = null;
                  }),
                  title: const Text(
                    'Auto-unlock in-game cosmetic',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Automatically grants a skin, background, or frame',
                    style: ts.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  secondary: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _kTeal.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                        child: Text('🎨', style: TextStyle(fontSize: 18))),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
                if (_grantCosmetic) ...[
                  Divider(
                      height: 1,
                      color: cs.outlineVariant.withAlpha(80)),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: _selectedCosmetic != null
                        ? _CosmeticPreviewAvatar(
                            cosmetic: _selectedCosmetic!)
                        : Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _kTeal.withAlpha(80), width: 1.5),
                            ),
                            child: Icon(Icons.add_rounded,
                                color: _kTeal),
                          ),
                    title: Text(
                      _selectedCosmetic?.name ?? 'Choose a cosmetic',
                      style: ts.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _selectedCosmetic == null
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                      ),
                    ),
                    subtitle: _selectedCosmetic != null
                        ? Row(
                            children: [
                              _RarityBadge(
                                  rarity: _selectedCosmetic!.rarity),
                              const SizedBox(width: 6),
                              Text(
                                _cosmeticTypeLabel(
                                    _selectedCosmetic!.type),
                                style: ts.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant),
                              ),
                            ],
                          )
                        : null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kTeal.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedCosmetic != null ? 'Change' : 'Select',
                        style: const TextStyle(
                          color: _kTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () => _pickCosmetic(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _valid ? _submit : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isNew ? 'Add Reward' : 'Save Changes',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCosmetic() async {
    final picked = await showModalBottomSheet<CosmeticItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _CosmeticPickerSheet(),
    );
    if (picked != null) setState(() => _selectedCosmetic = picked);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cosmetic preview avatar (used in edit sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _CosmeticPreviewAvatar extends StatelessWidget {
  const _CosmeticPreviewAvatar({required this.cosmetic});

  final CosmeticItem cosmetic;

  @override
  Widget build(BuildContext context) {
    if (cosmetic.type == CosmeticType.background &&
        cosmetic.assetKey.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Image.asset(cosmetic.assetKey, fit: BoxFit.cover),
        ),
      );
    }
    if (cosmetic.type == CosmeticType.zillaSkin &&
        cosmetic.colorValue != null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(cosmetic.colorValue!),
          boxShadow: [
            BoxShadow(
              color: Color(cosmetic.colorValue!).withAlpha(80),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Center(
            child: Text('🦎', style: TextStyle(fontSize: 20))),
      );
    }
    if (cosmetic.type == CosmeticType.avatarFrame) {
      return Image.asset('assets/frames/frame-icon.png',
          width: 44, height: 44);
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _kTeal.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
          child: Text('🎨', style: TextStyle(fontSize: 22))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rarity badge
// ─────────────────────────────────────────────────────────────────────────────

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.rarity});

  final CosmeticRarity? rarity;

  @override
  Widget build(BuildContext context) {
    final icon = switch (rarity) {
      CosmeticRarity.epic => 'assets/icons/epic-loot.png',
      CosmeticRarity.rare => 'assets/icons/rare-loot.png',
      _ => 'assets/icons/common-loot.png',
    };
    return Image.asset(icon, width: 16, height: 16);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cosmetic picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CosmeticPickerSheet extends StatefulWidget {
  const _CosmeticPickerSheet();

  @override
  State<_CosmeticPickerSheet> createState() => _CosmeticPickerSheetState();
}

class _CosmeticPickerSheetState extends State<_CosmeticPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<CosmeticItem> _itemsFor(CosmeticType? type) {
    final all = CosmeticCatalog.items.where((c) => !c.isDefault);
    if (type == null) {
      return all
          .where((c) =>
              c.type == CosmeticType.background ||
              c.type == CosmeticType.zillaSkin ||
              c.type == CosmeticType.avatarFrame)
          .toList();
    }
    return all.where((c) => c.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: [
                Text(
                  'Choose Cosmetic to Auto-Unlock',
                  style: ts.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'This cosmetic will be granted when the kid reaches this level',
                  style:
                      ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: AppTheme.zillaGreen,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: AppTheme.zillaGreen,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              const Tab(text: 'All'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/backgrounds/background-icon.png',
                        width: 16, height: 16),
                    const SizedBox(width: 5),
                    const Text('Backgrounds'),
                  ],
                ),
              ),
              const Tab(text: 'Skins'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/frames/frame-icon.png',
                        width: 14, height: 14),
                    const SizedBox(width: 5),
                    const Text('Frames'),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _CosmeticGrid(items: _itemsFor(null)),
                _CosmeticGrid(items: _itemsFor(CosmeticType.background)),
                _CosmeticGrid(items: _itemsFor(CosmeticType.zillaSkin)),
                _CosmeticGrid(items: _itemsFor(CosmeticType.avatarFrame)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmeticGrid extends StatelessWidget {
  const _CosmeticGrid({required this.items});

  final List<CosmeticItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('No items',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _CosmeticGridTile(item: items[i]),
    );
  }
}

class _CosmeticGridTile extends StatelessWidget {
  const _CosmeticGridTile({required this.item});

  final CosmeticItem item;

  Color get _rarityColor {
    switch (item.rarity) {
      case CosmeticRarity.epic:
        return _kEpicPurple;
      case CosmeticRarity.rare:
        return _kRareBlue;
      case CosmeticRarity.common:
        return _kCommonGreen;
      case null:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(item),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _rarityColor.withAlpha(60),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _rarityColor.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Preview area
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: _buildPreview(),
              ),
            ),

            // Name + rarity
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 7),
              child: Column(
                children: [
                  Text(
                    item.name,
                    style: ts.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Image.asset(
                    _rarityAsset(),
                    width: 18,
                    height: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (item.type == CosmeticType.background && item.assetKey.isNotEmpty) {
      return Image.asset(item.assetKey, fit: BoxFit.cover);
    }
    if (item.type == CosmeticType.zillaSkin && item.colorValue != null) {
      return Container(
        color: Color(item.colorValue!),
        child: const Center(
          child: Text('🦎', style: TextStyle(fontSize: 32)),
        ),
      );
    }
    if (item.type == CosmeticType.avatarFrame) {
      return Container(
        color: const Color(0xFF1A2A3A),
        child: Center(
          child: Image.asset('assets/frames/frame-icon.png',
              width: 40, height: 40),
        ),
      );
    }
    return Container(
      color: const Color(0xFF1A2A3A),
      child: Center(
        child: Text(
          _emojiForType(item.type),
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }

  String _rarityAsset() {
    switch (item.rarity) {
      case CosmeticRarity.epic:
        return 'assets/icons/epic-loot.png';
      case CosmeticRarity.rare:
        return 'assets/icons/rare-loot.png';
      default:
        return 'assets/icons/common-loot.png';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

CosmeticItem? _cosmeticById(String id) {
  try {
    return CosmeticCatalog.items.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}

String _emojiForType(CosmeticType type) {
  switch (type) {
    case CosmeticType.background:
      return '🖼️';
    case CosmeticType.zillaSkin:
      return '🦎';
    case CosmeticType.avatarFrame:
      return '🪟';
    case CosmeticType.title:
      return '🏷️';
    case CosmeticType.avatar:
      return '😀';
  }
}

String _cosmeticTypeLabel(CosmeticType type) {
  switch (type) {
    case CosmeticType.zillaSkin:
      return 'Zilla Skin';
    case CosmeticType.background:
      return 'Background';
    case CosmeticType.avatarFrame:
      return 'Avatar Frame';
    case CosmeticType.title:
      return 'Title';
    case CosmeticType.avatar:
      return 'Avatar';
  }
}
