const FREE_KIDS = 2;
const FREE_CUSTOM_CHORES = 3;
const FREE_CUSTOM_REWARDS = 3;

const DEFAULT_CHORE_TITLES = new Set([
  "Do the Dishes",
  "Load the Dishwasher",
  "Unload the Dishwasher",
  "Wipe Down Counters",
  "Wipe the Stove",
  "Clean the Microwave",
  "Set the Table",
  "Clear the Table",
  "Sweep the Floor",
  "Mop the Floor",
  "Vacuum",
  "Take Out the Trash",
  "Take Out the Recycling",
  "Start the Laundry",
  "Fold the Laundry",
  "Put Away Laundry",
  "Make Your Bed",
  "Clean Your Room",
  "Clean the Toilet",
  "Clean the Shower",
  "Clean the Bathroom Sink",
  "Wipe the Mirrors",
  "Water the Plants",
  "Mow the Lawn",
  "Rake Leaves",
  "Pull Weeds",
  "Feed the Dog",
  "Walk the Dog",
  "Clean the Litter Box",
  "Feed the Fish",
  "Feed the Cat",
  "Do Homework",
  "Read for 30 Minutes",
  "Pack Your Backpack",
  "Brush Your Teeth",
  "Take a Shower",
  "Brush Your Hair",
  "Get Dressed",
]);

const DEFAULT_REWARD_TITLES = new Set([
  "Candy",
  "Choose Dessert",
  "Ice Cream",
  "Bake Cookies Together",
  "Gas Station Treat",
  "Choose Dinner",
  "Pizza Night",
  "Bedtime Story",
  "Choose Car Music",
  "Extra Screen Time",
  "Stay Up 30 Minutes Late",
  "Skip a Chore",
  "Breakfast in Bed",
  "Build a Fort",
  "Park Trip",
  "Backyard Campfire",
  "Game Night",
  "Movie Night",
  "Pool or Splash Pad",
  "Bowling Trip",
  "Go to the Movies",
  "Go to Arcade",
  "Go to a Sports Game",
  "New Book",
  "New Toy",
  "New Video Game",
]);

/**
 * Built-in chores/rewards are not custom. A client-forged isCustom:false
 * still counts as custom when the title is not a built-in.
 * @param {object} data
 * @param {Set<string>} defaults
 * @return {boolean}
 */
function countsAsCustom(data, defaults) {
  const title = data && data.title;
  if (data && data.isCustom === false && defaults.has(title)) return false;
  return true;
}

/**
 * Kind stored on a join-code document. Missing kind is the legacy kid/QR code.
 * @param {object} data
 * @return {"parent"|"child"}
 */
function joinCodeKind(data) {
  return data && data.kind === "parent" ? "parent" : "child";
}

/**
 * @param {Array<{id: string, role?: string, active?: boolean, displayName?: string, name?: string, avatarKey?: string}>} members
 * @return {Array<{id: string, displayName: string, avatarKey: string|null}>}
 */
function previewKids(members) {
  return (members || [])
      .filter((member) => isKidRole(member.role) && member.active !== false)
      .map((member) => ({
        id: member.id,
        displayName: member.displayName || member.name || "Kid",
        avatarKey: member.avatarKey || null,
      }));
}

function isKidRole(role) {
  return role === "kid" || role === "child";
}

module.exports = {
  FREE_KIDS,
  FREE_CUSTOM_CHORES,
  FREE_CUSTOM_REWARDS,
  DEFAULT_CHORE_TITLES,
  DEFAULT_REWARD_TITLES,
  countsAsCustom,
  isKidRole,
  joinCodeKind,
  previewKids,
};
