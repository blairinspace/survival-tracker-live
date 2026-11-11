# Pass 1 — functional audit findings

Audited 2026-11-11 against commit 1d0ed3e of `sw_survival_tracker.html`
(2,524 lines), all eleven chunks of REVIEW_PLAN.md plus the CSS and markup, with
a final cross-read of the tick loop against the constants and actions. Every
claim marked **verified** was reproduced in a `jsc` harness built from the
`tools/sim.sh` stub (the real tracker script with a stubbed DOM). Nothing has
been fixed.

Severity: **blocker** wrong numbers, lost state, crash · **major** visible wrong
behaviour in a session · **minor** edge case or cosmetic · **note** style, dead
code, docs drift.

## Blockers

**F-01 · blocker · 778 · `migrate()` crashes on a character id that is not in `CHARS`.**
`newCharState(cfg(cs.id))` is called for every saved character; `cfg` returns
`undefined` for an unknown id and `newCharState` dereferences `c.id`.
Reproduction (verified): add `{id:'ghost'}` to `s.chars` and call `migrate(s)` →
`TypeError: undefined is not an object (evaluating 'c.id')`. In practice: a
save file from a build whose roster differed, or a live room written by a client
running a build with a character this build lacks (a renamed or removed id).
`importState` shows "Invalid save file"; `applyRemote` throws inside the
Firebase callback and the room never loads on that client.
Fix: in `migrate`, drop (or keep as-is but skip) characters whose id has no
config: `s.chars = s.chars.filter(cs => cfg(cs.id))` before the per-character
loop, and log one line so the GM knows a character was dropped.

## Major

**F-02 · major · 973–974 · Strain- and wound-threshold notices repeat on every tick chunk.**
Both checks sit in `tick()` and push an event each call while the condition
holds, not on the crossing. Reproduction (verified): set Cal's strain to 12
(threshold 12), advance 8 h → 8 identical "has exceeded strain threshold"
entries; a 12-hour Advance adds 12. The log is capped at 100 entries
(`logMsg`), so one unconscious character flushes a day of real events.
Fix: remember the previous state (`cs.wasUncon`, `cs.wasDead`) and emit only on
the false→true transition, as the tier notices already do via `lastTiers`.

**F-03 · major · 2508 · Solo state is never persisted; a page reload resets to Day 1.**
`init()` always does `S = freshState()`. The only `localStorage` writes are the
player name and the last room id. In a live room the state comes back from the
server, but a solo GM who refreshes (or whose tab is discarded on mobile) loses
the session unless they clicked 💾 Save. The Rules tab does not warn about this.
Fix: `lsSet('st_state', JSON.stringify(S))` from `scheduleSync()` (debounced,
already called after every change) and restore it in `init()` when no room is
joined. If this is intentional, say so in the Rules tab next to Save/Load.

**F-04 · major (live rooms) · 2405–2406, 2364 · After one failed push, the next incoming snapshot discards all local edits.**
`pushLocal` sets `CLOUD.shadow = null` on a write error. `applyRemote` then
takes the `remoteSub` wholesale because `(CLOUD.synced && CLOUD.shadow)` is
false, instead of three-way merging. Reproduction (verified): with
`CLOUD.synced=true, shadow=null`, set Cal's wounds to 4, apply a remote
snapshot with wounds 0 → local wounds become 0. Trigger: any transient network
error or a rules-denied write.
Fix: keep the last good shadow on failure (set a `CLOUD.dirty` flag so the
next `pushLocal` resends everything), or merge against `syncSubset(S)` as
base when the shadow is missing.

## Minor

**F-05 · minor · 1372 · Nested arrays from the room are not re-arrayified.**
`onRoomSnap` only arrayifies `remote.chars` and `remote.log`; `migrate` only
`s.log`. If RTDB ever returns `inv`, `conds`, `cargo`, `smuggle` or `fuelLog` as
an index-keyed object (it does so for sparse arrays), `syncInv` dies on
`cs.inv.find`. Reproduction (verified): convert one character's `inv` to
`{0:…,1:…}` and call `migrate` → `cs.inv.find is not a function`. This client
always writes whole compacted arrays, so the trigger is a hand-edited room or a
future partial write; low likelihood, hard crash.
Fix: in `migrate`, run `arrayify` on every list field (`inv`, `conds`,
`ship.cargo`, `ship.smuggle`, `ship.fuelLog`) before use.

