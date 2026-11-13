// Custom item entries — hand-maintained (NOT generated; tools/import-items.py never touches this file).
// These fill gaps in the workbook catalog so every inventory item can link to a database entry.
// Same record keys as items.js, plus:
//   t   inventory type the item lands as (Snack / Ration / Meal / Bag / Tool / …) when it isn't obvious from the group
//   d   description shown on the character sheet
// Stats marked DRAFT in the description are placeholders written by Claude — correct them freely.
const ITEMS_CUSTOM = [
  // --- food & drink (the tracker's hunger buttons consume these by type) ---
  {"n":"Snack","g":"Gear","c":"Survival","t":"Snack","p":1,"e":0,"ra":0,"d":"A bite on the move: ration bar, jerky, dried fruit. The snack button eats one (a small hunger relief, no time cost)."},
  {"n":"Meal","g":"Gear","c":"Survival","t":"Meal","p":10,"e":0,"ra":0,"d":"A prepared or cooked meal. The meal button eats one over 30 minutes (the best hunger relief, and a little rest)."},
  {"n":"Canteen","g":"Gear","c":"Survival","p":5,"e":0,"ra":0,"d":"A 20 oz water bottle. Its fill level is tracked on the Tracker card."},
  // --- droid upkeep ---
  {"n":"Droid Power Pack","g":"Gear","c":"Equipment","p":25,"e":0,"ra":1,"d":"A spare power pack for a droid. Charged and depleted counts are tracked on the droid's Tracker card."},
  {"n":"BD-1 Battery Pack","g":"Gear","c":"Equipment","p":25,"e":0,"ra":1,"d":"A spare battery sized for BD-1, carried by Cal."},
  {"n":"Tool Attachments","g":"Gear","c":"Equipment","t":"Tool","e":0,"d":"A droid's built-in tool arms and probes. Counts as having the right tools for Mechanics and Computers checks."},
  {"n":"Integrated Systems","g":"Gear","c":"Equipment","e":0,"d":"A droid's built-in sensors, comms and processors."},
  // --- tools & sundries from the starting kits ---
  {"n":"Grappling Hook","g":"Gear","c":"Survival","t":"Tool","p":25,"e":1,"ra":1,"d":"Hook and line for climbing or swinging. DRAFT: adds a Boost die to Athletics checks to climb."},
  {"n":"Multitool","g":"Gear","c":"Industrial","t":"Tool","p":50,"e":1,"ra":1,"d":"Pocket tool with pliers, drivers and a cutter. DRAFT: lets you attempt simple Mechanics checks without a full tool kit."},
  {"n":"Salvaged Parts","g":"Gear","c":"Industrial","p":10,"e":1,"ra":0,"d":"Scavenged components. Spend them on repairs or trade them."},
  {"n":"Sling Bag","g":"Gear","c":"Equipment","t":"Bag","p":30,"e":0,"ra":0,"d":"A shoulder bag. Carried, it raises the encumbrance threshold by the amount in its Enc field."},
  {"n":"Nightsister Charms","g":"Gear","c":"Relics","e":0,"ra":8,"d":"Talismans of Dathomiri magick carried by Merrin."},
  {"n":"Doll","g":"Gear","c":"Other","p":5,"e":0,"ra":0,"d":"A child's toy. Kata does not go anywhere without it."},
  {"n":"Wig","g":"Gear","c":"Other","p":30,"e":0.2,"ra":0,"d":"Synthetic fiber, a hat of hair."},
  // --- weapons & armor not in the workbook ---
  {"n":"Ritual Dagger","g":"Melee Weapons","c":"Melee","sk":"Melee","dam":1,"crit":3,"rng":"Engaged","e":1,"hp":0,"ra":6,"q":"Pierce 1","d":"A Nightsister ceremonial blade. DRAFT stats, modelled on a combat knife."},
  {"n":"Flight Jacket","g":"Armour","c":"Armour","def":0,"soak":1,"p":50,"e":1,"hp":0,"ra":1,"d":"A padded pilot's jacket. DRAFT stats, same as heavy clothing."},
  {"n":"Poncho","g":"Armour","c":"Armour","def":0,"soak":1,"e":1,"hp":0,"ra":1,"d":"Stats copied from Cal's sheet on the Forge."},
  {"n":"Stormtrooper Armor","g":"Armour","c":"Armour","def":0,"soak":3,"r":1,"e":4,"hp":2,"ra":5,"d":"Stats copied from Cal's sheet on the Forge. Encumbrance is a DRAFT."},
  {"n":"Combat-Rated EVA Suit","g":"Armour","c":"Armour","def":0,"soak":2,"p":2500,"e":4,"hp":2,"ra":6,"d":"A sealed, armored vacuum suit with its own air supply and magnetic boots, built to take fire during boarding actions. DRAFT stats: soak of an enviro-suit, bulk of a spacesuit."},
  {"n":"Beskar Plating","g":"Armour","c":"Armour","def":2,"soak":3,"r":1,"e":3,"hp":5,"ra":10,"d":"Stats copied from Cal's sheet on the Forge. Encumbrance is a DRAFT."}
];
