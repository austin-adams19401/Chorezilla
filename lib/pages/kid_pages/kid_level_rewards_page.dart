// lib/pages/kid_pages/kid_level_rewards_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/models/cosmetics.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/themes/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tier color constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTierGreen1 = Color(0xFF2ECC71); // L1–5
const _kTierGreen2 = Color(0xFF27AE60);
const _kTierTeal1 = Color(0xFF1ABC9C); // L6–10
const _kTierTeal2 = Color(0xFF16A085);
const _kTierPurple1 = Color(0xFF9B59B6); // L11–15
const _kTierPurple2 = Color(0xFF8E44AD);
const _kTierGold1 = Color(0xFFFFB300); // L16–20
const _kTierGold2 = Color(0xFFF39C12);

List<Color> _tierColorsForLevel(int level) {
  if (level <= 5) return [_kTierGreen1, _kTierGreen2];
  if (level <= 10) return [_kTierTeal1, _kTierTeal2];
  if (level <= 15) return [_kTierPurple1, _kTierPurple2];
  return [_kTierGold1, _kTierGold2];
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class KidLevelRewardsPage extends StatelessWidget {
  const KidLevelRewardsPage({super.key, required this.memberId});

  final String memberId;

  Member? _resolveMember(AppState app) {
    try {
      return app.members.firstWhere((m) => m.id == memberId);
    } catch (_) {
      return app.currentMember ?? (app.members.isNotEmpty ? app.members.first : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final member = _resolveMember(app);
    if (member == null) {
      return const Scaffold(body: Center(child: Text('No kid found')));
    }

    final info = levelInfoForXp(member.xp);
    final currentLevel = info.level;
    final isPremium = app.family?.isPremium ?? false;
    final customRewards =
        isPremium ? app.family?.settings.customLevelRewards : null;
    final nextReward =
        nextLevelRewardFromLevel(currentLevel, customRewards: customRewards);
    final nextRewardLevel = nextReward?.level;

    final levelWidgets = <Widget>[];
    bool dividerInserted = false;

    for (int lvl = 1; lvl <= 20; lvl++) {
      final reward =
          levelRewardForLevel(lvl, customRewards: customRewards);
      final cosmeticTitle = titleForLevel(lvl);
      final tierColors = _tierColorsForLevel(lvl);
      final isEarned = lvl <= currentLevel;
      final isNext = lvl == nextRewardLevel;

      if (!dividerInserted && !isEarned && lvl > 1) {
        levelWidgets.add(_YouAreHereDivider(level: currentLevel));
        dividerInserted = true;
      }

      if (lvl == 1) {
        levelWidgets.add(
          _Level1Card(tierColors: tierColors, isEarned: isEarned),
        );
      } else if (isEarned) {
        levelWidgets.add(_EarnedLevelCard(
          level: lvl,
          reward: reward,
          cosmeticTitle: cosmeticTitle,
          tierColors: tierColors,
        ));
      } else if (isNext) {
        levelWidgets.add(_NextRewardCard(
          level: lvl,
          reward: reward,
          cosmeticTitle: cosmeticTitle,
          tierColors: tierColors,
          xpRemaining: info.xpNeededThisLevel - info.xpIntoLevel,
        ));
      } else {
        levelWidgets.add(_UpcomingLevelCard(
          level: lvl,
          reward: reward,
          cosmeticTitle: cosmeticTitle,
          tierColors: tierColors,
        ));
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Level Rewards',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _XpProgressBanner(
              member: member,
              info: info,
              nextReward: nextReward,
              customRewards: customRewards,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildListDelegate(levelWidgets),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP Progress Banner (hero header)
// ─────────────────────────────────────────────────────────────────────────────

class _XpProgressBanner extends StatelessWidget {
  const _XpProgressBanner({
    required this.member,
    required this.info,
    required this.nextReward,
    required this.customRewards,
  });

  final Member member;
  final LevelInfo info;
  final LevelRewardDefinition? nextReward;
  final Map<int, List<LevelRewardDefinition>>? customRewards;

  @override
  Widget build(BuildContext context) {
    final tierColors = _tierColorsForLevel(info.level);
    final xpRemaining = info.xpNeededThisLevel - info.xpIntoLevel;
    final isMaxed = nextReward == null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.deepNavy,
            tierColors[0].withValues(alpha: 0.35),
            AppTheme.deepNavy,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.displayName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LevelBadge(
                    level: info.level,
                    colors: tierColors,
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${info.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ),
                      if (!isMaxed)
                        Text(
                          '${info.xpIntoLevel} / ${info.xpNeededThisLevel} XP',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!isMaxed) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: info.progress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(tierColors[0]),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '$xpRemaining XP to unlock  ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${nextReward!.emoji} ${nextReward!.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kTierGold1.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: _kTierGold1.withValues(alpha: 0.5), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text(
                        'Max level reached!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YOU ARE HERE divider
// ─────────────────────────────────────────────────────────────────────────────

class _YouAreHereDivider extends StatelessWidget {
  const _YouAreHereDivider({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: _kTierGreen1.withValues(alpha: 0.4),
              thickness: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kTierGreen1, _kTierGreen2],
              ),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: _kTierGreen1.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.my_location_rounded,
                    size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'YOU ARE HERE — Level $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: _kTierGreen1.withValues(alpha: 0.4),
              thickness: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level 1 card
// ─────────────────────────────────────────────────────────────────────────────

class _Level1Card extends StatelessWidget {
  const _Level1Card({required this.tierColors, required this.isEarned});
  final List<Color> tierColors;
  final bool isEarned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tierColors[0].withValues(alpha: 0.85),
              tierColors[1].withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: tierColors[0].withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _LevelBadge(level: 1, colors: tierColors),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Journey Begins!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Complete chores to earn XP and level up.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Text('🦎', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 4),
            const Icon(Icons.check_circle_rounded,
                color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earned level card (levels ≤ currentLevel)
// ─────────────────────────────────────────────────────────────────────────────

class _EarnedLevelCard extends StatelessWidget {
  const _EarnedLevelCard({
    required this.level,
    required this.reward,
    required this.cosmeticTitle,
    required this.tierColors,
  });

  final int level;
  final LevelRewardDefinition? reward;
  final CosmeticItem? cosmeticTitle;
  final List<Color> tierColors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tierColors[0].withValues(alpha: 0.85),
              tierColors[1].withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: tierColors[0].withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _LevelBadge(level: level, colors: tierColors),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reward != null) ...[
                    Text(
                      reward!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (reward!.description.isNotEmpty)
                      Text(
                        reward!.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ] else if (cosmeticTitle != null) ...[
                    Text(
                      cosmeticTitle!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const Text(
                      'Title unlocked',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ] else ...[
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (reward != null)
              Text(reward!.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded,
                color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next reward card (animated spotlight)
// ─────────────────────────────────────────────────────────────────────────────

class _NextRewardCard extends StatefulWidget {
  const _NextRewardCard({
    required this.level,
    required this.reward,
    required this.cosmeticTitle,
    required this.tierColors,
    required this.xpRemaining,
  });

  final int level;
  final LevelRewardDefinition? reward;
  final CosmeticItem? cosmeticTitle;
  final List<Color> tierColors;
  final int xpRemaining;

  @override
  State<_NextRewardCard> createState() => _NextRewardCardState();
}

class _NextRewardCardState extends State<_NextRewardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _emoji =>
      widget.reward?.emoji ?? '🏅';

  String get _title =>
      widget.reward?.title ?? widget.cosmeticTitle?.name ?? 'Level ${widget.level}';

  String get _description =>
      widget.reward?.description ??
      (widget.cosmeticTitle != null ? 'Title unlocked: ${widget.cosmeticTitle!.name}' : '');

  @override
  Widget build(BuildContext context) {
    final tierColors = widget.tierColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          final glowOpacity = 0.3 + (_glow.value * 0.45);
          final glowBlur = 15.0 + (_glow.value * 18.0);
          final glowSpread = 1.0 + (_glow.value * 4.0);

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: tierColors[0].withValues(alpha: glowOpacity),
                  blurRadius: glowBlur,
                  spreadRadius: glowSpread,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: tierColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NEXT REWARD pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward_rounded,
                        size: 13, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'NEXT REWARD',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Big emoji + level badge row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(_emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(width: 14),
                  _LevelBadge(
                    level: widget.level,
                    colors: [
                      Colors.white.withValues(alpha: 0.3),
                      Colors.white.withValues(alpha: 0.15),
                    ],
                    size: 48,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              if (_description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35), width: 1),
                ),
                child: Text(
                  '${widget.xpRemaining} XP to go',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
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
// Upcoming / locked card
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingLevelCard extends StatelessWidget {
  const _UpcomingLevelCard({
    required this.level,
    required this.reward,
    required this.cosmeticTitle,
    required this.tierColors,
  });

  final int level;
  final LevelRewardDefinition? reward;
  final CosmeticItem? cosmeticTitle;
  final List<Color> tierColors;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: tierColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _LevelBadge(level: level, colors: tierColors),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reward != null) ...[
                      Text(
                        reward!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (reward!.description.isNotEmpty)
                        Text(
                          reward!.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ] else if (cosmeticTitle != null) ...[
                      Text(
                        cosmeticTitle!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Text(
                        'Title unlocked',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ] else ...[
                      Text(
                        'Level $level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (reward != null)
                Text(reward!.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              const Icon(Icons.lock_rounded, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level badge circle
// ─────────────────────────────────────────────────────────────────────────────

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.level,
    required this.colors,
    this.size = 44,
  });

  final int level;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Center(
        child: Text(
          '$level',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}
