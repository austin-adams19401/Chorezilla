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
            child: Text(helperText!, style: Theme.of(context).textTheme.bodySmall),
          ),

        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.onDrag,
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
            activeTickMarkColor: Theme.of(context).colorScheme.primary,
            inactiveTickMarkColor: Theme.of(context).colorScheme.primary,
            valueIndicatorTextStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          child: Slider.adaptive(
            min: 1,
            max: 5,
            divisions: 4, // 1,2,3,4,5
            label: _labels[value],
            value: value.toDouble(),
            onChanged: (d) => onChanged(d.round().clamp(1, 5)),
          ),
        ),
        ],
    );
  }
}
