import 'package:chorezilla/components/auth_scaffold.dart';
import 'package:chorezilla/pages/startup/kid_join_page.dart';
import 'package:flutter/material.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      headerTitle: 'Welcome to Chorezilla',
      headerSubtitle: 'Are you setting up for your family,\nor joining one?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Who are you?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            icon: Icons.family_restroom,
            title: "I'm a parent",
            subtitle: 'Create a family and add your kids',
            onTap: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            },
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.child_care,
            title: "I'm a kid",
            subtitle: 'Join my family with a code from my parent',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KidJoinPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
