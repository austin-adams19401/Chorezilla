import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/pages/kid_pages/kid_rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/common.dart';

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

    // Prefer explicit member, otherwise AppState's current or first
    Member? maybe = member ?? app.currentMember;
    maybe ??= app.members.isNotEmpty ? app.members.first : null;

    if (maybe == null) {
      return const SizedBox.shrink();
    }

    final Member m = maybe;

    // final cs = Theme.of(context).colorScheme;
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
                  // Name row
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
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Level + XP progress
                  _LevelProgressBar(member: m),

                  const SizedBox(height: 4),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🪙', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Text('Coins ${m.coins}',style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600,),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Text('🎁', style: TextStyle(fontSize: 28)),
                          label: const Text('Spend', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => KidRewardsPage(
                                  memberId: m.id
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create invite: $e')));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final avatar = (member.avatarKey ?? '').trim();
    final String display = avatar.isNotEmpty
        ? avatar
        : _initials(member.displayName);

    const double radius = 28;
    final double emojiSize = radius * 0.9;

    return CircleAvatar(
      radius: radius,
      backgroundColor: member.role == FamilyRole.child
          ? cs.tertiaryContainer
          : cs.secondaryContainer,
      child: Text(
        display,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: emojiSize, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final a = parts.first.characters.first.toUpperCase();
    final b = parts.last.characters.first.toUpperCase();
    return '$a$b';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level + XP progress
// ─────────────────────────────────────────────────────────────────────────────

class _LevelProgressBar extends StatelessWidget {
  const _LevelProgressBar({required this.member});
  final Member member;

    @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Use total XP to compute level & progress
    final info = levelInfoForXp(member.xp);
    final nextReward = nextLevelRewardFromLevel(info.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Level ${info.level}',
              style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Text(
              '${info.xpIntoLevel} / ${info.xpNeededThisLevel} XP',
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: info.progress,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),

        // Show upcoming milestone
        if (nextReward != null) ...[
          const SizedBox(height: 4),
          Text(
            'Next reward: Level ${nextReward.level} – ${nextReward.title}',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invite dialog
// ─────────────────────────────────────────────────────────────────────────────

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
