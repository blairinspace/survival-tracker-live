---
tags: [force, force-power, homebrew]
source: "Homebrew"
prerequisite: "Force Rating 2"
---

# Stasis

> **Homebrew Force power** · Prerequisite: **Force Rating 2** · Compare the published Bind power, which only immobilizes.

Fleshed out from the group's original sheet (Range / Targets / Duration columns, costs 15 / 20 / 25); the Control column and Mastery were added. Same format as the vault's power trees.

```yaml
power: "Stasis"
nodes:
  - {id: basic, name: "Basic Power", type: basic, cost: 15, connects: [r1c1, r1c2, r1c3, r1c4], effect: "The Force user traps a target in a field of slowed time. The user makes a Stasis power check as an opposed Discipline vs. Discipline check against one target within Short range. If the check succeeds, the user may spend 1 Force point to hold the target until the end of the user's next turn: the target is immobilized and staggered (it cannot move or take actions). (May not be activated multiple times.)"}
  - {id: r1c1, name: "Range", type: upgrade, cost: 15, connects: [basic, r2c1], effect: "Spend 1 Force point to increase the power's range by a number of range bands equal to Range upgrades purchased."}
  - {id: r1c2, name: "Magnitude", type: upgrade, cost: 15, connects: [basic, r2c2], effect: "Spend 1 Force point to affect one additional target within range per rank of Magnitude purchased."}
  - {id: r1c3, name: "Duration", type: upgrade, cost: 15, connects: [basic, r2c3], effect: "The stasis lasts one additional round per Duration upgrade purchased. Each held target repeats the opposed Discipline check at the start of its turn and breaks free on a success; the user adds [SB] to that check for every round the target has already been held."}
  - {id: r1c4, name: "Control (Slow)", type: upgrade, cost: 10, connects: [basic, r2c4], effect: "If the target resists the power, the user may spend 1 Force point to leave it disoriented and unable to perform a second maneuver until the end of the user's next turn."}
  - {id: r2c1, name: "Range", type: upgrade, cost: 20, connects: [r1c1, r3c1], effect: "Spend 1 Force point to increase the power's range by a number of range bands equal to Range upgrades purchased."}
  - {id: r2c2, name: "Magnitude", type: upgrade, cost: 20, connects: [r1c2, r3c2], effect: "Spend 1 Force point to affect one additional target within range per rank of Magnitude purchased."}
  - {id: r2c3, name: "Duration", type: upgrade, cost: 20, connects: [r1c3, r3c3], effect: "The stasis lasts one additional round per Duration upgrade purchased. Each held target repeats the opposed Discipline check at the start of its turn and breaks free on a success; the user adds [SB] to that check for every round the target has already been held."}
  - {id: r2c4, name: "Control (Objects)", type: upgrade, cost: 15, connects: [r1c4, r3c4], effect: "The power can target an unattended object or hazard of Silhouette 1 or smaller (a closing door, falling debris, a thrown grenade), freezing it in place for as long as the power lasts. No opposed check is needed."}
  - {id: r3c1, name: "Range", type: upgrade, cost: 25, connects: [r2c1, r4c1], effect: "Spend 1 Force point to increase the power's range by a number of range bands equal to Range upgrades purchased."}
  - {id: r3c2, name: "Magnitude", type: upgrade, cost: 25, connects: [r2c2, r4c1], effect: "Spend 1 Force point to affect one additional target within range per rank of Magnitude purchased."}
  - {id: r3c3, name: "Duration", type: upgrade, cost: 25, connects: [r2c3, r4c1], effect: "The stasis lasts one additional round per Duration upgrade purchased. Each held target repeats the opposed Discipline check at the start of its turn and breaks free on a success; the user adds [SB] to that check for every round the target has already been held."}
  - {id: r3c4, name: "Control (Preserve)", type: upgrade, cost: 20, connects: [r2c4, r4c1], effect: "The power can target a willing or incapacitated ally instead, with no opposed check. While held, bleeding, poison and Critical Injuries do not get worse, and the ally's hunger, thirst and fatigue stop advancing (the GM pauses them in the tracker)."}
  - {id: r4c1, name: "Mastery", type: upgrade, cost: 25, connects: [r3c1, r3c2, r3c3, r3c4], effect: "Spend 2 Force points: held targets are unaware of any time passing. The first attack made against each held target adds [BO], but ends the stasis on that target."}
```
