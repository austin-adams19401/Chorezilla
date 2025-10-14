// import 'dart:async';
// import 'dart:math';
// import 'dart:convert';
// import 'dart:io';
// import 'package:crypto/crypto.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';


// // ENUMS
// enum AuthState { unknown, signedOut, needsFamilySetup, ready }

// /// Simple id helper
// String _id() => DateTime.now().microsecondsSinceEpoch.toString();
// DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// DateTime _startOfWeek(DateTime d) {
//   final x = _dateOnly(d);
//   final diff = x.weekday - DateTime.monday; // 0..6
//   return x.subtract(Duration(days: diff));
// }

// class AppState extends ChangeNotifier {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;

//   AuthState _authState = AuthState.unknown;
//   AuthState get authState => _authState;

//   Map<String, dynamic>? _userDoc;
//   DocumentSnapshot<Map<String, dynamic>>? _familySnap;
//   StreamSubscription? _familySub;

//   String? get familyId => _userDoc?['familyId'];
//   Map<String , dynamic>? get family => _familySnap?.data();
//   Map<String, dynamic>? get userProfile => _userDoc;

//   String? _loadedUid;
//   bool _isLoading = false;
//   bool get isLoading => _isLoading;

//   Family? _family;
//   User? _user;

//   final List<Member> _members = [];
//   List<Member> get members => _members;

//   final List<Chore> _chores = [];
//   List<Chore> get chores => _chores;

//   String? _deviceIdHashCache;

//   Future<String> getDeviceIdHash() async {
//     if (_deviceIdHashCache != null) return _deviceIdHashCache!;
//     final info = DeviceInfoPlugin();
//     String base;

//     if (Platform.isAndroid) {
//       final a = await info.androidInfo;
//       base = '${a.manufacturer}|${a.model}|${a.id}|${a.hardware}|${a.device}';
//     } else if (Platform.isIOS) {
//       final i = await info.iosInfo;
//       base = '${i.name}|${i.systemName}|${i.model}|${i.identifierForVendor}';
//     } else {
//       // Fallback for web/desktop if you later support them
//       base = 'unknown-device';
//     }

//     _deviceIdHashCache = sha256.convert(utf8.encode(base)).toString();
//     return _deviceIdHashCache!;
//   }


//   void _onAuth(User? user) async {
//     _user = user;
//     _familySub?.cancel();
//     _familySub = null;
//     _familySnap = null;
//     _userDoc = null;
//     _members.clear();

//     if(user == null) {
//       _authState = AuthState.signedOut;
//       notifyListeners();
//       return;
//     }

//     final userRef = _db.collection('users').doc(user.uid);
//     final snap = await userRef.get();
//     _userDoc = snap.data();

//     final familyId = _userDoc?['familyId'];
//     if (familyId == null){
//       _authState = AuthState.needsFamilySetup;
//       notifyListeners();
//       return;
//     }

//     _familySub = _db.collection('families').doc(familyId)
//       .snapshots().listen((fam) {
//         _familySnap = fam;
//         _authState = AuthState.ready;
//         notifyListeners();
//       });
//   }

//   Future<void> logout() async {
//     await _familySub?.cancel();
//     _familySub = null;
//     _familySnap = null;
//     _userDoc = null;
//     _members.clear();
//     _authState = AuthState.signedOut;
//     notifyListeners();
//     await FirebaseAuth.instance.signOut();
//   }

//   AppState() {
//     _auth.authStateChanges().listen(_onAuth);
//   }

//     // 0-9 A-Z code (len=6 by default)
//   String _makeCode([int len = 6]) {
//     const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
//     final r = Random.secure();
//     return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
//   }

//   int pointsForDifficulty(int difficulty) {
//     switch (difficulty) {
//       case 1: return 5;
//       case 2: return 10;
//       case 3: return 20;
//       case 4: return 35;
//       case 5: return 55;
//       default: return 10;
//     }
//   }

//   Member? get currentProfile {
//   // 1) if a profile is selected, return that
//     if (_currentProfileId != null) {
//       final m = _members.firstWhere(
//         (e) => e.id == _currentProfileId,
//         //orElse: () => _members.isEmpty ? null as Member : _members.first,
//       );
//       return m;
//     }
//     // 2) otherwise prefer a member marked usesThisDevice
//     final devicePick = _members.where((m) => m.usesThisDevice).firstOrNull;
//     if (devicePick != null) return devicePick;

