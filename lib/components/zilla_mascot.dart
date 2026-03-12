// lib/components/zilla_mascot.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chorezilla/components/sprite_sheet_animation.dart';

/// An animated Zilla mascot widget that plays the walk cycle sprite sheet.
/// Tapping triggers a quick pop/scale animation.
/// Pass [skinId] to tint the mascot based on equipped Zilla skin.
class ZillaMascot extends StatefulWidget {
  const ZillaMascot({
    super.key,
    this.skinId,
    this.size = 72,
    this.onTap,
    this.animate = true,
  });

  final String? skinId;
  final double size;
  final VoidCallback? onTap;
  final bool animate;

  @override
  State<ZillaMascot> createState() => _ZillaMascotState();
}

class _ZillaMascotState extends State<ZillaMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;

  // Map skin IDs to tint colors. Default (null / classic) = no tint.
  static const _skinTints = <String, Color>{
    'zilla_blue_hoodie': Color(0xFF1565C0),
    'zilla_red_cape': Color(0xFFB71C1C),
    'zilla_pirate': Color(0xFF4A148C),
    'zilla_wizard': Color(0xFF1A237E),
  };

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _popController.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tintColor = _skinTints[widget.skinId];

    Widget sprite = SpriteSheetAnimation(
      assetPath: 'assets/icons/mascot/sprite-sheets/walking.png',
      size: widget.size,
      columns: 6,
      rows: 6,
      totalDuration: const Duration(milliseconds: 1200),
      loop: widget.animate,
    );

    if (tintColor != null) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(
          tintColor.withOpacity(0.30),
          BlendMode.srcATop,
        ),
        child: sprite,
      );
    }

    return GestureDetector(
      onTap: widget.onTap != null ? _handleTap : null,
      child: AnimatedBuilder(
        animation: _popController,
        builder: (context, child) {
          final popScale = 1.0 + math.sin(_popController.value * math.pi) * 0.25;
          return Transform.scale(scale: popScale, child: child);
        },
        child: sprite,
      ),
    );
  }
}
