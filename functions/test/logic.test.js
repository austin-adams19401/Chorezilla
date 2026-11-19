const test = require("node:test");
const assert = require("node:assert/strict");
const pins = require("../logic/pins");
const sub = require("../logic/subscription");
const loot = require("../logic/loot");
const limits = require("../logic/limits");

test("legacy SHA-256 matches familyId|pin and rejects plaintext lookalikes", () => {
  const hash = pins.legacySha256("fam", "1234");
  assert.equal(hash.length, 64);
  assert.equal(pins.verifyLegacy("fam", "1234", hash), true);
  assert.equal(pins.verifyLegacy("fam", "9999", hash), false);
  assert.equal(pins.verifyLegacy("other", "1234", hash), false);
  assert.equal(pins.verifyLegacy("fam", "1234", "1234"), true);
  assert.equal(pins.verifyLegacy("fam", "1234", ""), false);
});

test("pbkdf2 record verifies and does not match a different PIN", () => {
  const record = pins.createPinRecord("2468");
  assert.equal(record.kdf, "pbkdf2-sha256");
  assert.equal(record.iterations, pins.ITERATIONS);
  assert.equal(pins.verifyPinRecord("2468", record), true);
  assert.equal(pins.verifyPinRecord("2469", record), false);
  assert.equal(pins.verifyPinRecord("2468", null), false);
});

test("attempt window locks after 5 failures and resets after the window", () => {
  const now = 1000000;
  let state = pins.attemptState(null, now);
  assert.equal(state.locked, false);
  for (let i = 1; i <= 5; i++) {
    state = pins.attemptState({count: i, windowStartMs: now}, now + 1000);
  }
  assert.equal(state.count, 5);
  assert.equal(state.locked, true);
  const later = pins.attemptState(
      {count: 5, windowStartMs: now},
      now + pins.WINDOW_MS + 1,
  );
  assert.equal(later.count, 0);
  assert.equal(later.locked, false);
});

test("free tier does not become premium from a future trialExpiresAt", () => {
  const now = Date.now();
  const future = new Date(now + 3 * 86400000);
  assert.equal(sub.isPremiumFamily({
    subscriptionTier: "free",
    trialExpiresAt: future,
  }, now), false);
  assert.equal(sub.isPremiumFamily({
    subscriptionTier: "premium",
    subscriptionExpiresAt: future,
  }, now), true);
  assert.equal(sub.isPremiumFamily({subscriptionTier: "lifetime"}, now), true);
  assert.equal(sub.isPremiumFamily({
    subscriptionTier: "premium",
    subscriptionExpiresAt: new Date(now - 1000),
  }, now), false);
});

test("RevenueCat subscriber payload maps trials to premium, not free", () => {
  const now = Date.parse("2026-01-01T00:00:00Z");
  const expires = "2026-02-01T00:00:00Z";
  const trial = sub.fieldsFromSubscriber({
    entitlements: {
      "Chorezilla Unlimited": {
        expires_date: expires,
        product_identifier: "monthly",
      },
    },
    subscriptions: {
      monthly: {period_type: "trial", expires_date: expires},
    },
  }, now);
  assert.equal(trial.tier, "premium");
  assert.ok(trial.trialExpiresAt);
  assert.equal(trial.expiresAt.toISOString(), new Date(expires).toISOString());

  const lifetime = sub.fieldsFromSubscriber({
    entitlements: {
      "Chorezilla Unlimited": {
        expires_date: null,
        product_identifier: "lifetime",
      },
    },
    subscriptions: {},
  }, now);
  assert.equal(lifetime.tier, "lifetime");
  assert.equal(lifetime.expiresAt, null);

  const none = sub.fieldsFromSubscriber({entitlements: {}}, now);
  assert.equal(none.tier, "free");
});

test("billing grace forces free after 14 days", () => {
  const now = Date.parse("2026-06-01T00:00:00Z");
  const recent = new Date(now - 2 * 86400000).toISOString();
  const old = new Date(now - 15 * 86400000).toISOString();
  const active = {
    entitlements: {
      "Chorezilla Unlimited": {
        expires_date: "2026-07-01T00:00:00Z",
        product_identifier: "annual",
      },
    },
    subscriptions: {
      annual: {
        period_type: "normal",
        billing_issues_detected_at: recent,
      },
    },
  };
  assert.equal(sub.fieldsFromSubscriber(active, now).tier, "premium");
  active.subscriptions.annual.billing_issues_detected_at = old;
  assert.equal(sub.fieldsFromSubscriber(active, now).tier, "free");
});

