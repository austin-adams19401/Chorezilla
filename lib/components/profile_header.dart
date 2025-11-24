import 'package:chorezilla/components/leveling.dart';
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
                        Text(
                          '🪙 Coins ${m.coins}',
                          style: ts.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            side: BorderSide(color: Colors.green, width: 1),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showSpendCoinsDialog(context, m),
                          child: const Text('Spend'),
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

  Future<void> _showSpendCoinsDialog(BuildContext context, Member m) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final amount = await showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SpendCoinsDialog(member: m),
    );

    if (amount == null) return;

    await app.updateMember(m.id, {'coins': m.coins - amount});

    messenger.showSnackBar(SnackBar(content: Text('Spent $amount coins')));
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

class _SpendCoinsDialog extends StatefulWidget {
  const _SpendCoinsDialog({required this.member});

  final Member member;

  @override
  State<_SpendCoinsDialog> createState() => _SpendCoinsDialogState();
}

class _SpendCoinsDialogState extends State<_SpendCoinsDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final AnimationController _shakeController;
  late final Animation<Offset> _shakeAnimation;

  String? _error;
  bool _highlightError = false; // 👈 controls the red flash

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = TweenSequence<Offset>(
      [
        TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(0.03, 0)),
          weight: 1,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: const Offset(0.03, 0),
            end: const Offset(-0.03, 0),
          ),
          weight: 2,
        ),
        TweenSequenceItem(
          tween: Tween(begin: const Offset(-0.03, 0), end: Offset.zero),
          weight: 1,
        ),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerError(String message) {
    setState(() {
      _error = message;
      _highlightError = true;
    });

    _shakeController
      ..reset()
      ..forward();

    // After a short delay, fade the background back to normal
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _highlightError = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasError = _error != null;
    final baseColor = cs.surface;
    final errorColor = cs.errorContainer;

    return SlideTransition(
      position: _shakeAnimation,
      child: TweenAnimationBuilder<Color?>(
        // Animate between normal and error colors
        tween: ColorTween(
          begin: baseColor,
          end: _highlightError ? errorColor : baseColor,
        ),
        duration: const Duration(milliseconds: 250),
        builder: (ctx, color, child) {
          return AlertDialog(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Spend coins'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have ${m.coins} coins.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasError ? cs.onErrorContainer : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Coins to spend',
                    prefixIcon: const Icon(Icons.monetization_on_rounded),
                    errorText: _error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: hasError ? cs.onErrorContainer : cs.primary,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: hasError ? cs.error : cs.primary,
                ),
                onPressed: () {
                  final raw = _controller.text.trim();
                  final value = int.tryParse(raw);

                  if (value == null || value <= 0) {
                    _triggerError('Enter a positive number');
                    return;
                  }
                  if (value > m.coins) {
                    _triggerError('Not enough coins');
                    return;
                  }

                  Navigator.of(context).pop(value);
                },
                child: const Text('Spend'),
              ),
            ],
          );
        },
      ),
    );
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
