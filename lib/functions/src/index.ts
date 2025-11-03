// const scheduler = require('firebase-functions/v2/scheduler');
// const functions = require('firebase-functions');
// const admin = require('firebase-admin');
// const DateTime = require('luxon');

// admin.initializeApp();
// const db = admin.firestore();

// /**
//  * Runs every 15 minutes. Inside, we check each family's local day
//  * and only generate once per family per day (idempotent).
//  */
// export const dailyAssignmentGenerator = scheduler(
//   {
//     schedule: "every 15 minutes", // Cron is also supported if you prefer.
//     timeZone: "UTC",              // Keep the trigger in UTC; we handle per-family TZ inside.
//     region: "us-central1",
//     timeoutSeconds: 120,
//   },
//   async () => {
//     // 1) Load families (store each family's IANA timezone, e.g., "America/Denver")
//     const familiesSnap = await db.collection("families").get();

//     for (const famDoc of familiesSnap.docs) {
//       const fam = famDoc.data() as any;
//       const tz = fam.timezone || "America/Denver";

//       // 2) Compute "today" for the family's timezone (YYYYMMDD)
//       const nowTz = DateTime.now().setZone(tz);
//       const ymd = nowTz.toFormat("yyyyLLdd");

//       // Skip if we've already generated for this family today
//       if (fam.lastRunYMD === ymd) continue;

//       // 3) Get active chore templates
//       const choresSnap = await famDoc.ref
//         .collection("chores")
//         .where("active", "==", true)
//         .get();

//       const batch = db.batch();
//       let createdCount = 0;

//       for (const choreDoc of choresSnap.docs) {
//         const chore = choreDoc.data() as any;

//         // Decide if this template is due today (weekday rules, every N days, start/end range, etc.)
//         if (!isDueToday(chore, nowTz)) continue;

//         // Resolve who gets it (fixed, rotation, or “anyone”)
//         const assignees: string[] = resolveAssignees(chore, fam);

//         for (const memberId of assignees.length ? assignees : ["any"]) {
//           const keyPart = memberId === "any" ? "any" : memberId;
//           const id = `${ymd}_${choreDoc.id}_${keyPart}`; // deterministic ID prevents duplicates

//           const ref = famDoc.ref.collection("dailyAssignments").doc(id);

//           // Use create() so it throws if already exists (idempotent)
//           batch.create(ref, {
//             id,
//             choreId: choreDoc.id,
//             dateYMD: ymd,
//             assigneeId: memberId === "any" ? null : memberId,
//             status: "open",
//             points: pointsFromDifficulty(chore.difficulty),
//             createdAt: admin.firestore.FieldValue.serverTimestamp(),
//           });

//           createdCount++;
//         }

//         // Optional: advance rotation pointer on the chore template here (if you rotate daily)
//         // batch.update(choreDoc.ref, { nextAssigneeIndex: newIndex });
//       }

//       // 4) Mark family last run
//       batch.update(famDoc.ref, {
//         lastRunYMD: ymd,
//         updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//       });

//       // 5) Commit
//       try {
//         await batch.commit();
//         // logger.info(`Generated ${createdCount} assignments for family ${famDoc.id} on ${ymd}`);
//       } catch (e) {
//         // If some docs already existed, create() will fail — that's OK for idempotency.
//         // logger.warn(`Batch commit issue for family ${famDoc.id}: ${(e as Error).message}`);
//       }
//     }
//   }
// );

// // --- Helper stubs (keep simple & predictable) ---
// function isDueToday(_chore: any, _nowTz: DateTime): boolean {
//   // Examples:
//   // - daily
//   // - specific weekdays: chore.recurrence.daysOfWeek = [1..7] (Mon..Sun)
//   // - every N days since startDate
//   // - between startDate and endDate
//   // Implement to match your template fields.
//   return true;
// }

// function resolveAssignees(chore: any, family: any): string[] {
//   // Return ["memberId"] for fixed; next kid for rotation; [] for “anyone”.
//   if (chore.assignmentMode === "fixed" && chore.fixedAssigneeId) return [chore.fixedAssigneeId];
//   if (chore.assignmentMode === "rotate" && Array.isArray(chore.eligibleMemberIds) && chore.eligibleMemberIds.length) {
//     const i = (chore.nextAssigneeIndex ?? 0) % chore.eligibleMemberIds.length;
//     return [chore.eligibleMemberIds[i]];
//   }
//   return []; // means “anyone”
// }

// function pointsFromDifficulty(diff: number): number {
//   // Your mapping here (e.g., 1→10 pts, 2→20 pts, etc.)
//   return Math.max(1, Math.round(diff * 10));
// }