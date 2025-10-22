// lib/components/mascot_header.dart
import 'package:flutter/material.dart';

class MascotHeader extends StatelessWidget {
  const MascotHeader({super.key, this.title = 'Chorezilla', required this.subtitle});
  final String title;
  final String subtitle;

  static const String _transparantMascot = 'assets/icons/mascot/mascot_no_bg.png';
  static const String _squareMascot = 'assets/icons/mascot/mascot_1024.png';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 48, 24, 48),
      decoration: BoxDecoration(
        color: cs.secondary,
        
        borderRadius: BorderRadius.circular(24)
      ),
      child: Row(
        children: [
          // Mascot inside a soft circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: cs.secondary,
              shape: BoxShape.circle,
            ),
            child: _MascotImage(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                ),
                ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onPrimary.withValues(alpha: .90),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotImage extends StatelessWidget {
  const _MascotImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary),
      child: Image.asset(
        MascotHeader._transparantMascot,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) {
          return Image.asset(
            MascotHeader._squareMascot,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Icon(Icons.task_alt, size: 40, color: Theme.of(context).colorScheme.secondary),
          );
        },
      ),
    );
  }
}