**F-06 · minor · 2388 · `threeWayMerge` pairs characters by array index, not id.**
`out.chars[i] = L[i]` assumes local and remote rosters have identical order
and length. Reproduction (verified): a remote missing one mid-roster character
plus a local edit to a later character writes that character over a different
id's slot (duplicate id, one character lost until `migrate` re-adds a fresh
copy). Only happens when two clients run different rosters, which is exactly
the deploy window when a character is added.
Fix: merge by id (`out.chars = remote.chars.map(rc => localEdited[rc.id] ?? rc)`
plus append local-only ids), and do the same in `pushLocal`'s per-index diff
(write `chars/<id>` keyed objects, or re-derive the index from the remote).

**F-07 · minor · 1033 · Travel ETA is rounded to 2 decimals while the clock runs at 3.**
Reproduction (verified): ETA 0.30 h, a 0.004 h chunk (a status ending) leaves
ETA at 0.30 while `S.hour` moved. Repeated small status boundaries drift the
arrival later than the clock says.
Fix: use `toFixed(3)` like `S.hour`, or compute arrival as an absolute hour
(`S.arriveAt`) and compare.

**F-08 · minor · 1105, 1131 · Fractional snacks and stimpacks can never be used.**
Inventory qty inputs accept decimals (`setStock` and `setInv` use `parseFloat`)
but `eatSnack`/`useStim` require `>= 1`. Reproduction (verified): snacks 0.5 →
"out of snacks" forever. Rations are legitimately fractional; snacks and stims
are not.
Fix: `Math.round` (or `parseInt`) for snacks, stims and packs in `setStock`
and `setInv`, and `step="1"` on those inputs.

**F-09 · minor · 1050–1055 · A cancelled meal charges full rations for almost no relief.**
Cost is deducted when the status starts; relief is delivered over the duration.
Reproduction (verified): hunger 30, start a ration, advance ~1 min, cancel →
1.5 rations spent, 2 points of hunger relieved. The Rules say "keeps what was
already gained", but the player keeps nothing and loses the food.
Fix: either refund the un-eaten fraction on cancel, or apply the whole hunger
delta at start and let only the resting recovery run over time.

**F-10 · minor · 869, 997 · Unconscious characters keep the activity they collapsed in.**
Nothing forces `activity` to resting when strain ≥ threshold or a need hits
Collapse. Reproduction (verified): strain 12/12, activity strenuous, advance
2 h → fatigue +64, thirst accrues at ×3. An unconscious body is not sprinting.
Fix: in `tick`, treat `uncon || dead || any Collapse tier` as `actKey='resting'`
(or `'sleeping'`), and have `setAct` refuse changes while unconscious.

**F-11 · minor · 382, 397, 404 · Condition strain is uncapped; tier strain is capped.**
Need-tier strain stops at `strainCap = st*2` (line 997), but Sick, Poisoned and
Drunk add strain without a cap, and they also tick while asleep (verified: Sick
2 adds 16 strain over an 8 h sleep, while Sleep-Deprived strain is suppressed
by `!isStandby`). The card then shows strain far past any threshold.
Fix: route condition strain through one helper (`addStrain(cs, n)`) that caps
at `strainCap`, and decide per condition whether it runs during sleep.

**F-12 · minor · 1027 · A status remainder under 0.01 h applies its forced activity for a whole chunk.**
`advance` only stops at a boundary when `remain >= 0.01`. If drift leaves
`remain = 0.005`, the next chunk (up to 1 h) runs at the status's activity
(resting ×0.5 water) although the status ended after 18 seconds. Reachable only
through odd custom Advance values (e.g. 0.245).
Fix: when `remain < 0.01` and `> 0`, end the status at the top of the chunk
before computing `actKey`.

