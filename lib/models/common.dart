import 'package:cloud_firestore/cloud_firestore.dart';

// Enums shared across models
enum FamilyRole { owner, parent, child }
enum AssignmentStatus { assigned, completed, pending, approved, rejected }
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

extension AssignmentStatusUi on AssignmentStatus {
  String get label {
    switch (this) {
      case AssignmentStatus.assigned:  return 'Assigned';
      case AssignmentStatus.completed: return 'Completed';
      case AssignmentStatus.pending: return 'Pending';
      case AssignmentStatus.approved:  return 'Approved';
      case AssignmentStatus.rejected:  return 'Rejected';
    }
  }

  bool get isDone =>
      this == AssignmentStatus.completed || this == AssignmentStatus.approved;
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

extension UniqueByKey<T, KeyType> on Iterable<T> {
  /// Returns a new list with only the first item for each distinct key.
  List<T> uniqueByKey(KeyType Function(T item) selectKey) {
    final seenKeys = <KeyType>{};
    final uniqueItems = <T>[];
    for (final item in this) {
      final key = selectKey(item);
      final isNewKey = seenKeys.add(key); // add() returns false if key already existed
      if (isNewKey) uniqueItems.add(item);
    }
    return uniqueItems;
  }
}
