import 'dart:ui' as ui;

import 'package:chorezilla/services/sprite_cache_service.dart';
import 'package:flutter/material.dart';

/// A widget that plays a two-layer sprite sheet animation frame-by-frame.
///
/// The body layer is tinted with [tintColor] (via BlendMode.srcIn) and the
/// details layer is drawn on top untouched. Both sprite sheets are assumed to
/// be a uniform grid of [columns] x [rows] frames, read left-to-right,
/// top-to-bottom.
class SpriteSheetAnimation extends StatefulWidget {
  const SpriteSheetAnimation({
    super.key,
    required this.bodyAssetPath,
    required this.detailsAssetPath,
    required this.size,
    this.tintColor,
    this.columns = 6,
    this.rows = 6,
    this.totalDuration = const Duration(milliseconds: 1200),
    this.loop = true,
    this.onComplete,
  });

  final String bodyAssetPath;
  final String detailsAssetPath;
  final double size;
  final Color? tintColor;
  final int columns;
  final int rows;
  final Duration totalDuration;
  final bool loop;
  final VoidCallback? onComplete;

  @override
  State<SpriteSheetAnimation> createState() => _SpriteSheetAnimationState();
}

class _SpriteSheetAnimationState extends State<SpriteSheetAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.Image? _bodyImage;
  ui.Image? _detailsImage;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    );

    if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward();
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      });
    }

    _loadImages();
  }

  Future<void> _loadImages() async {
    final bodyFilename = widget.bodyAssetPath.split('/').last;
    final detailsFilename = widget.detailsAssetPath.split('/').last;

    final results = await Future.wait([
      SpriteSheetCacheService.getBytes(bodyFilename),
      SpriteSheetCacheService.getBytes(detailsFilename),
    ]);

    final bodyImage = await decodeImageFromList(results[0]);
    final detailsImage = await decodeImageFromList(results[1]);

    if (mounted) {
      setState(() {
        _bodyImage = bodyImage;
        _detailsImage = detailsImage;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final bodyImage = _bodyImage;
    final detailsImage = _detailsImage;

    if (bodyImage == null || detailsImage == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final totalFrames = widget.columns * widget.rows;
        final int frameIndex;
        if (disableAnimations) {
          frameIndex = totalFrames - 1;
        } else {
          frameIndex =
              (_controller.value * totalFrames).floor().clamp(0, totalFrames - 1);
        }

        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _SpritePainter(
            bodyImage: bodyImage,
            detailsImage: detailsImage,
            tintColor: widget.tintColor,
            frameIndex: frameIndex,
            columns: widget.columns,
            rows: widget.rows,
          ),
        );
      },
    );
  }
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter({
    required this.bodyImage,
    required this.detailsImage,
    required this.tintColor,
    required this.frameIndex,
    required this.columns,
    required this.rows,
  });

  final ui.Image bodyImage;
  final ui.Image detailsImage;
  final Color? tintColor;
  final int frameIndex;
  final int columns;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final col = frameIndex % columns;
    final row = frameIndex ~/ columns;

    // Body frame
    final bodyFrameWidth = bodyImage.width / columns;
    final bodyFrameHeight = bodyImage.height / rows;
    final bodySrc = Rect.fromLTWH(
      col * bodyFrameWidth,
      row * bodyFrameHeight,
      bodyFrameWidth,
      bodyFrameHeight,
    );

    // Details frame
    final detFrameWidth = detailsImage.width / columns;
    final detFrameHeight = detailsImage.height / rows;
    final detSrc = Rect.fromLTWH(
      col * detFrameWidth,
      row * detFrameHeight,
      detFrameWidth,
      detFrameHeight,
    );

    // Maintain the source frame's aspect ratio within the destination square.
    final frameAspect = bodyFrameWidth / bodyFrameHeight;
    final dstAspect = size.width / size.height;
    final Rect dst;
    if (frameAspect > dstAspect) {
      final h = size.width / frameAspect;
      dst = Rect.fromLTWH(0, (size.height - h) / 2, size.width, h);
    } else {
      final w = size.height * frameAspect;
      dst = Rect.fromLTWH((size.width - w) / 2, 0, w, size.height);
    }

    // Draw body layer with optional tint
    final bodyPaint = Paint();
    if (tintColor != null) {
      bodyPaint.colorFilter = ColorFilter.mode(tintColor!, BlendMode.srcIn);
    }
    canvas.drawImageRect(bodyImage, bodySrc, dst, bodyPaint);

    // Draw details layer on top (no tint)
    canvas.drawImageRect(detailsImage, detSrc, dst, Paint());
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.frameIndex != frameIndex ||
      old.bodyImage != bodyImage ||
      old.detailsImage != detailsImage ||
      old.tintColor != tintColor;
}