**F-13 · minor · 1623 · The sleep-hours field resets to 8 on every render.**
`value="8"` is hard-coded in the template, and `render()` rebuilds the card on
every action by anyone (and on every remote update). A player who types 10 and
then does anything else first sleeps 8. Kata (needs 10 h) hits this every night.
Fix: store the last typed value on the character (`cs.sleepHrs`) and default
Kata's to `mods.sleepNeed`.

**F-14 · minor · 2483–2486 · Deferred remote updates can swallow a click.**
A remote update held by `isEditing()` is applied 60 ms after `focusout`.
Clicking a button while a text field has focus fires `focusout` on mousedown;
if the press lasts longer than 60 ms, `applyRemote → render()` replaces the DOM
between mousedown and mouseup and the `click` never fires. Not reproducible
headlessly; reasoning from the event order.
Fix: defer the pending apply to the next `click`/`pointerup` as well, or apply
it only when `document.activeElement` is `body` and no pointer button is down.

## Notes

**F-15 · note · 2036 · Rules say rest halves sleep debt; the code uses ×0.75.**
`SLEEP.restingMult` is 0.75 but the status table says "sleep debt ticks at
half rate while resting". Fix: interpolate `${SLEEP.restingMult}`.

**F-16 · note · 315, 2055, 2147 · Sleep tier hours are literals that no longer match the rate.**
At `awakeRate` 1.04 the tiers land at 25, 49, 73 and 96 h; the comment and two
Rules paragraphs say 25/48/72/96. Fix: derive with `tierAt('sleep', name)` the
way the other ladders do.

**F-17 · note · 2033–2038 · The timed-status table is all literals.**
−25, −30, −5, −3/−6, −8/−14, 15/30 min and the sleep-credit sentence are typed
by hand rather than read from `STATUSES`. Changing a status silently desyncs
the Rules. Fix: build the rows from `STATUSES` like `actRows`/`envRows`.

**F-18 · note · 1433 · `needColor` thresholds (35/60/85) differ from the tier ladders (26/51/76).**
Only used for droid charge/wear bars and ship gauges, so a droid at wear 30
shows green while its degradation tier may already be Strained. Fix: colour
droid bars from `DTIERS` or align the thresholds.

**F-19 · note · 1960 · Log entries render `l.m` as HTML and `l.c` into a class attribute unescaped.**
Locally every user string passes through `esc`, but remote log entries are
trusted as-is. Fine among friends; a hostile room member could inject markup.
Fix: whitelist `l.c` against the known classes and keep `esc` discipline on
the write side (already done).

**F-20 · note · 1380 · `setInv` does not guard a missing row; `setCargo` does.**
`it.auto` throws if `cs.inv[i]` is undefined. Not reachable through the UI
today because `change` fires before `focusout`, but inconsistent. Fix: `if(!it) return;`.

**F-21 · note · 2372 · Echo detection compares before nested arrayify.**
Harmless today (see F-05) but if nested lists ever arrive as objects the echo
check also fails and every snapshot re-merges. Same fix as F-05.

**F-22 · note · 252 · The Advance button does not clamp the typed hours.**
`max="168"` is on the input only. 2,000 h ran in 0.65 s headlessly, so no
freeze, but a typo of 1200 instead of 12 silently skips 50 days. Fix:
`clamp(..., 0.25, 168)` in the handler and confirm above 48 h.

**F-23 · note · CSS line 10 · `.sub` is defined and never used.** Only dead
selector found; every element id read by JS exists in the markup or in rendered
HTML.

## Checked and found clean

- **dt linearity and hourly effects:** every accrual in `tick` is linear in
  dt; `applyHourly` fires exactly once per accumulated hour across odd chunk
  sizes (verified: 0.25 + 0.5 + 0.25 h → one poison tick).
- **Status boundaries:** three characters with 0.25 h, 0.5 h and 1.3 h statuses
  all ended at the right clock time within one `advance(2)` (verified).
- **Stim timer:** `stimHrs` reaches exactly 0 and logs "wears off" once
  (verified across 0.3 h chunks).
