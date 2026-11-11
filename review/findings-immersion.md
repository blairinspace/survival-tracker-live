# Pass 2 — immersion audit findings

Audited 2026-11-11 against commit 8c1b6c9 (all pass-1 fixes in) of
`sw_survival_tracker.html`, chunks A, B, D and E: constants, tables, the tick
loop and the player actions. Ground truth was `./tools/sim.sh` plus a jsc
harness that ran a scripted "ordinary travel day" (16 h awake, walking, two
30-minute breaks, a ration at midday, a meal at night, drinking 10 oz whenever
Thirsty, 8 h sleep) and the worst- and best-case multiplier stacks. Nothing has
been changed.

Severity here means how often a table would notice: **major** every session,
**minor** in particular situations, **note** a wording or a judgment call.

The October anchors (thirst ≈ 3 days walking, hunger ≈ 29 days, water per
canteen, droid and gear wear) hold up and are not re-litigated below.

## Major

**I-01 · major · `ACTS.light.rest` (+8/hr), `NEEDS.rest` tiers · A normal walking day ends Exhausted or Spent.**
What the code does: the scripted ordinary day (Cal, temperate, light activity,
two 30-minute rests) reaches fatigue 92 on day one and 100 on days two and
three at bedtime — Exhausted, then Spent: "cannot take strenuous actions at
all, any attempt auto-fails". Without breaks the sim reaches Spent at 12.5 h.
Exhausted also arrives at 9.5 h of walking, which switches on the ×1.5 sleep
coupling, so Drowsy lands at 20 h instead of the 25 h the sleep ladder intends.
What reality expects: a fit adult walks 8 to 10 hours with a pack, with breaks,
and ends the day tired and sore, not incapable of exertion. Soldiers and
through-hikers do it daily. Fatigue should hit the top tiers from forced
marches and fighting, not from the party's default travel setting.
Proposed change: `light.rest` 8 → 5, `sedentary.rest` 2 → 1.5,
`travel.rest` 16 → 12, keep `strenuous` 32. Verified with the same scripted
day: bedtime fatigue 48 (Winded) and 58 (Weary), waking at 0; no-break anchors
become Spent at 20 h walking, 8.3 h forced march, 3.1 h combat; the sleep
coupling only engages after 15 h of walking. The Rules tab derives all of these
figures already.

**I-02 · major · hourly strain in `NEEDS` tiers and `CONDS` vs no strain recovery · Automatic strain with manual-only recovery knocks everyone out.**
What the code does: Sleep-Deprived, Delirious, Wrecked, Sick, Poisoned and
Drunk each add strain every hour (capped at 2× threshold since pass 1), but
nothing in the tracker ever removes strain: not sleep, not rest, not time. The
Rules say strain "recovers per core rules" by hand. Measured: Sick 1 →
unconscious at 12 h, Sick 2 or 3 → unconscious at 6 h; a walker who pulls an
all-nighter is unconscious at 45 h awake; strain 10 is still 10 after 8 h of
sleep. Once down, a character never wakes unless the GM clicks − twelve times.
What reality and the rules expect: FFG RAW, a full night's rest recovers all
strain, and a short rest recovers some. A feverish person is miserable for days,
not comatose by lunch; a sleepless person falls asleep, not unconscious.
Proposed change: make the sleep status recover strain (all of it on a sleep of
≥ 6 h, else `st/8` per hour), let Resting recover 1 strain per hour, and halve
the hourly rates (Sick 1 → 1 per 2 h, Sick 2+ → 1/hr; Sleep-Deprived 1 per 2 h).
Alternatively replace hourly strain with a once-per-encounter strain cost like
Famished already uses ("Begins every encounter with 3 strain"), which the GM
applies at the table.

**I-03 · major · `exhaustion()` (0.55 × charge + 0.45 × wear), `DTIERS` · Droids take dice penalties with three quarters of a pack left.**
What the code does: the degradation meter is a linear blend, so BD-1 on a fresh
pack, light duty, is Degraded (1 Setback to every check) after 11 h with 28% of
the pack used; Alpha reaches Strained (2 Setback, speed ×¾) at 70% used and
accrues 7 strain over a single 20-hour pack from the Impaired/Malfunctioning
tiers alone.
What fiction expects: a battery-powered machine runs at full performance until
the pack is nearly flat, then degrades sharply. Wear should degrade smoothly;
charge should not.
Proposed change: let charge contribute only past the halfway mark, steeply:
`x = 0.55*Math.max(0, (cs.charge-50)*2) + 0.45*cs.maint`, keep the +8 compounding
at 70+. BD-1 then stays Optimal for ~28 h of a 40 h pack and climbs through the
tiers over the last 12 h, which is also when the "swap pack" decision becomes
dramatic. Update the Rules line "Degradation = 55% Charge + 45% Wear".

