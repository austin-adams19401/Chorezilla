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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      decoration: BoxDecoration(
        color: cs.secondary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 125,
            height: 125,
            decoration: BoxDecoration(
              color: cs.secondary,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: _MascotImage(),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
        ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  height: 1.5,
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
