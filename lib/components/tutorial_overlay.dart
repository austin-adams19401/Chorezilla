// lib/components/tutorial_overlay.dart

import 'dart:ui' show lerpDouble;

import 'package:chorezilla/components/zilla_mascot.dart';
import 'package:chorezilla/models/zilla_animations.dart';
import 'package:chorezilla/themes/app_theme.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & data classes
// ─────────────────────────────────────────────────────────────────────────────

enum TutorialStep {
  step1Today,
  step2Chores,
  step3RewardsNav,
  step3bRewardsContent,
  step4HistoryNav,
  step4bHistoryContent,
  step5KidView,
}

class _StepData {
  const _StepData({
    required this.message,
    required this.subMessage,
    required this.actionHint,
    required this.actionLabel,
    required this.allowSpotlightTap,
  });

  final String message;
  final String subMessage;

  /// Short instruction telling the user what to tap next.
  final String actionHint;

  /// Empty string = no action button (step 1 — spotlight tap or skip only).
  final String actionLabel;

  /// If true, tapping the spotlight circle also fires onAdvance.
  final bool allowSpotlightTap;
}

const _steps = {
  TutorialStep.step1Today: _StepData(
    message: "This is where your kids' stats will live",
    subMessage: "Tap a kid's card to see their chores due today, track their progress, and cheer them on as they check things off.",
    actionHint: 'Tap the Chores tab to continue.',
    actionLabel: '',
    allowSpotlightTap: true,
  ),
  TutorialStep.step2Chores: _StepData(
    message: 'Create and manage chores here',
    subMessage: "Add chores, set coin values, and assign them to specific kids.",
    actionHint: "Tap 'New chore' to create your first chore.",
    actionLabel: '',
    allowSpotlightTap: true,
  ),
  TutorialStep.step3RewardsNav: _StepData(
    message: 'Build a rewards store your kids will love',
    subMessage: 'Create prizes your kids can redeem with the coins they earn from chores.',
    actionHint: 'Tap the Rewards tab to continue.',
    actionLabel: '',
    allowSpotlightTap: true,
  ),
  TutorialStep.step3bRewardsContent: _StepData(
    message: 'Build a rewards store your kids will love',
    subMessage: 'Set up prizes your kids actually want, like screen time or a trip for ice cream. They spend their earned coins here.',
    actionHint: 'Tap Next when you are ready.',
    actionLabel: 'Next',
    allowSpotlightTap: false,
  ),
  TutorialStep.step4HistoryNav: _StepData(
    message: 'Almost done!',
    subMessage: "One more tab to check out before you hand things off to the kids.",
    actionHint: 'Tap the History tab to continue.',
    actionLabel: '',
    allowSpotlightTap: true,
  ),
  TutorialStep.step4bHistoryContent: _StepData(
    message: "Track your family's progress here",
    subMessage: 'See a full log of completed chores, coins earned, and rewards redeemed. Great for spotting patterns and keeping kids accountable.',
    actionHint: 'Tap Next to finish up.',
    actionLabel: 'Next',
    allowSpotlightTap: false,
  ),
  TutorialStep.step5KidView: _StepData(
    message: 'Ready to hand off to your kids?',
    subMessage: "Switch to a kid-friendly view where your kids can see their chores, check them off, and spend their coins.",
    actionHint: "Tap 'Done' to switch to kid view and see how it works.",
    actionLabel: 'Done',
    allowSpotlightTap: true,
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// SpotlightPainter
// ─────────────────────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.center,
    required this.radius,
    required this.showCutout,
  });

  final Offset center;
  final double radius;
  final bool showCutout;

  @override
  void paint(Canvas canvas, Size size) {
    if (showCutout) {
      final outerPath = Path()..addRect(Offset.zero & size);
      final holePath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
      final cutout =
          Path.combine(PathOperation.difference, outerPath, holePath);

      canvas.drawPath(
        cutout,
        Paint()..color = Colors.black.withValues(alpha: 0.30),
      );

      // Subtle white ring around the spotlight
      canvas.drawCircle(
        center,
        radius + 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.30),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.center != center || old.radius != radius || old.showCutout != showCutout;
}

// ─────────────────────────────────────────────────────────────────────────────
// TutorialOverlay
// ─────────────────────────────────────────────────────────────────────────────

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.step,
    required this.previousStep,
    required this.onAdvance,
    required this.onSkip,
  });

  final TutorialStep step;
  final TutorialStep? previousStep;
  final VoidCallback onAdvance;
  final VoidCallback onSkip;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  ({Offset center, double radius}) _spotlightFor(
    TutorialStep step,
    MediaQueryData mq,
  ) {
    final w = mq.size.width;
    final h = mq.size.height;
    final bottom = mq.padding.bottom;
    final top = mq.padding.top;

    switch (step) {
      case TutorialStep.step1Today:
        // Chores tab = nav index 1 of 4
        return (
          center: Offset(w * 1.5 / 4, h - bottom - 40),
          radius: 48,
        );
      case TutorialStep.step2Chores:
        // Extended FAB "New chore" — bottom-right, above NavigationBar
        // Extended FAB height ~48dp, width ~150dp; center x ≈ w - 16 - 75, center y ≈ h - bottom - 80(nav) - 16 - 24
        return (
          center: Offset(w - 91, h - bottom - 120),
          radius: 64,
        );
      case TutorialStep.step3RewardsNav:
      case TutorialStep.step3bRewardsContent:
        // Rewards tab = nav index 2 of 4
        return (
          center: Offset(w * 2.5 / 4, h - bottom - 40),
          radius: 48,
        );
      case TutorialStep.step4HistoryNav:
      case TutorialStep.step4bHistoryContent:
        // History tab = nav index 3 of 4
        return (
          center: Offset(w * 3.5 / 4, h - bottom - 40),
          radius: 48,
        );
      case TutorialStep.step5KidView:
        // "Kid view" TextButton.icon in AppBar trailing actions
        return (
          center: Offset(w - 72, top + kToolbarHeight / 2),
          radius: 50,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final stepData = _steps[widget.step]!;

    final current = _spotlightFor(widget.step, mq);
    final prev = widget.previousStep != null
        ? _spotlightFor(widget.previousStep!, mq)
        : current;

    const double navBarHeight = 80.0;
    final bool isBottomCard = widget.step == TutorialStep.step1Today;

    // Card sits below the AppBar for most steps; centered vertically for
    // step5 since that spotlights the AppBar area.
    final cardTop = widget.step == TutorialStep.step5KidView
        ? mq.size.height * 0.35
        : mq.padding.top + kToolbarHeight + 16.0;
    final cardBottom = mq.padding.bottom + navBarHeight + 8.0;

    final hasActionButton = stepData.actionLabel.isNotEmpty;

    return FadeTransition(
      opacity: _fadeAnim,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(widget.step),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          final center = Offset.lerp(prev.center, current.center, t)!;
          final radius = lerpDouble(prev.radius, current.radius, t)!;

          return Stack(
            children: [
              // 1. Dimmed overlay with spotlight hole
              CustomPaint(
                size: mq.size,
                painter: _SpotlightPainter(
                  center: center,
                  radius: radius,
                  showCutout: stepData.allowSpotlightTap || !hasActionButton,
                ),
              ),

              // 2. Full-screen tap blocker
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: const SizedBox.expand(),
              ),

              // 3. Spotlight tap zone (on top of blocker)
              if (stepData.allowSpotlightTap)
                Positioned(
                  left: center.dx - radius,
                  top: center.dy - radius,
                  width: radius * 2,
                  height: radius * 2,
                  child: GestureDetector(
                    onTap: widget.onAdvance,
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // 4 & 5. Message card + Mascot
              if (isBottomCard)
                Positioned(
                  bottom: cardBottom,
                  left: 24,
                  right: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.only(
                            left: 80,
                            right: 20,
                            top: 16,
                            bottom: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.deepNavy,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.zillaGreen,
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stepData.message,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                stepData.subMessage,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                stepData.actionHint,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.zillaGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    onPressed: widget.onSkip,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.zillaGreen
                                          .withValues(alpha: 0.55),
                                      foregroundColor: AppTheme.deepNavy,
                                    ),
                                    child: const Text('Skip'),
                                  ),
                                  if (hasActionButton) ...[
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: widget.onAdvance,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.zillaGreen,
                                        foregroundColor: AppTheme.deepNavy,
                                      ),
                                      child: Text(stepData.actionLabel),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -16,
                        left: -16,
                        child: ZillaMascot(
                          size: 80,
                          animate: true,
                          availableAnimations: [ZillaAnimations.wave],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // 4. Message card
                Positioned(
                  top: cardTop,
                  left: 24,
                  right: 24,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 80,
                        right: 20,
                        top: 16,
                        bottom: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.deepNavy,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.zillaGreen,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stepData.message,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stepData.subMessage,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            stepData.actionHint,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.zillaGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FilledButton(
                                onPressed: widget.onSkip,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.zillaGreen
                                      .withValues(alpha: 0.55),
                                  foregroundColor: AppTheme.deepNavy,
                                ),
                                child: const Text('Skip'),
                              ),
                              if (hasActionButton) ...[
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: widget.onAdvance,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.zillaGreen,
                                    foregroundColor: AppTheme.deepNavy,
                                  ),
                                  child: Text(stepData.actionLabel),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 5. Mascot — renders ON TOP of card, fully visible including head
                Positioned(
                  top: cardTop - 16,
                  left: 8,
                  child: ZillaMascot(
                    size: 80,
                    animate: true,
                    availableAnimations: [ZillaAnimations.wave],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