//     // 3) otherwise first member, or null if empty
//     return _members.firstOrNull;
//   }

//   // =========================
//   // Light / Dark Theme
//   // =========================
//   ThemeMode _themeMode = ThemeMode.system;
//   ThemeMode get themeMode => _themeMode;

//     Future<void> loadTheme() async {
//     final prefs = await SharedPreferences.getInstance();
//     final v = prefs.getString('themeMode');
//     _themeMode = switch (v) {
//       'light' => ThemeMode.light,
//       'dark'  => ThemeMode.dark,
//       _       => ThemeMode.system,
//     };
//     notifyListeners();
//   }

//   Future<void> setThemeMode(ThemeMode mode) async {
//     _themeMode = mode;
//     notifyListeners();

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('themeMode', switch (mode) {
//       ThemeMode.light => 'light',
//       ThemeMode.dark  => 'dark',
//       _               => 'system',
//     });
//     notifyListeners();
//   }

//   // ---------------- Family state ----------------
//   String? _currentProfileId;
//   String? get currentProfileId => _currentProfileId;

//   set family(Family? value) {
//     _family = value;
//     notifyListeners();
//   }

//   set members(List<Member> value) {
//     _members
//       ..clear()
//       ..addAll(value);
//     notifyListeners();
//   }

//   set currentProfileId(String? value) {
//     _currentProfileId = value;
//     notifyListeners();
//   }

//   /// Hydrate this AppState from Firestore for an existing family.
//   /// Loads family doc (name, createdAt) + members (including flags).
//   /// Returns true on success so UI can await and then render.
//   Future<bool> loadFamilyFromFirestore(String familyId) async {
//     try {
//       final db = FirebaseFirestore.instance;

//       // ----- Family doc -----
//       final famDoc = await db.collection('families').doc(familyId).get();
//       final famData = famDoc.data();
//       if (famData == null) return false;

//       final name = (famData['name'] as String?) ?? 'Family';
//       final createdAt = (famData['createdAt'] is Timestamp)
//           ? (famData['createdAt'] as Timestamp).toDate()
//           : DateTime.now();

//       _family = Family(
//         id: familyId,
//         name: name,
//         createdAt: createdAt,
//       );

//       // ----- Members -----
//       final memSnap = await db
//           .collection('families')
//           .doc(familyId)
//           .collection('members')
//           .get();

//       _members
//         ..clear()
//         ..addAll(memSnap.docs.map((d) {
//           final m = d.data();
//           final roleStr = ((m['role'] as String?) ?? 'child').toLowerCase();

//           return Member(
//             id: d.id,
//             familyId: familyId,
//             name: (m['name'] as String?) ?? 'Member',
//             avatar: (m['avatar'] as String?) ?? '👤',
//             role: roleStr == 'parent' ? MemberRole.parent : MemberRole.child,
//             // optional flags: default safely if missing
//             usesThisDevice: (m['usesThisDevice'] as bool?) ?? false,
//             requiresPin: (m['requiresPin'] as bool?) ?? false,
//             pin: (m['pin'] as String?),
//           );
//         }));

//       _currentProfileId = _members.isNotEmpty ? _members.first.id : null;

//       notifyListeners();
//       return true;
//     } catch (_) {
//       return false;
//     }
//   }

// Future<void> loadFor(User user) async {
//   if (_loadedUid == user.uid) return; // already loaded
//   _isLoading = true;
//   notifyListeners();
//   try {
//     // await _loadUserProfile(user.uid);
//     // await _loadFamily(user.uid);
//     // await _subscribeFamilyStreams(); // keep state fresh
//     _loadedUid = user.uid;
//   } finally {
//     _isLoading = false;
//     notifyListeners();
//   }
// }

//   /// Create a new family with an auto id & join code, write initial members,
// /// link current user as parent, hydrate local state, and return familyId.
// Future<String> createFamily({
//     required String familyName,
//     required List<Member> initialMembers,
//   }) async {
//     final db = FirebaseFirestore.instance;
//     final uid = FirebaseAuth.instance.currentUser!.uid;

//     // ids
//     final familyDoc = db.collection('families').doc(); // auto-id
//     final familyId = familyDoc.id;
//     final code = _makeCode(6);

//     // 1) families/{fid}
//     await familyDoc.set({
//       'name': familyName.trim().isEmpty ? 'Family' : familyName.trim(),
//       'code': code,
//       'createdBy': uid,
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     // 2) /joinCodes/{code} → fid
//     await db.collection('joinCodes').doc(code).set({
//       'familyId': familyId,
//       'createdBy': uid,
//       'createdAt': FieldValue.serverTimestamp(),
//     });

//     // 3) link /users/{uid}
//     await db.collection('users').doc(uid).set({
//       'familyId': familyId,
//       'role': 'parent',
//       'memberId': null,
//     }, SetOptions(merge: true));

//     // 4) members
//     final membersCol = familyDoc.collection('members');
//     final batch = db.batch();
//     for (final m in initialMembers) {
//       final doc = membersCol.doc(m.id); // keep stable ids from UI
//       batch.set(doc, {
//         'name': m.name,
//         'avatar': m.avatar,
//         'role': m.role == MemberRole.parent ? 'parent' : 'child',
//         'usesThisDevice': m.usesThisDevice,
//         'requiresPin': m.requiresPin,
//         'pin': m.pin,
//       }, SetOptions(merge: true));
//     }
//     await batch.commit();

//     // 5) hydrate local state
//     _family = Family(id: familyId, name: familyName, createdAt: DateTime.now());
//     _members
//       ..clear()
//       ..addAll(initialMembers);
//     _currentProfileId = _members.isNotEmpty ? _members.first.id : null;
//     notifyListeners();

//     return familyId;
//   }


//   void createOrUpdateFamily(String name) {
//     if (_family == null) {
//       _family = Family(id: _id(), name: name, createdAt: DateTime.now());
//     } else {
//       _family!.name = name;
//     }
//     notifyListeners();
//   }

//   /// Return the existing join code for the current family, creating one if missing.
//   Future<String> createInvite() async {
//     final fid = familyId ?? _familySnap?.id;
//     if (fid == null || fid.isEmpty) {
//       throw StateError('No family for invite');
//     }

//     final db = FirebaseFirestore.instance;
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     final famRef = db.collection('families').doc(fid);

//     // read current code
//     final snap = await famRef.get();
//     String? code = (snap.data()?['code'] as String?);

//     // create one if missing and backfill /joinCodes
//     if (code == null || code.trim().isEmpty) {
//       code = _makeCode(6);
//       await famRef.set({'code': code}, SetOptions(merge: true));
//     }

//     await db.collection('joinCodes').doc(code).set({
//       'familyId': fid,
//       'createdBy': uid,
//       'createdAt': FieldValue.serverTimestamp(),
//     }, SetOptions(merge: true));

//     return code;
//   }

//   /// Join an existing family by its invite code.
//   /// Links the current user as a parent and (optionally) ensures a parent member exists.
//   Future<String> redeemInvite(
//     String code, {
//     String? parentDisplayName,
//   }) async {
//     final db = FirebaseFirestore.instance;
//     final uid = FirebaseAuth.instance.currentUser!.uid;
//     final input = code.trim().toUpperCase();
//     if (input.isEmpty) {
//       throw ArgumentError('Invite code cannot be empty');
//     }

//     // 1) look up /joinCodes/{code}
//     final codeDoc = await db.collection('joinCodes').doc(input).get();
//     if (!codeDoc.exists) {
//       throw StateError('Invite code not found');
//     }
//     final familyId = (codeDoc.data()!['familyId'] as String);

//     // 2) link /users/{uid}
//     await db.collection('users').doc(uid).set({
//       'familyId': familyId,
//       'role': 'parent',
//       'memberId': null,
//     }, SetOptions(merge: true));

//     // 3) (optional) ensure a parent member exists for display, if a name was provided
//     if (parentDisplayName != null && parentDisplayName.trim().isNotEmpty) {
//       final membersCol = db.collection('families').doc(familyId).collection('members');

//       // try to find an existing parent member with the same name
//       final existing = await membersCol
//           .where('role', isEqualTo: 'parent')
//           .where('name', isEqualTo: parentDisplayName.trim())
//           .limit(1)
//           .get();

//       if (existing.docs.isEmpty) {
//         await membersCol.add({
//           'name': parentDisplayName.trim(),
//           'avatar': '👤',
//           'role': 'parent',
//           'usesThisDevice': false,
//           'requiresPin': false,
//           'pin': null,
//         });
//       }
//     }

//     // 4) hydrate local state for this family so UI can render immediately
//     await loadFamilyFromFirestore(familyId);
//     return familyId;
//   }


//   void addMember({
//     required String name,
//     required MemberRole role,
//     required String avatar,
//     bool usesThisDevice = true,
//     bool requiresPin = false,
//     String? pin,
//   }) {
//     final fam =
//         _family ?? Family(id: _id(), name: 'Family', createdAt: DateTime.now());
//     _family ??= fam;

//     final m = Member(
//       id: _id(),
//       familyId: fam.id,
//       name: name,
//       role: role,
//       avatar: avatar,
//       usesThisDevice: usesThisDevice,
//       requiresPin: requiresPin,
//       pin: requiresPin ? pin : null,
//     );
//     _members.add(m);
//     _currentProfileId ??= m.id;
//     notifyListeners();
//   }

//   void updateMemberRole(String memberId, MemberRole role) {
//     final i = _members.indexWhere((m) => m.id == memberId);
//     if (i != -1) {
//       _members[i].role = role;
//       notifyListeners();
//     }
//   }

//   void updateUsesThisDevice(String memberId, bool value) {
//     final i = _members.indexWhere((m) => m.id == memberId);
//     if (i != -1) {
//       _members[i].usesThisDevice = value;
//       notifyListeners();
//     }
//   }

//   void updatePin(String memberId, {required bool requiresPin, String? pin}) {
//     final i = _members.indexWhere((m) => m.id == memberId);
//     if (i != -1) {
//       _members[i].requiresPin = requiresPin;
//       _members[i].pin = requiresPin ? pin : null;
//       notifyListeners();
//     }
//   }

//   bool verifyPin(String memberId, String input) {
//     final m = _members.firstWhere((e) => e.id == memberId,
//         orElse: () => throw StateError('Missing member'));
//     if (!m.requiresPin) return true;
//     return (m.pin ?? '') == input;
//   }

//   void upsertMember(Member member) {
//     final i = _members.indexWhere((m) => m.id == member.id);
//     if (i >= 0) {
//       _members[i] = member;
//     } else {
//       _members.add(member);
//     }
//     notifyListeners();
//   }

//   /// Remove a member by id.
//   void removeMember(String memberId) {
//     _members.removeWhere((m) => m.id == memberId);
//     if (_currentProfileId == memberId) {
//       _currentProfileId = _members.isNotEmpty ? _members.first.id : null;
//     }
//     notifyListeners();
//   }


//   void setCurrentProfile(String memberId) {
//     _currentProfileId = memberId;
//     notifyListeners();
//   }

//   Member? memberById(String id) =>
//       _members.where((m) => m.id == id).firstOrNull;
//   List<Member> membersByIds(Iterable<String> ids) =>
//       ids.map(memberById).whereType<Member>().toList();
      

//   // =========================
//   // Chores / Completions
//   // =========================
//   final List<ChoreCompletion> _completions = [];

// void addChore({
//   required String title,
//   required int points,
//   required int difficulty,
//   required ChoreSchedule schedule,
//   Set<int>? daysOfWeek,
//   required Set<String> assigneeIds,
//   IconData? icon,
//   Color? iconColor,
// }) {
//   _chores.add(Chore(
//     id: _id(),
//     title: title,
//     points: points,
//     difficulty: difficulty,
//     schedule: schedule,
//     daysOfWeek: daysOfWeek != null ? Set<int>.from(daysOfWeek) : {},
//     assigneeIds: Set<String>.from(assigneeIds),
//     icon: icon,
//     iconColor: iconColor,
//   ));
//   notifyListeners();
// }

//   void updateChore({
//     required String choreId,
//     String? title,
//     int? points,
//     ChoreSchedule? schedule,
//     Set<int>? daysOfWeek,
//     IconData? icon,
//     Color? iconColor,
//   }) {
//     final c = _chores.firstWhere((x) => x.id == choreId);
//     if (title != null) c.title = title;
//     if (points != null) c.points = points;
//     if (schedule != null) c.schedule = schedule;
//     if (daysOfWeek != null) {
//       c.daysOfWeek
//         ..clear()
//         ..addAll(daysOfWeek);
//     }
//     if (icon != null) c.icon = icon;
//     if (iconColor != null) c.iconColor = iconColor;
//     notifyListeners();
//   }

//   void deleteChore(String choreId) {
//     _chores.removeWhere((x) => x.id == choreId);
//     _completions.removeWhere((x) => x.choreId == choreId);
//     notifyListeners();
//   }

//   void toggleAssignee(String choreId, String memberId) {
//     final c = _chores.firstWhere((x) => x.id == choreId);
//     if (c.assigneeIds.contains(memberId)) {
//       c.assigneeIds.remove(memberId);
//     } else {
//       c.assigneeIds.add(memberId);
//     }
//     notifyListeners();
//   }

//   void assignMembersToChore(String choreId, Set<String> memberIds) {
//     final c = _chores.firstWhere((x) => x.id == choreId);
//     c.assigneeIds.addAll(memberIds);
//     notifyListeners();
//   }

//   void completeChore(String choreId, String memberId) {
//     _completions.add(ChoreCompletion(
//       id: _id(),
//       choreId: choreId,
//       memberId: memberId,
//       completedAt: DateTime.now(),
//     ));
//     notifyListeners();
//   }

//   /// Record completion on an arbitrary calendar day (used by parent grid taps).
//   void completeChoreOn(String choreId, String memberId, DateTime day) {
//     _completions.add(ChoreCompletion(
//       id: _id(),
//       choreId: choreId,
//       memberId: memberId,
//       completedAt: DateTime(day.year, day.month, day.day, 12),
//     ));
//     notifyListeners();
//   }

//   // -------- Queries / Derived --------

//   List<Chore> choresForMember(String memberId) =>
//       _chores.where((c) => c.assigneeIds.contains(memberId)).toList();

//   int pointsForMemberAllTime(String memberId) {
//     var total = 0;
//     for (final comp in _completions.where((x) => x.memberId == memberId)) {
//       final chore = _chores.firstWhere(
//         (c) => c.id == comp.choreId,
//         orElse: () => Chore(
//           id: '',
//           title: '',
//           points: 0,
//           difficulty: 3,
//           schedule: ChoreSchedule.daily,
//         ),
//       );
//       total += chore.points;
//     }
//     return total;
//   }

//   bool wasCompletedOnDay(String choreId, String memberId, DateTime day) {
//     final t = _dateOnly(day);
//     return _completions.any((c) =>
//         c.choreId == choreId &&
//         c.memberId == memberId &&
//         _dateOnly(c.completedAt) == t);
//   }

//   bool wasCompletedInWeek(
//       String choreId, String memberId, DateTime anyDayInWeek) {
//     final s = _startOfWeek(anyDayInWeek);
//     final e = s.add(const Duration(days: 6));
//     return _completions.any((c) {
//       if (c.choreId != choreId || c.memberId != memberId) return false;
//       final d = _dateOnly(c.completedAt);
//       return !d.isBefore(s) && !d.isAfter(e);
//     });
//   }

//   /// Is this chore scheduled on [day], independent of completions?
//   bool isScheduledOnDate(Chore chore, DateTime day) {
//     switch (chore.schedule) {
//       case ChoreSchedule.daily:
//         return true;
//       case ChoreSchedule.weeklyAny:
//         // If no weekday chosen => any day in the week.
//         // If one (or more) weekdays chosen => only those day(s).
//         return chore.daysOfWeek.isEmpty
//             ? true
//             : chore.daysOfWeek.contains(day.weekday);
//       case ChoreSchedule.customDays:
//         return chore.daysOfWeek.contains(day.weekday);
//     }
//   }

//   /// Should the chore appear for [memberId] on [day]?
//   /// This combines scheduling with once-per-week gating (for weekly-any).
//   bool isApplicableForMemberOnDate(
//       Chore chore, String memberId, DateTime day) {
//     if (!isScheduledOnDate(chore, day)) return false;

//     if (chore.schedule == ChoreSchedule.weeklyAny) {
//       if (chore.daysOfWeek.isEmpty) {
//         // Weekly (any day): show until they finish once in the week.
//         final doneThisWeek = wasCompletedInWeek(chore.id, memberId, day);
//         return !doneThisWeek;
//       } else {
//         // Weekly on a specific day(s): show on those day(s) (no week-wide gating).
//         return true;
//       }
//     }

//     // Daily / Custom days: show on scheduled day
//     return true;
//   }

//   Future<void> updateFamilyName(String toSave) async {
//     final famId = _family?.id ?? (_userDoc?['familyId'] as String?);
//     if (famId == null || (toSave).toString().trim().isEmpty) return;

//     final name = toSave.toString().trim();
//     await _db.collection('families').doc(famId).set(
//       {'name': name},
//       SetOptions(merge: true),
//     );

//     // Update local cache
//     if (_family != null) _family = _family!.copyWith(name: name);
//     notifyListeners();
//   }

//   Future<void> rotateInviteCode() async {
//     final fid = familyId ?? _familySnap?.id;
//     if (fid == null || fid.isEmpty) {
//       throw StateError('No family for invite rotation');
//     }

//     final db = FirebaseFirestore.instance;
//     final famRef = db.collection('families').doc(fid);

//     // read old
//     final snap = await famRef.get();
//     final oldCode = (snap.data()?['code'] as String?);
//     final newCode = _makeCode(6);

//     final batch = db.batch();
//     batch.set(famRef, {'code': newCode}, SetOptions(merge: true));

//     if (oldCode != null && oldCode.trim().isNotEmpty) {
//       batch.delete(db.collection('joinCodes').doc(oldCode));
//     }

//     batch.set(db.collection('joinCodes').doc(newCode), {
//       'familyId': fid,
//       'createdBy': FirebaseAuth.instance.currentUser?.uid,
//       'createdAt': FieldValue.serverTimestamp(),
//     }, SetOptions(merge: true));

//     await batch.commit();
//   }

//   Future<void> addChild({required String name, required String avatar}) async {
//     final famId = _family?.id ?? (_userDoc?['familyId'] as String?);
//     if (famId == null) return;

//     final membersCol = _db.collection('families').doc(famId).collection('members');
//     final doc = membersCol.doc(); // auto id

//     await doc.set({
//       'name': name.trim().isEmpty ? 'Child' : name.trim(),
//       'avatar': avatar,
//       'role': 'child',
//       'usesThisDevice': false,
//       'requiresPin': false,
//       'pin': null,
//     });

//     // Update local state (optional but keeps UI snappy)
//     _members.add(Member(
//       id: doc.id,
//       familyId: famId,
//       name: name.trim().isEmpty ? 'Child' : name.trim(),
//       avatar: avatar,
//       role: MemberRole.child,
//       usesThisDevice: false,
//       requiresPin: false,
//       pin: null,
//     ));
//     notifyListeners();
//   }

//   Future<void> removeChild({required String kidId}) async {
//     final famId = _family?.id ?? (_userDoc?['familyId'] as String?);
//     if (famId == null) return;

//     await _db.collection('families').doc(famId)
//         .collection('members').doc(kidId).delete();

//     _members.removeWhere((m) => m.id == kidId);
//     if (_currentProfileId == kidId) {
//       _currentProfileId = _members.isNotEmpty ? _members.first.id : null;
//     }
//     notifyListeners();
//   }

//   void attachAuthListener() {}
// }

// // Iterable helper (avoids bringing in package:collection)
// extension _FirstOrNull<E> on Iterable<E> {
//   E? get firstOrNull => isEmpty ? null : first;
// }

// // ---- CopyWith extensions ----
// extension FamilyCopyX on Family {
//   Family copyWith({String? id, String? name, DateTime? createdAt}) {
//     return Family(id: id ?? this.id, name: name ?? this.name, createdAt: createdAt ?? this.createdAt);
//   }
// }
// extension MemberCopyX on Member {
//   Member copyWith({
//     String? id,
//     String? familyId,
//     String? name,
//     String? avatar,
//     MemberRole? role,
//     bool? usesThisDevice,
//     bool? requiresPin,
//     String? pin,
//   }) {
//     return Member(
//       id: id ?? this.id,
//       familyId: familyId ?? this.familyId,
//       name: name ?? this.name,
//       avatar: avatar ?? this.avatar,
//       role: role ?? this.role,
//       usesThisDevice: usesThisDevice ?? this.usesThisDevice,
//       requiresPin: requiresPin ?? this.requiresPin,
//       pin: pin ?? this.pin,
//     );
//   }
// }
