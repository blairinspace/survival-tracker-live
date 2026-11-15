---
aliases: [Scrapper]
tags: [talent-tree, universal, homebrew]
career: Universal
status: homebrew
---

# Scrapper - Universal

> **Homebrew** · Career: Universal

Years spent cutting dead ships apart for a guild that pays by the tonne. The four columns are the
four things the work teaches: finding what still works in a wreck, keeping worn gear running past
its limits, working at heights without flinching, and haggling over every part. Every talent is a
published one; only the arrangement is the group's own. The tree grants no Force rating and no
lightsaber talents.

**Additional career skills:** Athletics, Mechanics, Negotiation, Perception

## Talent Tree

Grid is 4 columns by 5 rows; node IDs are `r<row>c<col>`; XP cost is 5 × row. `connects` lists neighbours joined by a path (paths run both ways). A talent can be bought only if it is in row 1 or connected to one already owned.

```yaml
specialization: "Scrapper - Universal"
grid: {columns: 4, rows: 5}
nodes:
  - {id: r1c1, name: "Utinni!", type: Passive, force_talent: false, ranked: true, cost: 5, connects: [r2c1]}
  - {id: r1c2, name: "Gearhead", type: Passive, force_talent: false, ranked: true, cost: 5, connects: [r2c2]}
  - {id: r1c3, name: "Conditioned", type: Passive, force_talent: false, ranked: true, cost: 5, connects: [r2c3]}
  - {id: r1c4, name: "Wheel and Deal", type: Passive, force_talent: false, ranked: true, cost: 5, connects: [r2c4]}
  - {id: r2c1, name: "Tinkerer", type: Passive, force_talent: false, ranked: true, cost: 10, connects: [r1c1, r2c2, r3c1]}
  - {id: r2c2, name: "Toughened", type: Passive, force_talent: false, ranked: true, cost: 10, connects: [r1c2, r2c1, r3c2]}
  - {id: r2c3, name: "Confidence", type: Passive, force_talent: false, ranked: true, cost: 10, connects: [r1c3, r3c3]}
  - {id: r2c4, name: "Smooth Talker", type: Active (Incidental), force_talent: false, ranked: true, cost: 10, connects: [r1c4, r3c4]}
  - {id: r3c1, name: "Jury Rigged", type: Passive, force_talent: false, ranked: true, cost: 15, connects: [r2c1, r4c1]}
  - {id: r3c2, name: "Exceed Specifications", type: Active, force_talent: false, ranked: false, cost: 15, connects: [r2c2, r3c3]}
  - {id: r3c3, name: "Freerunning", type: Active, force_talent: false, ranked: false, cost: 15, connects: [r2c3, r3c2, r4c3]}
  - {id: r3c4, name: "One Person's Trash", type: Active, force_talent: false, ranked: false, cost: 15, connects: [r2c4, r4c4]}
  - {id: r4c1, name: "Redundant Systems", type: Active, force_talent: false, ranked: false, cost: 20, connects: [r3c1, r5c1]}
  - {id: r4c2, name: "Speaks Binary", type: Passive, force_talent: false, ranked: true, cost: 20, connects: [r5c2]}
  - {id: r4c3, name: "Confidence", type: Passive, force_talent: false, ranked: true, cost: 20, connects: [r3c3, r4c4, r5c3]}
  - {id: r4c4, name: "Another's Treasure", type: Passive, force_talent: false, ranked: false, cost: 20, connects: [r3c4, r4c3, r5c4]}
  - {id: r5c1, name: "Contraption", type: Active, force_talent: false, ranked: false, cost: 25, connects: [r4c1, r5c2]}
  - {id: r5c2, name: "Resourceful Refit", type: Active, force_talent: false, ranked: false, cost: 25, connects: [r4c2, r5c1, r5c3]}
  - {id: r5c3, name: "Dedication", type: Passive, force_talent: false, ranked: true, cost: 25, connects: [r4c3, r5c2]}
  - {id: r5c4, name: "Master Merchant", type: Active, force_talent: false, ranked: false, cost: 25, connects: [r4c4]}
```

| ID | Talent | Type | Ranked | XP | Connects to |
|---|---|---|---|---|---|
| r1c1 | Utinni! | Passive | Yes | 5 | r2c1 |
| r1c2 | Gearhead | Passive | Yes | 5 | r2c2 |
| r1c3 | Conditioned | Passive | Yes | 5 | r2c3 |
| r1c4 | Wheel and Deal | Passive | Yes | 5 | r2c4 |
| r2c1 | Tinkerer | Passive | Yes | 10 | r1c1, r2c2, r3c1 |
| r2c2 | Toughened | Passive | Yes | 10 | r1c2, r2c1, r3c2 |
| r2c3 | Confidence | Passive | Yes | 10 | r1c3, r3c3 |
| r2c4 | Smooth Talker | Active (Incidental) | Yes | 10 | r1c4, r3c4 |
| r3c1 | Jury Rigged | Passive | Yes | 15 | r2c1, r4c1 |
| r3c2 | Exceed Specifications | Active |  | 15 | r2c2, r3c3 |
| r3c3 | Freerunning | Active |  | 15 | r2c3, r3c2, r4c3 |
| r3c4 | One Person's Trash | Active |  | 15 | r2c4, r4c4 |
| r4c1 | Redundant Systems | Active |  | 20 | r3c1, r5c1 |
| r4c2 | Speaks Binary | Passive | Yes | 20 | r5c2 |
| r4c3 | Confidence | Passive | Yes | 20 | r3c3, r4c4, r5c3 |
| r4c4 | Another's Treasure | Passive |  | 20 | r3c4, r4c3, r5c4 |
| r5c1 | Contraption | Active |  | 25 | r4c1, r5c2 |
| r5c2 | Resourceful Refit | Active |  | 25 | r4c2, r5c1, r5c3 |
| r5c3 | Dedication | Passive | Yes | 25 | r4c3, r5c2 |
| r5c4 | Master Merchant | Active |  | 25 | r4c4 |
