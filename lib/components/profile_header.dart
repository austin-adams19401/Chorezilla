import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/models/cosmetics.dart';
import 'package:chorezilla/pages/kid_pages/kid_edit_profile_page.dart';
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

    Member? maybe = member ?? app.currentMember;
    maybe ??= app.members.isNotEmpty ? app.members.first : null;

    if (maybe == null) {
      return const SizedBox.shrink();
    }

    final Member m = maybe;

    final isChild = m.role == FamilyRole.child;
    final allowanceConfig = isChild ? app.allowanceForMember(m.id) : null;
    final hasAllowance =
        isChild && allowanceConfig != null && allowanceConfig.enabled;

    // Kids get the redesigned two-zone hero header.
    if (isChild) {
      return Material(
        color: Colors.transparent,
        child: _KidHeroHeader(
          member: m,
          showSwitchButton: showSwitchButton,
          onSwitchMember: onSwitchMember,
          hasAllowance: hasAllowance,
        ),
      );
    }

    // ── Parent / non-kid layout (unchanged) ───────────────────────────────────
    final theme = Theme.of(context);
    final ts = theme.textTheme;

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          _LevelProgressBar(member: m),
                        ],
                      ),
                    ),
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
// Kid hero header — two-zone layout
// ─────────────────────────────────────────────────────────────────────────────

class _KidHeroHeader extends StatelessWidget {
  const _KidHeroHeader({
    required this.member,
    required this.showSwitchButton,
    this.onSwitchMember,
    required this.hasAllowance,
  });

