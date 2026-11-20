const crypto = require("crypto");

const ITERATIONS = 120000;
const KEYLEN = 32;
const DIGEST = "sha256";
const MAX_ATTEMPTS = 5;
const WINDOW_MS = 15 * 60 * 1000;

/**
 * Legacy client hash: SHA-256 hex of `${familyId}|${pin}`.
 * @param {string} familyId
 * @param {string} pin
 * @return {string}
 */
function legacySha256(familyId, pin) {
  return crypto.createHash("sha256").update(`${familyId}|${pin}`).digest("hex");
}

/**
 * @param {string} value
 * @return {boolean}
 */
function isLegacySha256(value) {
  return typeof value === "string" && /^[0-9a-f]{64}$/.test(value);
}

/**
 * @param {string} pin
 * @param {string} salt hex
 * @param {number} iterations
 * @return {string}
 */
function pbkdf2Hex(pin, salt, iterations) {
  return crypto.pbkdf2Sync(pin, salt, iterations, KEYLEN, DIGEST).toString("hex");
}

/**
 * @param {string} pin
 * @return {{kdf: string, iterations: number, salt: string, hash: string}}
 */
function createPinRecord(pin) {
  const salt = crypto.randomBytes(16).toString("hex");
  return {
    kdf: "pbkdf2-sha256",
    iterations: ITERATIONS,
    salt,
    hash: pbkdf2Hex(pin, salt, ITERATIONS),
  };
}

/**
 * @param {string} pin
 * @param {{hash?: string, salt?: string, iterations?: number}|null} record
 * @return {boolean}
 */
function verifyPinRecord(pin, record) {
  if (!record || typeof record.hash !== "string" || typeof record.salt !== "string") {
    return false;
  }
  const iterations = Number(record.iterations) || ITERATIONS;
  const derived = pbkdf2Hex(pin, record.salt, iterations);
  const a = Buffer.from(derived, "hex");
  const b = Buffer.from(record.hash, "hex");
  if (a.length === 0 || a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

/**
 * Verify a value stored by older clients (hex SHA-256 or raw 4-digit PIN).
 * @param {string} familyId
 * @param {string} pin
 * @param {string|null|undefined} stored
 * @return {boolean}
 */
function verifyLegacy(familyId, pin, stored) {
  if (stored == null) return false;
  const value = String(stored);
  if (value.length === 0) return false;
  if (isLegacySha256(value)) return legacySha256(familyId, pin) === value;
  return value === pin;
}

/**
 * @param {string} pin
 * @return {boolean}
 */
function isValidPin(pin) {
  return typeof pin === "string" && /^\d{4}$/.test(pin);
}

/**
 * @param {{count?: number, windowStartMs?: number}|null|undefined} entry
 * @param {number} now
 * @return {{count: number, windowStartMs: number, locked: boolean}}
 */
function attemptState(entry, now) {
  const start = entry && Number(entry.windowStartMs);
  const fresh = !start || now - start >= WINDOW_MS;
  const count = fresh ? 0 : Number(entry.count) || 0;
  return {
    count,
    windowStartMs: fresh ? now : start,
    locked: count >= MAX_ATTEMPTS,
  };
}

module.exports = {
  ITERATIONS,
  MAX_ATTEMPTS,
  WINDOW_MS,
  legacySha256,
  isLegacySha256,
  createPinRecord,
  verifyPinRecord,
  verifyLegacy,
  isValidPin,
  attemptState,
};