test("webhook TEST events are ignored and expiration clears premium", () => {
  const now = Date.parse("2026-03-01T00:00:00Z");
  assert.equal(sub.fieldsFromWebhookEvent({type: "TEST"}, now).ignore, true);
  const expired = sub.fieldsFromWebhookEvent({
    type: "EXPIRATION",
    product_id: "monthly",
  }, now);
  assert.equal(expired.tier, "free");
  const purchase = sub.fieldsFromWebhookEvent({
    type: "INITIAL_PURCHASE",
    product_id: "annual",
    period_type: "NORMAL",
    expiration_at_ms: now + 30 * 86400000,
  }, now);
  assert.equal(purchase.tier, "premium");
});

test("level thresholds match the app pacing", () => {
  assert.equal(sub.levelForXp(0), 1);
  assert.equal(sub.levelForXp(99), 1);
  assert.equal(sub.levelForXp(100), 2);
  assert.equal(sub.levelForXp(4450), 10);
  assert.equal(sub.xpForLevel(2), 100);
  assert.equal(sub.levelCosmeticId({}, 3, false), "zilla_sky_blue");
  assert.equal(sub.levelCosmeticId({
    settings: {customLevelRewards: {"3": [{cosmeticId: "bg_ocean"}]}},
  }, 3, false), "zilla_sky_blue");
  assert.equal(sub.levelCosmeticId({
    settings: {customLevelRewards: {"3": [{cosmeticId: "bg_ocean"}]}},
  }, 3, true), "bg_ocean");
});

test("loot rarity is 50/40/10 and best-of-three keeps the higher roll", () => {
  assert.equal(loot.rarityFromRoll(0), "common");
  assert.equal(loot.rarityFromRoll(49), "common");
  assert.equal(loot.rarityFromRoll(50), "rare");
  assert.equal(loot.rarityFromRoll(89), "rare");
  assert.equal(loot.rarityFromRoll(90), "epic");
  assert.equal(loot.rarityFromRoll(99), "epic");

  const scripted = [95, 10, 60];
  let i = 0;
  const rolled = loot.rollBestOfThree(() => scripted[i++]);
  assert.deepEqual(rolled.rolls, ["epic", "common", "rare"]);
  assert.equal(rolled.best, "epic");

  const counts = {common: 0, rare: 0, epic: 0};
  const n = 20000;
  for (let nRoll = 0; nRoll < n; nRoll++) counts[loot.rarityFromRoll(Math.floor(Math.random() * 100))]++;
  assert.ok(Math.abs(counts.common / n - 0.5) < 0.02);
  assert.ok(Math.abs(counts.rare / n - 0.4) < 0.02);
  assert.ok(Math.abs(counts.epic / n - 0.1) < 0.02);
});

test("loot pick prefers an unowned item of the rolled rarity", () => {
  const picked = loot.pickItem("background", "epic", [], () => 0);
  assert.equal(picked.isDuplicate, false);
  assert.equal(picked.item.type, "background");
  assert.equal(picked.item.rarity, "epic");

  const owned = loot.catalog
      .filter((c) => c.type === "avatar" && !c.isDefault && c.rarity)
      .map((c) => c.id);
  const dup = loot.pickItem("avatar", "common", owned, () => 0);
  assert.equal(dup.isDuplicate, true);
});

test("kid role accepts child and kid; custom flag cannot hide a made-up title", () => {
  assert.equal(limits.isKidRole("child"), true);
  assert.equal(limits.isKidRole("kid"), true);
  assert.equal(limits.isKidRole("parent"), false);
  assert.equal(limits.countsAsCustom(
      {title: "Do the Dishes", isCustom: false},
      limits.DEFAULT_CHORE_TITLES,
  ), false);
  assert.equal(limits.countsAsCustom(
      {title: "Invented chore", isCustom: false},
      limits.DEFAULT_CHORE_TITLES,
  ), true);
  assert.equal(limits.countsAsCustom(
      {title: "Candy", isCustom: false},
      limits.DEFAULT_REWARD_TITLES,
  ), false);
});
