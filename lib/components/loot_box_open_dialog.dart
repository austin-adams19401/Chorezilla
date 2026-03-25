// lib/components/loot_box_open_dialog.dart

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'package:chorezilla/components/avatar_cosmetic_widgets.dart';
import 'package:chorezilla/components/sprite_sheet_animation.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/cosmetics.dart';

// ---------------------------------------------------------------------------
// Top-level helpers
// ---------------------------------------------------------------------------

String _lootIconPath(CosmeticRarity r) {
  switch (r) {
    case CosmeticRarity.common:
      return 'assets/icons/common-loot.png';
    case CosmeticRarity.rare:
      return 'assets/icons/rare-loot.png';
    case CosmeticRarity.epic:
      return 'assets/icons/epic-loot.png';
  }
}

List<Color> _boxGradient(CosmeticType type) {
  switch (type) {
    case CosmeticType.background:
      return [const Color(0xFF0D7377), const Color(0xFF5C35A0)];
    case CosmeticType.zillaSkin:
      return [const Color(0xFF1565C0), const Color(0xFF6A1B9A)];
    case CosmeticType.avatarFrame:
      return [const Color(0xFF7B1FA2), const Color(0xFFC2185B)];
    case CosmeticType.title:
      return [const Color(0xFFE65100), const Color(0xFFB71C1C)];
    case CosmeticType.avatar:
      return [const Color(0xFF00897B), const Color(0xFF00ACC1)];
  }
}

