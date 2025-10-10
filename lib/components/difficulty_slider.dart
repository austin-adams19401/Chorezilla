// Reusable difficulty slider (1–5, discrete)
import 'package:flutter/material.dart';

class DifficultySlider extends StatelessWidget {
  const DifficultySlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Difficulty',
    this.helperText,
  });

  final int value; // 1..5
  final ValueChanged<int> onChanged;
  final String title;
  final String? helperText;

  static const _labels = {
    1: 'Very Easy',
    2: 'Easy',
    3: 'Medium',
    4: 'Hard',
    5: 'Very Hard',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row with live value chip
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Chip(
              label: Text(_labels[value]!, style: const TextStyle(fontWeight: FontWeight.w600)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(helperText!, style: Theme.of(context).textTheme.bodyMedium),
          ),

        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.onDrag,
            tickMarkShape: const VerticalLineTickMarkShape(height: 12, strokeWidth: 2),
            activeTickMarkColor: Theme.of(context).colorScheme.primary,
            inactiveTickMarkColor: Theme.of(context).colorScheme.primary,
            valueIndicatorTextStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          child: Slider.adaptive(
            min: 1,
            max: 5,
            divisions: 4, // required for tick marks to show
            label: _labels[value],
            value: value.toDouble(),
            onChanged: (d) => onChanged(d.round().clamp(1, 5)),
          ),
        ),
        ],
    );
  }
}

/// Vertical line tick marks for [Slider].
class VerticalLineTickMarkShape extends SliderTickMarkShape {
  const VerticalLineTickMarkShape({
    this.height = 15.0,
    this.strokeWidth = 4.0,
  });

  /// Total height of the vertical line.
  final double height;

  /// Line thickness.
  final double strokeWidth;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
  }) {
    return Size(strokeWidth, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    bool isEnabled = false,
    bool isDiscrete = false,
    Offset? thumbCenter,
  }) {
    final Canvas canvas = context.canvas;

    // Choose the right color (Flutter provides active/inactive colors via the theme)
    final ColorTween colorTween = ColorTween(
      begin: sliderTheme.inactiveTickMarkColor ?? sliderTheme.disabledInactiveTickMarkColor,
      end: sliderTheme.activeTickMarkColor ?? sliderTheme.disabledActiveTickMarkColor,
    );

    final paint = Paint()
      ..color = (colorTween.evaluate(enableAnimation) ??
          sliderTheme.activeTickMarkColor ??
          Colors.black)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double half = height / 2.0;

    // Draw a vertical line centered on the track.
    canvas.drawLine(
      Offset(center.dx, center.dy - half),
      Offset(center.dx, center.dy + half),
      paint,
    );
  }
}