**I-04 · major · `ACTS.travel.water` 2.0, `ACTS.strenuous.water` 3.0 and the comment above `ACTS` · Combat costs 7.5 oz an hour, not "a canteen".**
What the code does: Cal's baseline is 60 oz per day of light activity, i.e.
2.5 oz/hr; moderate is 5 oz/hr and strenuous 7.5 oz/hr. The comment on the
table says sustained combat "costs a canteen" (20 oz) per hour.
What reality expects: sweat rates in hard exertion run 1 to 1.5 litres an hour
(34 to 50 oz); a forced march in temperate weather about half that. The anchor
of 3 days to Collapse applies to walking and is fine; the activity multipliers
on top of it are 3 to 5 times too gentle.
Proposed change: `travel.water` 2.0 → 3.0, `strenuous.water` 3.0 → 8.0 (20 oz
an hour for Cal, matching the comment). Combat is set for an hour or two at a
time, so this bites exactly where it should: a fight at noon in the desert
empties the canteens. Check `heatAdapt` still reads sensibly at the new rates.

## Minor

**I-05 · minor · `ENV_COND_CHANCE`, `applyHourly` env block · Exposure never happens to sleepers, in jungles, or less to the adapted.**
What the code does: Chilled/Overheated onset rolls only while awake (`!isStandby`),
Humid is `heat:true` but has no entry so nobody ever overheats in a jungle,
and Tann's `heatAdapt` and Merrin's `coldAdapt` do not reduce the onset chance
or the condition's multiplier.
What reality expects: the night is when the cold kills; humid heat is the
classic heat-casualty environment; the Twi'lek should shrug off desert heat
across the board.
Proposed change: roll onset while asleep too (it is the point of shelter), add
`humid: 0.05`, and scale the chance by the adaptation (`chance * (adapt ?? 1)`),
with the same factor on the condition's water/hunger multiplier.

**I-06 · minor · `ENVS.frozen.hunger` 1.6 + `CONDS.chilled.mult.hunger` 1.3 · Cold stacks to +108% calories.**
What the code does: Cal walking in Extreme Cold burns ×1.6; once the hourly
roll makes him Chilled (expected after ~8 h) it is ×2.08, so Collapse in under
11 days.
What reality expects: the environment comment itself says cold raises burn
30–60%. Shivering adds more, but ×2 sustained for days exceeds what a body does.
Proposed change: either treat Chilled as the environment's own effect (no
extra hunger when `ENVS[S.env].cold` is already applied, keep the fatigue ×1.2
and the Setback), or drop `chilled.mult.hunger` to 1.15.

**I-07 · minor · `CONDS.sick` · Fever tires nobody and costs no sleep.**
What the code does: Sick multiplies thirst and hunger by 1 + 0.1 per stack,
adds strain and (3+) wounds. Fatigue and sleep debt are untouched.
What reality expects: illness is exhausting and sleep is broken by fever. The
appetite point is defensible (metabolic demand rises even as appetite falls).
Proposed change: `mult.rest: l=>1+0.15*l, mult.sleep: l=>1+0.1*l`, and say so in
the fx text ("tires 15%/stack faster").

