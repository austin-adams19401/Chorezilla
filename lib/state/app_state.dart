// lib/state/app_state.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Adjust these paths to your project layout if needed
import 'package:chorezilla/firebase_queries/family_repo.dart' as repo_file;
import 'package:chorezilla/models/user_profile.dart';
import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/models/common.dart';

/// Central app state.
/// - Slow/structural state stays on this ChangeNotifier (user/family/theme).
/// - Fast-changing lists are exposed via ValueNotifiers so only consumers of
///   those lists rebuild (reduces jank & GC).
class AppState extends ChangeNotifier {
  AppState({
    required this.auth,
    required this.repo,
    ThemeMode initialThemeMode = ThemeMode.system,
  })  : _themeMode = initialThemeMode {
    // Attach by default (main.dart may also call attachAuthListener(), which is idempotent)
    _authSub = auth.authStateChanges().listen(_onAuthChanged);

    // Hot-reload / already signed-in case
    final u = auth.currentUser;
    if (u != null) {
      _bootstrapForUser(u);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dependencies
  // ───────────────────────────────────────────────────────────────────────────
  final FirebaseAuth auth;
  final repo_file.FamilyRepo repo;

  // ───────────────────────────────────────────────────────────────────────────
  // Theme
  // ───────────────────────────────────────────────────────────────────────────
  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // User & Family (rare changes)
  // ───────────────────────────────────────────────────────────────────────────
  UserProfile? _user;
  UserProfile? get user => _user;

  String? _familyId;
  String? get familyId => _familyId;

  Family? _family;
  Family? get family => _family;

  bool get isReady => auth.currentUser != null && _familyId != null && _family != null;
  // Boot flags to avoid false "setup" routing during hot restart
  bool _familyLoaded = false;
  bool _membersLoaded = false;
  bool get bootLoaded => _familyLoaded && _membersLoaded;


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

  void setCurrentMember(String? memberId) {
    if (_currentMemberId == memberId) return;
    // Stop previous kid streams
    if (_currentMemberId != null) stopKidStreams(_currentMemberId!);
    _currentMemberId = memberId;
    // Start new
    if (memberId != null) startKidStreams(memberId);
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Hot lists (ValueNotifiers)
  // ───────────────────────────────────────────────────────────────────────────
  final ValueNotifier<List<Member>> membersVN = ValueNotifier<List<Member>>(<Member>[]);
  final ValueNotifier<List<Chore>> choresVN = ValueNotifier<List<Chore>>(<Chore>[]);
  final ValueNotifier<List<Assignment>> reviewQueueVN = ValueNotifier<List<Assignment>>(<Assignment>[]);

  // Legacy getters (keep older UI code compiling)
  List<Member> get members => membersVN.value;
  List<Member> get parents => members.where((m) => m.role == FamilyRole.parent && m.active).toList();
  List<Chore> get chores => choresVN.value;
  List<Assignment> get reviewQueue => reviewQueueVN.value;

  // Kid-specific caches (child dashboard convenience)
  final Map<String, List<Assignment>> _kidAssigned = <String, List<Assignment>>{};
  final Map<String, List<Assignment>> _kidCompleted = <String, List<Assignment>>{};
  List<Assignment> assignedForKid(String memberId) => _kidAssigned[memberId] ?? const [];
  List<Assignment> completedForKid(String memberId) => _kidCompleted[memberId] ?? const [];

  // ───────────────────────────────────────────────────────────────────────────
  // Subscriptions
  // ───────────────────────────────────────────────────────────────────────────
  StreamSubscription<User?>? _authSub;

  StreamSubscription<Family>? _familySub;
  StreamSubscription<List<Member>>? _membersSub;
  StreamSubscription<List<Chore>>? _choresSub;
  StreamSubscription<List<Assignment>>? _reviewSub;

  final Map<String, StreamSubscription<List<Assignment>>> _kidAssignedSubs = {};
  final Map<String, StreamSubscription<List<Assignment>>> _kidCompletedSubs = {};

  // Allow main.dart to call this explicitly; safe to call more than once.
  void attachAuthListener() {
    _authSub ??= auth.authStateChanges().listen(_onAuthChanged);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Auth flow
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _onAuthChanged(User? u) async {
    if (u == null) {
      await _teardown();
      return;
    }
    await _bootstrapForUser(u);
  }

  Future<void> _bootstrapForUser(User u) async {
    // 1) Ensure profile exists & fetch it
    final profile = await repo.ensureUserProfile(
      u.uid,
      displayName: u.displayName,
      email: u.email,
    );
    _user = profile;

    // 2) Decide current family; if none, create a new family + owner membership
    String? famId = profile.defaultFamilyId;
    famId ??= await _createFamilyWithOwner(u);

    // 3) Bind streams if changed
    if (_familyId != famId) {
      _familyId = famId;
      _startFamilyStreams(famId);
    }

    notifyListeners(); // structural change (user/family)
  }

  // Create a family + owner member, and set defaultFamilyId on user
  Future<String> _createFamilyWithOwner(User u) async {
    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc();
    final ownerName = u.displayName?.trim().isNotEmpty == true ? u.displayName!.trim() : 'Parent';
    final familyName = '${ownerName.split(' ').first} Family';

    final memberRef = famRef.collection('members').doc(); // auto id for member

    final userRef = db.collection('users').doc(u.uid);

    final batch = db.batch();
    batch.set(famRef, {
      'name': familyName,
      'ownerUid': u.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'settings': {
        'pointsPerDifficulty': {
          '1': 10, '2': 20, '3': 35, '4': 55, '5': 80,
        }
      },
      'active': true,
    }, SetOptions(merge: true));

    batch.set(memberRef, {
      'userId': u.uid,
      'displayName': ownerName,
      'role': 'parent',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // store defaultFamilyId on the user profile so next boot picks it
    batch.set(userRef, {
      'defaultFamilyId': famRef.id,
    }, SetOptions(merge: true));

    await batch.commit();
    return famRef.id;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Family streams (bind once per family)
  // ───────────────────────────────────────────────────────────────────────────
  void _startFamilyStreams(String familyId) {
    // Reset boot flags whenever we bind to a (new) family
    _familyLoaded = false;
    _membersLoaded = false;

    // Family doc (rare changes — name/settings)
    _familySub?.cancel();
    _familySub = repo.watchFamily(familyId).listen((fam) {
      _family = fam;
      if (!_familyLoaded) {
        _familyLoaded = true;
        notifyListeners(); // notify once when family is first loaded
      } else {
        notifyListeners(); // fine: a few widgets read name/settings
      }
    });

    // Members (hot list)
    _membersSub?.cancel();
    _membersSub = repo.watchMembers(familyId).listen((list) {
      membersVN.value = list;
      if (!_membersLoaded) {
        _membersLoaded = true;
        notifyListeners(); // let router know members are ready
      }
    });

    // Chores (hot list)
    _choresSub?.cancel();
    _choresSub = repo.watchChores(familyId).listen((list) {
      choresVN.value = list;
    });

    // Review queue (completed awaiting approval)
    _reviewSub?.cancel();
    _reviewSub = repo.watchReviewQueue(familyId).listen((list) {
      reviewQueueVN.value = list;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Assignment streams
  // ───────────────────────────────────────────────────────────────────────────



  // ───────────────────────────────────────────────────────────────────────────
  // Kid streams (implemented here with Firestore to avoid repo mismatches)
  // ───────────────────────────────────────────────────────────────────────────
  void startKidStreams(String memberId) {
    final famId = _familyId;
    if (famId == null) return;

    _kidAssignedSubs[memberId]?.cancel();
    _kidAssignedSubs[memberId] = _watchAssignmentsForKid(famId, memberId, AssignmentStatus.assigned).listen((list) {
      _kidAssigned[memberId] = list;
    });

    _kidCompletedSubs[memberId]?.cancel();
    _kidCompletedSubs[memberId] = _watchAssignmentsForKid(famId, memberId, AssignmentStatus.completed).listen((list) {
      _kidCompleted[memberId] = list;
    });
  }

  void stopKidStreams(String memberId) {
    _kidAssignedSubs.remove(memberId)?.cancel();
    _kidCompletedSubs.remove(memberId)?.cancel();
    _kidAssigned.remove(memberId);
    _kidCompleted.remove(memberId);
  }

  Stream<List<Assignment>> _watchAssignmentsForKid(
    String familyId,
    String memberId,
    AssignmentStatus status,
  ) {
    final db = FirebaseFirestore.instance;
    final statusWire = _statusToWire(status); // stored as string
    final q = db
        .collection('families')
        .doc(familyId)
        .collection('assignments')
        .where('memberId', isEqualTo: memberId)
        .where('status', isEqualTo: statusWire)
        .orderBy('due');

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
  }

  String _statusToWire(AssignmentStatus s) {
    switch (s) {
      case AssignmentStatus.assigned:
        return 'assigned';
      case AssignmentStatus.completed:
        return 'completed';
      case AssignmentStatus.approved:
        return 'approved';
      case AssignmentStatus.rejected:
        return 'rejected';
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Profile & family helpers
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> refreshAfterProfileChange() async {
    final u = auth.currentUser;
    if (u == null) return;
    final profile = await repo.ensureUserProfile(u.uid, displayName: u.displayName, email: u.email);
    _user = profile;
    if (_familyId != profile.defaultFamilyId && profile.defaultFamilyId != null) {
      _familyId = profile.defaultFamilyId;
      _startFamilyStreams(_familyId!);
    }
    notifyListeners();
  }

  // Invite helpers (forward to repo — you already added these)
  Future<String> ensureJoinCode() async {
    final famId = _familyId!;
    return repo.ensureJoinCode(famId);
  }

  Future<String?> redeemJoinCode(String code) {
    return repo.redeemJoinCode(code);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Writes
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> addChild({
    required String name,
    String? avatarKey,
    String? pinHash,
  }) async {
    final famId = _familyId!;
    await repo.addChild(
      famId, 
      displayName: name,
      avatarKey: avatarKey,
      pinHash: pinHash,
    );
  }

  Future<void> updateMember(String memberId, Map<String, dynamic> patch) async {
    final famId = _familyId!;
    await repo.updateMember(famId, memberId, patch);
  }

  Future<void> removeMember(String memberId) async {
    final famId = _familyId!;
    await repo.removeMember(famId, memberId);
  }

  /// Create chore template directly in Firestore (repo variant seems missing in your file).
  Future<void> createChore({
    required String title,
    String? description,
    String? iconKey,
    required int difficulty,
    Recurrence? recurrence,
  }) async {
    final famId = _familyId!;
    final db = FirebaseFirestore.instance;
    final choresRef = db.collection('families').doc(famId).collection('chores').doc();

    final points = _family?.settings.difficultyToXP[difficulty] ??
        (difficulty.clamp(1, 5) * 10);

    await choresRef.set({
      'title': title,
      'description': description,
      'icon': iconKey,
      'difficulty': difficulty,
      'points': points,
      'active': true,
      'recurrence': recurrence?.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateChore({
    required String choreId,
    required String title,
    String? description,
    String? iconKey,
    required int difficulty,
    Recurrence? recurrence,
  }) async {
    final fam = family!;
    await repo.updateChoreTemplate(
      fam.id,
      choreId: choreId,
      title: title,
      description: description,
      iconKey: iconKey,
      difficulty: difficulty,
      settings: fam.settings,
      recurrence: recurrence,
    );
  }


  Future<void> assignChore({
    required String choreId,
    required Iterable<String> memberIds,
    required DateTime due,
  }) async {
    final famId = _familyId!;
    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final assignmentsRef = famRef.collection('assignments');

    final chore = chores.firstWhere((c) => c.id == choreId, orElse: () => throw Exception('Chore not found'));
    final ids = memberIds.toSet();
    final mems = members.where((m) => ids.contains(m.id)).toList();
    if (mems.isEmpty) throw Exception('No valid members selected');

    final batch = db.batch();
    for (final m in mems) {
      final aRef = assignmentsRef.doc();
      batch.set(aRef, {
        'choreId': chore.id,
        'choreTitle': chore.title,
        'choreIcon': chore.icon,
        'memberId': m.id,
        'memberName': m.displayName,
        'status': 'assigned',
        'due': Timestamp.fromDate(DateTime(due.year, due.month, due.day)),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateChoreDefaultAssignees({
    required String choreId,
    required List<String> memberIds,
    }) async {
      await repo.updateChoreDefaultAssignees(familyId!, choreId: choreId, memberIds: memberIds);
      // Optional: refresh caches if you keep a local chores list
    }


  // Future<void> completeAssignment(String assignmentId, {String? note}) async {
  //   final famId = _familyId!;
  //   await repo.completeAssignment(famId, assignmentId, note: note);
  // }

  Future<void> approveAssignment(String assignmentId, {String? parentMemberId}) async {
    final famId = _familyId!;
    await repo.approveAssignment(famId, assignmentId, parentMemberId: parentMemberId);
  }

  Future<void> rejectAssignment(String assignmentId, {String reason = ''}) async {
    final famId = _familyId!;
    await repo.rejectAssignment(famId, assignmentId, reason: reason);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Teardown / dispose
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _teardown() async {
    _user = null;
    _family = null;
    _familyId = null;
    _currentMemberId = null;
    _familyLoaded = false;
    _membersLoaded = false;


    await _familySub?.cancel();
    await _membersSub?.cancel();
    await _choresSub?.cancel();
    await _reviewSub?.cancel();
    _familySub = _membersSub = _choresSub = _reviewSub = null;

    for (final s in _kidAssignedSubs.values) {
      await s.cancel();
    }
    for (final s in _kidCompletedSubs.values) {
      await s.cancel();
    }
    _kidAssignedSubs.clear();
    _kidCompletedSubs.clear();
    _kidAssigned.clear();
    _kidCompleted.clear();

    // Clear slices (doesn't notify by itself)
    membersVN.value = const [];
    choresVN.value = const [];
    reviewQueueVN.value = const [];

    notifyListeners(); // structural reset
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _familySub?.cancel();
    _membersSub?.cancel();
    _choresSub?.cancel();
    _reviewSub?.cancel();
    for (final s in _kidAssignedSubs.values) {
      s.cancel();
    }
    for (final s in _kidCompletedSubs.values) {
      s.cancel();
    }
    membersVN.dispose();
    choresVN.dispose();
    reviewQueueVN.dispose();
    super.dispose();
  }
}
