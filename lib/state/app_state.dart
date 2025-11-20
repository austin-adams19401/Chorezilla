library;

// lib/state/app_state.dart
import 'dart:async';
import 'package:chorezilla/models/common.dart';
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
import 'package:google_sign_in/google_sign_in.dart';

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

    debugPrint('STATE CONSTRUCTOR: possible user: user=${u?.uid} - ${u?.displayName}');
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
  AuthStatus authState = AuthStatus.unknown;
  User? _firebaseUser;
  User? get firebaseUser => _firebaseUser;

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
    debugPrint('ATTACHING AUTH LISTENER');
    _authSub ??= auth.authStateChanges().listen(_onAuthChanged);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Auth flow
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _onAuthChanged(User? u) async {
    debugPrint('AUTH CHANGED!');

    _firebaseUser = u;

    if (u == null) {
      debugPrint('AUTH CHANGED: user is null, teardown');
      await _teardown();
      return;
    }

    debugPrint('AUTH CHANGED: user=${u.uid} - ${u.displayName}');
    await _getDataForUser(u);

    // Ensure anyone watching AppState rebuilds after auth change
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();

      if (kIsWeb || !GoogleSignIn.instance.supportsAuthenticate()) {
        // Web or fallback path
        final provider = GoogleAuthProvider();
        final uc = await auth.signInWithPopup(provider);
        debugPrint(
          'GOOGLE SIGN IN: WEB user=${uc.user?.uid} - ${uc.user?.displayName}',
        );
        // No need to call _getDataForUser here; _onAuthChanged will fire.
        return;
      }

      final account = await GoogleSignIn.instance.authenticate();

      final authData = account.authentication;
      final idToken = authData.idToken;

      if (idToken == null) {
        debugPrint('Google returned no idToken. Check client IDs / platform setup.');
        return;
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCred = await auth.signInWithCredential(credential);

      debugPrint(
        'GOOGLE SIGN IN: user=${userCred.user?.uid} - ${userCred.user?.displayName}',
      );
    } on GoogleSignInException catch (e) {
      debugPrint('Google Sign-In error: ${e.code} ${e.description}');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth error: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('Unexpected Google sign-in error: $e');
    }
  }


//   Future<void> _postSignInBootstrap(User? user) async {
//   // if (user == null) return;
//   //   final db = FirebaseFirestore.instance;

//   //   final uid = user.uid;
//   //   final userRef = repo_file.userDoc(db, uid);
//   //   final now = FieldValue.serverTimestamp();

//   //   // 1) Upsert users/{uid} (UserProfile)
//   //   final snap = await userRef.get();
//   //   if (!snap.exists) {
//   //     await userRef.set({
//   //       'displayName': user.displayName,
//   //       'email': user.email,
//   //       'photoURL': user.photoURL,
//   //       'defaultFamilyId': null,
//   //       'memberships': {}, // familyId -> { memberId, role }
//   //       'createdAt': now,
//   //       'lastSignInAt': now,
//   //       'provider': 'google',
//   //     }, SetOptions(merge: true));
//   //   } else {
//   //     await userRef.set({'lastSignInAt': now, 'displayName': user.displayName, 'photoURL': user.photoURL}, SetOptions(merge: true));
//   //   }

//   // 2) Decide where to go (needs setup vs ready)
//   // final data = (await userRef.get()).data() as Map<String, dynamic>? ?? {};
//   // final String? defaultFamilyId = data['defaultFamilyId'] as String?;
//   // final Map<String, dynamic> memberships = (data['memberships'] as Map<String, dynamic>? ?? {});

//   // if ((defaultFamilyId == null || defaultFamilyId.isEmpty) && memberships.isEmpty) {
//   //   // New account → Setup
//   //   pendingSetupPrefill = SetupPrefill(
//   //     displayName: user.displayName,
//   //     email: user.email,
//   //     photoUrl: user.photoURL,
//   //   );
//   //   authState = AuthState.needsFamilySetup;
//   //   notifyListeners();
//   //   // Your router should show the Parent/Family Setup screen when authState==needsFamilySetup
//   // } else {
//   //   // Returning user with a family → proceed to home bootstrap
//   //   authState = AuthState.ready;
//   //   notifyListeners();
//   //   // Load family, members, chores, etc. (your existing watchers)
//   // }
// }

  Future<void> _getDataForUser(User u) async {
    // 1) Ensure profile exists & fetch it
    debugPrint('_getDataForUser: ${u.email} - ${u.displayName}');
    final profile = await repo.checkForUserProfile(u.uid, displayName: u.displayName, email: u.email);
    
    _user = profile;
    String? famId = profile.defaultFamilyId;

    debugPrint('_getDataForUser: email:${_user?.email} - name: ${_user?.displayName} - famId: $famId');

    if (_familyId != famId) {
      _familyId = famId;
    }

    if (famId != null && famId.isNotEmpty) {
      _startFamilyStreams(famId);
    }

    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Family streams (bind once per family)
  // ───────────────────────────────────────────────────────────────────────────
  void _startFamilyStreams(String familyId) {
    // Reset boot flags whenever we bind to a (new) family
    debugPrint('STARTING FAMILY STREAMS: famName: ${family?.name} - famId: $familyId');
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
      notifyListeners();
    });

    // Chores (hot list)
    _choresSub?.cancel();
    _choresSub = repo.watchChores(familyId).listen((list) {
      choresVN.value = list;
      notifyListeners();
    });

    // Review queue (completed awaiting approval)
    _reviewSub?.cancel();
    _reviewSub = repo.watchReviewQueue(familyId).listen((list) {
      reviewQueueVN.value = list;
      notifyListeners();
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
      case AssignmentStatus.pending:
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
    final profile = await repo.checkForUserProfile(u.uid, displayName: u.displayName, email: u.email);
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
    debugPrint('ADDING CHILD');
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
    _firebaseUser = null;
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