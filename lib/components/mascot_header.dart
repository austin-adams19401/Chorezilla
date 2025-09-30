// lib/components/mascot_header.dart
import 'package:flutter/material.dart';

class MascotHeader extends StatelessWidget {
  const MascotHeader({super.key, this.title = 'Chorezilla'});
  final String title;

  static const String _paddedMascot = 'assets/icons/mascot/mascot_no_bg_padded.png';
  static const String _squareMascot = 'assets/icons/mascot/mascot_1024.png';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 48, 24, 24),
      decoration: BoxDecoration(
        // gradient: LinearGradient(
        //   colors: [cs.secondary, cs.secondaryContainer],
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        // ),
        
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // Mascot inside a soft circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: _MascotImage(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: cs.inversePrimary,
                    fontWeight: FontWeight.w700,
                  ),
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
    // Try transparent mascot first, then square, then icon
    return Image.asset(
      MascotHeader._paddedMascot,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) {
        return Image.asset(
          MascotHeader._squareMascot,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Icon(Icons.task_alt, size: 40, color: Theme.of(context).colorScheme.inversePrimary),
        );
      },
    );
  }
}
