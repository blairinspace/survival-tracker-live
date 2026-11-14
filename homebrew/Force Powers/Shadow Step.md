---
tags: [force, force-power, homebrew]
source: "Homebrew"
prerequisite: "Force Rating 2"
---

# Shadow Step

> **Homebrew Force power** · Prerequisite: **Force Rating 2** · Written for Merrin's Nightsister magick.

The user steps out of the world in a flare of green ichor and back into it somewhere else. Columns run straight down from the basic power; Mastery joins the bottom of all four.

**Seeing a place through magick** (Control: Unseen) answers *where*, not *how far*: the place must still be within the power's range. On that Discipline check, [AD] gives a sense of who or what is there, [TH] means she arrives a little off target, and [DE] means something there felt her looking. The 30 minutes is the tracker's meditate action.

```yaml
power: "Shadow Step"
nodes:
  - {id: basic, name: "Basic Power", type: basic, cost: 15, connects: [r1c1, r1c2, r1c3, r1c4], effect: "The Force user vanishes and reappears elsewhere. The user makes a Shadow Step power check as an action and may spend 1 Force point to move instantly to a spot they can see within Short range, arriving on their feet. (May not be activated multiple times.)"}
  - {id: r1c1, name: "Range", type: upgrade, cost: 10, connects: [basic, r2c1], effect: "Spend 1 Force point to increase the power's range by a number of range bands equal to Range upgrades purchased."}
  - {id: r1c2, name: "Magnitude", type: upgrade, cost: 10, connects: [basic, r2c2], effect: "Spend 1 Force point to bring one additional willing, engaged character (or an object of Silhouette 1 or smaller) per Magnitude upgrade purchased."}
  - {id: r1c3, name: "Control (Maneuver)", type: upgrade, cost: 15, connects: [basic, r2c3], effect: "Once per round, the user may suffer 2 strain to make the Shadow Step power check as a maneuver instead of an action."}
  - {id: r1c4, name: "Control (Unseen)", type: upgrade, cost: 10, connects: [basic, r2c4], effect: "The destination does not need to be in sight if the user has stood there before, can sense a living being there, or has seen it through her magick. To see a place she meditates for 30 minutes and makes a Discipline check: Average ([DI][DI]) with an object from the place or a guide who has been there, Hard with only a description, Daunting with only a name. On a success it counts as a place she has stood in until she next sleeps."}
  - {id: r2c1, name: "Range", type: upgrade, cost: 15, connects: [r1c1, r3c1], effect: "Spend 1 Force point to increase the power's range by a number of range bands equal to Range upgrades purchased."}
  - {id: r2c2, name: "Magnitude", type: upgrade, cost: 15, connects: [r1c2, r3c1], effect: "Spend 1 Force point to bring one additional willing, engaged character (or an object of Silhouette 1 or smaller) per Magnitude upgrade purchased."}
  - {id: r2c3, name: "Control (Ambush)", type: upgrade, cost: 15, connects: [r1c3, r3c1], effect: "After arriving Engaged with a target that did not see the user coming, add [BO][BO] to the user's next combat check against that target this turn."}
  - {id: r2c4, name: "Control (Evade)", type: upgrade, cost: 15, connects: [r1c4, r3c1], effect: "Once per encounter, when hit by an attack, the user may suffer 3 strain to make a Shadow Step power check as an out-of-turn incidental. Spend 2 Force points to move to Short range and reduce the damage by the user's Force rating."}
  - {id: r3c1, name: "Mastery", type: upgrade, cost: 25, connects: [r2c1, r2c2, r2c3, r2c4], effect: "Spend 2 Force points to step to any place within Extreme range that the user knows well, including one seen through her magick. Once per session, this may be any distance on the same world."}
```
