// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'package:chorezilla/models/family.dart';
// import 'package:chorezilla/models/member.dart';
// import 'package:chorezilla/models/chore.dart';
// import 'package:chorezilla/models/assignment.dart';

// class LocalCache {
//   static const _familyKey = 'cz_family';
//   static const _membersKey = 'cz_members';
//   static const _choresKey = 'cz_chores';
//   static String _assignmentsKeyForDate(DateTime date) =>
//       'cz_assignments_${date.year}${date.month}${date.day}';

//   Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

//   // ---- Family ----
//   Future<void> saveFamily(Family family) async {
//     final prefs = await _prefs;
//     prefs.setString(_familyKey, jsonEncode(family.toJson()));
//   }

//   Future<Family?> loadFamily() async {
//     final prefs = await _prefs;
//     final raw = prefs.getString(_familyKey);
//     if (raw == null) return null;
//     return Family.fromJson(jsonDecode(raw));
//   }

//   // ---- Members ----
//   Future<void> saveMembers(List<Member> members) async {
//     final prefs = await _prefs;
//     final list = members.map((m) => m.toJson()..['id'] = m.id).toList();
//     prefs.setString(_membersKey, jsonEncode(list));
//   }

//   Future<List<Member>?> loadMembers() async {
//     final prefs = await _prefs;
//     final raw = prefs.getString(_membersKey);
//     if (raw == null) return null;
//     final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
//     return list
//         .map((m) => Member.fromJson(m..remove('id'), m['id'] as String))
//         .toList();
//   }

//   // ---- Chores ----
//   Future<void> saveChores(List<Chore> chores) async {
//     final prefs = await _prefs;
//     prefs.setString(
//       _choresKey,
//       jsonEncode(chores.map((c) => c.toJson()..['id'] = c.id).toList()),
//     );
//   }

//   Future<List<Chore>?> loadChores() async {
//     final prefs = await _prefs;
//     final raw = prefs.getString(_choresKey);
//     if (raw == null) return null;
//     final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
//     return list
//         .map((c) => Chore.fromJson(c..remove('id'), c['id'] as String))
//         .toList();
//   }

//   // ---- Today’s assignments ----
//   Future<void> saveTodayAssignments(
//     DateTime today,
//     List<Assignment> assignments,
//   ) async {
//     final prefs = await _prefs;
//     final key = _assignmentsKeyForDate(today);
//     prefs.setString(
//       key,
//       jsonEncode(assignments.map((a) => a.toJson()..['id'] = a.id).toList()),
//     );
//   }

//   Future<List<Assignment>?> loadTodayAssignments(DateTime today) async {
//     final prefs = await _prefs;
//     final key = _assignmentsKeyForDate(today);
//     final raw = prefs.getString(key);
//     if (raw == null) return null;
//     final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
//     return list
//         .map((a) => Assignment.fromJson(a..remove('id'), a['id'] as String))
//         .toList();
//   }
// }
