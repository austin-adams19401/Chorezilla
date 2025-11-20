library;

// lib/state/app_state.dart
import 'dart:async';
import 'package:chorezilla/models/award.dart';
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
    debugPrint('setCurrentMember: old=$_currentMemberId new=$memberId');

    if (_currentMemberId == memberId) return;
    if (_currentMemberId != null) stopKidStreams(_currentMemberId!);
    _currentMemberId = memberId;
    if (memberId != null) startKidStreams(memberId);
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Hot lists (ValueNotifiers)
  // ───────────────────────────────────────────────────────────────────────────
  final ValueNotifier<List<Member>> membersVN = ValueNotifier<List<Member>>(<Member>[]);
  final ValueNotifier<List<Chore>> choresVN = ValueNotifier<List<Chore>>(<Chore>[]);
  final ValueNotifier<List<Assignment>> reviewQueueVN = ValueNotifier<List<Assignment>>(<Assignment>[]);
  
    // All "assigned" assignments for the current family (used for avatars / assign sheet)
  final ValueNotifier<List<Assignment>> familyAssignedVN =
      ValueNotifier<List<Assignment>>(<Assignment>[]);


  // Legacy getters (keep older UI code compiling)
  List<Member> get members => membersVN.value;
  List<Member> get parents => members.where((m) => m.role == FamilyRole.parent && m.active).toList();
  List<Chore> get chores => choresVN.value;
  List<Assignment> get reviewQueue => reviewQueueVN.value;
  List<Assignment> get familyAssigned => familyAssignedVN.value;


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
    StreamSubscription<List<Assignment>>? _familyAssignedSub; 


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
    _reviewSub = _watchReviewQueue(familyId).listen((list) {
      reviewQueueVN.value = list;
      notifyListeners();
    });

        // Family-level "assigned" assignments (for avatars + assign sheet)
    _familyAssignedSub?.cancel();
    _familyAssignedSub =
        _watchAssignmentsForFamily(familyId, AssignmentStatus.assigned).listen((
          list,
        ) {
          familyAssignedVN.value = list;
          // No notifyListeners needed; widgets will use ValueListenableBuilder.
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
    if (famId == null) {
      debugPrint('KID_STREAMS: cannot start, no familyId.');
      return;
    }

    debugPrint('KID_STREAMS: starting for member=$memberId family=$famId');

    _kidAssignedSubs[memberId]?.cancel();
    _kidAssignedSubs[memberId] =
        _watchAssignmentsForKid(
          famId,
          memberId,
          AssignmentStatus.assigned,
        ).listen((list) {
          debugPrint('KID_STREAM_ASSIGNED[$memberId]: count=${list.length}');
          for (final a in list) {
            debugPrint(
              '  ASSIGNED[$memberId] aId=${a.id} status=${a.status} choreId=${a.choreId}',
            );
          }
          _kidAssigned[memberId] = list;
          notifyListeners(); // make sure this is here
        });

    _kidCompletedSubs[memberId]?.cancel();
    _kidCompletedSubs[memberId] =
        _watchAssignmentsForKid(
          famId,
          memberId,
          AssignmentStatus.completed,
        ).listen((list) {
          debugPrint('KID_STREAM_COMPLETED[$memberId]: count=${list.length}');
          for (final a in list) {
            debugPrint(
              '  COMPLETED[$memberId] aId=${a.id} status=${a.status} choreId=${a.choreId}',
            );
          }
          _kidCompleted[memberId] = list;
          notifyListeners(); // and here too
        });
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

  Stream<List<Assignment>> _watchReviewQueue(String familyId) {
    final db = FirebaseFirestore.instance;

    final q = db
        .collection('families')
        .doc(familyId)
        .collection('assignments')
        .where('requiresApproval', isEqualTo: true)
        .where('status', isEqualTo: 'pending') 
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
        return 'pending';
      case AssignmentStatus.rejected:
        return 'rejected';
    }
  }

    // Watch all assignments in a family for a given status (no member filter)
  Stream<List<Assignment>> _watchAssignmentsForFamily(
    String familyId,
    AssignmentStatus status,
  ) {
    final db = FirebaseFirestore.instance;
    final statusWire = _statusToWire(status);
    final q = db
        .collection('families')
        .doc(familyId)
        .collection('assignments')
        .where('status', isEqualTo: statusWire)
        .orderBy('due');

    return q.snapshots().map((s) => s.docs.map(Assignment.fromDoc).toList());
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

  Future<void> createChore({
    required String title,
    String? description,
    String? iconKey,
    required int difficulty,
    Recurrence? recurrence,
    bool requiresApproval = true,
  }) async {
    final famId = _familyId!;
    final db = FirebaseFirestore.instance;
    final choresRef = db
        .collection('families')
        .doc(famId)
        .collection('chores')
        .doc();

    final points =
        _family?.settings.difficultyToXP[difficulty] ??
        (difficulty.clamp(1, 5) * 10);

    await choresRef.set({
      'title': title,
      'description': description,
      'icon': iconKey,
      'difficulty': difficulty,
      'points': points,
      'active': true,
      'recurrence': recurrence?.toMap(),
      'requiresApproval': requiresApproval,
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
    bool requiresApproval = true,
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
      requiresApproval: requiresApproval,
    );
  }


    /// Delete a chore template and all its assignments (no orphan docs).
  Future<void> deleteChore(String choreId) async {
    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when calling deleteChore');
    }

    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final choreRef = famRef.collection('chores').doc(choreId);
    final assignmentsRef = famRef.collection('assignments');

    debugPrint('DELETE_CHORE: famId=$famId choreId=$choreId');

    // Delete all assignments for this chore in batches to be safe
    const batchSize = 200;
    while (true) {
      final snap = await assignmentsRef
          .where('choreId', isEqualTo: choreId)
          .limit(batchSize)
          .get();

      if (snap.docs.isEmpty) {
        break;
      }

      final batch = db.batch();
      for (final doc in snap.docs) {
        debugPrint('DELETE_CHORE: deleting assignment ${doc.id}');
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Finally delete the chore doc itself
    await choreRef.delete();
    debugPrint('DELETE_CHORE: chore $choreId deleted.');
  }


  /// This uses the `defaultAssignees` list stored on the Chore template,
  /// not the per-day Assignment docs. That way avatars stay stable even
  /// when today's instance moves from assigned → pending → approved.
  Set<String> assignedMemberIdsForChore(String choreId) {
    try {
      final chore = chores.firstWhere((c) => c.id == choreId);
      return chore.defaultAssignees.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Return the Member objects corresponding to this chore's default assignees.
  List<Member> assignedMembersForChore(String choreId) {
    final ids = assignedMemberIdsForChore(choreId);
    if (ids.isEmpty) return const <Member>[];

    return members.where((m) => ids.contains(m.id)).toList();
  }


  /// Remove assignment(s) for these member ids for a chore.
  ///
  /// We look at the in-memory `familyAssignedVN` list (which only contains
  /// status == 'assigned') and delete those docs by id.
  Future<void> unassignChore({
    required String choreId,
    required Set<String> memberIds,
  }) async {
    if (memberIds.isEmpty) return;

    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when calling unassignChore');
    }
    

    // Find the currently-assigned docs we need to remove.
    final toDelete = familyAssignedVN.value
        .where((a) => a.choreId == choreId && memberIds.contains(a.memberId))
        .toList();

    if (toDelete.isEmpty) {
      debugPrint(
        'unassignChore: nothing to delete for chore=$choreId members=$memberIds',
      );
      return;
    }

    final db = FirebaseFirestore.instance;
    final col = db.collection('families').doc(famId).collection('assignments');

    final batch = db.batch();
    for (final a in toDelete) {
      // NOTE: if your Assignment model uses a different id field name,
      // e.g. `assignmentId`, change `a.id` accordingly.
      batch.delete(col.doc(a.id));
    }
    await batch.commit();
  }

Future<void> assignChore({
    required String choreId,
    required Iterable<String> memberIds,
    required DateTime due,
  }) async {
    final famId = _familyId;
    if (famId == null) {
      debugPrint('ASSIGN_CHORE: no familyId set!');
      throw StateError('No family selected when calling assignChore');
    }

    debugPrint(
      'ASSIGN_CHORE: famId=$famId choreId=$choreId memberIds=$memberIds',
    );

    final fam = family!;
    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final assignmentsRef = famRef.collection('assignments');

    // Find the chore template
    final chore = chores.firstWhere(
      (c) => c.id == choreId,
      orElse: () {
        debugPrint('ASSIGN_CHORE: chore $choreId not found in chores list!');
        throw Exception('Chore not found');
      },
    );

    // Avoid duplicate assignments for same chore/kid combo
    final ids = memberIds.toSet();
    debugPrint('ASSIGN_CHORE: unique memberIds=$ids');

    final alreadyAssigned = assignedMemberIdsForChore(choreId);
    debugPrint('ASSIGN_CHORE: alreadyAssignedIdsForChore=$alreadyAssigned');

    final targetIds = ids.difference(alreadyAssigned);
    debugPrint('ASSIGN_CHORE: targetIds(after diff)=$targetIds');

    if (targetIds.isEmpty) {
      debugPrint('ASSIGN_CHORE: nothing new to assign, returning early.');
      return;
    }

    final mems = members.where((m) => targetIds.contains(m.id)).toList();
    debugPrint(
      'ASSIGN_CHORE: resolved mems=${mems.map((m) => '${m.id}:${m.displayName}').toList()}',
    );

    if (mems.isEmpty) {
      debugPrint('ASSIGN_CHORE: no valid members found, throwing.');
      throw Exception('No valid members selected');
    }

    // Use your award helper
    final award = calcAwards(
      difficulty: chore.difficulty,
      settings: fam.settings,
    );
    debugPrint('ASSIGN_CHORE: award xp=${award.xp} coins=${award.coins}');

    final normalizedDue = DateTime(due.year, due.month, due.day);

    final batch = db.batch();
    for (final m in mems) {
      final aRef = assignmentsRef.doc();
      debugPrint(
        'ASSIGN_CHORE: creating doc=${aRef.id} for member=${m.id} (${m.displayName})',
      );

      batch.set(aRef, {
        'familyId': famId,
        'choreId': chore.id,
        'choreTitle': chore.title,
        'choreIcon': chore.icon,
        'memberId': m.id,
        'memberName': m.displayName,
        'difficulty': chore.difficulty,
        'xp': award.xp,
        'coinAward': award.coins,
        'requiresApproval': chore.requiresApproval,
        'status': 'assigned', // key for kid streams & home tab
        'due': Timestamp.fromDate(normalizedDue),
        'assignedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('ASSIGN_CHORE: batch committed ${mems.length} docs.');

    try {
      // Find the latest in-memory copy of this chore
      final currentChore = chores.firstWhere((c) => c.id == choreId);

      // Existing defaults + newly assigned kids
      final existingDefaults = currentChore.defaultAssignees.toSet();
      final updatedDefaults = {...existingDefaults, ...ids};

      // If nothing actually changed, skip the write
      if (updatedDefaults.length == existingDefaults.length) {
        return;
      }

      await updateChoreDefaultAssignees(
        choreId: choreId,
        memberIds: updatedDefaults.toList(),
      );
    } catch (e) {
      debugPrint('ASSIGN_CHORE: failed to update defaultAssignees: $e');
    }
  }


  Future<void> updateChoreDefaultAssignees({
    required String choreId,
    required List<String> memberIds,
    }) async {
      await repo.updateChoreDefaultAssignees(familyId!, choreId: choreId, memberIds: memberIds);
      // Optional: refresh caches if you keep a local chores list
    }

Future<void> completeAssignment(String assignmentId) async {
    final famId = _familyId;
    if (famId == null) {
      throw StateError('No family selected when calling completeAssignment');
    }

    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final aRef = famRef.collection('assignments').doc(assignmentId);

    // 1) Load the assignment so we can get choreId + memberId
    final snap = await aRef.get();
    if (!snap.exists) {
      throw StateError('Assignment $assignmentId not found');
    }

    final assignment = Assignment.fromDoc(snap);

    // 2) Log completion via the repo "events" function
    const dayStartHour = 4; // TODO: wire to settings later if you want
    await repo.completeAssignment(
      familyId: famId,
      choreId: assignment.choreId,
      memberId: assignment.memberId,
      dayStartHour: dayStartHour,
    );

    // 3) Update the assignment doc itself so streams/UI move it out of "To Do"
    final statusWire = assignment.requiresApproval ? 'pending' : 'completed';

    await aRef.update({
      'status': statusWire,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveAssignment(String assignmentId, {String? parentMemberId}) async {
    final famId = _familyId!;
    await repo.approveAssignment(famId, assignmentId, parentMemberId: parentMemberId);
  }

  Future<void> rejectAssignment(String assignmentId, {String reason = ''}) async {
    final famId = _familyId!;
    await repo.rejectAssignment(famId, assignmentId, reason: reason);
  }
  

  // ───────────────────────────────────────────────────────────────────────────
  // Recurring Assignment Creation Helpers
  // ───────────────────────────────────────────────────────────────────────────

    Member? _findMemberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool _choreOccursOnDate(Chore chore, DateTime date) {
    final r = chore.recurrence;
    if (r == null) {
      // No recurrence → we won't auto-generate; assignments must be manual.
      return false;
    }

    switch (r.type) {
      case 'daily':
        return true;

      case 'weekly':
      case 'custom':
        final days = r.daysOfWeek;
        if (days == null || days.isEmpty) return false;
        // DateTime.weekday: 1=Mon .. 7=Sun (Mon=1)
        return days.contains(date.weekday);

      case 'once':
      default:
        // For now we don't auto-generate "once" chores;
        // you can add date-based logic later.
        return false;
    }
  }

    /// Ensure that for today's date, each default assignee of each recurring chore
  /// has an Assignment doc (status = 'assigned').
  ///
  /// Idempotent: safe to call multiple times. It checks existing assignments
  /// with due == today and only creates missing ones.
  Future<void> ensureAssignmentsForToday() async {
    final famId = _familyId;
    final fam = _family;
    if (famId == null || fam == null) {
      debugPrint('ensureAssignmentsForToday: no family loaded, skipping.');
      return;
    }

    final db = FirebaseFirestore.instance;
    final famRef = db.collection('families').doc(famId);
    final assignmentsRef = famRef.collection('assignments');

    // Normalize "today" to a date-only value (midnight).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTs = Timestamp.fromDate(today);

    debugPrint('ensureAssignmentsForToday: famId=$famId date=$today');

    // 1) Load all assignments that are already due today.
    final existingSnap = await assignmentsRef
        .where('due', isEqualTo: todayTs)
        .get();

    // Map: choreId -> set of memberIds that already have an assignment today.
    final Map<String, Set<String>> existingByChore = {};
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      final choreId = data['choreId'] as String? ?? '';
      final memberId = data['memberId'] as String? ?? '';
      if (choreId.isEmpty || memberId.isEmpty) continue;
      existingByChore.putIfAbsent(choreId, () => <String>{}).add(memberId);
    }

    int createdCount = 0;
    final batch = db.batch();

    for (final chore in chores) {
      if (!chore.active) continue;
      if (!_choreOccursOnDate(chore, today)) continue;
      if (chore.defaultAssignees.isEmpty) continue;

      final alreadyForChore = existingByChore[chore.id] ?? const <String>{};

      for (final memberId in chore.defaultAssignees) {
        if (alreadyForChore.contains(memberId)) {
          // This kid already has today's assignment for this chore.
          continue;
        }

        final member = _findMemberById(memberId);
        if (member == null) {
          debugPrint(
            'ensureAssignmentsForToday: member $memberId not found, skipping.',
          );
          continue;
        }

        // Use your Award helper to compute XP + coins.
        final award = calcAwards(
          difficulty: chore.difficulty,
          settings: fam.settings,
        );

        final aRef = assignmentsRef.doc();
        batch.set(aRef, {
          'familyId': famId,
          'choreId': chore.id,
          'choreTitle': chore.title,
          'choreIcon': chore.icon,
          'memberId': member.id,
          'memberName': member.displayName,
          'difficulty': chore.difficulty,
          'xp': award.xp,
          'coinAward': award.coins,
          'requiresApproval': chore.requiresApproval,
          'status': 'assigned',
          'due': todayTs,
          'assignedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        createdCount++;
      }
    }

    if (createdCount == 0) {
      debugPrint('ensureAssignmentsForToday: no new assignments needed.');
      return;
    }

    await batch.commit();
    debugPrint(
      'ensureAssignmentsForToday: created $createdCount new assignments for $today.',
    );
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
    await _familyAssignedSub?.cancel();

    _familySub = _membersSub = _choresSub = _reviewSub = _familyAssignedSub = null;

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
    familyAssignedVN.value = const [];

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
  
  void stopKidStreams(String s) {}
}