import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/family_models.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (app.members.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: app.members.map((m) {
          final selected = app.currentProfileId == m.id;
          final isKid = m.role == MemberRole.child;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => app.setCurrentProfile(m.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: selected ? cs.primary : Colors.transparent,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isKid ? cs.tertiaryContainer : cs.secondaryContainer,
                      child: Text(m.avatar, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      m.name,
                      style: TextStyle(
                        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (!m.usesThisDevice) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.phone_iphone, size: 16, color: cs.outlineVariant),
                    ]
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
