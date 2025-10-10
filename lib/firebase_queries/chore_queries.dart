import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chore.dart';
import '../sources/firestore_service.dart';

class ChoreQueries {
  ChoreQueries(FirebaseFirestore db) : _fs = FirestoreService(db);
  final FirestoreService _fs;

  // Centralize paths:
  String _choresCol(String familyId) => 'families/$familyId/chores';
  String _choreDoc(String familyId, String choreId) => '${_choresCol(familyId)}/$choreId';

  Future<List<Chore>> listChores(String familyId) {
    return _fs.getCol<Chore>(
      path: _choresCol(familyId),
      fromMap: Chore.fromMap,
    );
  }

  Stream<List<Chore>> watchChores(String familyId) {
    return _fs.streamCol<Chore>(
      path: _choresCol(familyId),
      fromMap: Chore.fromMap,
    );
  }

  Future<List<Chore>> listChoresForDay(String familyId, String day) {
    return _fs.getCol<Chore>(
      path: _choresCol(familyId),
      query: (q) => q.where('schedule', arrayContains: day),
      fromMap: Chore.fromMap,
    );
  }

  Future<void> addChore(String familyId, Chore c) {
    // if you want auto-id, call _fs.add; if you have your own id, use set on _choreDoc
    return _fs.add(path: _choreDoc(familyId, c.id), data: c.toMap());
  }

  Future<void> deleteChore(String familyId, String choreId) {
    return _fs.delete(path: _choreDoc(familyId, choreId));
  }
}