Color _rarityGlowColor(CosmeticRarity r) {
  switch (r) {
    case CosmeticRarity.common:
      return Colors.amber;
    case CosmeticRarity.rare:
      return Colors.lightBlueAccent;
    case CosmeticRarity.epic:
      return Colors.purpleAccent;
  }
}

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

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _upgradeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _confetti.play();
        setState(() {});
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
      if (_previousRarity != null &&
          newState.currentRarity != null &&
          newState.currentRarity!.index > _previousRarity!.index) {
        _upgradeController.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final box = widget.boxDefinition;
    final gradient = _boxGradient(box.cosmeticType);
    final revealDone = _revealController.isCompleted;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 56),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Diagonal shine streak
              Positioned(
                top: -30,
                left: -20,
                child: Transform.rotate(
                  angle: -0.5,
                  child: Container(
                    width: 80,
                    height: 340,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Confetti emitter
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 25,
                  maxBlastForce: 20,
                  minBlastForce: 5,
                  emissionFrequency: 0.4,
                  gravity: 0.2,
                ),
              ),

              // Close button — only visible before the reveal starts
              if (!_clickState.isFinished)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                ),

              // Main content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 28), // clearance for close button

                    // ── Visual area ─────────────────────────────────────────
                    SizedBox(
                      height: 250,
                      child: _clickState.isFinished
                          ? _RevealAnimation(
                              controller: _revealController,
                              clickState: _clickState,
                            )
                          : _ClickingArea(
                              clickState: _clickState,
                              shakeController: _shakeController,
                              upgradeController: _upgradeController,
                              onTap: _onBoxTap,
                            ),
                    ),

                    const SizedBox(height: 12),

                    // ── Text / info ──────────────────────────────────────────
                    AnimatedBuilder(
                      animation: _revealController,
                      builder: (context, _) {
                        if (!_clickState.isFinished) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                box.name,
                                style: ts.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '🪙',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${box.costCoins} coins',
                                    style: ts.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _ClickDots(count: _clickState.clickCount),
                            ],
                          );
                        } else if (_revealController.value >= _burstDuration) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'You got...',
                                style: ts.titleSmall?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _clickState.wonItem?.name ?? '',
                                style: ts.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_clickState.wonItem?.description.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _clickState.wonItem!.description,
                                  style: ts.bodySmall?.copyWith(
                                    color: Colors.white70,
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
                                    color: Colors.white.withValues(alpha: 0.15),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '🪙',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Already owned — +${_clickState.coinRefund} coins refunded',
                                        style: ts.bodySmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        } else {
                          // Animation in progress — hold space so dialog
                          // doesn't collapse
                          return const SizedBox(height: 72);
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Button ───────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: revealDone
                          ? FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(_clickState),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: gradient.first,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              child: const Text('Nice!'),
                            )
                          : OutlinedButton(
                              onPressed:
                                  _clickState.isFinished ? null : _onBoxTap,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.35),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  width: 1.5,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(_tapPrompt),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    required this.clickState,
    required this.shakeController,
    required this.upgradeController,
    required this.onTap,
  });

  final LootBoxClickState clickState;
  final AnimationController shakeController;
  final AnimationController upgradeController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rarity = clickState.currentRarity ?? CosmeticRarity.common;
    final glowColor = _rarityGlowColor(rarity);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with radial glow ring — shake + upgrade pulse both applied
          AnimatedBuilder(
            animation: Listenable.merge([shakeController, upgradeController]),
            builder: (context, child) {
              final angle = math.sin(shakeController.value * math.pi * 5) *
                  0.15 *
                  (1 - shakeController.value);
              final pulse = 1.0 +
                  0.15 *
                      math
                          .sin(upgradeController.value * math.pi)
                          .clamp(0.0, 1.0);
              return Transform.scale(
                scale: pulse,
                child: Transform.rotate(angle: angle, child: child),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withValues(alpha: 0.45),
                    glowColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Image.asset(
                  _lootIconPath(rarity),
                  width: 140,
                  height: 140,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Rarity badge (appears after first click)
          if (clickState.clickCount > 0 && clickState.currentRarity != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _RarityBadge(
                key: ValueKey(clickState.currentRarity),
                rarity: clickState.currentRarity!,
                upgradeController: upgradeController,
              ),
            )
          else
            const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reveal animation phase (after 3rd tap)
// ---------------------------------------------------------------------------

class _RevealAnimation extends StatelessWidget {
  const _RevealAnimation({
    required this.controller,
    required this.clickState,
  });

  final AnimationController controller;
  final LootBoxClickState clickState;

  static const _shakeDuration = 0.35;
  static const _burstDuration = 0.65;

  @override
  Widget build(BuildContext context) {
    final item = clickState.wonItem;
    final glowColor =
        _rarityGlowColor(clickState.currentRarity ?? CosmeticRarity.common);

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
        final sparkleRadius = sparkleProgress * 88.0;
        final sparkleOpacity =
            (sparkleProgress * (1 - sparkleProgress) * 4).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Sparkles burst — white + rarity color alternating
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
                      size: 18,
                      color: i.isEven ? Colors.white : glowColor,
                    ),
                  ),
                );
              }),

            // Box icon — shakes then fades
            Opacity(
              opacity: boxOpacity,
              child: Transform.rotate(
                angle: shakeAngle,
                child: Image.asset(
                  _lootIconPath(
                    clickState.currentRarity ?? CosmeticRarity.common,
                  ),
                  width: 120,
                  height: 120,
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
                        bodyAssetPath:
                            'assets/mascot/sprite-sheets/celebrate_body.png',
                        detailsAssetPath:
                            'assets/mascot/sprite-sheets/celebrate_details.png',
                        size: 72,
                        tintColor: Color(0xFF2ECC71),
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
// Rarity badge
// ---------------------------------------------------------------------------

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({
    super.key,
    required this.rarity,
    required this.upgradeController,
  });

  final CosmeticRarity rarity;
  final AnimationController upgradeController;

  @override
  Widget build(BuildContext context) {
    final color = _rarityGlowColor(rarity);

    return AnimatedBuilder(
      animation: upgradeController,
      builder: (context, child) {
        final scale = 1.0 +
            0.2 *
                math.sin(upgradeController.value * math.pi).clamp(0.0, 1.0);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 14,
            ),
          ],
        ),
        child: Text(
          rarity.displayName.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Click progress dots
// ---------------------------------------------------------------------------

class _ClickDots extends StatelessWidget {
  const _ClickDots({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: filled ? 12 : 8,
          height: filled ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
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
    final Widget icon;
    switch (item.type) {
      case CosmeticType.background:
        icon = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            item.assetKey,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        );
        break;
      case CosmeticType.zillaSkin:
        icon = Image.asset(
          'assets/mascot/mascot_plain.png',
          width: 80,
          height: 80,
          color: item.colorValue != null ? Color(item.colorValue!) : null,
          colorBlendMode: item.colorValue != null ? BlendMode.srcIn : null,
        );
        break;
      case CosmeticType.avatarFrame:
        icon = SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
              ),
              FrameOverlay(frameId: item.id, radius: 32),
            ],
          ),
        );
        break;
      case CosmeticType.avatar:
        icon = ClipOval(
          child: Image.asset(
            item.assetKey,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        );
        break;
      case CosmeticType.title:
        icon = const Text('🏆', style: TextStyle(fontSize: 56));
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 10),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
