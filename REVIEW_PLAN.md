# Survival Tracker — full code review plan

Written 2026-11-11. Goal: comb every line of `sw_survival_tracker.html` twice
(functional, then immersion), fix what we find, and only then start the big
edits and additions on a clean, trusted base.

## 0. Baseline first (before any auditing)

- **Commit the working tree.** `git status` shows a 386-line uncommitted diff in
  both HTML files (the October decay recalibration: `SLEEP`, `REHYDRATE.capOz`,
  `STARVE_WOUND_HRS`, new ENV/ACT multipliers, character `hungerRate`s) plus the
  untracked `tools/sim.sh`. Audit findings and fixes must be diffable against a
  known commit, so land this first as "Recalibrate decay rates; add sim harness".
- **Audit the source only.** `index.html` is a byte-identical copy that
  `deploy.sh` regenerates. Never edit it by hand during the review.
- **Oracle:** `./tools/sim.sh` runs the real simulation headlessly in `jsc` and
  prints time-to-tier tables, wound clocks, drink conversions and a UI smoke
  test. It passes today (exit 0, 0 broken Rules interpolations). Run it before
  and after every change; paste its tables into immersion findings as evidence.

## 1. How the file is organized (2,524 lines)

Review in these chunks. Each is small enough to hold whole; each has one job.

| # | Lines | Section | What lives there |
|---|-------|---------|------------------|
| A | 305–470 | Constants | `SLEEP`, `MAINT_BASE`, `ENC_*`, `FORCE_PER_PT`, `STIM`, `REHYDRATE`, `REFEED`, `STARVE_WOUND_HRS`, `SLEEP_FATIGUE`, `FATIGUE_SLEEP`, `HYG`, `ENV_COND_CHANCE`, `STATUSES`, `CONDS`, `AUTO_ITEMS`, `ENVS`, `ACTS` |
| B | 474–730 | Tables | `CHARS` (kits, mods, traits), `NEEDS` tiers + fx text, `DTIERS`, wear constants, `SHIP*` |
| C | 731–865 | State & helpers | `freshState`, `newCharState`, `migrate`, `ozToPts`, encumbrance, `condMult`, `exhaustion` |
| D | 866–1045 | Simulation core | `tick`, `applyHourly`, `advance` (dt chunking, status boundaries, hourAcc) |
| E | 1047–1240 | Player actions | statuses, sleep, drink, eat, hygiene, stims, Force, attrs, conditions, droid upkeep |
| F | 1243–1365 | Ship | `tickShip`, fuel, systems, energy distribution, shields, torpedoes, cargo |
| G | 1366–1420 | Inventory & wear | `syncInv`, item edits, use/tune/overhaul |
| H | 1419–1720 | Render: characters | portraits, need rows, cards, `render()` |
| I | 1712–1950 | Render: ship, chips, party actions, log | `renderShip`, `setAct`, `partyAddCond`, `logMsg`, `editNeed` |
| J | 1982–2250 | Import/export & Rules tab | `exportState`, `importState`, `buildRules` (derived figures) |
| K | 2252–2524 | Live sync | `syncSubset`, `prune`/`arrayify`, `threeWayMerge`, `applyRemote`, room lifecycle, `init` |

CSS (lines 7–201) and markup (202–304) get a light pass at the end of the
functional comb, for things like dead selectors and ids that no handler uses.

## 2. Method for both passes

- **One chunk per prompt run**, in table order, plus one final cross-chunk run
  that re-reads D with A, B, C and E together (the bugs that matter are
  interactions between constants and the tick loop).
- **Comb, don't fix.** Each run only appends findings to
  `review/findings-functional.md` or `review/findings-immersion.md`. Fixing
  during the comb hides the pattern of the bug and breaks the baseline.
- **Finding format** (one row each): `ID · severity · lines · claim · how to
  reproduce (clock steps, or a sim.sh number) · proposed fix`. Severity:
  **blocker** (wrong numbers, lost state, crash), **major** (visible wrong
  behaviour in a session), **minor** (edge case, cosmetic), **note** (style,
  dead code, docs drift).
- **Verify before recording.** A claim about a rate or a wound clock gets a
  line in `tools/sim.sh` (or a one-off `jsc` script) that demonstrates it. A
  claim about UI state gets a step list that reproduces it in the browser.
- **Fix phase** after both combs: triage by severity, fix in `sw_survival_tracker.html`
  only, run `./tools/sim.sh`, then `./deploy.sh "..."` copies to `index.html`.

## 3. Pass 1 — functional audit prompt

Paste this per chunk, replacing the line range and section name.

