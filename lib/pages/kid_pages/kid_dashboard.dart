import 'dart:async';
import 'dart:io';

import 'package:chorezilla/components/badge_unlock_dialog.dart';
import 'package:chorezilla/components/leveling.dart';
import 'package:chorezilla/components/profile_header.dart';
import 'package:chorezilla/components/zilla_level_up_hero.dart';
import 'package:chorezilla/models/badge.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/pages/kid_pages/kid_badges_page.dart';
import 'package:chorezilla/pages/kid_pages/kid_edit_profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/data/chorezilla_repo.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/cosmetics.dart';

import 'package:chorezilla/pages/kid_pages/kid_rewards_page.dart';
import 'package:chorezilla/pages/kid_pages/kid_activity_page.dart';

class KidDashboardPage extends StatefulWidget {
  const KidDashboardPage({super.key, this.memberId});

  /// If omitted, we’ll fall back to AppState.currentMember.
  final String? memberId;

  @override
  State<KidDashboardPage> createState() => _KidDashboardPageState();
}

class _KidDashboardPageState extends State<KidDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _busyIds = {}; // assignmentIds being completed
  String? _watchingMemberId;
  int? _lastSeenLevel;

  late final AppState _app;

  late final ConfettiController _confettiController;
  bool _celebrationActive = false;
  bool _showConfetti = false;

  // image picker for photo proof
  final ImagePicker _imagePicker = ImagePicker();

  // NEW: local "today" stream, same as ParentTodayTab → filtered per kid
  StreamSubscription<List<Assignment>>? _todayAssignmentsSub;
  List<Assignment> _todayAssignmentsForKid = [];
  bool _todayAssignmentsBootstrapped = false;

  @override
  void initState() {
    super.initState();

    _app = context.read<AppState>();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    // Bind streams once the widget is in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final member = _resolveMember(_app);
      if (member != null) {
        _bindStreamsForMember(member);
      }
    });
  }

  @override
  void didUpdateWidget(covariant KidDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the widget was rebuilt with a different explicit memberId, re-bind.
    if (oldWidget.memberId != widget.memberId) {
      final member = _resolveMember(_app);
      if (member != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _bindStreamsForMember(member);
        });
      }
    }
  }

  @override
  void dispose() {
    _todayAssignmentsSub?.cancel();
    if (_watchingMemberId != null) {
      _app.stopKidStreams(_watchingMemberId!);
    }
    _confettiController.dispose();
    super.dispose();
  }

  /// Bind both:
  ///  - AppState's kid streams (for rewards, etc.)
  ///  - Local "today" assignments stream filtered for this kid
  void _bindStreamsForMember(Member member) {
    final familyId = _app.familyId;
    if (familyId == null) {
      debugPrint('ChildDashboardPage: no familyId; cannot bind kid streams.');
      return;
    }

    // Avoid rebinding if we're already watching this kid and stream exists.
    if (_watchingMemberId == member.id && _todayAssignmentsSub != null) {
      return;
    }

    // Stop previous AppState kid streams when switching kids
    if (_watchingMemberId != null && _watchingMemberId != member.id) {
      _app.stopKidStreams(_watchingMemberId!);
    }

    _watchingMemberId = member.id;
    _lastSeenLevel = null;

    // Start AppState-level kid streams (for rewards, etc.)
    _app.startKidStreams(member.id);

    // Local "today" stream – same as ParentTodayTab, filtered by memberId
    _todayAssignmentsSub?.cancel();
    _todayAssignmentsBootstrapped = false;
    _todayAssignmentsForKid = [];

    debugPrint(
      'ChildDashboardPage: binding today stream for kid=${member.displayName} '
      '(${member.id}) family=$familyId',
    );

    _todayAssignmentsSub = _app.repo.watchAssignmentsDueToday(familyId).listen((
      all,
    ) {
      final filtered = all.where((a) => a.memberId == member.id).toList();

      debugPrint(
        'ChildDashboardPage[todayStream]: kid=${member.displayName} total=${filtered.length}',
      );

      if (!mounted) return;
      setState(() {
        _todayAssignmentsForKid = filtered;
        _todayAssignmentsBootstrapped = true;
      });
    });
  }

  Member? _resolveMember(AppState app) {
    if (!app.isReady) return null;
    if (widget.memberId != null) {
      return app.members
          .where((m) => m.id == widget.memberId)
          .cast<Member?>()
          .firstOrNull;
    }
    return app.currentMember ?? app.members.firstOrNull;
  }

  Future<void> _showBadgeUnlockDialogs(List<BadgeDefinition> badges) async {
    for (final badge in badges) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => BadgeUnlockDialog(badge: badge),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();

    if (!app.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final member = _resolveMember(app);
    if (member == null) {
      return const Scaffold(body: Center(child: Text('No kid selected')));
    }
    if (member.role != FamilyRole.child) {
      return const Scaffold(
        body: Center(child: Text('This dashboard is for child accounts.')),
      );
    }

        // If currentMember changed under us (via profile switcher), re-bind streams.
    if (_watchingMemberId != member.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _bindStreamsForMember(member);
      });
    }

    _handleLevelChange(member);

    final allowBonusChores = (member.allowBonusChores);

    final choresLoaded = _todayAssignmentsBootstrapped;

    // Kid background cosmetic
    final backgroundId = member.equippedBackgroundId ?? 'bg_default';
    final backgroundItem = CosmeticCatalog.byId(backgroundId);
    final String? backgroundAsset =
        backgroundItem.type == CosmeticType.background
        ? backgroundItem.assetKey
        : null;

    // "Today" window (local time)
    final now = DateTime.now();

    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    bool isToday(DateTime? t) {
      if (t == null) return false;
      return !t.isBefore(todayStart) && t.isBefore(tomorrowStart);
    }

    final allForKid = _todayAssignmentsForKid;

    final requiredTodos =
        allForKid
            .where(
              (a) => a.bonus != true && a.status == AssignmentStatus.assigned,
            )
            .toList()
          ..sort(_byDueThenTitle);

    final bonusTodos =
        allForKid
            .where(
              (a) => a.bonus == true && a.status == AssignmentStatus.assigned,
            )
            .toList()
          ..sort(_byDueThenTitle);


    final submitted =
        allForKid.where((a) => a.status == AssignmentStatus.pending).toList()
          ..sort(_byDueThenTitle);


    final completedToday =
        allForKid
            .where(
              (a) =>
                  a.status == AssignmentStatus.completed &&
                  isToday(a.completedAt),
            )
            .toList()
          ..sort(_byCompletedAtDescThenTitle);

      // 🔹 BONUS CHORES: which bonus chores are still available for this kid today?
      final allChores = app.chores;
      final allBonusChores = allChores.where(
    (c) => c.active && (c.bonusOnly == true),
  );

  // Chores this kid already has today (any status)
  final takenChoreIds = allForKid
    .map((a) => a.choreId)
    .where((id) => id.isNotEmpty)
    .toSet();

  // If this kid is not allowed, there are *no* available bonus chores to pick.
  final availableBonusChores = allowBonusChores
      ? (allBonusChores.where((c) => !takenChoreIds.contains(c.id)).toList()
          ..sort((a, b) => a.title.compareTo(b.title)))
      : <Chore>[];


    debugPrint(
      'ChildDashboardPage: kid=${member.displayName} '
      'todos=${requiredTodos.length} submitted=${submitted.length} '
      'completedToday=${completedToday.length} (loaded=$choresLoaded)',
    );

    final pendingRewards = app.pendingRewardsForKid(member.id);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dayComplete = app.isDayCompleteForKid(member.id);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
        elevation: 0,
        title: const Text("Today's Chores"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 28),
            tooltip: 'Activity',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KidActivityPage(memberId: member.id),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded, size: 28),
            tooltip: 'Badges',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KidBadgesPage(memberId: member.id),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.card_giftcard, size: 28),
            tooltip: 'Rewards',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KidRewardsPage(memberId: member.id),
                ),
              );
            },
          ),
        ],
      ),
            body: Stack(
        children: [
          // Background layer: either equipped image or fallback gradient
          Container(
            decoration: backgroundAsset != null
                ? BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(backgroundAsset),
                      fit: BoxFit.cover,
                    ),
                  )
                : BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.secondary, cs.primary],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
          ),


          // Main content
          Column(
            children: [
              const SizedBox(height: 4),

                            // Profile header inside a tappable rounded hero card
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KidEditProfilePage(memberId: member.id),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ProfileHeader(
                      member: member,
                      showInviteButton: false,
                      showSwitchButton: false,
                    ),
                  ),
                ),
              ),


              if (pendingRewards.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: _PendingRewardsBanner(
                    count: pendingRewards.length,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KidRewardsPage(
                            memberId: member.id,
                            initialTabIndex: 1,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (dayComplete)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You finished all your main chores for today! Bonus chores are extra if you want more coins and XP.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Tabs + lists on a rounded “sheet”
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: const BorderRadius.all(Radius.circular(24)
                      ),
                    ),
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'To Do'),
                              Tab(text: 'Submitted'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Tab 1: To Do
                                if (!choresLoaded)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else
                                  Column(
                                    children: [
                                      if (availableBonusChores.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            12,
                                            12,
                                            4,
                                          ),
                                          child: _BonusChoresSection(
                                            kid: member,
                                            chores: availableBonusChores,
                                          ),
                                        ),
                                      Expanded(
                                        child: _TodoList(
                                          memberId: member.id,
                                          items: requiredTodos,
                                          bonusItems: bonusTodos,
                                          busyIds: _busyIds,
                                          onComplete: _completeAssignment,
                                          completedToday: completedToday,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Tab 2: Submitted
                                if (!choresLoaded)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else
                                  _SubmittedList(items: submitted),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Confetti overlay on top of everything
          if (_showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    emissionFrequency: 0.05,
                    numberOfParticles: 15,
                    gravity: 0.35,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _completeAssignment(Assignment a) async {
    final app = context.read<AppState>();
    setState(() => _busyIds.add(a.id));

    try {
      File? file;

      // Only ask for photo proof if this assignment requires parent approval.
      if (a.requiresApproval) {
        // Ask how they want to proceed (camera / gallery / no photo / cancel)
        final choice = await showDialog<ProofChoice>(
          context: context,
          barrierDismissible: false, // can't tap outside to dismiss
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Add a photo?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Take photo'),
                    onTap: () => Navigator.of(ctx).pop(ProofChoice.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Choose from gallery'),
                    onTap: () => Navigator.of(ctx).pop(ProofChoice.gallery),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('Mark done without photo'),
                    onTap: () => Navigator.of(ctx).pop(ProofChoice.skip),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );

        // User hit back or tapped "Cancel" → do NOT complete.
        if (choice == null) {
          return; // finally will still clear _busyIds
        }

        // User explicitly chose to complete without photo.
        if (choice == ProofChoice.skip) {
          file = null;
        } else {
          // camera or gallery
          final source = choice == ProofChoice.camera
              ? ImageSource.camera
              : ImageSource.gallery;

          final picked = await _imagePicker.pickImage(
            source: source,
            imageQuality: 75,
          );

          // If they backed out of camera/gallery, treat that as cancel.
          if (picked == null) {
            return;
          }

          file = File(picked.path);
        }
      }

      // If we got a file, upload & attach proof.
      if (file != null) {
        try {
          final url = await _uploadProofPhoto(a, file);
          await _attachProofToAssignment(a, url);
        } catch (e, st) {
          debugPrint('Error uploading proof photo: $e\n$st');

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Couldn\'t upload the photo. Completing the chore without it.',
              ),
            ),
          );
        }
      }
            // Existing completion logic (status, XP, coins, streaks, etc.)
      await app.completeAssignment(a.id);

            final newBadges = await app.checkAndAwardStreakBadgesForKid(a.memberId);

      if (!mounted) return;

      if (newBadges.isNotEmpty) {
        await _showBadgeUnlockDialogs(newBadges);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(a.id));
    }
  }

  /// Upload the proof photo to Firebase Storage and return the download URL.
  Future<String> _uploadProofPhoto(Assignment a, File file) async {
    final storage = FirebaseStorage.instance;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = storage.ref().child(
      'families/${a.familyId}/proofs/${a.id}_$ts.jpg',
    );

    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Attach the proof to the assignment document in Firestore.
  Future<void> _attachProofToAssignment(Assignment a, String photoUrl) async {
    final db = FirebaseFirestore.instance;
    final doc = db
        .collection('families')
        .doc(a.familyId)
        .collection('assignments')
        .doc(a.id);

    await doc.update({
      'proof': {'photoUrl': photoUrl, 'note': null},
    });
  }

  void _handleLevelChange(Member member) {
    final info = levelInfoForXp(member.xp);
    final currentLevel = info.level;

    final storedLevel = member.level; // from your Member model
    final baseline = _lastSeenLevel ?? storedLevel;

    if (currentLevel > baseline) {
      _lastSeenLevel = currentLevel;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _triggerLevelUpCelebration(member, info);
      });
    } else {
      _lastSeenLevel = baseline;
    }
  }

  Future<void> _triggerLevelUpCelebration(
    Member member,
    LevelInfo info, {
    bool simulate = false,
  }) async {
    if (!mounted) return;
    if (_celebrationActive) return;

    _celebrationActive = true;

    // 1) START CONFETTI FIRST
    setState(() {
      _showConfetti = true;
    });
    _confettiController.play();

    final lvlReward = levelRewardForLevel(info.level);

    if (!simulate) {
      final app = context.read<AppState>();
      app.updateMember(member.id, {'level': info.level});

      if (lvlReward != null) {
        try {
          await app.createLevelUpRewardRedemptionForKid(
            memberId: member.id,
            level: info.level,
            rewardTitle: lvlReward.title,
          );
        } catch (_) {
          // ignore
        }
      }
    }

    if (!mounted) return;

    // 2) WHILE CONFETTI IS RUNNING, SHOW THE DIALOG (Zilla animates here)
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;

        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (context, dialogScale, _) {
              return Transform.scale(
                scale: dialogScale,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: cs.surface,
                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Level up!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Zilla + sparkles animating while confetti runs
                      ZillaLevelUpHero(size: 96),
                      const SizedBox(height: 16),
                      Text(
                        '${member.displayName} reached Level ${info.level}!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${info.xpIntoLevel} / ${info.xpNeededThisLevel} XP for this level',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (lvlReward != null && !simulate) ...[
                        const SizedBox(height: 16),
                        // reward card...
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Keep going to earn more coins and unlock rewards!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(simulate ? 'Close' : 'Awesome!'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;

    // 3) STOP CONFETTI AFTER DIALOG CLOSES
    setState(() {
      _showConfetti = false;
    });
    _confettiController.stop();
    _celebrationActive = false;
  }

  // ---- Helpers --------------------------------------------------------------

  int _byDueThenTitle(Assignment a, Assignment b) {
    final ad = a.due;
    final bd = b.due;
    if (ad == null && bd == null) {
      return a.choreTitle.compareTo(b.choreTitle);
    } else if (ad == null) {
      return 1;
    } else if (bd == null) {
      return -1;
    } else {
      final cmp = ad.compareTo(bd);
      return cmp != 0 ? cmp : a.choreTitle.compareTo(b.choreTitle);
    }
  }

  int _byCompletedAtDescThenTitle(Assignment a, Assignment b) {
    final ad = a.completedAt;
    final bd = b.completedAt;
    if (ad == null && bd == null) {
      return a.choreTitle.compareTo(b.choreTitle);
    } else if (ad == null) {
      return 1;
    } else if (bd == null) {
      return -1;
    } else {
      final cmp = bd.compareTo(ad); // newest first
      return cmp != 0 ? cmp : a.choreTitle.compareTo(b.choreTitle);
    }
  }

  @override
  bool get wantKeepAlive => true;
}

// ============================================================================
// Widgets
// ============================================================================

class _TodoList extends StatelessWidget {
  const _TodoList({
    required this.memberId,
    required this.items,
    required this.bonusItems, 
    required this.completedToday,
    required this.busyIds,
    required this.onComplete,
  });

  final String memberId;
  final List<Assignment> items;
  final List<Assignment> bonusItems;
  final Set<String> busyIds;
  final Future<void> Function(Assignment) onComplete;
  final List<Assignment> completedToday;

  @override
  Widget build(BuildContext context) {
    final hasTodos = items.isNotEmpty;
    final hasCompleted = completedToday.isNotEmpty;
    final hasBonus = bonusItems.isNotEmpty;

    if (!hasTodos && !hasCompleted && !hasBonus) {
      return const _EmptyState(
        emoji: '🎉',
        title: 'All caught up!',
        subtitle: 'No chores to do right now.',
      );
    }


    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int crossAxisCount;
        if (width < 480) {
          crossAxisCount = 1; // narrow phones → full-width
        } else if (width < 800) {
          crossAxisCount = 2; // larger phones / small tablets
        } else {
          crossAxisCount = 3; // big tablets
        }

        const gridSpacing = 12.0;
        const tileHeight = 120.0;

        return CustomScrollView(
          slivers: [
            if (hasTodos) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'To do',
                    style: ts.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: gridSpacing,
                    mainAxisSpacing: gridSpacing,
                    mainAxisExtent: tileHeight,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final a = items[index];
                    final busy = busyIds.contains(a.id);
                    final isRejected = a.status == AssignmentStatus.rejected;

                    return _AssignmentTile(
                      assignment: a,
                      completed: false,
                      rejected: isRejected,
                      trailing: FilledButton(
                        onPressed: busy ? null : () => onComplete(a),
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Mark done'),
                      ),
                    );
                  }, childCount: items.length),
                ),
              ),
            ],

            if (hasBonus) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Bonus chores (extra coins!)',
                    style: ts.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: gridSpacing,
                    mainAxisSpacing: gridSpacing,
                    mainAxisExtent: tileHeight,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final a = bonusItems[index];
                    final busy = busyIds.contains(a.id);

                    return _AssignmentTile(
                      assignment: a,
                      completed: false,
                      rejected: false,
                      trailing: FilledButton(
                        onPressed: busy ? null : () => onComplete(a),
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Do this'),
                      ),
                    );
                  }, childCount: bonusItems.length),
                ),
              ),
            ],

            if (hasCompleted) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Done today',
                    style: ts.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: gridSpacing,
                    mainAxisSpacing: gridSpacing,
                    mainAxisExtent: tileHeight,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final a = completedToday[index];
                    return _AssignmentTile(
                      assignment: a,
                      completed: true,
                      trailing: Icon(
                        Icons.check_circle_rounded,
                        color: cs.primary,
                      ),
                    );
                  }, childCount: completedToday.length),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SubmittedList extends StatelessWidget {
  const _SubmittedList({required this.items});
  final List<Assignment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        emoji: '⌛',
        title: 'Nothing submitted yet',
        subtitle:
            'Pending chores will show up here until a parent reviews them.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = items[i];
        return _AssignmentTile(
          assignment: a,
          trailing: const _StatusPill(text: 'Pending review'),
        );
      },
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.trailing,
    this.completed = false,
    this.rejected = false,
  });

  final Assignment assignment;
  final Widget trailing;
  final bool completed;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final icon = assignment.choreIcon?.trim();

    const double iconBoxSize = 50;
    final double emojiSize = iconBoxSize * 0.65;

    final baseTitleStyle = ts.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    TextStyle? titleStyle;
    if (completed) {
      titleStyle = baseTitleStyle?.copyWith(
        decoration: TextDecoration.lineThrough,
        color: cs.onSurfaceVariant,
      );
    } else if (rejected) {
      titleStyle = baseTitleStyle?.copyWith(color: cs.error);
    } else {
      titleStyle = baseTitleStyle;
    }

    final xpStyle = completed
        ? ts.bodyMedium?.copyWith(color: cs.onSurfaceVariant)
        : ts.bodyMedium;

    return Card(
      elevation: 0,
      color: completed
          ? cs.surfaceContainerHighest
          : rejected
          ? cs.errorContainer
          : cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Text(
                    icon == null || icon.isEmpty ? '🧩' : icon,
                    style: TextStyle(fontSize: emojiSize),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.choreTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.add, size: 16, color: cs.secondary),
                      const SizedBox(width: 1),
                      Text('${assignment.xp} pts', style: xpStyle),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Simple empty-state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text(title, style: ts.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRewardsBanner extends StatelessWidget {
  const _PendingRewardsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final text = count == 1
        ? 'You have 1 reward waiting'
        : 'You have $count rewards waiting';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text('🎁', style: ts.titleLarge),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: ts.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _BonusChoresSection extends StatelessWidget {
  const _BonusChoresSection({required this.kid, required this.chores});

  final Member kid;
  final List<Chore> chores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final app = context.read<AppState>();
    final family = app.family;

    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Bonus chores',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Want extra coins and XP? Pick one!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: chores.map((chore) {
                final xp =
                    family?.settings.difficultyToXP[chore.difficulty] ??
                    (chore.difficulty.clamp(1, 5) * 10);
                final coins = family != null
                    ? (xp * family.settings.coinPerPoint).round()
                    : 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          chore.icon?.isNotEmpty == true ? chore.icon! : '🧩',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chore.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$xp XP · $coins coins',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () async {
                          try {
                            await app.pickupBonusChore(
                              memberId: kid.id,
                              choreId: chore.id,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '"${chore.title}" was added to your list for today!',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not add chore: $e'),
                              ),
                            );
                          }
                        },
                        child: const Text('Do this'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// handy extension
extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