**I-08 · minor · `CONDS.drunk`, `CONDS.caffeinated` · Time never sobers anyone.**
What the code does: both fx texts promise that time clears them ("Only time,
water & rest sober you up"; "Wears off after a few hours"), but neither has a
duration or an hourly decay. The stimpack already has a 4 h timer.
Proposed change: give leveled/timed conditions an `hours` field and an hourly
step: Drunk loses one level every 2 h (about one drink an hour metabolised),
Caffeinated ends after 4 h, with a log line each time.

**I-09 · minor · `drink()` with `REHYDRATE.capOz` · The 10 oz cap is per click, not per hour.**
What the code does: a Dehydrated character can take ten 10-oz sips in zero game
time (with a refill in between) and rehydrate instantly; the cap only trims a
single gulp.
What reality expects: the cap models what a cramping gut keeps down over time,
roughly 8 to 10 oz every 15 to 20 minutes.
Proposed change: record `cs.lastDrinkAt` (game hour) and, while Dehydrated+,
refuse a second drink within 0.25 h with a log line ("still cramping — wait").

**I-10 · minor · `HYG.wipe` 25 for 5 oz, `HYG.clothes` 10 · A field wipe undoes four days of grime.**
What the code does: at the Grubby rate (0.26/hr) a 5-oz wipe removes 4 days of
accumulation, a change of clothes 1.6 days; a full 30-minute wash removes two
tiers.
What reality expects: a wipe-down freshens but does not reset; it should hold
the line, not win it.
Proposed change: `wipe` 25 → 12 (about two days of Grubby grime), `clothes`
10 → 8, keep the wash at 50. Or keep the numbers and raise `wipeOz` to 10 so the
water trade-off is real.

**I-11 · minor · `sleepRecovery` 100/sleepNeed flat · One night erases four days awake.**
What the code does: sleep debt recovers at 12.5/hr regardless of depth, so a
Wrecked character (96 h awake) is Rested after one 8 h sleep; fatigue 100 falls
to 30 in the same night.
What reality expects: after three or four days awake, one long sleep restores
most function but a second night is needed to clear it; recovery is front-loaded
but not total.
Proposed change: cap recovery per sleep status at 75 points when debt starts
above 75 (first night brings Wrecked to Drowsy), or let the per-hour rate taper
in the last quarter of the sleep. Note for the GM in the Sleep ladder text.

**I-12 · minor · `NEEDS.sleep` Drowsy `min:26` with `awakeRate` 1.04 · Nobody feels drowsy until 25 hours awake.**
What the code does: Drowsy (Setback to Perception/Vigilance) starts at 25 h
awake, Kata at 20 h.
What reality expects: attention and reaction time degrade noticeably after
17 to 19 hours awake (the much-quoted "like 0.05% blood alcohol" mark); 24 h is
closer to the 0.1% mark.
Proposed change: Drowsy `min` 26 → 19 (18 h awake; Kata 15 h), leave the other
tiers so Sleep-Deprived still lands at 49 h. With I-01 in place the fatigue
coupling no longer pulls these forward on an ordinary day.

**I-13 · minor · `CHARS[*].waterOz` and `SNACK_HUNGER` · Daily water is low; a snack is two-thirds of a day's food.**
Water: Cal's 60 oz/day is 1.8 L; guidance for an active adult male in temperate
weather is 2.5 to 3.5 L (85 to 120 oz). Since the thirst ladder is anchored in
days, not litres, this only changes the canteen conversion: at 90 oz a 20-oz
canteen is 5.3 points instead of 8, a third of a day becomes a fifth. Food: the
light-activity ladder accrues 15.1 points a day; a ration restores 25 (1.7 days),
a meal 30 (2 days), a snack 10 (0.7 days). Measured over ten days, one ration a
day settles at Gnawing (hunger ≈ 17) and two meals a day stay Satisfied, which
reads well as a 1,200 vs 2,400 kcal diet; the ladder is appetite-shaped, not
calorie-shaped, so this is acceptable. The snack is the outlier: 10 points is
40% of a meal for something eaten on the move.
Proposed change: `SNACK_HUNGER` 10 → 5 (snack = a third of a day); consider
`waterOz` Cal/Tann/Gibbs 90, Bode 110, Merrin 75, Pike/Kata 55 if the group
prefers canteens to feel small. Both are GM taste; the current values are not
wrong, only generous.

**I-14 · minor · `coldAdapt` applies to hunger only · "Cold bites 40% less" is narrower than it says.**
Merrin's trait and the Rules both say cold bites 40% less. In code `coldAdapt`
scales only the environment's hunger multiplier; the cold fatigue multiplier
(`ENVS.cold.rest` 1.25, `frozen` 1.5), the Chilled condition and the Chilled
onset chance are unaffected (measured: Merrin's frozen fatigue 10.2/hr vs Cal
12.0, and that gap is her `restRate`, not her cold adaptation). Same pattern for
Tann's `heatAdapt` and Overheated.
Proposed change: apply the adaptation factor to every heat/cold effect (env
rest multiplier, condition multipliers, onset chance), or narrow the trait text
to "burns 40% fewer extra calories in the cold".

## Notes

**I-15 · note · `NEEDS.water` Desiccated `wounds:1` and Collapse hourly check · The death roll is redundant.**
Desiccated (76+) deals a wound an hour; the meter reaches Collapse 13 h later,
by which time wounds have exceeded a threshold of 12. The hourly Daunting
Resilience "or death" check at Collapse rarely gets to matter. Starvation was
tuned so its wound clock and meter arrive together; thirst could use the same
treatment (wounds every 2 h at Desiccated, 1/hr at Collapse) so the rescue
window the text promises exists.

**I-16 · note · `CONDS.poisoned` fx · Omits the +20% water the code applies.**
Every other condition's text states its multipliers; Poisoned says "1 strain/hr
until treated" and nothing about thirst. Add "vomiting and sweats: +20% water".

**I-17 · note · `tick()` stimulant · The ×0.5 fatigue factor is a literal.**
`(cs.stimHrs>0?0.5:1)` sits in the tick loop while every other stim figure is in
`STIM`. Move it to `STIM.fatigueMult` so the Rules line can read it.

**I-18 · note · hunger ladder shape · The Gnawing cliff.**
Rates run 0.63, 0.63, 0.21, 0.12, 0.12, 0.12: a 3× drop at Gnawing then flat.
Decelerating is right, but the single cliff means a character sits in Gnawing
for two days and Famished for nine. A smoother 0.63 → 0.42 → 0.25 → 0.15 →
0.12 → 0.12 keeps Collapse near 29 days while making the middle tiers move.
Taste; check with `sim.sh` if changed.

**I-19 · note · ship wear counts idling as powered operation.**
A system loses a pip per 168 h of any non-docked status, including Idling at a
spaceport, so five weeks of sitting with systems on takes the hyperdrive
Offline. Fine for tension; if it surprises the table, scale wear by
`SHIP_ACTS[..].tph` or exempt idling.

## Checked and found consistent

- **Thirst ladder:** 3.1 days walking, 6.3 resting, 24 h scorching, 9 h fighting
  in scorching heat, 2.8 days in extreme cold (cold does not reduce need).
  Tier onsets (dry mouth at 11 h, headache and Setback at 26 h, −1 Brawn/Agility
  at 47 h) track real dehydration percentages.
- **Hunger ladder:** 28.7 days to Collapse walking, wounds from day 20 landing
  with the meter at 95; Hungry within a workday, Gnawing after a day. One ration
  a day equilibrates at Gnawing, two meals keep Satisfied (see I-13).
- **Hygiene ladder:** Grubby at 2 days, Filthy at 6, Squalid at 14, Diseased at
  29; halving rates per tier; daily Resilience at Squalid, a Sick stack per day
  at Diseased.
- **Activity and environment multipliers:** PAL-shaped hunger (0.5 sleep,
  0.6 rest, 0.8 sedentary, 1.25 march, 1.75 combat); water ×1.0/1.1 in cold,
  ×1.6 humid, ×2.5 scorching; thin atmosphere raises water, hunger and fatigue.
- **Multiplier stacking:** worst plausible thirst stack (child, combat,
  scorching, Overheated, Sick 3, overloaded) is 19.5 pts/hr, Thirsty in 34
  minutes and Collapse in about 4 hours: brutal, and about right for heat
  stroke. Best case (resting, 8 Force points, caffeinated) is 0.2 pts/hr,
  Collapse in 16 days: Jedi-trance plausible. No multiplier is applied twice;
  Soaked-in-cold adds Chilled once.
- **Condition texts vs code:** Chilled 30%/20%, Overheated 40%/20%, Sick
  10%/stack, Drunk 15/30/45%, Fear 15%/level, Caffeinated 40%/15%/10%, Limping
  30%, Inspired 10%, Ion 50%, Corroded 50% all match their multipliers.
  Sick's 1 wound / 4 h and the 2 strain/hr at 2+ match the hourly code.
- **Character traits vs mods:** Bode +25%, Gibbs +15%, Pike +35% and −15%
  fatigue, Kata ×1.25 sleep/10 h need/+10% water/+10% fatigue/+15% hunger,
  Tann heat 40%, BD-1 −10% wear, Alpha −25% environmental wear all match.
  Exceptions are the scope points in I-14.
- **Actions:** ration 15 min, meal 30 min with 1.25× cost and −5 fatigue,
  meditation's 15-minute sleep credit, wash two tiers over 30 min, stimpack
  5/4/3/2/1 healing with +2 wounds past five, refeeding cap 10 at Starving,
  half nourishment while Dehydrated, 10-oz rehydration cap all behave as
  described (subject to I-09, I-10).
- **Couplings over an ordinary day:** thirst stays 11–16 drinking 10 oz when
  Thirsty (about 45 oz a day), hygiene reaches Grubby on day three, sleep debt
  20 at bedtime and 0 at waking, strain stays 0. Apart from fatigue (I-01) the
  day reads as a believable day on the trail.
- **Droids and ship:** BD-1 40 h and Alpha 20 h per pack on light duty, 18/9 h
  in combat; wear 30 days to critical; the Mantis cruises 56 days or jumps for
  100 h on a full tank; energy routing conserves points and overcharge bonuses
  show on the card.

## Suggested order if fixing

I-01 and I-02 together (they decide whether an ordinary day is playable), then
I-03 and I-04 (one constant each plus a Rules line), then I-05 to I-12 as a
"conditions and recovery" pass, with `./tools/sim.sh` after every constant.
I-13 and I-18 are table taste; ask before changing.

## Resolution (2026-11-11)

I-01 to I-04 fixed in one commit, verified in the jsc harness and `./tools/sim.sh`:

| Finding | Change | Measured after |
|---|---|---|
| I-01 | `ACTS` rest: light 5, sedentary 1.5, moderate 12 | scripted day ends fatigue 48 (Winded) / 58 (Weary), wakes at 0; Spent at 20 h walking, 8.3 h march, 3.1 h combat |
| I-02 | Resting recovers 1 strain/hr; sleep/standby `⌈st/8⌉`/hr; sleep ≥ `SLEEP.fullNightHrs` (6) clears all; Ill 0.5/hr, Sick 2+ 1/hr, Sleep-Deprived 0.5/hr; `addStrain` accumulates fractions in `cs.strainFrac` | Ill walker: strain 8 at bedtime, 0 at waking; Gravely Ill: down at 12 h, back up after 6 h resting; sleep-deprived walker collapses at 57 h awake (Delirious), not 45 |
| I-03 | `exhaustion()` charge term `0.55 × max(0, (charge−50)×2)` | BD-1 first Setback at 25 h / 63% used (was 11 h / 28%); Alpha 3 strain per pack (was 7) |
| I-04 | `ACTS` water: moderate 3.0, strenuous 8.0 | Cal 2.5 / 7.5 / 20 oz per hour; one hour of desert combat = 20 thirst; Collapse in 5 h of desert fighting |

I-05 to I-19 remain open.

## Resolution, part 2 (2026-11-11)

I-05 to I-12 fixed in one commit; harness and `./tools/sim.sh` green:

| Finding | Change | Measured after |
|---|---|---|
| I-05 | onset rolls while asleep; `humid` 0.05; chance × `climateAdapt`; Chilled/Overheated excess × adaptation | sleeper in Extreme Cold gets Chilled; jungle overheats; at a 4.9% roll Cal overheats and Tann (×0.4) does not; Tann's Overheated water ×1.16 instead of ×1.4 |
| I-06 | Chilled hunger ×1 when the environment is cold | Cal walking in Extreme Cold: Collapse 18 days (was 13.8 with the double count); Chilled in temperate still ×1.3 |
| I-07 | Sick `rest` ×(1+0.15l), `sleep` ×(1+0.1l) | Sick 2: fatigue ×1.30, sleep ×1.20 |
| I-08 | `decayHrs`: Drunk 2 (one level), Caffeinated 4 (clear); `cd.hrs` counter, reset by condLvl | Hammered at 0 h → Drunk 2 h → Tipsy 4 h → sober 6 h; Caffeinated gone at 4 h; each step logged |
| I-09 | `REHYDRATE.waitHrs` 0.25, `cs.lastDrinkAt` | three instant sips at thirst 70 → only the first lands (66); after +15 min the next sip works; hydrated characters unaffected |
| I-10 | `HYG.wipe` 12, `HYG.clothes` 8 | a wipe removes 1.9 days of Grubby-tier grime |
| I-11 | `SLEEP.deepDebtFrom` 76, `deepDebtCap` 75 on the sleep status | Wrecked 100 → 25 after night one → 0 after night two; from 60 → 0 in one night; plain Sleeping activity (no status) is uncapped |
| I-12 | Drowsy `min` 19 | Drowsy at 18–19 h awake (sedentary), Kata 15 h; Sleep-Deprived still 49 h |

Harness: `tools/sim.sh` now pins the needs it is not measuring (and strain/wounds), which the pass-1 "unconscious = resting" rule had made necessary.

Still open: I-13 (water per day, snack size: taste), I-14 (adaptation scope on fatigue), I-15 (thirst death-roll redundancy), I-16 (Poisoned text), I-17 (stim literal), I-18 (hunger curve shape: taste), I-19 (ship idling wear).
