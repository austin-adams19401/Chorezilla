const fs = require("fs");
const path = require("path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} = require("firebase/firestore");

const projectId = "demo-chorezilla";
let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

async function seed() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "families/fam1"), {
      name: "The Kids",
      ownerUid: "owner",
      onboardingComplete: false,
      subscriptionTier: "free",
    });
    await setDoc(doc(db, "users/owner"), {
      displayName: "Owner",
      role: "parent",
      defaultFamilyId: "fam1",
      memberships: {fam1: {memberId: "owner", role: "parent"}},
    });
    await setDoc(doc(db, "users/kid"), {
      displayName: "Kid Login",
      role: "kid",
      defaultFamilyId: "fam1",
      familyId: "fam1",
      memberId: "kid1",
      memberships: {fam1: {memberId: "kid1", role: "child"}},
    });
    await setDoc(doc(db, "users/stranger"), {displayName: "Stranger"});
    await setDoc(doc(db, "families/fam1/members/kid1"), {
      displayName: "Sam",
      role: "child",
      coins: 10,
      xp: 0,
      ownedCosmetics: ["title_level_1"],
      active: true,
    });
    await setDoc(doc(db, "families/fam1/private/security"), {
      parentPin: {hash: "secret"},
    });
  });
}

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

test("strangers and signed-out users cannot read a family", async () => {
  await seed();
  await assertFails(getDoc(doc(dbFor("stranger"), "families/fam1")));
  await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), "families/fam1")));
  await assertFails(getDoc(doc(dbFor("stranger"), "families/fam1/members/kid1")));
});

test("the owner can read the family and cannot write subscription fields", async () => {
  await seed();
  const db = dbFor("owner");
  await assertSucceeds(getDoc(doc(db, "families/fam1")));
  await assertSucceeds(updateDoc(doc(db, "families/fam1"), {name: "Renamed"}));
  await assertFails(updateDoc(doc(db, "families/fam1"), {subscriptionTier: "lifetime"}));
  await assertFails(updateDoc(doc(db, "families/fam1"), {
    trialExpiresAt: new Date(Date.now() + 86400000),
  }));
  await assertFails(updateDoc(doc(db, "families/fam1"), {parentPinHash: "abc"}));
});

test("a linked kid can update coins but not cosmetics or the pin hash", async () => {
  await seed();
  const db = dbFor("kid");
  await assertSucceeds(getDoc(doc(db, "families/fam1/chores/nope")));
  await assertSucceeds(updateDoc(doc(db, "families/fam1/members/kid1"), {coins: 12}));
  await assertSucceeds(updateDoc(doc(db, "families/fam1/members/kid1"), {
    ownedCosmetics: ["title_level_1", "title_level_2"],
  }));
  await assertFails(updateDoc(doc(db, "families/fam1/members/kid1"), {
    ownedCosmetics: ["title_level_1", "bg_dino"],
  }));
  await assertFails(updateDoc(doc(db, "families/fam1/members/kid1"), {pinHash: "1234"}));
  await assertFails(getDoc(doc(db, "families/fam1/private/security")));
});

test("a kid login cannot rename or delete the family", async () => {
  await seed();
  const db = dbFor("kid");
  await assertFails(updateDoc(doc(db, "families/fam1"), {name: "Hacked"}));
  await assertSucceeds(setDoc(doc(db, "families/fam1/assignments/a1"), {
    status: "assigned",
    memberId: "kid1",
  }));
  await assertFails(deleteDoc(doc(db, "families/fam1")));
});

test("owner creates a child with zero coins and cannot mint coins on create", async () => {
  await seed();
  const db = dbFor("owner");
  await assertSucceeds(setDoc(doc(db, "families/fam1/members/kid2"), {
    displayName: "New",
    role: "child",
    coins: 0,
    active: true,
    ownedCosmetics: ["title_level_1"],
  }));
  await assertFails(setDoc(doc(db, "families/fam1/members/kid3"), {
    displayName: "Rich",
    role: "child",
    coins: 500,
    active: true,
  }));
});

test("a user cannot point their profile at a family they do not own", async () => {
  await seed();
  const db = dbFor("stranger");
  await assertFails(updateDoc(doc(db, "users/stranger"), {
    defaultFamilyId: "fam1",
    memberships: {fam1: {memberId: "kid1", role: "parent"}},
    role: "parent",
  }));
  await assertSucceeds(updateDoc(doc(db, "users/stranger"), {displayName: "Pat"}));
});

test("owner can publish a join code and other users cannot read the code doc", async () => {
  await seed();
  const owner = dbFor("owner");
  await assertSucceeds(setDoc(doc(owner, "joinCodes/ABC123"), {
    familyId: "fam1",
    kind: "child",
    createdAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(dbFor("stranger"), "joinCodes/ABC123")));
  await assertFails(setDoc(doc(dbFor("stranger"), "joinCodes/ZZZZZZ"), {
    familyId: "fam1",
    kind: "child",
    createdAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(owner, "joinCodes/NOPARENT"), {
    familyId: "fam1",
    createdAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(owner, "joinCodes/ABC123"), {kind: "parent"}));
  await assertSucceeds(setDoc(doc(owner, "joinCodes/PARENT1"), {
    familyId: "fam1",
    kind: "parent",
    createdAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(owner, "families/fam1"), {parentJoinCode: "PARENT1"}));
  await assertFails(setDoc(doc(dbFor("kid"), "joinCodes/PARENT2"), {
    familyId: "fam1",
    kind: "parent",
    createdAt: serverTimestamp(),
  }));
});

test("a member cannot promote their own role to parent", async () => {
  await seed();
  const kid = dbFor("kid");
  await assertFails(updateDoc(doc(kid, "users/kid"), {role: "parent"}));
  await assertSucceeds(setDoc(doc(kid, "families/kid"), {
    name: "Kid family",
    ownerUid: "kid",
  }));
  await assertFails(updateDoc(doc(kid, "users/kid"), {
    role: "parent",
    defaultFamilyId: "kid",
    familyId: "kid",
    memberships: {kid: {memberId: "kid", role: "parent"}},
  }));
});

test("a profile marked parent is not a parent without parentUids", async () => {
  await seed();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users/pretend"), {
      displayName: "Pretend",
      role: "parent",
      defaultFamilyId: "fam1",
      memberships: {fam1: {memberId: "pretend", role: "parent"}},
    });
  });
  const db = dbFor("pretend");
  await assertFails(updateDoc(doc(db, "families/fam1"), {name: "Taken over"}));
  await assertFails(deleteDoc(doc(db, "families/fam1/members/kid1")));
});

test("creating a family as premium from the client is rejected", async () => {
  await seed();
  const db = dbFor("stranger");
  await assertFails(setDoc(doc(db, "families/stranger"), {
    name: "Mine",
    ownerUid: "stranger",
    subscriptionTier: "lifetime",
  }));
  await assertSucceeds(setDoc(doc(db, "families/stranger"), {
    name: "Mine",
    ownerUid: "stranger",
    onboardingComplete: false,
  }));
});

test("sanity: seeded kid coins stayed readable by the owner", async () => {
  await seed();
  const snap = await assertSucceeds(getDoc(doc(dbFor("owner"), "families/fam1/members/kid1")));
  assert.equal(snap.data().coins, 10);
});
