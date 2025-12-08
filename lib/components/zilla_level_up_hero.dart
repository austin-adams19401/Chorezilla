import 'dart:math' as math;

import 'package:flutter/material.dart';

class ZillaLevelUpHero extends StatelessWidget {
  final double size;

  const ZillaLevelUpHero({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        // Pop + straighten
        final scale = 0.7 + 0.4 * value; // 0.6 → 1.0
        final tilt = (1 - value) * 0.18;

        // Sparkle radius and opacity (slower fade so you SEE them)
        final double sparkleRadius = (size / 2 + 40) * value;
        final double sparkleOpacity = (1.0 - value * 0.5).clamp(0.0, 1.0);

        // 8 big stars around Zilla
        final sparkles = List<Widget>.generate(8, (i) {
          final angle = (i * 2 * math.pi) / 8;
          final dx = sparkleRadius * math.cos(angle);
          final dy = sparkleRadius * math.sin(angle);

          final color = (i % 3 == 0)
              ? cs.primary
              : (i % 3 == 1)
              ? cs.secondary
              : cs.tertiary;

          return Opacity(
            opacity: sparkleOpacity,
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Icon(Icons.star, size: 18, color: color),
            ),
          );
        });

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: tilt,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow
                Container(
                  width: size + 40,
                  height: size + 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.secondary,
                  ),
                ),
                // Ring
                Container(
                  width: size + 40,
                  height: size + 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withValues(alpha: .9),
                      width: 5,
                    ),
                  ),
                ),
                // Big obvious sparkles
                ...sparkles,
                // Zilla icon
                SizedBox(
                  width: size,
                  height: size,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(
                      'assets/icons/mascot/mascot_no_bg.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
