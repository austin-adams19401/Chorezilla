import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService(this._db);
  final FirebaseFirestore _db;

  // Collection & doc helpers to reduce typos
  CollectionReference<Map<String, dynamic>> col(String path) => _db.collection(path);
  DocumentReference<Map<String, dynamic>> doc(String path) => _db.doc(path);

  // Common CRUD helpers
  Future<T?> getDoc<T>({
    required String path,
    required T Function(Map<String, dynamic> data, String id) fromMap,
  }) async {
    final snap = await doc(path).get();
    if (!snap.exists) return null;
    return fromMap(snap.data()!, snap.id);
  }

  Stream<T?> streamDoc<T>({
    required String path,
    required T Function(Map<String, dynamic> data, String id) fromMap,
  }) {
    return doc(path).snapshots().map((s) => s.exists ? fromMap(s.data()!, s.id) : null);
  }

  Future<List<T>> getCol<T>({
    required String path,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> q)? query,
    required T Function(Map<String, dynamic> data, String id) fromMap,
  }) async {
    Query<Map<String, dynamic>> q = col(path);
    if (query != null) q = query(q);
    final snap = await q.get();
    return snap.docs.map((d) => fromMap(d.data(), d.id)).toList();
  }

  Stream<List<T>> streamCol<T>({
    required String path,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> q)? query,
    required T Function(Map<String, dynamic> data, String id) fromMap,
  }) {
    Query<Map<String, dynamic>> q = col(path);
    if (query != null) q = query(q);
    return q.snapshots().map((s) => s.docs.map((d) => fromMap(d.data(), d.id)).toList());
  }

  Future<void> set({
    required String path,
    required Map<String, dynamic> data,
    bool merge = true,
  }) => doc(path).set(data, SetOptions(merge: merge));

  Future<DocumentReference<Map<String, dynamic>>> add({
    required String path,
    required Map<String, dynamic> data,
  }) => col(path).add(data);

  Future<void> update({
    required String path,
    required Map<String, dynamic> data,
  }) => doc(path).update(data);

  Future<void> delete({ required String path }) => doc(path).delete();
}
