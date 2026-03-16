// lib/components/loot_box_open_dialog.dart

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'package:chorezilla/components/sprite_sheet_animation.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/cosmetics.dart';

/// 3-click loot box opening dialog.
///
/// The kid taps the box 3 times. Each click rolls a rarity; the best rarity
/// rolled so far is kept. After the 3rd click, the actual cosmetic is selected
/// and a reveal animation plays.
///
/// Pops with a [LootBoxClickState] (isFinished == true) when the kid taps
/// "Nice!". The caller is responsible for writing the result to Firestore.
class LootBoxOpenDialog extends StatefulWidget {
  const LootBoxOpenDialog({
    super.key,
    required this.boxDefinition,
    required this.ownedCosmetics,
  });

  final LootBoxDefinition boxDefinition;
  final List<String> ownedCosmetics;

  @override
  State<LootBoxOpenDialog> createState() => _LootBoxOpenDialogState();
}

class _LootBoxOpenDialogState extends State<LootBoxOpenDialog>
    with TickerProviderStateMixin {
  LootBoxClickState _clickState = const LootBoxClickState();
  CosmeticRarity? _previousRarity;

  late final AnimationController _shakeController;
  late final AnimationController _upgradeController;
  late final AnimationController _revealController;
  late final ConfettiController _confetti;

  static const _burstDuration = 0.65;

  @override
  void initState() {
    super.initState();

    _confetti = ConfettiController(duration: const Duration(seconds: 2));

    // Short shake played on each of the first two taps
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Elastic scale bounce on the rarity meter when rarity upgrades
    _upgradeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Full 2.2 s reveal animation triggered after the 3rd tap
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _confetti.play();
        setState(() {}); // enable the Nice! button
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _upgradeController.dispose();
    _revealController.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _onBoxTap() {
    if (_clickState.isFinished) return;

    _previousRarity = _clickState.currentRarity;
    final newState = widget.boxDefinition.rollClick(
      _clickState,
      widget.ownedCosmetics,
    );
    setState(() => _clickState = newState);

    if (newState.isFinished) {
      _revealController.forward();
    } else {
      _shakeController.forward(from: 0);
      // Flash upgrade animation if rarity improved
      if (_previousRarity != null &&
          newState.currentRarity != null &&
          newState.currentRarity!.index > _previousRarity!.index) {
        _upgradeController.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final box = widget.boxDefinition;
    final revealDone = _revealController.isCompleted;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Confetti emitter (active after reveal completes)
            ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 5,
              emissionFrequency: 0.4,
              gravity: 0.2,
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Visual area ──────────────────────────────────────────────
                SizedBox(
                  height: 220,
                  child: _clickState.isFinished
                      ? _RevealAnimation(
                          controller: _revealController,
                          box: box,
                          clickState: _clickState,
                        )
                      : _ClickingArea(
                          box: box,
                          clickState: _clickState,
                          shakeController: _shakeController,
                          upgradeController: _upgradeController,
                          previousRarity: _previousRarity,
                          onTap: _onBoxTap,
                        ),
                ),

                const SizedBox(height: 16),

                // ── Title / item name ────────────────────────────────────────
                if (!_clickState.isFinished) ...[
                  Text(
                    box.name,
                    style: ts.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🪙 ${box.costCoins} coins',
                    style: ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ] else if (_revealController.value >= _burstDuration) ...[
                  Text(
                    'You got...',
                    style: ts.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _clickState.wonItem?.name ?? '',
                    style: ts.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_clickState.wonItem?.description.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      _clickState.wonItem!.description,
                      style: ts.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_clickState.isDuplicate) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            'Already owned — +${_clickState.coinRefund} coins refunded',
                            style: ts.bodySmall?.copyWith(
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 20),

                // ── Button ───────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: revealDone
                      ? FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_clickState),
                          child: const Text('Nice!'),
                        )
                      : FilledButton(
                          onPressed: _clickState.isFinished ? null : _onBoxTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                          ),
                          child: Text(_tapPrompt),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _tapPrompt {
    switch (_clickState.clickCount) {
      case 0:
        return 'Tap to begin!';
      case 1:
        return 'Tap to boost!';
      default:
        return 'One more tap!';
    }
  }
}

// ---------------------------------------------------------------------------
// Clicking phase UI (before the 3rd tap)
// ---------------------------------------------------------------------------

class _ClickingArea extends StatelessWidget {
  const _ClickingArea({
    required this.box,
    required this.clickState,
    required this.shakeController,
    required this.upgradeController,
    required this.previousRarity,
    required this.onTap,
  });

  final LootBoxDefinition box;
  final LootBoxClickState clickState;
  final AnimationController shakeController;
  final AnimationController upgradeController;
  final CosmeticRarity? previousRarity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Box emoji with shake animation
          AnimatedBuilder(
            animation: shakeController,
            builder: (context, child) {
              final angle = math.sin(shakeController.value * math.pi * 5) *
                  0.15 *
                  (1 - shakeController.value);
              return Transform.rotate(angle: angle, child: child);
            },
            child: Text(
              box.categoryEmoji,
              style: const TextStyle(fontSize: 80),
            ),
          ),

          const SizedBox(height: 16),

          // Rarity meter (appears after first click)
          if (clickState.clickCount > 0 && clickState.currentRarity != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _RarityMeter(
                key: ValueKey(clickState.currentRarity),
                rarity: clickState.currentRarity!,
                upgradeController: upgradeController,
              ),
            )
          else
            const SizedBox(height: 52), // placeholder to keep height stable
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reveal animation phase (after 3rd tap — mirrors original dialog logic)
// ---------------------------------------------------------------------------

class _RevealAnimation extends StatelessWidget {
  const _RevealAnimation({
    required this.controller,
    required this.box,
    required this.clickState,
  });

  final AnimationController controller;
  final LootBoxDefinition box;
  final LootBoxClickState clickState;

  static const _shakeDuration = 0.35;
  static const _burstDuration = 0.65;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = clickState.wonItem;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;

        // Phase 1: shake (0.0 – 0.35)
        final shakeProgress = (t / _shakeDuration).clamp(0.0, 1.0);
        final shakeAngle = shakeProgress < 1.0
            ? math.sin(shakeProgress * math.pi * 6) *
                0.12 *
                (1 - shakeProgress)
            : 0.0;

        // Phase 2: box fade out (0.35 – 0.65)
        final boxOpacity = t < _shakeDuration
            ? 1.0
            : (1.0 -
                    ((t - _shakeDuration) /
                        (_burstDuration - _shakeDuration)))
                .clamp(0.0, 1.0);

        // Phase 3: reveal (0.65 – 1.0)
        final revealRaw = t < _burstDuration
            ? 0.0
            : (t - _burstDuration) / (1.0 - _burstDuration);
        final revealProgress =
            Curves.easeOutBack.transform(revealRaw.clamp(0.0, 1.0));
        final revealOpacity = revealRaw.clamp(0.0, 1.0);
        final revealSlide = (1.0 - revealProgress) * 30.0;

        // Sparkles during burst
        final sparkleProgress = t > _shakeDuration && t < _burstDuration
            ? ((t - _shakeDuration) / (_burstDuration - _shakeDuration))
                .clamp(0.0, 1.0)
            : 0.0;
        final sparkleRadius = sparkleProgress * 80.0;
        final sparkleOpacity =
            (sparkleProgress * (1 - sparkleProgress) * 4).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Sparkles burst
            if (sparkleOpacity > 0)
              ...List.generate(8, (i) {
                final angle = (i * 2 * math.pi) / 8;
                return Opacity(
                  opacity: sparkleOpacity,
                  child: Transform.translate(
                    offset: Offset(
                      sparkleRadius * math.cos(angle),
                      sparkleRadius * math.sin(angle),
                    ),
                    child: Icon(
                      Icons.star,
                      size: 16,
                      color: i.isEven ? cs.primary : cs.secondary,
                    ),
                  ),
                );
              }),

            // Box (shakes then fades)
            Opacity(
              opacity: boxOpacity,
              child: Transform.rotate(
                angle: shakeAngle,
                child: Text(
                  box.categoryEmoji,
                  style: const TextStyle(fontSize: 72),
                ),
              ),
            ),

            // Revealed item
            if (item != null)
              Opacity(
                opacity: revealOpacity,
                child: Transform.translate(
                  offset: Offset(0, revealSlide),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SpriteSheetAnimation(
                        assetPath:
                            'assets/icons/mascot/sprite-sheets/celebrate.png',
                        size: 64,
                        columns: 6,
                        rows: 6,
                        totalDuration: Duration(milliseconds: 1800),
                        loop: false,
                      ),
                      const SizedBox(height: 8),
                      _ItemReveal(item: item),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Rarity meter widget
// ---------------------------------------------------------------------------

class _RarityMeter extends StatelessWidget {
  const _RarityMeter({
    super.key,
    required this.rarity,
    required this.upgradeController,
  });

  final CosmeticRarity rarity;
  final AnimationController upgradeController;

  static Color _rarityColor(CosmeticRarity r) {
    switch (r) {
      case CosmeticRarity.common:
        return Colors.amber;
      case CosmeticRarity.rare:
        return Colors.blue;
      case CosmeticRarity.epic:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final color = _rarityColor(rarity);

    return AnimatedBuilder(
      animation: upgradeController,
      builder: (context, child) {
        final scale = 1.0 +
            0.25 *
                math.sin(upgradeController.value * math.pi).clamp(0.0, 1.0);
        return Transform.scale(scale: scale, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Icon(
                i < rarity.starCount
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: i < rarity.starCount
                    ? color
                    : Colors.grey.withValues(alpha: 0.4),
                size: 32,
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            rarity.displayName,
            style: ts.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item reveal card
// ---------------------------------------------------------------------------

class _ItemReveal extends StatelessWidget {
  const _ItemReveal({required this.item});

  final CosmeticItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final String emoji;
    switch (item.type) {
      case CosmeticType.background:
        emoji = '🖼️';
        break;
      case CosmeticType.zillaSkin:
        emoji = '🦖';
        break;
      case CosmeticType.avatarFrame:
        emoji = '⭐';
        break;
      case CosmeticType.title:
        emoji = '🏆';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Text(
            item.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
