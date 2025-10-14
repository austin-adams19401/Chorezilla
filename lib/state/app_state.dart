// -------------------------------------------------------
// Responsibilities:
//  - Listen to FirebaseAuth and bootstrap user+family via FamilyRepo.ensureUserProfile
//  - Hold in-memory UI state (family, members, chores, per-kid assignment lists)
//  - Expose streams via ChangeNotifier (widgets use context.watch<AppState>())
//  - Delegate ALL Firestore reads/writes to FamilyRepo
//
// Usage:
//   final app = context.watch<AppState>();
//   if (!app.isReady) return CircularProgressIndicator();
//   final kids = app.kids; final chores = app.chores; ...
//
// Wiring (in main.dart):
//   ChangeNotifierProvider(
//     create: (_) => AppState(
//       repo: FamilyRepo(db: FirebaseFirestore.instance),
//       auth: FirebaseAuth.instance,
//     )..attachAuthListener(),
//     child: MyApp(),
//   );
//
import 'dart:async';
import 'package:chorezilla/firebase_queries/family_repo.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/common.dart';
import '../models/user_profile.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../models/chore.dart';
import '../models/assignment.dart';
import '../models/reward.dart';

// -------------------------------------------------------
// AppState
// -------------------------------------------------------
class AppState extends ChangeNotifier {
  AppState({required this.repo, required this.auth});

  // Dependencies
  final FamilyRepo repo;
  final FirebaseAuth auth;

  // ---------- Auth+Bootstrap ----------
  UserProfile? _user;
  String? _familyId;
  Family? _family;

  UserProfile? get user => _user;
  String? get familyId => _familyId;
  Family? get family => _family;
  bool get isReady => _user != null && _familyId != null && _family != null;

  // ---------- Family-scoped live data ----------
  List<Member> _members = const [];
  List<Chore> _chores = const [];
  List<Assignment> _reviewQueue = const [];
  List<Reward> _rewards = const [];

  List<Member> get members => _members;
  List<Member> get kids => _members.where((m) => m.role == FamilyRole.child).toList(growable: false);
  List<Member> get parents => _members.where((m) => m.role == FamilyRole.parent).toList(growable: false);

  List<Chore> get chores => _chores;
  List<Assignment> get reviewQueue => _reviewQueue;
  List<Reward> get rewards => _rewards;

  // Per-kid assignment buckets
  final Map<String, List<Assignment>> _kidAssigned = {};  // status=assigned
  final Map<String, List<Assignment>> _kidCompleted = {}; // status=completed

  List<Assignment> assignedForKid(String memberId) => _kidAssigned[memberId] ?? const [];
  List<Assignment> completedForKid(String memberId) => _kidCompleted[memberId] ?? const [];

  // ---------- UI prefs ----------
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  String? _currentMemberId;
  String? get currentMemberId => _currentMemberId;
  Member? get currentMember => _members.firstWhere(
        (m) => m.id == _currentMemberId,
        orElse: () => _members.isEmpty ? null as Member : _members.first,
      );

