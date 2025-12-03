/* eslint-disable camelcase */
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp({
    projectId: "chorezilla-dev",
});
const db = admin.firestore();

// Helper: random code like "A7G9JK2Q"
function randomCode(len = 8) {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let out = "";
    for (let i = 0; i < len; i++) {
        out += chars[Math.floor(Math.random() * chars.length)];
    }
    return out;
}

/**
 * Callable: createInvite
 * Input: {familyId: string, ttlHours?: number}
 * Output: {code: string, familyId: string, expiresAt: string}
 */
exports.createInvite = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) {
            throw new functions.https.HttpsError(
                "unauthenticated",
                "Sign in required."
            );
        }

        const familyIdRaw = data && data.familyId ? data.familyId : "";
        const familyId = familyIdRaw.toString().trim();

        const ttlRaw = data && data.ttlHours;
        const ttlHours = Number.isFinite(+ttlRaw) ? +ttlRaw : 72;

        if (!familyId) {
            throw new functions.https.HttpsError(
                "invalid-argument",
                "Missing familyId."
            );
        }

        const famRef = db.collection("families").doc(familyId);
        const famSnap = await famRef.get();
        if (!famSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Family not found.");
        }

        const famData = famSnap.data() || {};
        const parents = famData.parentUids || {};
        if (parents[uid] !== true) {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Only parents can create invites."
            );
        }

        const code = randomCode(8);
        const expiresAt = admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + ttlHours * 3600 * 1000)
        );

        const famInviteRef = famRef.collection("invites").doc(code);
        const globalInviteRef = db.collection("invites").doc(code);

        await db.runTransaction(async (tx) => {
            const existing = await tx.get(globalInviteRef);
            if (existing.exists) {
                throw new functions.https.HttpsError(
                    "aborted",
                    "Code collision, try again."
                );
            }
            tx.set(famInviteRef, {
                familyId: familyId,
                createdBy: uid,
                expiresAt: expiresAt,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            tx.set(globalInviteRef, {
                familyId: familyId,
                expiresAt: expiresAt,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });

        return { code, familyId, expiresAt: expiresAt.toDate().toISOString() };
    });

/**
 * Callable: redeemInvite
 * Input: {code: string, displayName?: string}
 * Output: {familyId: string}
 */
exports.redeemInvite = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
        const uid = context.auth && context.auth.uid;
        if (!uid) {
            throw new functions.https.HttpsError(
                "unauthenticated",
                "Sign in required."
            );
        }

        const codeRaw = data && data.code ? data.code : "";
        const code = codeRaw.toString().trim();

        const displayNameRaw =
            data && data.displayName ? data.displayName : "Parent";
        const displayName = displayNameRaw.toString().trim();

        if (!code) {
            throw new functions.https.HttpsError("invalid-argument", "Missing code.");
        }

        const globalInviteRef = db.collection("invites").doc(code);
        const userRef = db.collection("users").doc(uid);

        return await db.runTransaction(async (tx) => {
            const invSnap = await tx.get(globalInviteRef);
            if (!invSnap.exists) {
                throw new functions.https.HttpsError("not-found", "Invalid invite.");
            }
            const inv = invSnap.data();
            let expiresAt = new Date(0);
            if (inv.expiresAt && typeof inv.expiresAt.toDate === "function") {
                expiresAt = inv.expiresAt.toDate();
            }
            if (expiresAt < new Date()) {
                throw new functions.https.HttpsError(
                    "failed-precondition",
                    "Invite expired."
                );
            }

            const familyId = inv.familyId;
            const famRef = db.collection("families").doc(familyId);
            const famSnap = await tx.get(famRef);
            if (!famSnap.exists) {
                throw new functions.https.HttpsError("not-found", "Family missing.");
            }

            // Link user → family, add to parentUids, and add a member row
            tx.set(
                userRef,
                {
                    displayName: displayName,
                    role: "parent",
                    familyId: familyId,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            tx.set(famRef, { ["parentUids." + uid]: true }, { merge: true });

            const memRef = famRef.collection("members").doc();
            tx.set(memRef, {
                name: displayName,
                role: "parent",
                avatar: "🦄",
                usesThisDevice: true,
                requiresPin: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Delete both invite docs (single-use)
            const famInviteRef = famRef.collection("invites").doc(code);
            tx.delete(globalInviteRef);
            tx.delete(famInviteRef);

            return { familyId: familyId };
        });
    });

exports.notifyOnAssignmentCompleted = functions
    .region("us-central1")
    .firestore.document("families/{familyId}/assignments/{assignmentId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data() || {};
        const after = change.after.data() || {};

        const familyId = context.params.familyId;
        const assignmentId = context.params.assignmentId;

        console.log("admin.app().options:", admin.app().options);
        console.log("GCLOUD_PROJECT:", process.env.GCLOUD_PROJECT);

        const beforeStatus = before.status;
        const afterStatus = after.status;
        const requiresApproval = !!after.requiresApproval;

        console.log(
            "notifyOnAssignmentCompleted fired:",
            JSON.stringify(
                {
                    familyId,
                    assignmentId,
                    beforeStatus,
                    afterStatus,
                    requiresApproval,
                },
                null,
                2
            )
        );

        // Only care about requiresApproval assignments
        if (!requiresApproval) {
            console.log("Skipping: requiresApproval is false.");
            return null;
        }

        // Fire when status changes *to pending* (kid submitted for review)
        if (beforeStatus === afterStatus) {
            console.log("Skipping: status unchanged.");
            return null;
        }
        if (afterStatus !== "pending") {
            console.log('Skipping: afterStatus is not "pending".');
            return null;
        }

        const kidName = after.memberName || "Your kid";
        const choreTitle = after.choreTitle || "a chore";
        const proof = after.proof || {};
        const hasPhoto = !!proof.photoUrl;
        const hasNote = !!(proof.note && proof.note.trim());


        let notifTitle = "Chore ready for review";
        let notifBody = `${kidName} marked "${choreTitle}" as done.`;

        if (hasPhoto && hasNote) {
            notifTitle = "📷 + 💬 Proof to review";
            notifBody = `${kidName} sent a photo and note for "${choreTitle}".`;
        } else if (hasPhoto) {
            notifTitle = "📷 Photo proof ready";
            notifBody = `${kidName} sent a photo for "${choreTitle}".`;
        } else if (hasNote) {
            notifTitle = "💬 Note to review";
            notifBody = `${kidName} left a note on "${choreTitle}".`;
        }

        const membersSnap = await db
            .collection("families")
            .doc(familyId)
            .collection("members")
            .where("role", "in", ["parent"])
            .get();

        const tokens = [];

        membersSnap.forEach((doc) => {
            const data = doc.data();

            // NEW: respect notificationsEnabled (default: true)
            const enabled = data.notificationsEnabled;
            const wantsNotifications = enabled !== false; // undefined or true ⇒ ON
            if (!wantsNotifications) {
                return; // skip this parent
            }

            const memberTokens = data.fcmTokens;
            if (Array.isArray(memberTokens)) {
                memberTokens.forEach((t) => {
                    if (typeof t === "string" && t.length > 0) {
                        tokens.push(t);
                    }
                });
            }
        });

        console.log(`Found ${tokens.length} parent tokens.`);
        if (tokens.length === 0) return null;

        const multicastMessage = {
            tokens, // array of registration tokens
            notification: {
                title: notifTitle,
                body: notifBody,
            },
            data: {
                type: "assignment_review",
                familyId,
                assignmentId,
            },
        };

        try {
            const response = await admin
                .messaging()
                .sendEachForMulticast(multicastMessage);
            console.log(
                `FCM sendEachForMulticast: success=${response.successCount}, failure=${response.failureCount}`
            );

            if (response.failureCount > 0) {
                const errors = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success) {
                        errors.push({
                            token: tokens[idx],
                            code: resp.error?.code,
                            message: resp.error?.message,
                            details: resp.error?.details,
                        });
                    }
                });
                console.log("FCM failures:", JSON.stringify(errors, null, 2));
            }

        } catch (err) {
            console.error("Error sending FCM notification:", {
                message: err.message,
                code: err.code,
                stack: err.stack,
                errorInfo: err.errorInfo,
                details: err.details,
            });
        }

        return null;
    });
