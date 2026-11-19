const ENTITLEMENT = "Chorezilla Unlimited";
const GRACE_MS = 14 * 24 * 60 * 60 * 1000;

/**
 * @param {number} level
 * @return {number}
 */
function xpForLevel(level) {
  if (level <= 1) return 0;
  const thresholds = [0, 100, 250, 450, 700, 1050, 1550, 2250, 3200, 4450];
  const idx = level - 1;
  if (idx < thresholds.length) return thresholds[idx];
  let xp = thresholds[thresholds.length - 1];
  let gap = 1250;
  const extra = level - thresholds.length;
  for (let i = 0; i < extra; i++) {
    gap = Math.round(gap * 1.3);
    xp += gap;
  }
  return xp;
}

/**
 * @param {number} totalXp
 * @return {number}
 */
function levelForXp(totalXp) {
  let xp = Number(totalXp) || 0;
  if (xp < 0) xp = 0;
  let level = 1;
  while (xp >= xpForLevel(level + 1)) {
    level++;
    if (level > 1000) break;
  }
  return level;
}

/**
 * Premium is lifetime, or an unexpired premium tier.
 * A future trialExpiresAt does NOT grant premium when tier is free.
 * @param {object} data family document
 * @param {number} now ms
 * @return {boolean}
 */
function isPremiumFamily(data, now) {
  const fam = data || {};
  const tier = fam.subscriptionTier || "free";
  const at = typeof now === "number" ? now : Date.now();
  if (tier === "lifetime") return true;
  if (tier !== "premium") return false;
  const billing = toDate(fam.billingIssueDetectedAt);
  if (billing && at - billing.getTime() >= GRACE_MS) return false;
  if (billing) return true;
  const expiry = toDate(fam.subscriptionExpiresAt) || toDate(fam.trialExpiresAt);
  if (!expiry) return true;
  return expiry.getTime() > at;
}

/**
 * @param {*} value
 * @return {Date|null}
 */
function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value === "number") return new Date(value);
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

/**
 * Map a RevenueCat REST subscriber payload to Firestore subscription fields.
 * Active trials are stored as tier "premium" (not free + trialExpiresAt).
 * @param {object} subscriber
 * @param {number} now
 * @return {{tier: string, expiresAt: Date|null, trialExpiresAt: Date|null,
 *   billingIssueDetectedAt: Date|null}}
 */
function fieldsFromSubscriber(subscriber, now) {
  const at = typeof now === "number" ? now : Date.now();
  const sub = subscriber || {};
  const entitlements = sub.entitlements || {};
  const entitlement = entitlements[ENTITLEMENT] || null;
  const subscriptions = sub.subscriptions || {};
  if (!entitlement) {
    return {
      tier: "free",
      expiresAt: null,
      trialExpiresAt: null,
      billingIssueDetectedAt: null,
    };
  }

  const productId = String(entitlement.product_identifier || "");
  const expiresAt = toDate(entitlement.expires_date);
  const subInfo = subscriptions[productId] || {};
  const period = String(subInfo.period_type || "").toLowerCase();
  const billing = toDate(subInfo.billing_issues_detected_at);
  const nonSubs = sub.non_subscriptions || {};
  const hasNonSub = Array.isArray(nonSubs[productId]) && nonSubs[productId].length > 0;
  const active = !expiresAt || expiresAt.getTime() > at;
  const lifetime = productId.toLowerCase().includes("lifetime") ||
    (expiresAt == null && (hasNonSub || period !== "trial"));

  let tier = "free";
  let trialExpiresAt = null;
  let keptExpires = null;
  if (active && lifetime) {
    tier = "lifetime";
  } else if (active) {
    tier = "premium";
    keptExpires = expiresAt;
    if (period === "trial") trialExpiresAt = expiresAt;
  }

  return applyBillingGrace({
    tier,
    expiresAt: keptExpires,
    trialExpiresAt,
    billingIssueDetectedAt: billing,
  }, at);
}

