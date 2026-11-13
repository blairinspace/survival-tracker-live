---
tags: [force, force-power, homebrew]
source: "Homebrew"
prerequisite: "Force Rating 2"
---

# Psychometry

> **Homebrew Force power** · Prerequisite: **Force Rating 2**

Same format as the vault's power trees: grid positions are `r<row>c<col>` on a 4-column grid (a wide box uses the column of its left edge), `connects` lists the boxes joined by a path, and `effect` is the text on the box.

```yaml
power: "Psychometry"
nodes:
  - {id: basic, name: "Basic Power", type: basic, cost: 10, connects: [r1c2, r1c3], effect: "The Force user can touch an object and read impressions left on it by its owner or the most recent user. The user may spend 1 Force point to gain a sense of the emotional state of the object's user during its most recent use, up to one day in the past."}
  - {id: r1c1, name: "Magnitude (Month)", type: upgrade, cost: 10, connects: [r1c2, r2c1], effect: "Spend 1 Force point to enable the user to perceive feelings or events regarding the object up to one month in the past."}
  - {id: r1c2, name: "Magnitude (Week)", type: upgrade, cost: 10, connects: [basic, r1c1], effect: "Spend 1 Force point to enable the user to perceive feelings or events regarding the object up to one week in the past."}
  - {id: r1c3, name: "Range", type: upgrade, cost: 5, connects: [basic, r1c4], effect: "Spend 1 Force point to enable the user to perceive details about feelings or events regarding the object up to an additional range band per rank of Range upgrade purchased."}
  - {id: r1c4, name: "Range", type: upgrade, cost: 5, connects: [r1c3, r2c4], effect: "Spend 1 Force point to enable the user to perceive details about feelings or events regarding the object up to an additional range band per rank of Range upgrade purchased."}
  - {id: r2c1, name: "Magnitude (Year)", type: upgrade, cost: 15, connects: [r1c1, r2c2], effect: "Spend 1 Force point to enable the user to perceive feelings or events regarding the object up to one year in the past."}
  - {id: r2c2, name: "Magnitude (Decade)", type: upgrade, cost: 15, connects: [r2c1, r3c1], effect: "Spend 1 Force point to enable the user to perceive feelings or events regarding the object up to one decade in the past."}
  - {id: r2c3, name: "Range", type: upgrade, cost: 5, connects: [r2c4], effect: "Spend 1 Force point to enable the user to perceive details about feelings or events regarding the object up to an additional range band per rank of Range upgrade purchased."}
  - {id: r2c4, name: "Range", type: upgrade, cost: 5, connects: [r1c4, r2c3], effect: "Spend 1 Force point to enable the user to perceive details about feelings or events regarding the object up to an additional range band per rank of Range upgrade purchased."}
  - {id: r3c1, name: "Magnitude (Century)", type: upgrade, cost: 15, connects: [r2c2, r3c3], effect: "Spend 1 Force point to enable the user to perceive feelings or events regarding the object up to one century in the past."}
  - {id: r3c3, name: "Control (Sight)", type: upgrade, cost: 10, connects: [r3c1, r3c4], effect: "The user can perceive images of the events surrounding the object's use."}
  - {id: r3c4, name: "Control (Sound)", type: upgrade, cost: 10, connects: [r3c3, r4c1], effect: "The user can perceive sounds of the events surrounding the object's use."}
  - {id: r4c1, name: "Mastery", type: upgrade, cost: 20, connects: [r3c4], effect: "The user can perceive a full sensory illusion of events surrounding the object's use throughout its lifetime."}
```
