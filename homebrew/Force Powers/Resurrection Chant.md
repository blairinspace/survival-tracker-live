---
tags: [force, force-power, homebrew]
source: "Homebrew"
prerequisite: "Force Rating 3"
---

# Resurrection Chant

> **Homebrew Force power** · Prerequisite: **Force Rating 3** · Written for Merrin's Nightsister magick. Compare the Mastery of Heal/Harm, which restores someone who has only just died.

The Chant of Resurrection calls the dead up to serve. It needs actual bodies within range, a committed Force die for as long as any of them stand, and it always costs Conflict. Columns run straight down from the basic power; Mastery joins the bottom of all four.

```yaml
power: "Resurrection Chant"
nodes:
  - {id: basic, name: "Basic Power", type: basic, cost: 20, connects: [r1c1, r1c2, r1c3, r1c4], effect: "The user chants the dead back to their feet. As an action she makes a Resurrection Chant power check and may spend 2 Force points to raise one corpse within Short range as a mindless servant until the end of the encounter. She must commit [FO] while any servant stands. Raised dead are minions that act on her turn and obey simple commands: Brawn 3, Agility 2, soak 3, wound threshold 4, Brawl attack for 4 damage (Critical 5). They feel no fear, pain or strain. Each use gives 2 Conflict, or 5 if she knew the dead in life."}
  - {id: r1c1, name: "Magnitude", type: upgrade, cost: 10, connects: [basic, r2c1], effect: "Spend 1 Force point to raise one additional corpse per Magnitude upgrade purchased. The dead she raises together act as one minion group."}
  - {id: r1c2, name: "Range", type: upgrade, cost: 10, connects: [basic, r2c2], effect: "Spend 1 Force point to increase the power's range by a number of range bands equal to Range upgrades purchased."}
  - {id: r1c3, name: "Strength", type: upgrade, cost: 10, connects: [basic, r2c3], effect: "Each Strength upgrade purchased gives her raised dead +1 soak, +2 wound threshold and +1 damage."}
  - {id: r1c4, name: "Control (Armed)", type: upgrade, cost: 10, connects: [basic, r2c4], effect: "The raised dead can use weapons and armor found on or near their bodies, attacking with the weapon's own damage and qualities."}
  - {id: r2c1, name: "Magnitude", type: upgrade, cost: 15, connects: [r1c1, r3c1], effect: "Spend 1 Force point to raise one additional corpse per Magnitude upgrade purchased. The dead she raises together act as one minion group."}
  - {id: r2c2, name: "Duration", type: upgrade, cost: 15, connects: [r1c2, r3c2], effect: "The raised dead stand for as long as [FO] stays committed, to a limit of the next sunrise, instead of falling at the end of the encounter."}
  - {id: r2c3, name: "Strength", type: upgrade, cost: 15, connects: [r1c3, r3c3], effect: "Each Strength upgrade purchased gives her raised dead +1 soak, +2 wound threshold and +1 damage."}
  - {id: r2c4, name: "Control (Dread)", type: upgrade, cost: 15, connects: [r1c4, r3c4], effect: "A living enemy who becomes Engaged with her raised dead for the first time must make an Average ([DI][DI]) fear check, Hard if four or more dead stand."}
  - {id: r3c1, name: "Magnitude", type: upgrade, cost: 20, connects: [r2c1, r4c1], effect: "Spend 1 Force point to raise one additional corpse per Magnitude upgrade purchased. The dead she raises together act as one minion group."}
  - {id: r3c2, name: "Control (Distant Command)", type: upgrade, cost: 15, connects: [r2c2, r4c1], effect: "She may command her dead at any distance, and may spend 1 Force point to see and hear through one of them until the end of her next turn."}
  - {id: r3c3, name: "Control (Remains)", type: upgrade, cost: 15, connects: [r2c3, r4c1], effect: "The power can raise the long dead (bones and husks) and the bodies of beasts of Silhouette 2 or smaller. A beast keeps its natural attacks."}
  - {id: r3c4, name: "Control (Release)", type: upgrade, cost: 15, connects: [r2c4, r4c1], effect: "Once per round, when she is hit by an attack, she may release one raised servant within Short range as an out-of-turn incidental. It falls for good and takes the hit in her place."}
  - {id: r4c1, name: "Mastery", type: upgrade, cost: 25, connects: [r3c1, r3c2, r3c3, r3c4], effect: "Once per session, spend 3 Force points: one raised servant wakes with the mind and skills it had in life until the end of the scene. It can speak and remember, acts as a rival, and is not bound to obey. She gains 5 Conflict."}
```