/**
 * Map a RevenueCat webhook event when the REST API is not called.
 * @param {object} event
 * @param {number} now
 * @return {{tier: string, expiresAt: Date|null, trialExpiresAt: Date|null,
 *   billingIssueDetectedAt: Date|null, ignore: boolean}}
 */
function fieldsFromWebhookEvent(event, now) {
  const at = typeof now === "number" ? now : Date.now();
  const type = String((event && event.type) || "");
  if (type === "TEST") {
    return {
      tier: "free",
      expiresAt: null,
      trialExpiresAt: null,
      billingIssueDetectedAt: null,
      ignore: true,
    };
  }
  const productId = String((event && event.product_id) || "");
  const expiresAt = event && event.expiration_at_ms ? new Date(Number(event.expiration_at_ms)) : null;
  const period = String((event && event.period_type) || "").toLowerCase();
  const lifetime = productId.toLowerCase().includes("lifetime") || type === "NON_RENEWING_PURCHASE";
  const ended = type === "EXPIRATION" || type === "REFUND";
  let billing = null;
  if (type === "BILLING_ISSUE") billing = new Date(at);

  if (ended) {
    return applyBillingGrace({
      tier: "free",
      expiresAt: null,
      trialExpiresAt: null,
      billingIssueDetectedAt: billing,
    }, at);
  }

  const active = lifetime || !expiresAt || expiresAt.getTime() > at;
  let tier = "free";
  let trialExpiresAt = null;
  let keptExpires = null;
  if (active && lifetime && type !== "BILLING_ISSUE") {
    tier = "lifetime";
  } else if (active) {
    tier = "premium";
    keptExpires = lifetime ? null : expiresAt;
    if (period === "trial" && expiresAt) trialExpiresAt = expiresAt;
  }
  return {
    ...applyBillingGrace({
      tier,
      expiresAt: keptExpires,
      trialExpiresAt,
      billingIssueDetectedAt: billing,
    }, at),
    ignore: false,
  };
}

/**
 * @param {{tier: string, expiresAt: Date|null, trialExpiresAt: Date|null,
 *   billingIssueDetectedAt: Date|null}} fields
 * @param {number} now
 * @return {{tier: string, expiresAt: Date|null, trialExpiresAt: Date|null,
 *   billingIssueDetectedAt: Date|null}}
 */
function applyBillingGrace(fields, now) {
  const billing = fields.billingIssueDetectedAt;
  if (!billing) return fields;
  if (now - billing.getTime() >= GRACE_MS) {
    return {
      tier: "free",
      expiresAt: null,
      trialExpiresAt: null,
      billingIssueDetectedAt: billing,
    };
  }
  return fields;
}

const DEFAULT_LEVEL_COSMETICS = {
  3: "zilla_sky_blue",
  6: "bg_dino",
  8: "frame_stars",
  11: "zilla_coral",
  13: "bg_ocean",
  16: "zilla_purple",
  18: "frame_rainbow",
  19: "zilla_gold",
};

/**
 * Cosmetic id granted at [level], honoring premium custom rewards.
 * @param {object} family
 * @param {number} level
 * @param {boolean} premium
 * @return {string|null}
 */
function levelCosmeticId(family, level, premium) {
  if (premium) {
    const custom = family && family.settings && family.settings.customLevelRewards;
    const list = custom && (custom[String(level)] || custom[level]);
    if (Array.isArray(list) && list.length > 0) {
      const id = list[0] && list[0].cosmeticId;
      return typeof id === "string" && id.length > 0 ? id : null;
    }
  }
  return DEFAULT_LEVEL_COSMETICS[level] || null;
}

module.exports = {
  ENTITLEMENT,
  GRACE_MS,
  xpForLevel,
  levelForXp,
  isPremiumFamily,
  fieldsFromSubscriber,
  fieldsFromWebhookEvent,
  levelCosmeticId,
  DEFAULT_LEVEL_COSMETICS,
};
