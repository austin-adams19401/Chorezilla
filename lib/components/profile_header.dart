import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/pages/kid_pages/kid_rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/history.dart';

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

    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final cs = theme.colorScheme;

    final isChild = m.role == FamilyRole.child;
    final allowanceConfig = isChild ? app.allowanceForMember(m.id) : null;
    final hasAllowance =
        isChild && allowanceConfig != null && allowanceConfig.enabled;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        m.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: ts.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                _AvatarCircle(member: m),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                    
                              // Level + XP progress
                              _LevelProgressBar(member: m),
                    
                              const SizedBox(height: 6),
                    
                              // Coins + Spend button (slight style refresh)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.secondaryContainer,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '🪙',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${m.coins}',
                                            style: ts.labelLarge?.copyWith(
                                              color: cs.onPrimaryContainer,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'coins',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 3,
                                        ),
                                        foregroundColor: Colors.black,
                                        backgroundColor: cs.secondaryContainer
                                      ),
                                      icon: const Text(
                                        '🎁',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                      label: const Text(
                                        'Spend',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => KidRewardsPage(memberId: m.id),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                    
                              // NEW: Allowance summary for kids
                              if (hasAllowance) ...[
                                const SizedBox(height: 6),
                                _AllowanceHeaderSummary(memberId: m.id),
                              ],
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
                  ],
                ),
              ],
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
// Allowance summary (header)
// ─────────────────────────────────────────────────────────────────────────────

class _AllowanceHeaderSummary extends StatelessWidget {
  const _AllowanceHeaderSummary({required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final ts = theme.textTheme;
    final cs = theme.colorScheme;

    final config = app.allowanceForMember(memberId);
    if (!config.enabled || config.fullAmountCents <= 0) {
      return const SizedBox.shrink();
    }

    // Current week (Mon-based)
    final weekStart = weekStartFor(DateTime.now());
    final histories = app.buildWeeklyHistory(weekStart);

    WeeklyKidHistory? wk;
    for (final h in histories) {
      if (h.member.id == memberId) {
        wk = h;
        break;
      }
    }

    final full = config.fullAmountCents / 100.0;
    double earned = 0.0;
    double ratio = 0.0;
    int effectiveDays = 0;
    final requiredDays = config.daysRequiredForFull;

    if (wk?.allowanceResult != null) {
      final r = wk!.allowanceResult!;
      earned = (r.payoutCents / 100.0);
      ratio = r.ratio.clamp(0.0, 1.0);
      effectiveDays = r.effectiveDays;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: ratio,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(cs.secondary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Allowance this week: '
          '\$${earned.toStringAsFixed(2)} of \$${full.toStringAsFixed(2)}',
          style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Text(
          'Days counted: $effectiveDays/$requiredDays',
          style: ts.bodySmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: .9),
          ),
        ),
      ],
    );
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

    const double radius = 36;
    final double emojiSize = radius * 0.95;

    return CircleAvatar(
      radius: radius,
      backgroundColor: member.role == FamilyRole.child
          ? cs.primaryContainer
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
