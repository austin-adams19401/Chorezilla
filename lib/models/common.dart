import 'package:cloud_firestore/cloud_firestore.dart';

// Enums shared across models
enum FamilyRole { parent, child }
enum AssignmentStatus { assigned, completed, approved, rejected }
enum AuthState { unknown, signedOut, needsFamilySetup, ready }

// Enum <-> String helpers
String roleToString(FamilyRole r) => r.name;
FamilyRole roleFromString(String s) => FamilyRole.values.firstWhere(
      (e) => e.name == s,
      orElse: () => FamilyRole.child,
    );

String statusToString(AssignmentStatus s) => s.name;
AssignmentStatus statusFromString(String s) => AssignmentStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => AssignmentStatus.assigned,
    );

// Timestamp/Date helpers
DateTime? tsAsDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

Timestamp? dateAsTs(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

// Map key conversion helpers
Map<int, int> mapStringIntToIntInt(Map<String, dynamic>? raw) {
  final out = <int, int>{};
  if (raw == null) return out;
  raw.forEach((k, v) {
    final kk = int.tryParse(k);
    final vv = (v is int) ? v : (v is num ? v.toInt() : null);
    if (kk != null && vv != null) out[kk] = vv;
  });
  return out;
}

Map<String, int> mapIntIntToStringInt(Map<int, int>? raw) {
  final out = <String, int>{};
  if (raw == null) return out;
  raw.forEach((k, v) => out[k.toString()] = v);
  return out;
}
