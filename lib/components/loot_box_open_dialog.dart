// lib/components/loot_box_open_dialog.dart

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'package:chorezilla/components/sprite_sheet_animation.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/cosmetics.dart';

/// Shows a loot box opening animation and reveals the won item.
/// Call this after the Firestore write has already completed so the result
/// is guaranteed before the animation plays.
class LootBoxOpenDialog extends StatefulWidget {
  const LootBoxOpenDialog({
    super.key,
    required this.boxDefinition,
    required this.result,
  });

  final LootBoxDefinition boxDefinition;
  final LootBoxResult result;

  @override
  State<LootBoxOpenDialog> createState() => _LootBoxOpenDialogState();
}

class _LootBoxOpenDialogState extends State<LootBoxOpenDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ConfettiController _confetti;

  // Phase intervals
  static const _shakeDuration = 0.35;
  static const _burstDuration = 0.65;
  // reveal runs from 0.65 → 1.0

  @override
  void initState() {
    super.initState();

    _confetti = ConfettiController(duration: const Duration(seconds: 2));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _confetti.play();
      }
    });

    // Auto-play
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final item = widget.result.wonItem;
    final box = widget.boxDefinition;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            // ── Phase 1: Shake (0.0 – 0.35) ─────────────────────────────────
            final shakeProgress = (t / _shakeDuration).clamp(0.0, 1.0);
            final shakeAngle = shakeProgress < 1.0
                ? math.sin(shakeProgress * math.pi * 6) * 0.12 * (1 - shakeProgress)
                : 0.0;

            // ── Phase 2: Box fade out (0.35 – 0.65) ──────────────────────────
            final boxOpacity = t < _shakeDuration
                ? 1.0
                : (1.0 - ((t - _shakeDuration) / (_burstDuration - _shakeDuration)))
                    .clamp(0.0, 1.0);

            // ── Phase 3: Reveal (0.65 – 1.0) ─────────────────────────────────
            final revealRaw = t < _burstDuration
                ? 0.0
                : (t - _burstDuration) / (1.0 - _burstDuration);
            final revealProgress = Curves.easeOutBack.transform(revealRaw.clamp(0.0, 1.0));
            final revealOpacity = revealRaw.clamp(0.0, 1.0);
            final revealSlide = (1.0 - revealProgress) * 30.0;

            // Sparkles during burst
            final sparkleProgress = t > _shakeDuration && t < _burstDuration
                ? ((t - _shakeDuration) / (_burstDuration - _shakeDuration)).clamp(0.0, 1.0)
                : 0.0;
            final sparkleRadius = sparkleProgress * 80.0;
            final sparkleOpacity = (sparkleProgress * (1 - sparkleProgress) * 4).clamp(0.0, 1.0);

            return Stack(
              alignment: Alignment.topCenter,
              children: [
                // Confetti emitter
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
                    // Box + sparkles + reveal stacked in a fixed-height area
                    SizedBox(
                      height: 200,
                      child: Stack(
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
                                box.tierEmoji,
                                style: const TextStyle(fontSize: 72),
                              ),
                            ),
                          ),

                          // Revealed item
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
                                    totalDuration:
                                        Duration(milliseconds: 1800),
                                    loop: false,
                                  ),
                                  const SizedBox(height: 8),
                                  _ItemReveal(
                                    item: item,
                                    isDuplicate: widget.result.isDuplicate,
                                    coinRefund: widget.result.coinRefund,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Box name / title
                    Text(
                      t < _burstDuration ? box.name : 'You got...',
                      style: ts.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 8),

                    if (t >= _burstDuration) ...[
                      Text(
                        item.name,
                        style: ts.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: ts.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (widget.result.isDuplicate) ...[
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
                                'Already owned — +${widget.result.coinRefund} coins refunded',
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

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: t >= _burstDuration
                            ? () => Navigator.of(context).pop()
                            : null,
                        child: const Text('Nice!'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItemReveal extends StatelessWidget {
  const _ItemReveal({
    required this.item,
    required this.isDuplicate,
    required this.coinRefund,
  });

  final CosmeticItem item;
  final bool isDuplicate;
  final int coinRefund;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Pick a representative emoji based on cosmetic type
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
