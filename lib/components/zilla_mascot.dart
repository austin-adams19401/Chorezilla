// lib/components/zilla_mascot.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chorezilla/components/sprite_sheet_animation.dart';
import 'package:chorezilla/models/cosmetics.dart';
import 'package:chorezilla/models/zilla_animations.dart';

/// An animated Zilla mascot widget.
///
/// Cycles through [availableAnimations] (defaults to the free set if omitted).
/// Tapping triggers a quick pop/scale animation.
/// Pass [skinId] to tint the mascot based on the equipped Zilla skin.
class ZillaMascot extends StatefulWidget {
  const ZillaMascot({
    super.key,
    this.skinId,
    this.size = 72,
    this.onTap,
    this.animate = true,
    this.availableAnimations,
  });

  final String? skinId;
  final double size;
  final VoidCallback? onTap;
  final bool animate;

  /// The animations this kid has access to. Null = free tier defaults.
  final List<ZillaAnimationDef>? availableAnimations;

  @override
  State<ZillaMascot> createState() => _ZillaMascotState();
}

class _ZillaMascotState extends State<ZillaMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;
  final _rng = math.Random();
  int _animIndex = 0;

  List<ZillaAnimationDef> get _animations {
    final provided = widget.availableAnimations;
    if (provided != null && provided.isNotEmpty) return provided;
    return ZillaAnimations.freeAnimationIds
        .map((id) => ZillaAnimations.byId(id))
        .whereType<ZillaAnimationDef>()
        .toList();
  }

  ZillaAnimationDef get _current =>
      _animations[_animIndex % _animations.length];

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Start on a random animation so multiple mascots on screen feel varied.
    final anims = _animations;
    if (anims.length > 1) {
      _animIndex = _rng.nextInt(anims.length);
    }
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

  void _onAnimationComplete() {
    if (!mounted) return;
    setState(() {
      _animIndex = (_animIndex + 1) % _animations.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final anim = _current;
    final colorValue = CosmeticCatalog.tintColorValueForSkin(widget.skinId);
    final tintColor = colorValue != null ? Color(colorValue) : null;

    Widget sprite = SpriteSheetAnimation(
      key: ValueKey(anim.id),
      assetPath: anim.assetPath,
      size: widget.size,
      columns: anim.columns,
      rows: anim.rows,
      totalDuration: anim.duration,
      loop: false,
      onComplete: widget.animate ? _onAnimationComplete : null,
    );

    if (tintColor != null) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(
          tintColor.withValues(alpha: 0.30),
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
          final popScale =
              1.0 + math.sin(_popController.value * math.pi) * 0.25;
          return Transform.scale(scale: popScale, child: child);
        },
        child: sprite,
      ),
    );
  }
}
