import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// On-screen digit pad so iOS never covers the action button with the
/// system number keyboard.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxLength = 4,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int maxLength;

  void _push(String digit) {
    if (value.length >= maxLength) return;
    HapticFeedback.selectionClick();
    onChanged(value + digit);
  }

  void _backspace() {
    if (value.isEmpty) return;
    HapticFeedback.selectionClick();
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keys = <String?>[
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      null, '0', 'del',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
        final keyHeight = width < 360 ? 48.0 : 56.0;
        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: (width / 3) / keyHeight,
          children: [
            for (final key in keys)
              if (key == null)
                const SizedBox.shrink()
              else if (key == 'del')
                _PadKey(
                  onPressed: _backspace,
                  child: Icon(Icons.backspace_outlined, color: cs.onSurface),
                )
              else
                _PadKey(
                  onPressed: () => _push(key),
                  child: Text(
                    key,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.value,
    required this.length,
    this.selected = false,
    this.obscure = true,
    this.onTap,
  });

  final String value;
  final int length;
  final bool selected;
  final bool obscure;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer.withValues(alpha: 0.45) : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < length; i++)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < value.length ? cs.primary : Colors.transparent,
                    border: Border.all(
                      color: i < value.length ? cs.primary : cs.outline,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: !obscure && i < value.length
                      ? Text(
                          value[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Center(child: child),
      ),
    );
  }
}
