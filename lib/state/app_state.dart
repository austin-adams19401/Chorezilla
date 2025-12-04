library;

// lib/state/app_state.dart
import 'dart:async';
import 'dart:convert';
import 'package:chorezilla/models/award.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/history.dart';
import 'package:chorezilla/services/local_cache.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:chorezilla/data/chorezilla_repo.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chorezilla/models/user_profile.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/models/reward.dart';
import 'package:chorezilla/models/reward_redemption.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'kid_streams_state.dart';
part 'allowance_history_state.dart';
part 'chore_rewards_state.dart';
part 'family_streams_state.dart';
part 'pin_state.dart';
part 'ui_state.dart';
part 'auth_state.dart';


const String _viewModeKey = 'viewMode';

/// Central app state.
/// - Slow/structural state stays on this ChangeNotifier (user/family/theme).
/// - Fast-changing lists are exposed via ValueNotifiers so only consumers of
///   those lists rebuild (reduces jank & GC).
class AppState extends ChangeNotifier {
  AppState({
    required this.auth,
    required this.repo,
    ThemeMode initialThemeMode = ThemeMode.system,
  }) : _themeMode = initialThemeMode {
    // Attach auth listener once
    _authSub = auth.authStateChanges().listen(_onAuthChanged);

    // Hot-reload / already signed-in case
    final u = auth.currentUser;
    _firebaseUser = u;

    debugPrint(
      'STATE CONSTRUCTOR: possible user: user=${u?.uid} - ${u?.displayName}',
    );
    if (u != null) {
      debugPrint('STATE CONSTRUCTOR: user exists =${u.uid} - ${u.displayName}');
      _getDataForUser(u);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dependencies
  // ───────────────────────────────────────────────────────────────────────────
  final FirebaseAuth auth;
  final ChorezillaRepo repo;
  final LocalCache _cache = LocalCache();
  AuthStatus authState = AuthStatus.unknown;
  User? _firebaseUser;
  User? get firebaseUser => _firebaseUser;

  // ───────────────────────────────────────────────────────────────────────────
  // Notification nav intent
  // ───────────────────────────────────────────────────────────────────────────
  String? _pendingNavTarget; // e.g. 'parent_approve'
  String? _pendingAssignmentId; // for future: focus a specific assignment

  String? get pendingNavTarget => _pendingNavTarget;
  String? get pendingAssignmentId => _pendingAssignmentId;

  // ───────────────────────────────────────────────────────────────────────────
  // Theme
  // ───────────────────────────────────────────────────────────────────────────
  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  // ───────────────────────────────────────────────────────────────────────────
  // NotifyListeners() Helper
  // ───────────────────────────────────────────────────────────────────────────

    void _notifyStateChanged() {
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Allowance & history state
  // ───────────────────────────────────────────────────────────────────────────
  /// Allowance settings per kid (by memberId).
  final Map<String, AllowanceConfig> _allowanceByMemberId = {};
  final Map<String, Map<String, DayStatus>> _dayStatusByMemberId = {};
  DateTime? _historyWeekStart;
  List<Assignment> _historyAssignments = const [];
  List<Assignment> get historyAssignments => _historyAssignments;

  // ───────────────────────────────────────────────────────────────────────────
  // View mode (Parent vs Kid) – persisted on device
  // ───────────────────────────────────────────────────────────────────────────
  AppViewMode _viewMode = AppViewMode.parent; // default
  bool _viewModeLoaded = false;

  AppViewMode get viewMode => _viewMode;
  bool get viewModeLoaded => _viewModeLoaded;

  // ───────────────────────────────────────────────────────────────────────────
  // User & Family (rare changes)
  // ───────────────────────────────────────────────────────────────────────────
  UserProfile? _user;
  UserProfile? get user => _user;

  String? _familyId;
  String? get familyId => _familyId;

  Family? _family;
  Family? get family => _family;

  bool get isReady =>
      auth.currentUser != null && _familyId != null && _family != null;

  // Boot flags to avoid false "setup" routing during hot restart
  bool _familyLoaded = false;
  bool _membersLoaded = false;

  // Parent PIN state: value + "have we loaded it yet?"
  String? _parentPinHash; // from Family.parentPinHash
  bool _parentPinKnown = false;

  bool get bootLoaded => _familyLoaded && _membersLoaded;
  bool get parentPinLoaded => _parentPinKnown;

  // Active member selection for child dashboard/profile header
  String? _currentMemberId;
  Member? get currentMember {
    final id = _currentMemberId;
    if (id == null) return null;
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Hot lists (ValueNotifiers)
  // ───────────────────────────────────────────────────────────────────────────
  final ValueNotifier<List<Member>> membersVN = ValueNotifier<List<Member>>(
    <Member>[],
  );
  final ValueNotifier<List<Chore>> choresVN = ValueNotifier<List<Chore>>(
    <Chore>[],
  );
  final ValueNotifier<List<Assignment>> reviewQueueVN =
      ValueNotifier<List<Assignment>>(<Assignment>[]);
  final ValueNotifier<List<Assignment>> missedAssignmentsVN =
      ValueNotifier<List<Assignment>>(<Assignment>[]);

  // All "assigned" assignments for the current family (used for avatars / assign sheet)
  final ValueNotifier<List<Assignment>> familyAssignedVN =
      ValueNotifier<List<Assignment>>(<Assignment>[]);

  // All rewards available in the family store
  final ValueNotifier<List<Reward>> rewardsVN = ValueNotifier<List<Reward>>(
    <Reward>[],
  );

  // Legacy getters (keep older UI code compiling)
  List<Member> get members => membersVN.value;
  List<Member> get parents =>
      members.where((m) => m.role == FamilyRole.parent && m.active).toList();
  List<Chore> get chores => choresVN.value;
  List<Assignment> get reviewQueue => reviewQueueVN.value;
  List<Assignment> get familyAssigned => familyAssignedVN.value;
  List<Assignment> get missedAssignments => missedAssignmentsVN.value;
  List<Reward> _rewards = const [];
  bool _rewardsBootstrapped = false;

  List<Reward> get rewards => _rewards;
  bool get rewardsBootstrapped => _rewardsBootstrapped;

  // Kid-specific caches (child dashboard convenience)
  final Map<String, List<Assignment>> _kidAssigned =
      <String, List<Assignment>>{};
  final Map<String, List<Assignment>> _kidCompleted =
      <String, List<Assignment>>{};
  List<Assignment> assignedForKid(String memberId) =>
      _kidAssigned[memberId] ?? const [];
  List<Assignment> completedForKid(String memberId) =>
      _kidCompleted[memberId] ?? const [];
  final Set<String> _kidAssignmentsBootstrapped = <String>{};
  final Set<String> _unlockedKidIds = <String>{};

  bool kidAssignmentsBootstrapped(String memberId) =>
      _kidAssignmentsBootstrapped.contains(memberId);

  bool _parentUnlocked = false;

  // ───────────────────────────────────────────────────────────────────────────
  // Subscriptions
  // ───────────────────────────────────────────────────────────────────────────
  StreamSubscription<User?>? _authSub;

  StreamSubscription<Family>? _familySub;
  StreamSubscription<List<Member>>? _membersSub;
  StreamSubscription<List<Chore>>? _choresSub;
  StreamSubscription<List<Assignment>>? _reviewSub;
  StreamSubscription<List<Assignment>>? _familyAssignedSub;
  StreamSubscription<List<Assignment>>? _missedSub;
  StreamSubscription<List<Assignment>>? _historyAssignmentsSub;
  StreamSubscription<List<Reward>>? _rewardsSub;
  StreamSubscription<List<RewardRedemption>>? _pendingRewardsSub;

  final Map<String, StreamSubscription<List<Assignment>>> _kidAssignedSubs = {};
  final Map<String, StreamSubscription<List<Assignment>>> _kidPendingSubs = {};
  final Map<String, StreamSubscription<List<Assignment>>> _kidCompletedSubs =
      {};
  final Map<String, StreamSubscription<List<RewardRedemption>>>
  _kidRewardRedemptionsSubs = {};

  // Today view caches for a kid
  final Map<String, List<Assignment>> _kidPending =
      <String, List<Assignment>>{};

  List<Assignment> pendingForKid(String memberId) =>
      _kidPending[memberId] ?? const [];

  final Map<String, List<RewardRedemption>> _pendingRewardsByMemberId =
      <String, List<RewardRedemption>>{};

  // Reward redemptions ("My Rewards") per kid
  final Map<String, List<RewardRedemption>> _kidRewardRedemptions =
      <String, List<RewardRedemption>>{};

  List<RewardRedemption> rewardRedemptionsForKid(String memberId) =>
      _kidRewardRedemptions[memberId] ?? const [];

  List<RewardRedemption> pendingRewardsForKid(String memberId) =>
      _pendingRewardsByMemberId[memberId] ?? const <RewardRedemption>[];

  /// Convenience: current kid's reward redemptions
  List<RewardRedemption> get currentKidRewardRedemptions {
    final m = currentMember;
    if (m == null) return const [];
    return rewardRedemptionsForKid(m.id);
  }
  
  // ───────────────────────────────────────────────────────────────────────────
  // Teardown / dispose
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _teardown() async {
    _firebaseUser = null;
    _user = null;
    _family = null;
    _familyId = null;
    _currentMemberId = null;
    _familyLoaded = false;
    _membersLoaded = false;
    _parentPinHash = null;
    _parentPinKnown = false;

    await _familySub?.cancel();
    await _membersSub?.cancel();
    await _choresSub?.cancel();
    await _reviewSub?.cancel();
    await _familyAssignedSub?.cancel();
    await _missedSub?.cancel();
    await _historyAssignmentsSub?.cancel();
    await _rewardsSub?.cancel();
    await _pendingRewardsSub?.cancel();

    _familySub = _membersSub = _choresSub = _reviewSub = _familyAssignedSub =
        _missedSub = _historyAssignmentsSub = _pendingRewardsSub = null;

    for (final s in _kidAssignedSubs.values) {
      await s.cancel();
    }
    for (final s in _kidPendingSubs.values) {
      await s.cancel();
    }
    for (final s in _kidCompletedSubs.values) {
      await s.cancel();
    }
    for (final s in _kidRewardRedemptionsSubs.values) {
      await s.cancel();
    }

    _kidAssignedSubs.clear();
    _kidPendingSubs.clear();
    _kidCompletedSubs.clear();
    _kidRewardRedemptionsSubs.clear();

    _kidAssigned.clear();
    _kidPending.clear();
    _kidCompleted.clear();
    _kidRewardRedemptions.clear();
    _pendingRewardsByMemberId.clear();
    _kidAssignmentsBootstrapped.clear();
    _unlockedKidIds.clear();

    _unlockedKidIds.clear();
    _parentUnlocked = false;

    _historyAssignments = const [];
    _historyWeekStart = null;

    membersVN.value = const [];
    choresVN.value = const [];
    reviewQueueVN.value = const [];
    familyAssignedVN.value = const [];
    rewardsVN.value = const [];

    _rewards = const [];
    _rewardsBootstrapped = false;

    await setViewMode(AppViewMode.parent);

    notifyListeners(); 

    await setViewMode(AppViewMode.parent);

    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _familySub?.cancel();
    _membersSub?.cancel();
    _choresSub?.cancel();
    _reviewSub?.cancel();
    _missedSub?.cancel();
    _historyAssignmentsSub?.cancel();
    _familyAssignedSub?.cancel();
    _rewardsSub?.cancel();
    _pendingRewardsSub?.cancel();

    for (final s in _kidAssignedSubs.values) {
      s.cancel();
    }
    for (final s in _kidCompletedSubs.values) {
      s.cancel();
    }
    for (final s in _kidPendingSubs.values) {
      s.cancel();
    }
    for (final s in _kidRewardRedemptionsSubs.values) {
      s.cancel();
    }

    membersVN.dispose();
    choresVN.dispose();
    reviewQueueVN.dispose();
    familyAssignedVN.dispose();
    rewardsVN.dispose();

    super.dispose();
  }
}