- **Rehydration and refeeding caps:** drink capped at 10 oz only when the
  canteen holds more; meal while Dehydrated and Starving halves then caps at 10
  (verified). Snacks bypass `REFEED` but equal the cap, so numerically safe.
- **`prune` keeps zeros:** Offline systems (0), zero defense arcs and zero shield
  boosts survive the wire format; empty `conds`, `log`, `cargo`, `crew` are
  dropped and restored by `migrate` (verified).
- **Escaping:** every user-typed string that reaches HTML or an attribute
  (item names, custom condition name and effect, notes, location, crew) goes
  through `esc`; `typeSelect` escapes custom types.
- **Condition gating:** card and party selects filter droid vs organic
  conditions; `partyCond` has no custom option so `partyAddCond` cannot hit an
  undefined definition.
- **Soaked-in-cold** adds the Chilled multiplier once and only for keys Chilled
  defines; droids unaffected (verified `condMult` = 1 for charge).
- **Strain threshold 0** disables the unconscious check as intended (verified).
- **Rules derivation:** thirst/hunger/hygiene ladders, environment and activity
  tables, character and droid rows, ship figures, wear and stim figures all
  interpolate from constants. Exceptions are F-15, F-16, F-17.
- **Element ids:** every `getElementById` target exists in the static markup
  or in the markup `render`/`renderShip` produce.

## Hand-off to pass 2 (immersion)

Observed while auditing, not functional defects:

- Light activity reaches Spent in 13 h; Exhausted at 10 h then multiplies sleep
  debt ×1.5, so a plain walking day reaches Drowsy at 20 h, not 25.
- Sick raises thirst and hunger only; no fatigue or sleep effect at 3+ stacks.
- Sleeping outdoors never triggers Chilled/Overheated (`!isStandby` guard).
- Sleep does not recover strain; the Rules say strain is cleared manually per
  core rules, so this is a design choice to confirm.
- Kata's default sleep input is 8 h against a 10 h need (see F-13).

## Resolution (2026-11-11)

All 23 findings were addressed in five commits on `main`, each verified in the
jsc harness and with `./tools/sim.sh` green:

| Commit theme | Findings | Outcome |
|---|---|---|
| Tick-loop defects | F-02, F-07, F-10, F-11, F-12 | fixed: one-shot threshold notices (`wasUncon`/`wasDead`), unconscious/dying/collapsed characters accrue as resting, `addStrain()` caps condition strain at 2× threshold, `endStatus()` closes sub-0.01 h slivers at the top of a chunk, ETA at 3 decimals |
| Save/load and live sync | F-01, F-04, F-05, F-06, F-14, F-19, F-20, F-21 | fixed: unknown ids dropped with a log line, nested lists re-arrayified, id-based character merge in the remote's order, failed push keeps the last good shadow, pending remote updates wait for pointerup, log class whitelisted, `setInv` guard |
| Card and actions | F-08, F-09, F-13, F-18, F-22, F-23 | fixed: whole-number snacks/stims/packs, pro-rata ration refund on cancel (also when switching activity), `cs.sleepHrs` remembered per character with the nightly need as default, bar colours at 26/51/76, `advanceCustom()` clamps and confirms > 48 h, dead `.sub` removed |
| Solo persistence | F-03 | fixed: debounced localStorage copy on every change, restored in `init()`, 🆕 New button with confirm, Rules "Saving & sessions" section |
| Rules derivation | F-15, F-16, F-17 | fixed: status table generated from `STATUSES`, sleep tier hours from `tier.min ÷ awakeRate` |

Residual, by design or deferred:

- Condition strain (Sick, Poisoned, Drunk) still ticks while asleep; tier
  strain does not. Left for the immersion pass to decide.
- `pushLocal` still writes characters by array index (`chars/<i>`). The merge
  is id-based, so a roster gap no longer corrupts data, but two clients on
  different rosters that both append a new character at the same index could
  still collide. Moving the wire format to `chars/<id>` would need a one-time
  room migration.
- Remote log entries are still trusted HTML (only the class is whitelisted).
