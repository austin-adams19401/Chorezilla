const crypto = require("crypto");
const pins = require("./logic/pins");
const sub = require("./logic/subscription");
const loot = require("./logic/loot");
const limits = require("./logic/limits");

/**
 * Wire security callables and triggers onto the functions export object.
 * @param {object} exportsObj
 * @param {{functions: object, admin: object, db: object}} deps
 */
function register(exportsObj, {functions, admin, db}) {
  const HttpsError = functions.https.HttpsError;
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  /**
   * @param {string} code
   * @param {string} message
   * @return {never}
   */
  function fail(code, message) {
    throw new HttpsError(code, message);
  }

  /**
   * @param {string} uid
   * @param {string} familyId
   * @return {Promise<{fam: object, user: object}>}
   */
  async function assertMember(uid, familyId) {
    if (!familyId) fail("invalid-argument", "Missing familyId.");
    const [famSnap, userSnap] = await Promise.all([
      db.collection("families").doc(familyId).get(),
      db.collection("users").doc(uid).get(),
    ]);
    if (!famSnap.exists) fail("not-found", "Family not found.");
    const fam = famSnap.data() || {};
    const user = userSnap.exists ? (userSnap.data() || {}) : {};
    const memberships = user.memberships || {};
    const ok = fam.ownerUid === uid ||
      (fam.parentUids && fam.parentUids[uid] === true) ||
      (fam.memberUids && fam.memberUids[uid] === true) ||
      user.defaultFamilyId === familyId ||
      user.familyId === familyId ||
      Object.prototype.hasOwnProperty.call(memberships, familyId);
    if (!ok) fail("permission-denied", "You are not in this family.");
    return {fam, user};
  }

  /**
   * @param {object} fam
   * @param {object} user
   * @param {string} uid
   * @return {boolean}
   */
  function isParentUser(fam, uid) {
    if (fam.ownerUid === uid) return true;
    if (fam.parentUids && fam.parentUids[uid] === true) return true;
    return false;
  }

  /**
   * @param {string} familyId
   * @return {FirebaseFirestore.DocumentReference}
   */
  function securityRef(familyId) {
    return db.collection("families").doc(familyId)
        .collection("private").doc("security");
  }

  /**
   * @param {string} familyId
   * @param {string} key
   * @param {boolean} success
   */
  async function recordAttempt(familyId, key, success) {
    const ref = securityRef(familyId);
    const outcome = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? (snap.data() || {}) : {};
      const attempts = Object.assign({}, data.attempts || {});
      const now = Date.now();
      const state = pins.attemptState(attempts[key], now);
      if (!success && state.locked) return "locked";
      if (success) {
        attempts[key] = {count: 0, windowStartMs: now};
      } else {
        attempts[key] = {
          count: state.count + 1,
          windowStartMs: state.windowStartMs,
        };
      }
      tx.set(ref, {attempts}, {merge: true});
      if (!success && attempts[key].count >= pins.MAX_ATTEMPTS) return "locked";
      return "ok";
    });
    if (outcome === "locked") {
      fail("resource-exhausted", "Too many PIN attempts. Try again in 15 minutes.");
    }
  }

  /**
   * @param {string} familyId
   * @param {string} key
   */
  async function assertNotLocked(familyId, key) {
    const snap = await securityRef(familyId).get();
    const attempts = (snap.exists && snap.data().attempts) || {};
    const state = pins.attemptState(attempts[key], Date.now());
    if (state.locked) {
      fail("resource-exhausted", "Too many PIN attempts. Try again in 15 minutes.");
    }
  }

  /**
   * @param {object} fields
   * @return {object}
   */
  function subscriptionWrite(fields) {
    const stamp = (d) => d ? Timestamp.fromDate(d) : null;
    return {
      subscriptionTier: fields.tier,
      subscriptionExpiresAt: stamp(fields.expiresAt),
      trialExpiresAt: stamp(fields.trialExpiresAt),
      billingIssueDetectedAt: stamp(fields.billingIssueDetectedAt),
      subscriptionUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  /**
   * @param {string} uid
   * @param {string} familyId
   */
  async function refreshFamilySubscription(uid, familyId) {
    const apiKey = process.env.REVENUECAT_SECRET_API_KEY || "";
    if (!apiKey) {
      fail("failed-precondition",
          "RevenueCat secret API key is not configured on the server.");
    }
    const url = "https://api.revenuecat.com/v1/subscribers/" +
      encodeURIComponent(uid);
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: "application/json",
      },
    });
    if (!response.ok) {
      const body = await response.text();
      console.error("RevenueCat subscriber lookup failed", response.status, body);
      fail("internal", "Could not verify the subscription with RevenueCat.");
    }
    const payload = await response.json();
    const famSnap = await db.collection("families").doc(familyId).get();
    const fam = famSnap.exists ? (famSnap.data() || {}) : {};
    if (!sub.mayApplySubscription(fam, uid)) {
      fail("permission-denied",
          "This subscription belongs to a different account than the one tied to the family.");
    }
    const fields = sub.fieldsFromSubscriber(payload.subscriber || {}, Date.now());
    await db.collection("families").doc(familyId).set({
      ...subscriptionWrite(fields),
      subscriptionAppUserId: uid,
    }, {merge: true});
    return {
      tier: fields.tier,
      expiresAt: fields.expiresAt ? fields.expiresAt.toISOString() : null,
      trialExpiresAt: fields.trialExpiresAt ? fields.trialExpiresAt.toISOString() : null,
    };
  }

  exportsObj.refreshSubscription = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const requested = data && data.familyId ? String(data.familyId) : "";
        const userSnap = await db.collection("users").doc(uid).get();
        const user = userSnap.exists ? (userSnap.data() || {}) : {};
        const familyId = requested || user.defaultFamilyId || user.familyId || "";
        if (!familyId) fail("failed-precondition", "No family to update.");
        const {fam} = await assertMember(uid, familyId);
        if (!sub.refreshCallerAllowed(uid, fam)) {
          fail("permission-denied",
              "Only the parent account tied to this family's subscription can refresh it.");
        }
        const billingUid = sub.billingAppUserId(fam);
        return refreshFamilySubscription(billingUid, familyId);
      });

  exportsObj.revenueCatWebhook = functions
      .region("us-central1")
      .https.onRequest(async (req, res) => {
        if (req.method !== "POST") {
          res.status(405).send("POST only");
          return;
        }
        const secret = process.env.REVENUECAT_WEBHOOK_AUTH || "";
        if (!secret) {
          console.error("REVENUECAT_WEBHOOK_AUTH is not set");
          res.status(503).send("Webhook auth is not configured");
          return;
        }
        const header = String(req.get("Authorization") || "");
        const presented = header.startsWith("Bearer ") ? header.slice(7) : header;
        const a = Buffer.from(presented);
        const b = Buffer.from(secret);
        const match = a.length === b.length && crypto.timingSafeEqual(a, b);
        if (!match) {
          res.status(401).send("Unauthorized");
          return;
        }
        const event = (req.body && req.body.event) || {};
        const appUserId = String(event.app_user_id || "");
        if (!appUserId || event.type === "TEST") {
          res.status(200).json({ok: true});
          return;
        }
        try {
          const userSnap = await db.collection("users").doc(appUserId).get();
          const user = userSnap.exists ? (userSnap.data() || {}) : {};
          let familyId = user.defaultFamilyId || user.familyId || "";
          if (!familyId) {
            const ownerFam = await db.collection("families").doc(appUserId).get();
            if (ownerFam.exists && (ownerFam.data() || {}).ownerUid === appUserId) {
              familyId = appUserId;
            }
          }
          if (!familyId) {
            console.log("Webhook: no family for", appUserId);
            res.status(200).json({ok: true, skipped: true});
            return;
          }
          const famSnap = await db.collection("families").doc(familyId).get();
          const fam = famSnap.exists ? (famSnap.data() || {}) : {};
          if (!sub.mayApplySubscription(fam, appUserId)) {
            console.log("Webhook: ignoring subscriber that is not tied to the family", appUserId);
            res.status(200).json({ok: true, skipped: true});
            return;
          }
          if (process.env.REVENUECAT_SECRET_API_KEY) {
            await refreshFamilySubscription(appUserId, familyId);
          } else {
            const fields = sub.fieldsFromWebhookEvent(event, Date.now());
            if (!fields.ignore) {
              await db.collection("families").doc(familyId)
                  .set(subscriptionWrite(fields), {merge: true});
            }
          }
          res.status(200).json({ok: true});
        } catch (err) {
          console.error("revenueCatWebhook", err);
          res.status(500).send("Webhook failed");
        }
      });

  exportsObj.setParentPin = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const familyId = data && data.familyId ? String(data.familyId) : "";
        const {fam} = await assertMember(uid, familyId);
        fam.id = familyId;
        if (!isParentUser(fam, uid)) {
          fail("permission-denied", "Only a parent can set the parent PIN.");
        }
        const raw = data ? data.pin : null;
        const ref = securityRef(familyId);
        const famRef = db.collection("families").doc(familyId);
        if (raw == null || raw === "") {
          await ref.set({parentPin: FieldValue.delete()}, {merge: true});
          await famRef.set({
            parentPinSet: false,
            parentPinHash: FieldValue.delete(),
          }, {merge: true});
          return {parentPinSet: false};
        }
        const pin = String(raw).trim();
        if (!pins.isValidPin(pin)) fail("invalid-argument", "PIN must be exactly 4 digits.");
        await ref.set({parentPin: pins.createPinRecord(pin)}, {merge: true});
        await famRef.set({
          parentPinSet: true,
          parentPinHash: FieldValue.delete(),
        }, {merge: true});
        return {parentPinSet: true};
      });

  exportsObj.verifyParentPin = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const familyId = data && data.familyId ? String(data.familyId) : "";
        const pin = data && data.pin ? String(data.pin).trim() : "";
        await assertMember(uid, familyId);
        if (!pins.isValidPin(pin)) return {ok: false};
        const key = `${uid}:pin`;
        await assertNotLocked(familyId, key);
        const secSnap = await securityRef(familyId).get();
        const sec = secSnap.exists ? (secSnap.data() || {}) : {};
        const famSnap = await db.collection("families").doc(familyId).get();
        const fam = famSnap.data() || {};
        let ok = false;
        if (sec.parentPin) ok = pins.verifyPinRecord(pin, sec.parentPin);
        else if (sec.parentLegacy) ok = pins.verifyLegacy(familyId, pin, sec.parentLegacy);
        else ok = pins.verifyLegacy(familyId, pin, fam.parentPinHash);
        await recordAttempt(familyId, key, ok);
        if (ok && !sec.parentPin) {
          await securityRef(familyId).set({
            parentPin: pins.createPinRecord(pin),
            parentLegacy: FieldValue.delete(),
          }, {merge: true});
          await db.collection("families").doc(familyId).set({
            parentPinSet: true,
            parentPinHash: FieldValue.delete(),
          }, {merge: true});
        }
        return {ok};
      });

  exportsObj.setKidPin = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const familyId = data && data.familyId ? String(data.familyId) : "";
        const memberId = data && data.memberId ? String(data.memberId) : "";
        if (!memberId) fail("invalid-argument", "Missing memberId.");
        const {fam} = await assertMember(uid, familyId);
        fam.id = familyId;
        if (!isParentUser(fam, uid)) {
          fail("permission-denied", "Only a parent can set a kid PIN.");
        }
        const memRef = db.collection("families").doc(familyId)
            .collection("members").doc(memberId);
        const memSnap = await memRef.get();
        if (!memSnap.exists) fail("not-found", "Kid not found.");
        const raw = data ? data.pin : null;
        if (raw == null || raw === "") {
          await securityRef(familyId).set({
            [`kidPins.${memberId}`]: FieldValue.delete(),
            [`kidLegacy.${memberId}`]: FieldValue.delete(),
          }, {merge: true});
          await memRef.set({
            pinSet: false,
            pinHash: FieldValue.delete(),
          }, {merge: true});
          return {pinSet: false};
        }
        const pin = String(raw).trim();
        if (!pins.isValidPin(pin)) fail("invalid-argument", "PIN must be exactly 4 digits.");
        await securityRef(familyId).set({
          [`kidPins.${memberId}`]: pins.createPinRecord(pin),
          [`kidLegacy.${memberId}`]: FieldValue.delete(),
        }, {merge: true});
        await memRef.set({
          pinSet: true,
          pinHash: FieldValue.delete(),
        }, {merge: true});
        return {pinSet: true};
      });

  exportsObj.verifyKidPin = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const familyId = data && data.familyId ? String(data.familyId) : "";
        const memberId = data && data.memberId ? String(data.memberId) : "";
        const pin = data && data.pin ? String(data.pin).trim() : "";
        await assertMember(uid, familyId);
        if (!memberId || !pins.isValidPin(pin)) return {ok: false};
        const key = `${uid}:pin`;
        await assertNotLocked(familyId, key);
        const secSnap = await securityRef(familyId).get();
        const sec = secSnap.exists ? (secSnap.data() || {}) : {};
        let parentOk = false;
        if (sec.parentPin) parentOk = pins.verifyPinRecord(pin, sec.parentPin);
        else if (sec.parentLegacy) parentOk = pins.verifyLegacy(familyId, pin, sec.parentLegacy);
        else {
          const famSnap = await db.collection("families").doc(familyId).get();
          parentOk = pins.verifyLegacy(familyId, pin, (famSnap.data() || {}).parentPinHash);
        }
        if (parentOk) {
          await recordAttempt(familyId, key, true);
          return {ok: true, via: "parent"};
        }
        const kidPins = sec.kidPins || {};
        const kidLegacy = sec.kidLegacy || {};
        let kidOk = false;
        if (kidPins[memberId]) kidOk = pins.verifyPinRecord(pin, kidPins[memberId]);
        else if (kidLegacy[memberId]) kidOk = pins.verifyLegacy(familyId, pin, kidLegacy[memberId]);
        else {
          const memSnap = await db.collection("families").doc(familyId)
              .collection("members").doc(memberId).get();
          kidOk = pins.verifyLegacy(familyId, pin, (memSnap.data() || {}).pinHash);
        }
        await recordAttempt(familyId, key, kidOk);
        if (kidOk && !kidPins[memberId]) {
          await securityRef(familyId).set({
            [`kidPins.${memberId}`]: pins.createPinRecord(pin),
            [`kidLegacy.${memberId}`]: FieldValue.delete(),
          }, {merge: true});
          await db.collection("families").doc(familyId)
              .collection("members").doc(memberId).set({
                pinSet: true,
                pinHash: FieldValue.delete(),
              }, {merge: true});
        }
        return {ok: kidOk, via: kidOk ? "kid" : null};
      });

  exportsObj.previewJoinCode = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const code = data && data.code ? String(data.code).trim().toUpperCase() : "";
        if (!code) fail("invalid-argument", "Missing code.");
        const codeSnap = await db.collection("joinCodes").doc(code).get();
        let familyId = "";
        let codeKind = "child";
        if (codeSnap.exists) {
          familyId = (codeSnap.data() || {}).familyId;
          codeKind = limits.joinCodeKind(codeSnap.data() || {});
        } else {
          const inviteSnap = await db.collection("invites").doc(code).get();
          if (!inviteSnap.exists) fail("not-found", "Code not found.");
          const invite = inviteSnap.data() || {};
          let expiresAt = new Date(0);
          if (invite.expiresAt && typeof invite.expiresAt.toDate === "function") {
            expiresAt = invite.expiresAt.toDate();
          }
          if (expiresAt < new Date()) {
            fail("failed-precondition", "Invite expired.");
          }
          familyId = invite.familyId;
          codeKind = "invite";
        }
        const famSnap = await db.collection("families").doc(familyId).get();
        if (!famSnap.exists) fail("not-found", "Family not found.");
        const fam = famSnap.data() || {};
        const membersSnap = await db.collection("families").doc(familyId)
            .collection("members")
            .get();
        const kids = limits.previewKids(membersSnap.docs.map((doc) => {
          return Object.assign({id: doc.id}, doc.data() || {});
        }));
        return {familyId, familyName: fam.name || "Family", kind: codeKind, kids};
      });

  exportsObj.joinWithFamilyCode = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const code = data && data.code ? String(data.code).trim().toUpperCase() : "";
        if (!code) fail("invalid-argument", "Missing code.");
        const codeSnap = await db.collection("joinCodes").doc(code).get();
        if (!codeSnap.exists) fail("not-found", "Code not found.");
        const codeData = codeSnap.data() || {};
        const kind = limits.joinCodeKind(codeData);
        const requestedKind = data && data.kind ? String(data.kind) : "";
        if (requestedKind && requestedKind !== kind) {
          fail("permission-denied", "This code cannot be used that way.");
        }
        const familyId = codeData.familyId;
        const famRef = db.collection("families").doc(familyId);
        const famSnap = await famRef.get();
        if (!famSnap.exists) fail("not-found", "Family not found.");
        const fam = famSnap.data() || {};
        const displayName = String((data && data.displayName) || "").trim() ||
          (kind === "parent" ? "Parent" : "Kid");

        const userRef = db.collection("users").doc(uid);
        let memberId = data && data.memberId ? String(data.memberId) : "";

        if (kind === "child" && !memberId) {
          const existingKids = await famRef.collection("members")
              .where("role", "in", ["child", "kid"]).get();
          const activeKids = existingKids.docs.filter((d) => d.data().active !== false);
          if (!sub.isPremiumFamily(fam, Date.now()) && activeKids.length >= limits.FREE_KIDS) {
            fail("failed-precondition",
                "This family is on the free plan and already has 2 kids.");
          }
          const memRef = famRef.collection("members").doc();
          memberId = memRef.id;
          await memRef.set({
            displayName,
            role: "child",
            userUid: uid,
            avatarKey: null,
            level: 1,
            xp: 0,
            coins: 0,
            badges: [],
            ownedCosmetics: ["title_level_1"],
            createdAt: FieldValue.serverTimestamp(),
            active: true,
            pinSet: false,
            allowanceEnabled: false,
            allowanceFullAmountCents: 0,
            allowanceDaysRequired: 7,
            allowancePayDay: 7,
          });
        } else if (kind === "child") {
          const memSnap = await famRef.collection("members").doc(memberId).get();
          if (!memSnap.exists) fail("not-found", "That profile was not found.");
          const mem = memSnap.data() || {};
          if (!limits.isKidRole(mem.role) || mem.active === false) {
            fail("failed-precondition", "Pick an active kid profile.");
          }
          const claim = limits.kidProfileClaim(mem.userUid, uid);
          if (claim === "taken") {
            fail("failed-precondition",
                "That profile is already linked to another login.");
          }
          if (claim === "claim") {
            await memSnap.ref.set({userUid: uid}, {merge: true});
          }
        } else {
          if (!sub.isPremiumFamily(fam, Date.now())) {
            fail("failed-precondition",
                "Inviting another parent requires Chorezilla Unlimited.");
          }
          const existing = await famRef.collection("members")
              .where("userUid", "==", uid).limit(1).get();
          const existingRole = existing.empty ? "" : existing.docs[0].data().role;
          const decision = limits.parentJoinDecision(existingRole);
          if (decision === "blocked") {
            fail("permission-denied",
                "A kid login cannot join this family as a parent.");
          }
          if (decision === "already-parent") {
            memberId = existing.docs[0].id;
          } else {
            const memRef = famRef.collection("members").doc();
            memberId = memRef.id;
            await memRef.set({
              displayName,
              name: displayName,
              role: "parent",
              userUid: uid,
              active: true,
              createdAt: FieldValue.serverTimestamp(),
            });
          }
          await famRef.set({[`parentUids.${uid}`]: true}, {merge: true});
        }

        await famRef.set({[`memberUids.${uid}`]: true}, {merge: true});
        const role = kind === "parent" ? "parent" : "child";
        await userRef.set({
          defaultFamilyId: familyId,
          familyId,
          memberId,
          role: kind === "parent" ? "parent" : "kid",
          [`memberships.${familyId}`]: {memberId, role},
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {familyId, memberId};
      });

  exportsObj.openLootBox = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const familyId = data && data.familyId ? String(data.familyId) : "";
        const memberId = data && data.memberId ? String(data.memberId) : "";
        const boxId = data && data.boxId ? String(data.boxId) : "";
        const box = loot.BOXES[boxId];
        if (!box) fail("invalid-argument", "Unknown loot box.");
        await assertMember(uid, familyId);
        const famRef = db.collection("families").doc(familyId);
        const memRef = famRef.collection("members").doc(memberId);
        const famPre = await famRef.get();
        if (!sub.isPremiumFamily(famPre.data() || {}, Date.now())) {
          const kidsSnap = await famRef.collection("members")
              .where("role", "in", ["child", "kid"]).get();
          const kids = kidsSnap.docs
              .map((d) => Object.assign({id: d.id}, d.data()))
              .filter((m) => m.active !== false)
              .sort((a, b) => {
                const ad = a.createdAt && a.createdAt.toMillis ? a.createdAt.toMillis() : 0;
                const bd = b.createdAt && b.createdAt.toMillis ? b.createdAt.toMillis() : 0;
                return ad - bd;
              });
          const index = kids.findIndex((m) => m.id === memberId);
          if (index >= limits.FREE_KIDS) {
            fail("failed-precondition", "Loot boxes are paused for this profile on the free plan.");
          }
        }
        const result = await db.runTransaction(async (tx) => {
          const memSnap = await tx.get(memRef);
          if (!memSnap.exists) fail("not-found", "Kid not found.");
          const mem = memSnap.data() || {};
          const coins = Number(mem.coins) || 0;
          if (coins < box.costCoins) fail("failed-precondition", "Not enough coins.");
          const owned = Array.isArray(mem.ownedCosmetics) ?
            mem.ownedCosmetics.map(String) : [];
          const rolled = loot.rollBestOfThree();
          const picked = loot.pickItem(box.type, rolled.best, owned);
          const isDuplicate = picked.isDuplicate || owned.includes(picked.item.id);
          const refund = isDuplicate ? box.duplicateCoinRefund : 0;
          const newCoins = coins - box.costCoins + refund;
          const newOwned = isDuplicate ? owned : owned.concat([picked.item.id]);
          tx.update(memRef, {coins: newCoins, ownedCosmetics: newOwned});
          return {
            rolls: rolled.rolls,
            best: rolled.best,
            wonItemId: picked.item.id,
            isDuplicate,
            coinRefund: refund,
            coins: newCoins,
          };
        });
        return result;
      });

  exportsObj.purchaseCosmetic = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const familyId = data && data.familyId ? String(data.familyId) : "";
        const memberId = data && data.memberId ? String(data.memberId) : "";
        const itemId = data && data.itemId ? String(data.itemId) : "";
        const item = loot.itemById(itemId);
        if (!item || item.isDefault || !item.costCoins) {
          fail("invalid-argument", "That item cannot be purchased.");
        }
        await assertMember(uid, familyId);
        const memRef = db.collection("families").doc(familyId)
            .collection("members").doc(memberId);
        await db.runTransaction(async (tx) => {
          const memSnap = await tx.get(memRef);
          if (!memSnap.exists) fail("not-found", "Kid not found.");
          const mem = memSnap.data() || {};
          const coins = Number(mem.coins) || 0;
          const owned = Array.isArray(mem.ownedCosmetics) ?
            mem.ownedCosmetics.map(String) : [];
          if (owned.includes(itemId)) fail("failed-precondition", "Already owned.");
          if (coins < item.costCoins) fail("failed-precondition", "Not enough coins.");
          tx.update(memRef, {
            coins: coins - item.costCoins,
            ownedCosmetics: owned.concat([itemId]),
          });
        });
        return {itemId, costCoins: item.costCoins};
      });

  exportsObj.grantLevelCosmetic = functions
      .region("us-central1")
      .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) fail("unauthenticated", "Sign in required.");
        const familyId = data && data.familyId ? String(data.familyId) : "";
        const memberId = data && data.memberId ? String(data.memberId) : "";
        const requested = Number(data && data.level);
        if (!requested || requested < 1) fail("invalid-argument", "Missing level.");
        await assertMember(uid, familyId);
        const famRef = db.collection("families").doc(familyId);
        const memRef = famRef.collection("members").doc(memberId);
        return db.runTransaction(async (tx) => {
          const memSnap = await tx.get(memRef);
          if (!memSnap.exists) fail("not-found", "Kid not found.");
          const mem = memSnap.data() || {};
          const plan = sub.planLevelGrant({
            xp: mem.xp,
            requestedLevel: requested,
            owned: mem.ownedCosmetics,
            grants: mem.levelCosmeticGrants,
          });
          if (plan.error === "invalid") fail("invalid-argument", "Missing level.");
          if (plan.error === "locked") {
            fail("failed-precondition", "That level is not unlocked yet.");
          }
          if (!plan.itemId) return {itemId: null};
          if (!plan.grant && !plan.record) return {itemId: plan.itemId};
          const owned = Array.isArray(mem.ownedCosmetics) ?
            mem.ownedCosmetics.map(String) : [];
          const update = {
            [`levelCosmeticGrants.${requested}`]: plan.itemId,
          };
          if (plan.grant && !owned.includes(plan.itemId)) {
            update.ownedCosmetics = owned.concat([plan.itemId]);
          }
          tx.update(memRef, update);
          return {itemId: plan.itemId};
        });
      });

  /**
   * Move legacy PIN material off client-readable documents.
   */
  async function migrateFamilyPin(familyId, after) {
    if (!after || !after.parentPinHash) return;
    await securityRef(familyId).set({
      parentLegacy: after.parentPinHash,
    }, {merge: true});
    await db.collection("families").doc(familyId).set({
      parentPinSet: true,
      parentPinHash: FieldValue.delete(),
    }, {merge: true});
  }

  exportsObj.migrateFamilyPinOnWrite = functions
      .region("us-central1")
      .firestore.document("families/{familyId}")
      .onWrite(async (change, context) => {
        if (!change.after.exists) return null;
        const after = change.after.data() || {};
        if (!after.parentPinHash) return null;
        try {
          await migrateFamilyPin(context.params.familyId, after);
        } catch (err) {
          console.error("migrateFamilyPinOnWrite", err);
        }
        return null;
      });

  exportsObj.backfillLegacyPins = functions
      .region("us-central1")
      .pubsub.schedule("every 60 minutes")
      .onRun(async () => {
        let cursor = null;
        for (let page = 0; page < 20; page++) {
          let query = db.collection("families")
              .orderBy(admin.firestore.FieldPath.documentId())
              .limit(50);
          if (cursor) query = query.startAfter(cursor);
          const snap = await query.get();
          if (snap.empty) break;
          for (const fam of snap.docs) {
            await migrateFamilyPin(fam.id, fam.data() || {});
            const members = await fam.ref.collection("members").get();
            for (const mem of members.docs) {
              const pinHash = (mem.data() || {}).pinHash;
              if (!pinHash) continue;
              await securityRef(fam.id).set({
                [`kidLegacy.${mem.id}`]: pinHash,
              }, {merge: true});
              await mem.ref.set({
                pinSet: true,
                pinHash: FieldValue.delete(),
              }, {merge: true});
            }
          }
          cursor = snap.docs[snap.docs.length - 1];
          if (snap.size < 50) break;
        }
        return null;
      });

  exportsObj.clearMemberLinkOnDelete = functions
      .region("us-central1")
      .firestore.document("families/{familyId}/members/{memberId}")
      .onDelete(async (snap, context) => {
        const uid = (snap.data() || {}).userUid;
        if (!uid) return null;
        const familyId = context.params.familyId;
        const famRef = db.collection("families").doc(familyId);
        const stillThere = await famRef.collection("members")
            .where("userUid", "==", uid).limit(1).get();
        if (!stillThere.empty) return null;
        await famRef.set({
          [`memberUids.${uid}`]: FieldValue.delete(),
          [`parentUids.${uid}`]: FieldValue.delete(),
        }, {merge: true});
        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();
        const user = userSnap.exists ? (userSnap.data() || {}) : {};
        const patch = {
          [`memberships.${familyId}`]: FieldValue.delete(),
        };
        if (user.defaultFamilyId === familyId) {
          patch.defaultFamilyId = FieldValue.delete();
        }
        if (user.familyId === familyId) patch.familyId = FieldValue.delete();
        if (user.memberId === context.params.memberId) {
          patch.memberId = FieldValue.delete();
        }
        await userRef.set(patch, {merge: true});
        return null;
      });

  exportsObj.migrateMemberPinOnWrite = functions
      .region("us-central1")
      .firestore.document("families/{familyId}/members/{memberId}")
      .onWrite(async (change, context) => {
        if (!change.after.exists) return null;
        const after = change.after.data() || {};
        if (!after.pinHash) return null;
        const familyId = context.params.familyId;
        const memberId = context.params.memberId;
        try {
          await securityRef(familyId).set({
            [`kidLegacy.${memberId}`]: after.pinHash,
          }, {merge: true});
          await change.after.ref.set({
            pinSet: true,
            pinHash: FieldValue.delete(),
          }, {merge: true});
        } catch (err) {
          console.error("migrateMemberPinOnWrite", err);
        }
        return null;
      });

  /**
   * @param {FirebaseFirestore.QueryDocumentSnapshot[]} docs
   * @param {Set<string>} defaults
   * @return {number}
   */
  function customCount(docs, defaults) {
    return docs.filter((d) => limits.countsAsCustom(d.data() || {}, defaults)).length;
  }

  exportsObj.enforceKidLimit = functions
      .region("us-central1")
      .firestore.document("families/{familyId}/members/{memberId}")
      .onCreate(async (snap, context) => {
        const data = snap.data() || {};
        if (!limits.isKidRole(data.role)) return null;
        const familyId = context.params.familyId;
        const famSnap = await db.collection("families").doc(familyId).get();
        const fam = famSnap.data() || {};
        if (sub.isPremiumFamily(fam, Date.now())) return null;
        const kids = await db.collection("families").doc(familyId)
            .collection("members").where("role", "in", ["child", "kid"]).get();
        const active = kids.docs.filter((d) => (d.data() || {}).active !== false);
        if (active.length > limits.FREE_KIDS) {
          console.log("Deleting over-limit kid", familyId, snap.id);
          await snap.ref.delete();
        }
        return null;
      });

  exportsObj.enforceCustomChoreLimit = functions
      .region("us-central1")
      .firestore.document("families/{familyId}/chores/{choreId}")
      .onWrite(async (change, context) => {
        if (!change.after.exists) return null;
        const after = change.after.data() || {};
        if (!limits.countsAsCustom(after, limits.DEFAULT_CHORE_TITLES)) return null;
        const before = change.before.exists ? (change.before.data() || {}) : null;
        if (before && limits.countsAsCustom(before, limits.DEFAULT_CHORE_TITLES)) return null;
        const familyId = context.params.familyId;
        const famSnap = await db.collection("families").doc(familyId).get();
        if (sub.isPremiumFamily(famSnap.data() || {}, Date.now())) return null;
        const chores = await db.collection("families").doc(familyId).collection("chores").get();
        if (customCount(chores.docs, limits.DEFAULT_CHORE_TITLES) > limits.FREE_CUSTOM_CHORES) {
          console.log("Deleting over-limit custom chore", familyId, change.after.id);
          await change.after.ref.delete();
        }
        return null;
      });

  exportsObj.enforceCustomRewardLimit = functions
      .region("us-central1")
      .firestore.document("families/{familyId}/rewards/{rewardId}")
      .onWrite(async (change, context) => {
        if (!change.after.exists) return null;
        const after = change.after.data() || {};
        if (!limits.countsAsCustom(after, limits.DEFAULT_REWARD_TITLES)) return null;
        const before = change.before.exists ? (change.before.data() || {}) : null;
        if (before && limits.countsAsCustom(before, limits.DEFAULT_REWARD_TITLES)) return null;
        const familyId = context.params.familyId;
        const famSnap = await db.collection("families").doc(familyId).get();
        if (sub.isPremiumFamily(famSnap.data() || {}, Date.now())) return null;
        const rewards = await db.collection("families").doc(familyId).collection("rewards").get();
        if (customCount(rewards.docs, limits.DEFAULT_REWARD_TITLES) > limits.FREE_CUSTOM_REWARDS) {
          console.log("Deleting over-limit custom reward", familyId, change.after.id);
          await change.after.ref.delete();
        }
        return null;
      });
}

module.exports = register;
