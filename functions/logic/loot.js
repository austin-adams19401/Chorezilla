const crypto = require("crypto");
const catalog = require("../data/cosmetic_catalog.json");

const RANK = {common: 0, rare: 1, epic: 2};

const BOXES = {
  lootbox_backgrounds: {type: "background", costCoins: 12, duplicateCoinRefund: 3},
  lootbox_skins: {type: "zillaSkin", costCoins: 8, duplicateCoinRefund: 2},
  lootbox_frames: {type: "avatarFrame", costCoins: 12, duplicateCoinRefund: 3},
  lootbox_avatars: {type: "avatar", costCoins: 10, duplicateCoinRefund: 2},
};

/**
 * 50/40/10 common/rare/epic. `roll` is an int in [0, 100).
 * @param {number} roll
 * @return {string}
 */
function rarityFromRoll(roll) {
  if (roll < 50) return "common";
  if (roll < 90) return "rare";
  return "epic";
}

/**
 * @param {() => number} [rng] returns int in [0, 100)
 * @return {{rolls: string[], best: string}}
 */
function rollBestOfThree(rng) {
  const next = rng || (() => crypto.randomInt(0, 100));
  const rolls = [];
  let best = null;
  for (let i = 0; i < 3; i++) {
    const rolled = rarityFromRoll(next());
    rolls.push(rolled);
    if (best == null || RANK[rolled] > RANK[best]) best = rolled;
  }
  return {rolls, best};
}

/**
 * Pick an item using the same fallback order as the client catalog.
 * @param {string} type CosmeticType name
 * @param {string} targetRarity
 * @param {string[]} owned
 * @param {() => number} [rngIndex] returns a float in [0, 1)
 * @return {{item: object, isDuplicate: boolean}}
 */
function pickItem(type, targetRarity, owned, rngIndex) {
  const nextIndex = rngIndex || Math.random;
  const ownedSet = new Set(owned || []);
  const pool = catalog.filter((c) => c.type === type && !c.isDefault && c.rarity);
  const choose = (list) => list[Math.floor(nextIndex() * list.length)];

  if (pool.length === 0) {
    const defaults = catalog.filter((c) => c.type === type && c.isDefault);
    const item = defaults[0] || catalog[0];
    return {item, isDuplicate: ownedSet.has(item.id)};
  }

  const exact = pool.filter((c) => c.rarity === targetRarity && !ownedSet.has(c.id));
  if (exact.length > 0) return {item: choose(exact), isDuplicate: false};

  const order = ["epic", "rare", "common"];
  for (const rarity of order) {
    if (rarity === targetRarity) continue;
    const other = pool.filter((c) => c.rarity === rarity && !ownedSet.has(c.id));
    if (other.length > 0) return {item: choose(other), isDuplicate: false};
  }

  const fallback = pool.filter((c) => c.rarity === targetRarity);
  const item = fallback.length > 0 ? choose(fallback) : choose(pool);
  return {item, isDuplicate: true};
}

/**
 * @param {string} type
 * @param {string[]} owned
 * @param {() => number} [rngIndex]
 * @return {object|null}
 */
function pickUnownedOfType(type, owned, rngIndex) {
  const nextIndex = rngIndex || Math.random;
  const ownedSet = new Set(owned || []);
  const pool = catalog.filter((c) => c.type === type && !ownedSet.has(c.id));
  if (pool.length === 0) return null;
  return pool[Math.floor(nextIndex() * pool.length)];
}

/**
 * @param {string} id
 * @return {object|null}
 */
function itemById(id) {
  return catalog.find((c) => c.id === id) || null;
}

module.exports = {
  BOXES,
  catalog,
  rarityFromRoll,
  rollBestOfThree,
  pickItem,
  pickUnownedOfType,
  itemById,
};