> You are auditing `sw_survival_tracker.html`, a single-file browser app (plain
> JS, no framework) that tracks survival needs for a tabletop RPG party, with
> optional Firebase RTDB live rooms. Review **lines L1–L2 (section NAME)** for
> functional defects only. Do not fix anything; append findings to
> `review/findings-functional.md` in the format: ID · severity
> (blocker/major/minor/note) · lines · claim · reproduction · proposed fix.
>
> Read the whole chunk before writing. Then check each of these, in order,
> and say explicitly which ones you checked and found clean:
>
> 1. **Simulation math.** `tick(cs, dt)` is called with dt ≤ 1 h, chunked by
>    `advance()`, which also stops at timed-status boundaries. Verify every
>    accrual is linear in dt, that nothing is applied once per call when it
>    should be once per hour (that is `applyHourly`'s job, driven by `hourAcc`)
>    or vice versa, and that `clamp(..., 0, 100)` cannot hide a tier crossing
>    or an event (`prev<100 && now>=100` patterns).
> 2. **Floating point.** Values are rounded with `toFixed(3)` in places. Find
>    any comparison that can miss because of drift (`=== 0`, `% 24 === 0`,
>    `remain <= 0`, `travelEta === 0`), and any counter that a fractional dt can
>    skip past.
> 3. **Tier and threshold boundaries.** Tiers use `min` with `>=`. Check every
>    hard-coded number that mirrors a tier (`cs.hunger < 76`, `cs.hygiene < 76`,
>    `REHYDRATE.thresh`, `REFEED.thresh`, `SLEEP_FATIGUE.thresh`,
>    `FATIGUE_SLEEP.thresh`) still matches the tier table it stands for.
> 4. **State shape and migration.** Every field written anywhere must be
>    created in `newCharState`/`freshShip` and patched in `migrate()` for old
>    saves and for room snapshots. Look for fields read before they exist, and
>    for `undefined` reaching arithmetic (`NaN` poisons a meter silently).
> 5. **Actions and guards.** For each player action: can it run during a timed
>    status, while unconscious, for the wrong character type (droid vs
>    organic, Force-sensitive only), with a negative or non-numeric input, or
>    twice in one click? Does it restore `cs.activity` from `prevAct` correctly
>    if the user changes activity mid-status?
> 6. **Render and DOM.** Handlers are inline `onclick` strings with ids built
>    by template literals. Check escaping of user text (`esc`) in every place
>    it is interpolated into HTML or into an attribute, element ids that are
>    read (`getElementById`) but not rendered in every state, and focus loss
>    when `render()` rebuilds innerHTML while a field is being edited
>    (`isEditing`).
> 7. **Live sync.** `syncSubset`, `prune`, `arrayify`, `threeWayMerge`,
>    `applyRemote`. RTDB drops empty arrays and null keys. Check what happens
>    when two players edit the same character in the same debounce window,
>    when `chars` order differs between base and remote, when a list is
>    emptied, when a snapshot arrives mid-`advance()`, and when `migrate` adds
>    defaults that then look like local edits and re-push forever.
> 8. **Import/export and Rules tab.** `importState` must survive a file from
>    an older version. `buildRules` must contain no literal day/hour figures;
>    every number must derive from the constants (`ladderHours`, `tierAt`).
> 9. **Dead and duplicated code.** Unused constants, functions, CSS selectors,
>    element ids; two code paths that compute the same thing differently.
>
> For every finding give the exact reproduction: the sequence of clock
> advances and clicks, or a `jsc` one-liner against the sim harness in
> `tools/sim.sh`. If you cannot reproduce it, file it as a note, not a bug.

## 4. Pass 2 — immersion audit prompt

Run after the functional pass is fixed, so numbers are trustworthy. Run it on
chunks A, B, D and E (constants, tables, tick, actions); the rest is UI.

> You are auditing the realism of `sw_survival_tracker.html`, a survival
> tracker for a Star Wars tabletop party (Genesys/FFG dice: Setback, Boost,
> difficulty upgrades, strain and wounds). Review **lines L1–L2 (section
> NAME)** for immersion errors: places where the decay of a need, the effect of
> an action, or the behaviour of a condition would make a player say "that's
> not how bodies work" or "that's not what the card said". Do not fix; append
> findings to `review/findings-immersion.md` as ID · severity · lines ·
> what the code does (with the number) · what reality or the fiction expects ·
> proposed constant or rule change.
>
> **Ground truth.** Run `./tools/sim.sh` first and keep its tables open. The
> calibration anchors already chosen are: thirst to Collapse ≈ 3 days walking,
> 6 resting, 1 day in desert heat; cold does not reduce water need; hunger to
> Collapse ≈ 29 days walking with starvation wounds (1 per 12 h at Emaciated+)
> landing with the meter; a character's `waterOz` is one day of light-activity
> water, so a 20 oz canteen is about a third of a day; droid wear ≈ 30 days
> unmaintained; gear wear ≈ 90 days ambient plus 5 per hard use. Treat those
> as settled unless the code contradicts its own anchor.
>
> For each mechanism in the chunk, answer these in writing:
>
> 1. **Rate vs reality.** Pick the time-to-tier from the sim table (or compute
>    it from the tier `rate`s and the multipliers in `ACTS`, `ENVS`, `CHARS.mods`,
>    `CONDS.mult`). State the real-world figure it should resemble (hours
>    awake before microsleeps, calories at a forced march in cold, sweat rate
>    in combat, days to lice and skin infection in the field). Flag any gap
>    larger than about ×1.5 either way.
> 2. **Curve shape.** Thirst accelerates, hunger and grime decelerate, sleep
>    is flat, fatigue is activity-driven. Does each tier's `rate` follow its
>    stated curve, and does the first tier line up with the "should act soon"
>    window a GM wants (a few hours for thirst, a day for hunger)?
> 3. **Multiplier stacking.** Multiply out the worst plausible stack
>    (strenuous · scorching · overheated · sick 3 · overloaded · child) and the
>    best (resting · temperate · 8 Force points · caffeinated). Is either
>    absurd? Is any multiplier applied twice through different paths
>    (environment `cold` flag plus the Chilled condition plus Soaked-in-cold)?
> 4. **Conditions.** For each entry in `CONDS`: does it touch the needs it
>    should and leave alone the ones it shouldn't? Fever without extra sleep
>    debt or fatigue, poison that only costs water, drunkenness that sobers
>    only with time, Chilled with no effect on thirst. Does severity (`lvls`)
>    scale sensibly, and does the `fx` text promise anything the code does
>    not do (or the reverse)?
> 5. **Actions and recovery.** Does the relief per action match its cost and
>    duration: a 15-minute ration vs a 30-minute meal, a snack, a 10 oz capped
>    drink at Dehydrated, a full wash vs a wipe-down, 8 hours of sleep vs
>    meditation's `sleepCredit`, a stimpack's fatigue relief and crash? Is
>    refeeding and rehydration caution modelled where it matters and skipped
>    where it should not be (snacks bypass `REFEED`)?
> 6. **Couplings.** Sleep deprivation slows fatigue recovery; exhaustion
>    speeds sleep debt; dehydration halves meals; Squalid rolls daily for
>    Sick; Diseased stacks Sick. Trace each through a full day of walking and
>    say whether the combined result reads as a believable bad day or a death
>    spiral the players cannot see coming. Note the sim figure that light
>    activity with no rest breaks reaches Spent at 13 h and, through
>    `FATIGUE_SLEEP`, drags Drowsy forward to 20 h: decide whether that is the
>    intended "no breaks" penalty or too punishing for an ordinary travel day.
> 7. **Character differences.** `hungerRate`, `waterRate`, `sleepRate`,
>    `sleepNeed`, `restRate`, `heatAdapt`, `coldAdapt`, `maintAdapt`. Does each
>    trait string on the card say exactly what its multiplier does, with the
>    same percentage? Do the species and frames justify the numbers?
> 8. **Text vs code.** Every `fx` string, trait, log message and Rules-tab
>    paragraph that names a number, a duration or a dice effect must match the
>    constant that drives it. List every literal number in prose that is not
>    interpolated from a constant.
> 9. **Droids and ship.** Charge and wear tiers against the stated pack hours
>    and maintenance interval; the ship's fuel burn, condition pips and energy
>    bonuses against the fiction of a small freighter.
>
> Write each finding so a GM could read it aloud: what happens now, what
> should happen, and the one constant or rule that changes it.

## 5. Seeds to verify first (spotted while mapping; none confirmed)

- Light activity reaches Spent (no strenuous actions at all) in 13 h, and the
  Exhausted tier at 10 h then multiplies sleep debt ×1.5, so a long walking day
  hits Drowsy at 20 h instead of the 25 h the sleep comment promises.
- The Sick condition raises thirst and hunger only; fever that neither tires
  nor costs sleep may read as thin at 3+ stacks.
- `eatSnack` ignores `REFEED` (harmless today because `SNACK_HUNGER` equals
  `REFEED.capPts`, but the invariant is accidental).
- `setAttr` only refreshes `encThresh` for Brawn; check that nothing else
  caches a derived value from attributes.
- `threeWayMerge` matches characters by array index, not id; confirm `migrate`
  can never reorder or append on one side only.

## 6. After the review

Fix phase in severity order, `sim.sh` green, one commit per theme, then
`deploy.sh`. Only then open the "significant edits and additions" list, with
each addition written against the sections above so it lands in the right
chunk and gets the same two-pass check before deploy.
