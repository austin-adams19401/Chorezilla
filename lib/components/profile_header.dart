import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:chorezilla/components/avatar_cosmetic_widgets.dart';
import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/models/cosmetics.dart';
import 'package:chorezilla/pages/kid_pages/kid_edit_profile_page.dart';
import 'package:chorezilla/services/sprite_cache_service.dart';
import 'package:flutter/gestures.dart';
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

    // Kids get the redesigned two-zone hero header.
    if (isChild) {
      return Material(
        color: Colors.transparent,
        child: _KidHeroHeader(
          member: m,
          showSwitchButton: showSwitchButton,
          onSwitchMember: onSwitchMember,
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
  });

  final Member member;
  final bool showSwitchButton;
  final VoidCallback? onSwitchMember;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final bool compact = MediaQuery.of(context).size.height < 680;

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
      height: compact
          ? 132 + (showTitle ? 24 : 0)
          : 160 + (showTitle ? 24 : 0),
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
              child: _buildMascotPanel(context, member),
            ),
          ),

          // ── Right: stats panel (1/3 width) ───────────────────────────────
          Flexible(
            flex: 1,
            child: Stack(
              children: [
                // Stats column
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 8 : 10, compact ? 1 : 2, compact ? 8 : 10, compact ? 1 : 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar — larger, centered
                      _AvatarCircle(member: member, radius: compact ? 22 : 32),

                      SizedBox(height: compact ? 2 : 4),

                      // Name
                      Text(
                        member.kidName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: ts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      // Title chip (only if equipped)
                      if (titleName != null) ...[
                        const SizedBox(height: 3),
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

                      SizedBox(height: compact ? 3 : 5),
                      // Level / XP bar
                      _LevelProgressBar(member: member, compact: true),
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

  Widget _buildMascotPanel(BuildContext context, Member m) {
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
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _CyclingMascot(
      skinId: m.equippedZillaSkinId,
      isPremium: context.read<AppState>().family?.isPremium ?? false,
      unlockedAnimations: m.unlockedAnimations,
    ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Allowance summary (header)
// ─────────────────────────────────────────────────────────────────────────────

class AllowanceHeaderSummary extends StatelessWidget {
  const AllowanceHeaderSummary({super.key, required this.memberId});
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
          '\$${earned.toStringAsFixed(2)}/\$${full.toStringAsFixed(2)} · $effectiveDays/$requiredDays days',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
    final avatarKey = (member.avatarKey ?? '').trim();
    final frameId = member.equippedAvatarFrameId;

    final circle = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.black,
      child: buildAvatarContent(avatarKey, radius * 0.95, _initials(member.displayName)),
    );

    if (frameId == null || frameId == 'frame_default') return circle;

    return Stack(
      alignment: Alignment.center,
      children: [
        circle,
        FrameOverlay(frameId: frameId, radius: radius),
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

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Level ${info.level}',
            style: ts.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: info.progress,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${info.xpIntoLevel} / ${info.xpNeededThisLevel} XP',
            style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

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
        if (nextReward != null) ...[
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
// Cycling mascot — idle → walk (with horizontal movement) → stationary phases
// After 30 s of inactivity: go-to-sleep → sleeping loop → wake-up on touch
// ─────────────────────────────────────────────────────────────────────────────

enum _SleepState { awake, goingToSleep, sleeping, wakingUp }

enum _MascotPhase {
  idle, walking, sweeping, looking, wiping,
  wave,
  grumpy, grrr,
  goingToSleep, sleepingLoop, wakingUp,
}

class _CyclingMascot extends StatefulWidget {
  const _CyclingMascot({
    this.skinId,
    this.isPremium = false,
    this.unlockedAnimations = const [],
  });
  final String? skinId;
  final bool isPremium;
  final List<String> unlockedAnimations;

  @override
  State<_CyclingMascot> createState() => _CyclingMascotState();
}

class _CyclingMascotState extends State<_CyclingMascot>
    with TickerProviderStateMixin {
  // Loaded image pairs (body + details) keyed by phase
  final _bodyImages = <_MascotPhase, ui.Image>{};
  final _detailsImages = <_MascotPhase, ui.Image>{};

  _MascotPhase _phase = _MascotPhase.idle;
  bool _facingRight = true;
  bool _resumeWalkAfterPoke = false;
  bool _isPoking = false;
  int _pokeIndex = 0;

  // Bag of stationary phases — shuffled and consumed, refilled when empty.
  final _bag = <_MascotPhase>[];

  // Free phases always available in the random cycle.
  static const _freeStationaryPhases = [
    _MascotPhase.idle,
    _MascotPhase.looking,
  ];

  // Premium phases and the animation IDs that unlock them.
  static const _premiumPhases = <String, _MascotPhase>{
    'wave':     _MascotPhase.wave,
    'sweeping': _MascotPhase.sweeping,
    'wiping':   _MascotPhase.wiping,
  };

  List<_MascotPhase> get _stationaryPhases {
    final phases = [..._freeStationaryPhases];
    if (widget.isPremium) {
      for (final id in widget.unlockedAnimations) {
        final phase = _premiumPhases[id];
        if (phase != null) phases.add(phase);
      }
    }
    return phases;
  }

  // Sprite loop duration for each phase
  static const _spriteDuration = <_MascotPhase, Duration>{
    _MascotPhase.idle:          Duration(milliseconds: 3500),
    _MascotPhase.sweeping:      Duration(milliseconds: 2250),
    _MascotPhase.looking:       Duration(milliseconds: 2500),
    _MascotPhase.wiping:        Duration(milliseconds: 2250),
    _MascotPhase.wave:          Duration(milliseconds: 2250),
    _MascotPhase.walking:       Duration(milliseconds: 2500),
    _MascotPhase.grumpy:        Duration(milliseconds: 1800),
    _MascotPhase.grrr:          Duration(milliseconds: 1400),
    _MascotPhase.goingToSleep:  Duration(milliseconds: 2000),
    _MascotPhase.sleepingLoop:  Duration(milliseconds: 2500),
    _MascotPhase.wakingUp:      Duration(milliseconds: 1800),
  };

  // How long to hold each stationary phase (seconds)
  // Sleep phases don't use this — they're managed via whenCompleteOrCancel.
  static const _holdDuration = <_MascotPhase, int>{
    _MascotPhase.idle:     4,
    _MascotPhase.sweeping: 4,
    _MascotPhase.looking:  3,
    _MascotPhase.wiping:   4,
    _MascotPhase.wave:     3,
  };

  // Drives sprite frame index (0.0 → 1.0, looping)
  late final AnimationController _spriteCtrl;

  // Drives horizontal position (0.0 = left, 1.0 = right)
  late final AnimationController _posCtrl;

  Timer? _phaseTimer;

  // Sleep state machine
  static const _inactivityTimeout = Duration(seconds: 30);
  Timer? _inactivityTimer;
  _SleepState _sleepState = _SleepState.awake;

  static const _assetPaths = <_MascotPhase, ({String body, String details})>{
    _MascotPhase.idle:          (body: 'assets/mascot/sprite-sheets/idle_body.png',          details: 'assets/mascot/sprite-sheets/idle_details.png'),
    _MascotPhase.walking:       (body: 'assets/mascot/sprite-sheets/walking_body.png',       details: 'assets/mascot/sprite-sheets/walking_details.png'),
    _MascotPhase.sweeping:      (body: 'assets/mascot/sprite-sheets/sweeping_body.png',      details: 'assets/mascot/sprite-sheets/sweeping_details.png'),
    _MascotPhase.looking:       (body: 'assets/mascot/sprite-sheets/idle2_body.png',         details: 'assets/mascot/sprite-sheets/idle2_details.png'),
    _MascotPhase.wiping:        (body: 'assets/mascot/sprite-sheets/wiping_body.png',        details: 'assets/mascot/sprite-sheets/wiping_details.png'),
    _MascotPhase.wave:          (body: 'assets/mascot/sprite-sheets/wave_body.png',          details: 'assets/mascot/sprite-sheets/wave_details.png'),
    _MascotPhase.grumpy:        (body: 'assets/mascot/sprite-sheets/grumpy_body.png',        details: 'assets/mascot/sprite-sheets/grumpy_details.png'),
    _MascotPhase.grrr:          (body: 'assets/mascot/sprite-sheets/grrr_body.png',          details: 'assets/mascot/sprite-sheets/grrr_details.png'),
    _MascotPhase.goingToSleep:  (body: 'assets/mascot/sprite-sheets/going-to-sleep_body.png', details: 'assets/mascot/sprite-sheets/going-to-sleep_details.png'),
    _MascotPhase.sleepingLoop:  (body: 'assets/mascot/sprite-sheets/sleeping_body.png',      details: 'assets/mascot/sprite-sheets/sleeping_details.png'),
    _MascotPhase.wakingUp:      (body: 'assets/mascot/sprite-sheets/wake-up_body.png',       details: 'assets/mascot/sprite-sheets/wake-up_details.png'),
  };

  @override
  void initState() {
    super.initState();
    _spriteCtrl = AnimationController(vsync: this);
    _posCtrl = AnimationController(vsync: this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointerEvent);
    _resetInactivityTimer();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final entries = _assetPaths.entries.toList();
    final loaded = await Future.wait(
      entries.map((e) async {
        final body = await _load(e.value.body);
        final details = await _load(e.value.details);
        return (body: body, details: details);
      }),
    );
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < entries.length; i++) {
        _bodyImages[entries[i].key] = loaded[i].body;
        _detailsImages[entries[i].key] = loaded[i].details;
      }
    });
    // Defer to next frame so the rebuild from setState above completes first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _advanceSequence();
    });
  }

  static Future<ui.Image> _load(String asset) async {
    final filename = asset.split('/').last;
    final bytes = await SpriteSheetCacheService.getBytes(filename);
    return decodeImageFromList(bytes);
  }

  static const _pokePhases = [
    _MascotPhase.wave,
    _MascotPhase.grumpy,
    _MascotPhase.grrr,
  ];

  void _pokeMascot() {
    if (!mounted) return;
    if (_sleepState != _SleepState.awake) return;
    if (_isPoking) return;

    _isPoking = true;
    _phaseTimer?.cancel();
    // If poked while walking, stop movement and resume walk after poke.
    _resumeWalkAfterPoke = _phase == _MascotPhase.walking;
    if (_resumeWalkAfterPoke) _posCtrl.stop();
    final reaction = _pokePhases[_pokeIndex % _pokePhases.length];
    _pokeIndex++;
    setState(() => _phase = reaction);
    _spriteCtrl.duration = _spriteDuration[reaction]!;
    _spriteCtrl.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted) return;
      _isPoking = false;
      if (_resumeWalkAfterPoke) {
        _resumeWalkAfterPoke = false;
        _startPhase(_MascotPhase.walking);
      } else {
        _advanceSequence();
      }
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, _triggerSleepSequence);
  }

  void _triggerSleepSequence() {
    if (!mounted || _sleepState != _SleepState.awake) return;
    _sleepState = _SleepState.goingToSleep;
    _phaseTimer?.cancel();
    _posCtrl.stop();
    setState(() => _phase = _MascotPhase.goingToSleep);
    _spriteCtrl.duration = _spriteDuration[_MascotPhase.goingToSleep]!;
    _spriteCtrl.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted || _sleepState != _SleepState.goingToSleep) return;
      _sleepState = _SleepState.sleeping;
      setState(() => _phase = _MascotPhase.sleepingLoop);
      _spriteCtrl.duration = _spriteDuration[_MascotPhase.sleepingLoop]!;
      _spriteCtrl.repeat();
    });
  }

  void _wakeUp() {
    if (!mounted || _sleepState == _SleepState.awake) return;
    _sleepState = _SleepState.wakingUp;
    _phaseTimer?.cancel();
    _spriteCtrl.stop();
    setState(() => _phase = _MascotPhase.wakingUp);
    _spriteCtrl.duration = _spriteDuration[_MascotPhase.wakingUp]!;
    _spriteCtrl.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted) return;
      _sleepState = _SleepState.awake;
      _resetInactivityTimer();
      _advanceSequence();
    });
  }

  void _onGlobalPointerEvent(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    if (_sleepState == _SleepState.sleeping ||
        _sleepState == _SleepState.goingToSleep) {
      _wakeUp();
    } else {
      _resetInactivityTimer();
    }
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
        // _resumeWalkAfterPoke means we were interrupted mid-walk by a poke —
        // skip the direction flip and sequence advance; _pokeMascot handles resumption.
        if (mounted && !_resumeWalkAfterPoke) {
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
    _inactivityTimer?.cancel();
    _phaseTimer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointerEvent);
    _spriteCtrl.dispose();
    _posCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyImage = _bodyImages[_phase];
    final detailsImage = _detailsImages[_phase];

    if (bodyImage == null || detailsImage == null) {
      return const SizedBox.expand();
    }

    final colorValue = CosmeticCatalog.tintColorValueForSkin(widget.skinId);
    final tintColor = colorValue != null ? Color(colorValue) : null;

    return GestureDetector(
      onTap: _pokeMascot,
      child: LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth;
        final spriteSize = constraints.maxHeight * 0.5; // half parent height

        return AnimatedBuilder(
          animation: Listenable.merge([_spriteCtrl, _posCtrl]),
          builder: (context, _) {
            const totalFrames = 36;
            final frameIndex =
                (_spriteCtrl.value * totalFrames).floor().clamp(0, totalFrames - 1);

            // Horizontal travel: sprite moves from left to right edge of panel
            final maxTravel = (panelWidth - spriteSize).clamp(0.0, double.infinity);
            final xOffset = _posCtrl.value * maxTravel;

            final painter = CustomPaint(
              size: Size(spriteSize, spriteSize),
              painter: _MascotFramePainter(
                bodyImage: bodyImage,
                detailsImage: detailsImage,
                tintColor: tintColor,
                frameIndex: frameIndex,
                flipHorizontal: !_facingRight,
              ),
            );

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
    required this.bodyImage,
    required this.detailsImage,
    required this.tintColor,
    required this.frameIndex,
    this.flipHorizontal = false,
  });

  final ui.Image bodyImage;
  final ui.Image detailsImage;
  final Color? tintColor;
  final int frameIndex;
  final bool flipHorizontal;

  static const int _columns = 6;
  static const int _rows = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final col = frameIndex % _columns;
    final row = frameIndex ~/ _columns;

    final bodyFrameW = bodyImage.width / _columns;
    final bodyFrameH = bodyImage.height / _rows;
    final bodySrc = Rect.fromLTWH(col * bodyFrameW, row * bodyFrameH, bodyFrameW, bodyFrameH);

    final detFrameW = detailsImage.width / _columns;
    final detFrameH = detailsImage.height / _rows;
    final detSrc = Rect.fromLTWH(col * detFrameW, row * detFrameH, detFrameW, detFrameH);

    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    if (flipHorizontal) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // Body layer with optional tint
    final bodyPaint = Paint();
    if (tintColor != null) {
      bodyPaint.colorFilter = ColorFilter.mode(tintColor!, BlendMode.srcIn);
    }
    canvas.drawImageRect(bodyImage, bodySrc, dst, bodyPaint);

    // Details layer on top (no tint)
    canvas.drawImageRect(detailsImage, detSrc, dst, Paint());

    if (flipHorizontal) canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotFramePainter old) =>
      old.frameIndex != frameIndex ||
      old.bodyImage != bodyImage ||
      old.detailsImage != detailsImage ||
      old.tintColor != tintColor ||
      old.flipHorizontal != flipHorizontal;
}
