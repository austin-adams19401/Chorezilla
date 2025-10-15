/* eslint-disable camelcase */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// Helper: random code like "A7G9JK2Q"
function randomCode(len = 8) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < len; i++) out += chars[Math.floor(Math.random() * chars.length)];
  return out;
}

/**
 * Callable: createInvite
 * Input: {familyId: string, ttlHours?: number}
 * Output: {code: string, familyId: string, expiresAt: string}
 */
exports.createInvite = functions.region('us-central1').https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  const familyId = (data?.familyId || '').toString().trim();
  const ttlHours = Number.isFinite(+data?.ttlHours) ? +data.ttlHours : 72;
  if (!familyId) throw new functions.https.HttpsError('invalid-argument', 'Missing familyId.');

  const famRef = db.collection('families').doc(familyId);
  const famSnap = await famRef.get();
  if (!famSnap.exists) throw new functions.https.HttpsError('not-found', 'Family not found.');

  const parents = famSnap.data()?.parentUids || {};
  if (parents[uid] !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Only parents can create invites.');
  }

  const code = randomCode(8);
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + ttlHours * 3600 * 1000)
  );

  const famInviteRef = famRef.collection('invites').doc(code);
  const globalInviteRef = db.collection('invites').doc(code);

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(globalInviteRef);
    if (existing.exists) {
      throw new functions.https.HttpsError('aborted', 'Code collision, try again.');
    }
    tx.set(famInviteRef, {
      familyId,
      createdBy: uid,
      expiresAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    tx.set(globalInviteRef, {
      familyId,
      expiresAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  return {code, familyId, expiresAt: expiresAt.toDate().toISOString()};
});

/**
 * Callable: redeemInvite
 * Input: {code: string, displayName?: string}
 * Output: {familyId: string}
 */
exports.redeemInvite = functions.region('us-central1').https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  const code = (data?.code || '').toString().trim();
  const displayName = (data?.displayName || 'Parent').toString().trim();
  if (!code) throw new functions.https.HttpsError('invalid-argument', 'Missing code.');

  const globalInviteRef = db.collection('invites').doc(code);
  const userRef = db.collection('users').doc(uid);

  return await db.runTransaction(async (tx) => {
    const invSnap = await tx.get(globalInviteRef);
    if (!invSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Invalid invite.');
    }
    const inv = invSnap.data();
    const expiresAt = inv.expiresAt?.toDate?.() ?? new Date(0);
    if (expiresAt < new Date()) {
      throw new functions.https.HttpsError('failed-precondition', 'Invite expired.');
    }

    const familyId = inv.familyId;
    const famRef = db.collection('families').doc(familyId);
    const famSnap = await tx.get(famRef);
    if (!famSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Family missing.');
    }

    // Link user → family, add to parentUids, and add a member row
    tx.set(userRef, {
      displayName,
      role: 'parent',
      familyId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});

    tx.set(famRef, {[`parentUids.${uid}`]: true}, {merge: true});

    const memRef = famRef.collection('members').doc();
    tx.set(memRef, {
      name: displayName,
      role: 'parent',
      avatar: '🦄',
      usesThisDevice: true,
      requiresPin: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Delete both invite docs (single-use)
    const famInviteRef = famRef.collection('invites').doc(code);
    tx.delete(globalInviteRef);
    tx.delete(famInviteRef);

    return {familyId};
  });
});

// TODO: auto create assignments daily without the need to open the app. 
// exports.generateDailyAssignments = functions.pubsub
//   .schedule('every day 00:00') // pick a time
//   .timeZone('America/Denver')  // or per-family if you store timezone
//   .onRun(async () => {
//     // for each family: call the same logic as ensureAssignmentsForToday
//   });
