import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that plays a sprite sheet animation frame-by-frame.
///
/// The sprite sheet is assumed to be a uniform grid of [columns] × [rows]
/// frames, read left-to-right, top-to-bottom.
class SpriteSheetAnimation extends StatefulWidget {
  const SpriteSheetAnimation({
    super.key,
    required this.assetPath,
    required this.size,
    this.columns = 6,
    this.rows = 6,
    this.totalDuration = const Duration(milliseconds: 1200),
    this.loop = true,
    this.onComplete,
  });

  final String assetPath;
  final double size;
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
  ui.Image? _image;

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

    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(widget.assetPath);
    final bytes = data.buffer.asUint8List();
    final image = await decodeImageFromList(bytes);
    if (mounted) {
      setState(() => _image = image);
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
    final image = _image;

    if (image == null) {
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
            image: image,
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
    required this.image,
    required this.frameIndex,
    required this.columns,
    required this.rows,
  });

  final ui.Image image;
  final int frameIndex;
  final int columns;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = image.width / columns;
    final frameHeight = image.height / rows;

    final col = frameIndex % columns;
    final row = frameIndex ~/ columns;

    final src = Rect.fromLTWH(
      col * frameWidth,
      row * frameHeight,
      frameWidth,
      frameHeight,
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.frameIndex != frameIndex || old.image != image;
}