  final Member member;
  final bool showSwitchButton;
  final VoidCallback? onSwitchMember;
  final bool hasAllowance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    // Resolve equipped title name, if any.
    final titleId = member.equippedTitleId;
    final showTitle = titleId != null && titleId != 'title_none';
    String? titleName;
    if (showTitle) {
      try {
        titleName = CosmeticCatalog.byId(titleId).name;
      } catch (_) {
        titleName = null;
      }
    }

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left: dark mascot panel (2/3 width) ──────────────────────────
          Flexible(
            flex: 2,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: _buildMascotPanel(member),
            ),
          ),

          // ── Right: stats panel (1/3 width) ───────────────────────────────
          Flexible(
            flex: 1,
            child: Stack(
              children: [
                // Stats column
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Avatar + Name (leave room for edit icon on the right)
                      Row(
                        children: [
                          _AvatarCircle(member: member, radius: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              member.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Space so text doesn't run under the edit icon
                          const SizedBox(width: 20),
                        ],
                      ),

                      // Title chip (only if equipped)
                      if (titleName != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            titleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),
                      // Level / XP bar (compact — no "next level" line)
                      _LevelProgressBar(member: member, compact: true),

                      const SizedBox(height: 5),
                      // Coins count
                      Row(
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${member.coins} coins',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),
                      // Spend button — full width
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  KidRewardsPage(memberId: member.id),
                            ),
                          ),
                          child: const Text('🎁 Spend'),
                        ),
                      ),

                      if (hasAllowance) ...[
                        const SizedBox(height: 5),
                        _AllowanceHeaderSummary(memberId: member.id),
                      ],
                    ],
                  ),
                ),

                // Edit profile icon — top-right corner
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Edit profile',
                    iconSize: 16,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            KidEditProfilePage(memberId: member.id),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ],
            ),
          ),

          // Switch button
          if (showSwitchButton)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Align(
                alignment: Alignment.topCenter,
                child: IconButton(
                  tooltip: 'Switch member',
                  onPressed: onSwitchMember,
                  icon: const Icon(Icons.switch_account_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMascotPanel(Member m) {
    // Resolve background asset: use equipped bg, fall back to bg_kitchen.
    String bgAsset = 'assets/backgrounds/bg_kitchen.png';
    final bgId = m.equippedBackgroundId;
    if (bgId != null) {
      try {
        final item = CosmeticCatalog.byId(bgId);
        if (item.assetKey.isNotEmpty) bgAsset = item.assetKey;
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(bgAsset),
          fit: BoxFit.cover,
        ),
      ),
      child: _CyclingMascot(skinId: m.equippedZillaSkinId),
    );
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
          'Allowance: '
          '\$${earned.toStringAsFixed(2)} of \$${full.toStringAsFixed(2)}',
          style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Text(
          'Days: $effectiveDays/$requiredDays',
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
  const _AvatarCircle({required this.member, this.radius = 36});
  final Member member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final avatar = (member.avatarKey ?? '').trim();
    final String display = avatar.isNotEmpty
        ? avatar
        : _initials(member.displayName);

    final double emojiSize = radius * 0.95;

    final frameId = member.equippedAvatarFrameId;

    final circle = CircleAvatar(
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

    if (frameId == null || frameId == 'frame_default') return circle;

    return Stack(
      alignment: Alignment.center,
      children: [
        circle,
        _FrameOverlay(frameId: frameId, radius: radius),
      ],
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
// Frame overlay (pure Flutter — no images needed)
// ─────────────────────────────────────────────────────────────────────────────

class _FrameOverlay extends StatelessWidget {
  const _FrameOverlay({required this.frameId, required this.radius});
  final String frameId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    switch (frameId) {
      case 'frame_stars':
        return _StarFrame(radius: radius, color: Colors.amber);
      case 'frame_rainbow':
        return _GradientBorderFrame(
          radius: radius,
          colors: const [
            Colors.red, Colors.orange, Colors.yellow,
            Colors.green, Colors.blue, Colors.purple,
          ],
        );
      case 'frame_gold':
        return _DoubleBorderFrame(
          radius: radius,
          outerColor: const Color(0xFFFFD700),
          innerColor: const Color(0xFFFFA000),
        );
      case 'frame_fire':
        return _StarFrame(
          radius: radius,
          color: Colors.deepOrange,
          icon: Icons.local_fire_department,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StarFrame extends StatelessWidget {
  const _StarFrame({
    required this.radius,
    required this.color,
    this.icon = Icons.star,
  });
  final double radius;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const int count = 8;
    final double outerRadius = radius + 10;
    return SizedBox(
      width: outerRadius * 2,
      height: outerRadius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outerRadius * 2,
            height: outerRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
            ),
          ),
          ...List.generate(count, (i) {
            final angle = (i * 2 * math.pi) / count - math.pi / 2;
            final dx = outerRadius * 0.85 * math.cos(angle);
            final dy = outerRadius * 0.85 * math.sin(angle);
            return Transform.translate(
              offset: Offset(dx, dy),
              child: Icon(icon, size: 10, color: color),
            );
          }),
        ],
      ),
    );
  }
}

class _GradientBorderFrame extends StatelessWidget {
  const _GradientBorderFrame({required this.radius, required this.colors});
  final double radius;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final double size = (radius + 10) * 2;
    return CustomPaint(
      size: Size(size, size),
      painter: _GradientRingPainter(colors: colors, strokeWidth: 3),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter({required this.colors, required this.strokeWidth});
  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 - strokeWidth / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => false;
}

class _DoubleBorderFrame extends StatelessWidget {
  const _DoubleBorderFrame({
    required this.radius,
    required this.outerColor,
    required this.innerColor,
  });
  final double radius;
  final Color outerColor;
  final Color innerColor;

  @override
  Widget build(BuildContext context) {
    final double outer = (radius + 11) * 2;
    final double inner = (radius + 7) * 2;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: outerColor, width: 2.5),
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: innerColor, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level + XP progress
// ─────────────────────────────────────────────────────────────────────────────

class _LevelProgressBar extends StatelessWidget {
  const _LevelProgressBar({required this.member, this.compact = false});
  final Member member;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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
            Flexible(
              child: Text(
                '${info.xpIntoLevel} / ${info.xpNeededThisLevel} XP',
                style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
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
        if (nextReward != null && !compact) ...[
          const SizedBox(height: 4),
          Text(
            'Next: Lvl ${nextReward.level} – ${nextReward.title}',
            style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
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

// ─────────────────────────────────────────────────────────────────────────────
// Cycling mascot — idle → walk (with horizontal movement) → sitting loop
// ─────────────────────────────────────────────────────────────────────────────

enum _MascotPhase {
  idle, walking, sweeping, looking, wiping, sitting,
  poked, sleeping, oneFoot, wave, fallDown,
}

class _CyclingMascot extends StatefulWidget {
  const _CyclingMascot({this.skinId});
  final String? skinId;

  @override
  State<_CyclingMascot> createState() => _CyclingMascotState();
}

class _CyclingMascotState extends State<_CyclingMascot>
    with TickerProviderStateMixin {
  // Loaded images keyed by phase
  final _images = <_MascotPhase, ui.Image>{};

  _MascotPhase _phase = _MascotPhase.idle;
  bool _facingRight = true;

  // Bag of stationary phases — shuffled and consumed, refilled when empty.
  final _bag = <_MascotPhase>[];

  static const _stationaryPhases = [
    _MascotPhase.idle,
    _MascotPhase.sweeping,
    _MascotPhase.looking,
    _MascotPhase.wiping,
    _MascotPhase.sitting,
    _MascotPhase.sleeping,
    _MascotPhase.oneFoot,
    _MascotPhase.wave,
    _MascotPhase.fallDown,
  ];

  // Sprite loop duration for each phase
  static const _spriteDuration = <_MascotPhase, Duration>{
    _MascotPhase.idle:     Duration(milliseconds: 2800),
    _MascotPhase.sweeping: Duration(milliseconds: 1800),
    _MascotPhase.looking:  Duration(milliseconds: 2000),
    _MascotPhase.wiping:   Duration(milliseconds: 1800),
    _MascotPhase.sitting:  Duration(milliseconds: 2000),
    _MascotPhase.poked:    Duration(milliseconds: 1600),
    _MascotPhase.sleeping: Duration(milliseconds: 3200),
    _MascotPhase.oneFoot:  Duration(milliseconds: 2000),
    _MascotPhase.wave:     Duration(milliseconds: 1800),
    _MascotPhase.fallDown: Duration(milliseconds: 2000),
    _MascotPhase.walking:  Duration(milliseconds: 2000),
  };

  // How long to hold each stationary phase (seconds)
  static const _holdDuration = <_MascotPhase, int>{
    _MascotPhase.idle:     4,
    _MascotPhase.sweeping: 4,
    _MascotPhase.looking:  3,
    _MascotPhase.wiping:   4,
    _MascotPhase.sitting:  3,
    _MascotPhase.poked:    2,
    _MascotPhase.sleeping: 5,
    _MascotPhase.oneFoot:  3,
    _MascotPhase.wave:     3,
    _MascotPhase.fallDown: 3,
  };

  // Drives sprite frame index (0.0 → 1.0, looping)
  late final AnimationController _spriteCtrl;

  // Drives horizontal position (0.0 = left, 1.0 = right)
  late final AnimationController _posCtrl;

  Timer? _phaseTimer;

  static const _skinTints = <String, Color>{
    'zilla_blue_hoodie': Color(0xFF1565C0),
    'zilla_red_cape': Color(0xFFB71C1C),
    'zilla_pirate': Color(0xFF4A148C),
    'zilla_wizard': Color(0xFF1A237E),
  };

  static const _assetPaths = <_MascotPhase, String>{
    _MascotPhase.idle:     'assets/icons/mascot/sprite-sheets/idle.png',
    _MascotPhase.walking:  'assets/icons/mascot/sprite-sheets/walking.png',
    _MascotPhase.sweeping: 'assets/icons/mascot/sprite-sheets/sweeping.png',
    _MascotPhase.looking:  'assets/icons/mascot/sprite-sheets/looking.png',
    _MascotPhase.wiping:   'assets/icons/mascot/sprite-sheets/wiping.png',
    _MascotPhase.sitting:  'assets/icons/mascot/sprite-sheets/sitting_down.png',
    _MascotPhase.poked:    'assets/icons/mascot/sprite-sheets/poked.png',
    _MascotPhase.sleeping: 'assets/icons/mascot/sprite-sheets/sleeping.png',
    _MascotPhase.oneFoot:  'assets/icons/mascot/sprite-sheets/one-foot.png',
    _MascotPhase.wave:     'assets/icons/mascot/sprite-sheets/wave.png',
    _MascotPhase.fallDown: 'assets/icons/mascot/sprite-sheets/fall_down.png',
  };

  @override
  void initState() {
    super.initState();
    _spriteCtrl = AnimationController(vsync: this);
    _posCtrl = AnimationController(vsync: this);
    _loadImages();
  }

  Future<void> _loadImages() async {
    final entries = _assetPaths.entries.toList();
    final loaded = await Future.wait(entries.map((e) => _load(e.value)));
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < entries.length; i++) {
        _images[entries[i].key] = loaded[i];
      }
    });
    // Defer to next frame so the rebuild from setState above completes first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _advanceSequence();
    });
  }

  static Future<ui.Image> _load(String asset) async {
    final data = await rootBundle.load(asset);
    return decodeImageFromList(data.buffer.asUint8List());
  }

  void _pokeMascot() {
    if (!mounted) return;
    // Cancel any in-progress phase and play poked once.
    _phaseTimer?.cancel();
    setState(() => _phase = _MascotPhase.poked);
    _spriteCtrl.duration = _spriteDuration[_MascotPhase.poked]!;
    _spriteCtrl.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) _advanceSequence();
    });
  }

  void _advanceSequence() {
    // After walking, always pick a stationary phase.
    // After a stationary phase, 50% chance to walk next.
    _MascotPhase next;
    if (_phase != _MascotPhase.walking && math.Random().nextBool()) {
      next = _MascotPhase.walking;
    } else {
      if (_bag.isEmpty) {
        _bag.addAll(_stationaryPhases);
        _bag.shuffle();
      }
      next = _bag.removeLast();
    }
    _startPhase(next);
  }

  void _startPhase(_MascotPhase phase) {
    if (!mounted) return;
    _phaseTimer?.cancel();
    setState(() => _phase = phase);

    _spriteCtrl.duration = _spriteDuration[phase]!;
    _spriteCtrl.repeat();

    if (phase == _MascotPhase.walking) {
      _posCtrl.duration = const Duration(milliseconds: 4500);
      final future = _facingRight
          ? _posCtrl.animateTo(1.0, curve: Curves.linear)
          : _posCtrl.animateTo(0.0, curve: Curves.linear);
      future.whenCompleteOrCancel(() {
        if (mounted) {
          setState(() => _facingRight = !_facingRight);
          _advanceSequence();
        }
      });
    } else {
      final secs = _holdDuration[phase]!;
      _phaseTimer = Timer(Duration(seconds: secs), _advanceSequence);
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _spriteCtrl.dispose();
    _posCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _images[_phase];

    if (image == null) {
      return const SizedBox.expand();
    }

    return GestureDetector(
      onTap: _pokeMascot,
      child: LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth;
        final spriteSize = constraints.maxHeight; // fill parent height

        return AnimatedBuilder(
          animation: Listenable.merge([_spriteCtrl, _posCtrl]),
          builder: (context, _) {
            const totalFrames = 36;
            final frameIndex =
                (_spriteCtrl.value * totalFrames).floor().clamp(0, totalFrames - 1);

            // Horizontal travel: sprite moves from left to right edge of panel
            final maxTravel = (panelWidth - spriteSize).clamp(0.0, double.infinity);
            final xOffset = _posCtrl.value * maxTravel;

            Widget painter = CustomPaint(
              size: Size(spriteSize, spriteSize),
              painter: _MascotFramePainter(
                image: image,
                frameIndex: frameIndex,
                flipHorizontal: !_facingRight,
              ),
            );

            final tintColor = _skinTints[widget.skinId];
            if (tintColor != null) {
              painter = ColorFiltered(
                colorFilter: ColorFilter.mode(
                  tintColor.withValues(alpha: 0.30),
                  BlendMode.srcATop,
                ),
                child: painter,
              );
            }

            return SizedBox(
              width: panelWidth,
              height: spriteSize,
              child: Stack(
                children: [
                  const SizedBox.expand(), // size anchor for Positioned children
                  Positioned(left: xOffset, child: painter),
                ],
              ),
            );
          },
        );
      },
      ),  // LayoutBuilder
    );    // GestureDetector
  }
}

class _MascotFramePainter extends CustomPainter {
  const _MascotFramePainter({
    required this.image,
    required this.frameIndex,
    this.flipHorizontal = false,
  });

  final ui.Image image;
  final int frameIndex;
  final bool flipHorizontal;

  static const int _columns = 6;
  static const int _rows = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final frameW = image.width / _columns;
    final frameH = image.height / _rows;
    final col = frameIndex % _columns;
    final row = frameIndex ~/ _columns;

    final src = Rect.fromLTWH(col * frameW, row * frameH, frameW, frameH);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    if (flipHorizontal) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(image, src, dst, Paint());
    if (flipHorizontal) canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotFramePainter old) =>
      old.frameIndex != frameIndex ||
      old.image != image ||
      old.flipHorizontal != flipHorizontal;
}
