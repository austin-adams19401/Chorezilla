import 'package:flutter/material.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/common.dart';

/// Displays a chore template with icon, title, points and a peek of assignees.
/// This version aligns with the new data models:
/// - Chore has `icon` (String?), `points`, `difficulty`
/// - Member has `role: FamilyRole`, `avatarKey` (String?), `displayName`
///
/// Usage:
///   ChoreCard(chore: chore, assignees: selectedMembers)
class ChoreCard extends StatelessWidget {
  const ChoreCard({
    super.key,
    required this.chore,
    required this.assignees,
  });

  final Chore chore;
  final List<Member> assignees;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _IconPill(icon: chore.icon),
            const SizedBox(width: 12),
            Expanded(
              child: _TitleSubtitle(
                title: chore.title,
                subtitle: chore.description,
                assignees: assignees,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon});
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final display = (icon == null || icon!.trim().isEmpty) ? "🧹" : icon!.trim();

    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        display,
        style: TextStyle(fontSize: 20, color: cs.onPrimaryContainer),
      ),
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  const _TitleSubtitle({
    required this.title,
    this.subtitle,
    required this.assignees,
  });

  final String title;
  final String? subtitle;
  final List<Member> assignees;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (subtitle != null && subtitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 8),
        _AssigneesRow(assignees: assignees),
      ],
    );
  }
}

/// Renders up to 4 assignee avatars plus a "+N" overflow.
class _AssigneesRow extends StatelessWidget {
  const _AssigneesRow({required this.assignees});
  final List<Member> assignees;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = assignees.take(4).toList();
    return Row(
      children: [
        for (final m in visible)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: m.role == FamilyRole.child
                  ? cs.tertiaryContainer
                  : cs.secondaryContainer,
              child: _AvatarContent(member: m),
            ),
          ),
        if (assignees.length > 4)
          Text(
            '+${assignees.length - 4}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final fg = Theme.of(context).colorScheme.onSecondaryContainer;

    final avatar = (member.avatarKey ?? '').trim();
    if (avatar.isNotEmpty) {
      // Assume avatarKey can be an emoji glyph or short string
      return Text(avatar, style: const TextStyle(fontSize: 16));
    }

    // Fallback: initials
    final name = member.displayName.trim();
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Text(
      initial,
      style: ts.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: fg),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        '$points pts',
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}



// import 'package:chorezilla/models/chore.dart';
// import 'package:chorezilla/models/common.dart';
// import 'package:chorezilla/models/member.dart';
// import 'package:flutter/material.dart';

// class ChoreCard extends StatelessWidget {
//   const ChoreCard({
//     super.key,
//     required this.chore,
//     required this.assignees,
//   });

//   final Chore chore;
//   final List<Member> assignees;

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return Card(
//       elevation: 0,
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: cs.surfaceContainerHighest),
//       ),
//       child: ListTile(
//         leading: chore.icon != null
//             ? CircleAvatar(
//                 backgroundColor: cs.secondaryContainer,
//                 child: Icon(
//                   chore.icon,
//                   color: chore.iconColor ?? cs.onSecondaryContainer,
//                 ),
//               )
//             : null,
//         title: Text(
//           chore.title,
//           style: const TextStyle(fontWeight: FontWeight.w600),
//           overflow: TextOverflow.ellipsis,
//         ),
//         subtitle: Text('${chore.points} pts • ${scheduleLabel(chore)}'),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ...assignees.take(4).map((m) => Padding(
//                   padding: const EdgeInsets.only(left: 4),
//                   child: CircleAvatar(
//                     radius: 14,
//                     backgroundColor: m.role == FamilyRole.child
//                         ? cs.tertiaryContainer
//                         : cs.secondaryContainer,
//                     child: Text(m.avatar, style: const TextStyle(fontSize: 16)),
//                   ),
//                 )),
//             if (assignees.length > 4)
//               Padding(
//                 padding: const EdgeInsets.only(left: 6),
//                 child: Text(
//                   '+${assignees.length - 4}',
//                   style: TextStyle(color: cs.onSurfaceVariant),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
