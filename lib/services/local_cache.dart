import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chorezilla/models/family.dart';
import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/chore.dart';
import 'package:chorezilla/models/assignment.dart';

class KidAssignmentsCache {
  final List<Assignment> assigned;
  final List<Assignment> pending;
  final List<Assignment> completed;

  KidAssignmentsCache({
    required this.assigned,
    required this.pending,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'assigned': assigned.map((a) => a.toCacheMap()).toList(),
        'pending': pending.map((a) => a.toCacheMap()).toList(),
        'completed': completed.map((a) => a.toCacheMap()).toList(),
      };

  factory KidAssignmentsCache.fromJson(Map<String, dynamic> json) {
    List<Assignment> parse(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .map((e) => Assignment.fromCacheMap(e as Map<String, dynamic>))
            .toList();
      }
      return const <Assignment>[];
    }

    return KidAssignmentsCache(
      assigned: parse('assigned'),
      pending: parse('pending'),
      completed: parse('completed'),
    );
  }
}

class LocalCache {
  static const _familyKeyPrefix = 'cz_family_';
  static const _membersKeyPrefix = 'cz_members_';
  static const _choresKeyPrefix = 'cz_chores_';
  static const _kidTodayKeyPrefix = 'cz_kid_today_';

  Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  String _dayKey(DateTime d) {
    final n = DateTime(d.year, d.month, d.day); // normalize
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // ---------- Family ----------
  Future<void> saveFamily(Family family) async {
    final prefs = await _prefs;
    final json = jsonEncode(family.toCacheMap());
    await prefs.setString('$_familyKeyPrefix${family.id}', json);
  }

  Future<Family?> loadFamily(String familyId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_familyKeyPrefix$familyId');
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return Family.fromCacheMap(map);
  }

  // ---------- Members ----------
  Future<void> saveMembers(String familyId, List<Member> members) async {
    final prefs = await _prefs;
    final list = members.map((m) => m.toCacheMap()).toList();
    await prefs.setString(
      '$_membersKeyPrefix$familyId',
      jsonEncode(list),
    );
  }

  Future<List<Member>?> loadMembers(String familyId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_membersKeyPrefix$familyId');
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Member.fromCacheMap(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Chores ----------
  Future<void> saveChores(String familyId, List<Chore> chores) async {
    final prefs = await _prefs;
    final list = chores.map((c) => c.toCacheMap()).toList();
    await prefs.setString(
      '$_choresKeyPrefix$familyId',
      jsonEncode(list),
    );
  }

  Future<List<Chore>?> loadChores(String familyId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_choresKeyPrefix$familyId');
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Chore.fromCacheMap(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Kid "Today" assignments ----------
  Future<void> saveKidTodayAssignments({
    required String familyId,
    required String memberId,
    required DateTime day,
    required List<Assignment> assigned,
    required List<Assignment> pending,
    required List<Assignment> completed,
  }) async {
    final prefs = await _prefs;
    final key = '$_kidTodayKeyPrefix${familyId}_${memberId}_${_dayKey(day)}';

    final cache = KidAssignmentsCache(
      assigned: assigned,
      pending: pending,
      completed: completed,
    );

    await prefs.setString(key, jsonEncode(cache.toJson()));
  }

  Future<KidAssignmentsCache?> loadKidTodayAssignments({
    required String familyId,
    required String memberId,
    required DateTime day,
  }) async {
    final prefs = await _prefs;
    final key = '$_kidTodayKeyPrefix${familyId}_${memberId}_${_dayKey(day)}';
    final raw = prefs.getString(key);
    if (raw == null) return null;

    final map = jsonDecode(raw) as Map<String, dynamic>;
    return KidAssignmentsCache.fromJson(map);
  }
}
