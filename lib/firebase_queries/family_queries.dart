import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family.dart';
import '../sources/firestore_service.dart';

class FamilyQueries {
  FamilyQueries(FirebaseFirestore db) : _fs = FirestoreService(db);
  final FirestoreService _fs;

  String _familyDoc(String familyId) => 'families/$familyId';

  Future<Family?> getFamily(String familyId) {
    return _fs.getDoc<Family>(
      path: _familyDoc(familyId),
      fromMap: Family.fromMap,
    );
  }

  Stream<Family?> watchFamily(String familyId) {
    return _fs.streamDoc<Family>(
      path: _familyDoc(familyId),
      fromMap: Family.fromMap,
    );
  }

  Future<void> upsertFamily(Family f) {
    return _fs.set(path: _familyDoc(f.id), data: f.toMap(), merge: true);
  }
}
