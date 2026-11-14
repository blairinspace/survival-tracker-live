---
tags: [force, force-power, homebrew]
source: "Homebrew"
prerequisite: "Force Rating 2"
---

# Blood Rite

> **Homebrew Force power** · Prerequisite: **Force Rating 2** · Written for Merrin's Nightsister magick.

Nightsister blood magick: a sample of a living being's blood lets the user find them, and fresh blood restores her. A sample comes from a wounding hit with a bladed weapon (spend two Advantage), a willing donor, or a fallen foe, and keeps for a day unless stored. Sustain and Mend work once per encounter per source of blood. Drinking blood taken by violence from a thinking being gives 1 Conflict; using Sap gives 2. Columns run straight down from the basic power; Mastery joins the bottom of all four.

```yaml
power: "Blood Rite"
nodes:
  - {id: basic, name: "Basic Power", type: basic, cost: 15, connects: [r1c1, r1c2, r1c3, r1c4], effect: "With a sample of a living being's blood in hand, the user makes a Blood Rite power check and may spend 1 Force point to know the direction and rough distance to that being for the rest of the scene, as long as it is within a few kilometres. The sample is used up. (May not be activated multiple times.)"}
  - {id: r1c1, name: "Range", type: upgrade, cost: 10, connects: [basic, r2c1], effect: "Each Range upgrade widens the trace: anywhere on the same world, then the same star system, then the same sector."}
  - {id: r1c2, name: "Control (Senses)", type: upgrade, cost: 15, connects: [basic, r2c2], effect: "Spend 1 Force point to share a moment of the traced being's senses, or to learn its condition (hurt, afraid, asleep)."}
  - {id: r1c3, name: "Control (Sustain)", type: upgrade, cost: 10, connects: [basic, r2c3], effect: "As a maneuver, the user drinks fresh blood from a sample, a willing donor or a fallen foe, and may spend 1 Force point to recover 2 strain. Once per encounter per source of blood."}
  - {id: r1c4, name: "Control (Blood Tie)", type: upgrade, cost: 15, connects: [basic, r2c4], effect: "While the user holds a being's blood, the user's other Force powers treat that being as within Short range and add [BO] to checks against it."}
  - {id: r2c1, name: "Range", type: upgrade, cost: 10, connects: [r1c1, r3c1], effect: "Each Range upgrade widens the trace: anywhere on the same world, then the same star system, then the same sector."}
  - {id: r2c2, name: "Duration", type: upgrade, cost: 10, connects: [r1c2, r3c2], effect: "Commit [FO] to hold a trace for as long as the die remains committed. The sample is not used up until the trace is released."}
  - {id: r2c3, name: "Control (Mend)", type: upgrade, cost: 15, connects: [r1c3, r3c3], effect: "When using Sustain, the user may spend 1 more Force point to heal 2 wounds. This does not count against stimpack limits. A willing donor suffers 1 wound each time."}
  - {id: r2c4, name: "Control (Sap)", type: upgrade, cost: 15, connects: [r1c4, r3c4], effect: "Spend 2 Force points: a being the user has a Blood Tie to suffers 2 strain, and the user recovers 2 strain. Using Sap gives 2 Conflict."}
  - {id: r3c1, name: "Range", type: upgrade, cost: 15, connects: [r2c1, r4c1], effect: "Each Range upgrade widens the trace: anywhere on the same world, then the same star system, then the same sector."}
  - {id: r3c2, name: "Magnitude", type: upgrade, cost: 10, connects: [r2c2, r4c1], effect: "The user may hold one additional trace at a time per Magnitude upgrade purchased."}
  - {id: r3c3, name: "Strength", type: upgrade, cost: 15, connects: [r2c3, r4c1], effect: "Each Strength upgrade purchased adds 1 to the strain or wounds from Sustain, Mend and Sap."}
  - {id: r3c4, name: "Strength", type: upgrade, cost: 10, connects: [r2c4, r4c1], effect: "Each Strength upgrade purchased adds 1 to the strain or wounds from Sustain, Mend and Sap."}
  - {id: r4c1, name: "Mastery", type: upgrade, cost: 25, connects: [r3c1, r3c2, r3c3, r3c4], effect: "The user binds a willing ally by shared blood. While [FO] stays committed, the user always knows where that ally is and how they fare, either may take the other's strain as their own, and the ally counts as a place the user knows well for Shadow Step at any range."}
```
