import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';

/// Horizontally scrollable strip of *all kids*:
///   NAME
///   [  BIG ICON  ]
/// No stats, just clean and compact.
class FamilyHeaderCompact extends StatelessWidget {
  const FamilyHeaderCompact({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final kids = app.members.where((m) => m.role == FamilyRole.child && m.active).toList();

    if (kids.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kids.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final m = kids[i];
          final icon = (m.avatarKey ?? '').trim();
          final display = icon.isEmpty ? _initials(m.displayName) : icon;
          return Container(
            width: 96,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  m.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 56, height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(display, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first.toUpperCase()}${parts.last.characters.first.toUpperCase()}';
  }
}