  void setCurrentMember(String? memberId) {
    _currentMemberId = memberId;
    notifyListeners();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('themeMode');
    if (s == 'dark') _themeMode = ThemeMode.dark;
    if (s == 'light') _themeMode = ThemeMode.light;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      _ => 'system',
    });
    notifyListeners();
  }

  // ---------- Subscriptions ----------
  StreamSubscription? _authSub;
  StreamSubscription? _familySub;
  StreamSubscription? _membersSub;
  StreamSubscription? _choresSub;
  StreamSubscription? _reviewSub;
  StreamSubscription? _rewardsSub;
  final Map<String, StreamSubscription> _assignedSubs = {};
  final Map<String, StreamSubscription> _completedSubs = {};

  String? _lastError;
  String? get lastError => _lastError;
  void _setError(Object e) { _lastError = e.toString(); notifyListeners(); }

  // -------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------
  void attachAuthListener() {
    _authSub?.cancel();
    _authSub = auth.authStateChanges().listen((u) async {
      if (u == null) { await _reset(); return; }
      try {
        final profile = await repo.ensureUserProfile(
          u.uid, displayName: u.displayName, email: u.email,
        );
        _user = profile;
        _familyId = profile.defaultFamilyId;
        notifyListeners();

        if (_familyId != null) {
          _startFamilyStreams(_familyId!);
        }
      } catch (e) {
        _setError(e);
      }
    });
  }

  Future<void> _reset() async {
    await _familySub?.cancel();
    await _membersSub?.cancel();
    await _choresSub?.cancel();
    await _reviewSub?.cancel();
    await _rewardsSub?.cancel();
    for (final s in _assignedSubs.values) { await s.cancel(); }
    for (final s in _completedSubs.values) { await s.cancel(); }
    _assignedSubs.clear(); _completedSubs.clear();

    _user = null; _familyId = null; _family = null;
    _members = const []; _chores = const []; _reviewQueue = const []; _rewards = const [];
    _kidAssigned.clear(); _kidCompleted.clear();
    _currentMemberId = null;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _familySub?.cancel();
    _membersSub?.cancel();
    _choresSub?.cancel();
    _reviewSub?.cancel();
    _rewardsSub?.cancel();
    for (final s in _assignedSubs.values) { s.cancel(); }
    for (final s in _completedSubs.values) { s.cancel(); }
    super.dispose();
  }

  Future<void> refreshAfterProfileChange() async {
    final u = auth.currentUser;
    if (u == null) return;
    final profile = await repo.ensureUserProfile(u.uid, displayName: u.displayName, email: u.email);
    _user = profile;
    _familyId = profile.defaultFamilyId;
    if (_familyId != null) {
      _startFamilyStreams(_familyId!);
    }
    notifyListeners();
  }


  // -------------------------------------------------------
  // Streams
  // -------------------------------------------------------
  void _startFamilyStreams(String familyId) {
    _familySub?.cancel();
    _familySub = repo.watchFamily(familyId).listen(
      (f) { _family = f; notifyListeners(); },
      onError: _setError,
    );

    _membersSub?.cancel();
    _membersSub = repo.watchMembers(familyId).listen(
      (list) { _members = list; notifyListeners(); },
      onError: _setError,
    );

    _choresSub?.cancel();
    _choresSub = repo.watchChores(familyId).listen(
      (list) { _chores = list; notifyListeners(); },
      onError: _setError,
    );

    _reviewSub?.cancel();
    _reviewSub = repo.watchReviewQueue(familyId).listen(
      (list) { _reviewQueue = list; notifyListeners(); },
      onError: _setError,
    );

    _rewardsSub?.cancel();
    _rewardsSub = repo.watchRewards(familyId).listen(
      (list) { _rewards = list; notifyListeners(); },
      onError: _setError,
    );
  }

  // Call when entering/leaving a kid dashboard
  void startKidStreams(String memberId) {
    final famId = _familyId; if (famId == null) return;
    if (_assignedSubs.containsKey(memberId)) return;

    _assignedSubs[memberId] = repo
        .watchAssignmentsForMember(famId, memberId: memberId, statuses: const [AssignmentStatus.assigned])
        .listen((list) { _kidAssigned[memberId] = list; notifyListeners(); }, onError: _setError);

    _completedSubs[memberId] = repo
        .watchAssignmentsForMember(famId, memberId: memberId, statuses: const [AssignmentStatus.completed])
        .listen((list) { _kidCompleted[memberId] = list; notifyListeners(); }, onError: _setError);
  }

  void stopKidStreams(String memberId) {
    _assignedSubs.remove(memberId)?.cancel();
    _completedSubs.remove(memberId)?.cancel();
    _kidAssigned.remove(memberId);
    _kidCompleted.remove(memberId);
    notifyListeners();
  }

  // -------------------------------------------------------
  // Commands (thin wrappers around FamilyRepo)
  // -------------------------------------------------------
  Future<String> addChild({required String name, String? avatarKey, String? pinHash}) async {
    final famId = _familyId!; // isReady precondition
    return repo.addChild(famId, displayName: name, avatarKey: avatarKey, pinHash: pinHash);
  }

  Future<void> updateMember(String memberId, Map<String, dynamic> patch) async {
    final famId = _familyId!;
    await repo.updateMember(famId, memberId, patch);
  }

  Future<String> ensureJoinCode() async {
    final famId = _familyId!;
    return repo.ensureJoinCode(famId);
  }

  Future<String?> redeemJoinCode(String code) async {
    return repo.redeemJoinCode(code);
  }

  Future<String> createChore({
    required String title,
    String? description,
    String? iconKey,
    required int difficulty,
    Recurrence? recurrence,
  }) async {
    final fam = _family; if (fam == null) throw Exception('Family not ready');
    final creatorId = parents.isNotEmpty ? parents.first.id : null;
    return repo.createChoreTemplate(
      fam.id,
      title: title,
      description: description,
      iconKey: iconKey,
      difficulty: difficulty,
      settings: fam.settings,
      createdByMemberId: creatorId,
      recurrence: recurrence,
    );
  }

  Future<void> assignChore({
    required String choreId,
    required Iterable<String> memberIds,
    required DateTime due,
  }) async {
    final famId = _familyId!;
    final chore = _chores.firstWhere((c) => c.id == choreId);
    final mems = _members.where((m) => memberIds.contains(m.id)).toList();
    await repo.assignChoreToMembers(famId, chore: chore, members: mems, due: due);
  }

  Future<void> completeAssignment(String assignmentId, {String? note, String? photoUrl}) async {
    final famId = _familyId!;
    await repo.completeAssignment(famId, assignmentId, note: note, photoUrl: photoUrl);
  }

  Future<void> approveAssignment(String assignmentId, {String? parentMemberId}) async {
    final famId = _familyId!;
    await repo.approveAssignment(famId, assignmentId, parentMemberId: parentMemberId);
  }

  Future<void> rejectAssignment(String assignmentId, {String? reason, String? parentMemberId}) async {
    final famId = _familyId!;
    await repo.rejectAssignment(famId, assignmentId, parentMemberId: parentMemberId, reason: reason);
  }

  Future<String> createReward({required String name, required int priceCoins, int? stock}) async {
    final famId = _familyId!;
    return repo.createReward(famId, name: name, priceCoins: priceCoins, stock: stock);
  }

  Future<void> purchaseReward({required String memberId, required Reward reward}) async {
    final famId = _familyId!;
    await repo.purchaseReward(famId, memberId: memberId, reward: reward);
  }
}
