
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:chorezilla/models/award.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import '../models/common.dart';
import '../models/user_profile.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../models/chore.dart';
import '../models/assignment.dart';
import '../models/reward.dart';

part 'package:chorezilla/data/repo_assignments.dart';
part 'package:chorezilla/data/repo_chores.dart';
part 'package:chorezilla/data/repo_families.dart';
part 'package:chorezilla/data/repo_invites.dart';
part 'package:chorezilla/data/repo_members.dart';
part 'package:chorezilla/data/repo_profiles.dart';
part 'package:chorezilla/data/repo_rewards.dart';
part 'package:chorezilla/data/repo_transactions.dart';


// Firestore path helpers
DocumentReference userDoc(FirebaseFirestore db, String uid) => db.doc('users/$uid');
DocumentReference familyDoc(FirebaseFirestore db, String familyId) => db.doc('families/$familyId');
CollectionReference membersColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/members');
CollectionReference choresColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/chores');
CollectionReference assignmentsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/assignments');
CollectionReference rewardsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/rewards');
CollectionReference devicesColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/devices');
CollectionReference eventsColl(FirebaseFirestore db, String familyId) => db.collection('families/$familyId/events');


class ChorezillaRepo {
  final FirebaseFirestore firebaseDB;
  ChorezillaRepo({required this.firebaseDB});

  // Shared helpers available to all parts
  Future<T> _tx<T>(Future<T> Function(Transaction) body) => firebaseDB.runTransaction(body);
  WriteBatch _batch() => firebaseDB.batch();
}