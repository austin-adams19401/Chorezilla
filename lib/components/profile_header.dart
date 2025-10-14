import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/common.dart';

/// ProfileHeader
///  - Reads AppState by default (current member + family)
///  - Or pass a [member] explicitly to render a specific person
///  - Optional actions: invite (parents only) and switch-member callback
///
/// Usage:
///   // simplest, uses AppState.currentMember
///   const ProfileHeader();
///
///   // or explicit
///   ProfileHeader(member: someMember, onSwitchMember: () { ... });
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    this.member,
    this.showInviteButton = true,
    this.showSwitchButton = false,
    this.onSwitchMember,
  });

  final Member? member;
  final bool showInviteButton;
  final bool showSwitchButton;
  final VoidCallback? onSwitchMember;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final Family? family = app.family;

    // Prefer explicit member, otherwise AppState's current or first
    Member? m = member ?? app.currentMember;
    m ??= app.members.isNotEmpty ? app.members.first : null;

    if (m == null) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            _AvatarCircle(member: m),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Role
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(role: m.role),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Family name (if available)
                  if (family != null)
                    Text(
                      family.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  const SizedBox(height: 8),
                  // Stats row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                        icon: Icons.military_tech_rounded,
                        label: 'Level',
                        value: '${m.level}',
                        background: cs.secondaryContainer,
                        foreground: cs.onSecondaryContainer,
                      ),
                      _StatChip(
                        icon: Icons.bolt_rounded,
                        label: 'XP',
                        value: '${m.xp}',
                        background: cs.tertiaryContainer,
                        foreground: cs.onTertiaryContainer,
                      ),
                      _StatChip(
                        icon: Icons.monetization_on_rounded,
                        label: 'Coins',
                        value: '${m.coins}',
                        background: cs.primaryContainer,
                        foreground: cs.onPrimaryContainer,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (showSwitchButton)
              IconButton(
                tooltip: 'Switch member',
                onPressed: onSwitchMember,
                icon: const Icon(Icons.switch_account_rounded),
              ),

            if (showInviteButton && m.role == FamilyRole.parent)
              IconButton(
                tooltip: 'Invite',
                onPressed: () => _handleInvite(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInvite(BuildContext context) async {
    final app = context.read<AppState>();
    try {
      final code = await app.ensureJoinCode();
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => _InviteDialog(code: code),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create invite: $e')),
      );
    }
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final avatar = (member.avatarKey ?? '').trim();

    // If you later store full image URLs in avatarKey, you can branch here and use NetworkImage
    final String display = avatar.isNotEmpty ? avatar : _initials(member.displayName);

    return CircleAvatar(
      radius: 28,
      backgroundColor: member.role == FamilyRole.child ? cs.tertiaryContainer : cs.secondaryContainer,
      child: Text(
        display,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final a = parts.first.characters.first.toUpperCase();
    final b = parts.last.characters.first.toUpperCase();
    return '$a$b';
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final FamilyRole role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = role == FamilyRole.parent ? cs.secondaryContainer : cs.tertiaryContainer;
    final fg = role == FamilyRole.parent ? cs.onSecondaryContainer : cs.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role == FamilyRole.parent ? 'Parent' : 'Child',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: TextStyle(fontSize: 12, color: foreground, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _InviteDialog extends StatelessWidget {
  const _InviteDialog({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Family Invite Code'),
      content: SelectableText(
        code,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: cs.primary,
          letterSpacing: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (!context.mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Code copied to clipboard')),
            );
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}


// import 'package:chorezilla/state/app_state.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../z_archive/app_state_old.dart';
// import '../models/family_models.dart';

// class ProfileHeader extends StatelessWidget {
//   const ProfileHeader({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final app = context.watch<AppState>();
//     final cs = Theme.of(context).colorScheme;

//     if (app.members.isEmpty) {
//       return const SizedBox.shrink();
//     }

//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//       child: Row(
//         children: app.members.map((m) {
//           final selected = app.currentProfileId == m.id;
//           final isKid = m.role == MemberRole.child;

//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 4),
//             child: InkWell(
//               borderRadius: BorderRadius.circular(28),
//               onTap: () => app.setCurrentProfile(m.id),
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
//                   borderRadius: BorderRadius.circular(28),
//                   border: Border.all(
//                     color: selected ? cs.primary : Colors.transparent,
//                     width: selected ? 2 : 1,
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     CircleAvatar(
//                       radius: 16,
//                       backgroundColor: isKid ? cs.tertiaryContainer : cs.secondaryContainer,
//                       child: Text(m.avatar, style: const TextStyle(fontSize: 18)),
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       m.name,
//                       style: TextStyle(
//                         color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
//                         fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
//                       ),
//                     ),
//                     if (!m.usesThisDevice) ...[
//                       const SizedBox(width: 6),
//                       Icon(Icons.phone_iphone, size: 16, color: cs.outlineVariant),
//                     ]
//                   ],
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }
