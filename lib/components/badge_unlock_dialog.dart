import 'package:flutter/material.dart';
import 'package:chorezilla/models/badge.dart';

class BadgeUnlockDialog extends StatelessWidget {
  const BadgeUnlockDialog({super.key, required this.event});

  final BadgeEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final badge = event.badge;
    final tier = event.newTier;

    // Pick asset path for the current tier (or one-time badge asset).
    final assetPath = tier != null
        ? badge.assetPathForTier(tier)
        : badge.assetPath;

    // Tier chip color
    Color tierColor(BadgeTier t) {
      switch (t) {
        case BadgeTier.bronze:
          return const Color(0xFFCD7F32);
        case BadgeTier.silver:
          return const Color(0xFF9E9E9E);
        case BadgeTier.gold:
          return const Color(0xFFFFB300);
        default:
          return cs.surfaceContainerHighest;
      }
    }

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, scale, _) {
          return Transform.scale(
            scale: scale,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: cs.surface,
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      event.dialogTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),

                  // Badge image or emoji
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: assetPath != null
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Text(
                                badge.icon,
                                style: const TextStyle(fontSize: 48),
                              ),
                            ),
                          )
                        : Text(
                            badge.icon,
                            style: const TextStyle(fontSize: 48),
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Tier chip for tiered badges
                  if (tier != null && tier != BadgeTier.locked) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: tierColor(tier),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        BadgeCatalog.tierName(tier),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // What they did to earn it
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'What you did:',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          badge.earnedHint(tier),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (event.coinBonus > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            '+${event.coinBonus} coins!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFFB300),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Text(
                    'Keep it up! More achievements unlock as you build habits.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Awesome!'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
