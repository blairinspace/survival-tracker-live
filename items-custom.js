// Custom item entries — hand-maintained (NOT generated; tools/import-items.py never touches this file).
// These fill gaps in the workbook catalog so every inventory item can link to a database entry.
// Same record keys as items.js, plus:
//   k   kind and  s  sub-category (the lists are in tools/item-kinds.json)   bag  1 = adds carrying capacity
//   d   description shown on the character sheet
//   u   condition id (CONDS key) applied when the item is used from the Tracker card's inventory (a use button appears)
// Stats marked DRAFT in the description are placeholders written by Claude — correct them freely.
const ITEMS_CUSTOM = [
  // --- food & drink (the tracker's hunger buttons consume these by type) ---
  {"n":"Snack","g":"Gear","c":"Survival","k":"Food","s":"Snacks","p":1,"e":0,"ra":0,"d":"A bite on the move: ration bar, jerky, dried fruit. The snack button eats one (a small hunger relief, no time cost)."},
  {"n":"Meal","g":"Gear","c":"Survival","k":"Food","s":"Meals","p":10,"e":0,"ra":0,"d":"A prepared or cooked meal. The meal button eats one over 30 minutes (the best hunger relief, and a little rest)."},
  {"n":"Caf","g":"Gear","c":"Survival","k":"Food","s":"Drinks","p":2,"e":0,"ra":0,"u":"caffeinated","d":"A hot cup of caf. Drinking one (the use button on the card) gives the Caffeinated condition: wired and alert, sleep debt accrues slower, a Boost die to Vigilance and Perception."},
  {"n":"Canteen","g":"Gear","c":"Survival","k":"Gear","s":"Survival & Camp","p":5,"e":0,"ra":0,"d":"A 20 oz water bottle. Its fill level is tracked on the Tracker card."},
  // --- droid upkeep ---
  {"n":"Droid Power Pack","g":"Gear","c":"Equipment","k":"Gear","s":"Light & Power","p":25,"e":0,"ra":1,"d":"A spare power pack for a droid. Charged and depleted counts are tracked on the droid's Tracker card."},
  {"n":"BD-1 Battery Pack","g":"Gear","c":"Equipment","k":"Gear","s":"Light & Power","p":25,"e":0,"ra":1,"d":"A spare battery sized for BD-1, carried by Cal."},
  {"n":"Tool Attachments","g":"Gear","c":"Equipment","k":"Tool","s":"Repair & Maintenance","e":0,"d":"A droid's built-in tool arms and probes. Counts as having the right tools for Mechanics and Computers checks."},
  {"n":"Integrated Systems","g":"Gear","c":"Equipment","k":"Gear","s":"Data","e":0,"d":"A droid's built-in sensors, comms and processors."},
  // --- tools & sundries from the starting kits ---
  {"n":"Grappling Hook","g":"Gear","c":"Survival","k":"Tool","s":"Heavy & Industrial","p":25,"e":1,"ra":1,"d":"Hook and line for climbing or swinging. DRAFT: adds a Boost die to Athletics checks to climb."},
  {"n":"Multitool","g":"Gear","c":"Industrial","k":"Tool","s":"Repair & Maintenance","p":50,"e":1,"ra":1,"d":"Pocket tool with pliers, drivers and a cutter. DRAFT: lets you attempt simple Mechanics checks without a full tool kit."},
  {"n":"Salvaged Parts","g":"Gear","c":"Industrial","k":"Gear","s":"Survival & Camp","p":10,"e":1,"ra":0,"d":"Scavenged components. Spend them on repairs or trade them."},
  {"n":"Canvas Backpack","g":"Gear","c":"Equipment","k":"Gear","s":"Packs & Carrying","p":50,"e":4,"ra":1,"d":"A sturdy two-strap canvas pack. Carried, it raises the encumbrance threshold by 4 (the amount in its Enc field) and weighs nothing itself.","bag":1},
  {"n":"Sling Bag","g":"Gear","c":"Equipment","k":"Gear","s":"Packs & Carrying","p":30,"e":0,"ra":0,"d":"A shoulder bag. Carried, it raises the encumbrance threshold by the amount in its Enc field.","bag":1},
  {"n":"Nightsister Charms","g":"Gear","c":"Relics","k":"Gear","s":"Relics","e":0,"ra":8,"d":"Talismans of Dathomiri magick carried by Merrin."},
  {"n":"Doll","g":"Gear","c":"Other","k":"Gear","s":"Recreation","p":5,"e":0,"ra":0,"d":"A child's toy. Kata does not go anywhere without it."},
  {"n":"Wig","g":"Gear","c":"Other","k":"Clothing","s":"Disguise & Stealth","p":30,"e":0.2,"ra":0,"d":"Synthetic fiber, a hat of hair."},
  // --- weapons, armor and clothing not in the workbook ---
  {"n":"Ritual Dagger","g":"Melee Weapons","c":"Melee","k":"Weapon","s":"Melee","sk":"Melee","dam":1,"crit":3,"rng":"Engaged","e":1,"hp":0,"ra":6,"q":"Pierce 1","d":"A Nightsister ceremonial blade. DRAFT stats, modelled on a combat knife."},
  {"n":"CEC Uniform","g":"Armour","c":"Armour","k":"Clothing","s":"Workwear & Uniforms","def":1,"soak":1,"e":1,"hp":0,"ra":2,"d":"A work uniform of the Corellian Engineering Corporation. Stats copied from the Forge."},
  {"n":"Flight Jacket","g":"Armour","c":"Armour","k":"Clothing","s":"Everyday","def":0,"soak":1,"p":50,"e":1,"hp":0,"ra":1,"d":"A padded pilot's jacket. DRAFT stats, same as heavy clothing."},
  {"n":"Poncho","g":"Armour","c":"Armour","k":"Clothing","s":"Environment Wear","def":0,"soak":1,"e":1,"hp":0,"ra":1,"d":"Stats copied from Cal's sheet on the Forge."},
  {"n":"Stormtrooper Armor","g":"Armour","c":"Armour","k":"Armor","s":"Combat","def":0,"soak":3,"r":1,"e":4,"hp":2,"ra":5,"d":"Stats copied from Cal's sheet on the Forge. Encumbrance is a DRAFT."},
  {"n":"Combat-Rated EVA Suit","g":"Armour","c":"Armour","k":"Armor","s":"Sealed & Hazard","def":0,"soak":2,"p":2500,"e":4,"hp":2,"ra":6,"d":"A sealed, armored vacuum suit with its own air supply and magnetic boots, built to take fire during boarding actions. DRAFT stats: soak of an enviro-suit, bulk of a spacesuit."},
  {"n":"Beskar Plating","g":"Armour","c":"Armour","k":"Armor","s":"Heavy & Powered","def":2,"soak":3,"r":1,"e":3,"hp":5,"ra":10,"d":"Stats copied from Cal's sheet on the Forge. Encumbrance is a DRAFT."}
];
