# Core R6 hand-off (Core engineer, 28 Oct 2026)

This is unverified until CI compiles it; there is no Swift compiler on this host. I did two full read-throughs for
compile errors: Swift 5, exhaustive switches over `RunMode` (now with `.zen`), `TrapEvent` and the new `GoalKind`, no
mutating, rethrowing or closure calls inside `#expect`, no ambiguous `.nan`, and no local shadowing a static.

`tools/balance-sim.js` stays a line-by-line port: `lastLightWave` and `zenDayWaves` are in `T`, and `paceWave` is
mirrored in the session and the pilot. The goal and halo constants are not in the sim (it has no goals or hints).
Every change is marked "R6" in the code. `Contracts.swift` was not touched.

## New files
- `Snap/Core/Goals.swift`: `GoalScope`, `GoalSpan`, `GoalKind`, `GoalSpec`, `GoalBookSlot`, `GoalBookState`, `GoalBookUpdate`,
  `GoalTracker`, `GoalBook`.
- `Snap/Core/Varieties.swift`: `VarietyUnlock`, `VarietyInfo`, `Varieties`.

## Goals: the API for the App
```swift
var book = GoalBook.start(seed: anyRandomUInt64, rank: rank)   // once; persist it (GoalBookState is Codable)
book = GoalBook.normalized(book, rank: rank)                   // after loading (drops unknown ids, refills)
GoalBook.activeGoals(book)                                     // [GoalSpec]: Home card, pause menu
var tracker = GoalBook.tracker(book, mode: mode)               // at run start (startPhase: if firstWave is set)
let toasts = tracker.ingest(events)                            // every frame: [GoalSpec] met just now (once each)
tracker.progress(def) / def.progressLabel(p) / tracker.isSpoiled(def) / tracker.counts(def)
let up = GoalBook.complete(book, tracker: tracker, rank: rank) // at Results, or when a run is left early
book = up.state                                                 // persist
// up.completed, up.added (same slots), up.growth (bonus included), up.bonus
```
- **The pool** has 39 goals: bite sizes, feasts, chains, sparing, species hunts, the time of day, run totals, 3 Daily
  goals and 2 Zen goals.
  - Each `GoalSpec` has an `id` (stable, persisted), a `template` with `{n}`, the `title`, a `kind`, a `target`, a `span`
    (`.run` keeps the best run; `.total` adds the runs up), a `scope` and its `ranks` band.
  - `unlocks` marks the 3 variety goals.
- **Scopes:**
  - `.anyMode` (raw value "any") covers Feed, Daily and Zen.
  - `.standard` covers Feed and Daily. These are run totals that endless Zen would make trivial.
  - `.daily` and `.zen` cover one mode each.
  - Attract and the lesson never count.
  - `GoalScope.label` gives a card tag: "Any mode", "Feed or Daily", "Daily" or "Zen".
- **Evaluation** reads the run's `TrapEvent`s and nothing else, so it ticks live.
  - `GoalBook.progress(for:mode:events:)` is the same evaluation for a whole event list.
  - `GoalBook.progress(for:result:)` answers from a `RunResult` where it can, and returns nil for day-phase goals. It is
    useful for demo frames. A test checks that it agrees with the events on a real run.
- **The draw** is deterministic, from `state.seed`, `state.draws` and the rank:
  - A variety goal comes first, once its band opens. Only one is active at a time, and it is never drawn again once
    done.
  - Otherwise the draw is a seeded pick that avoids:
    - active goals;
    - the last 6 completed;
    - an active goal's family (no two bite-size goals at once);
    - a second Daily or Zen goal.
  - Each rule is relaxed in turn if nothing is left.
- **Growth:** `GoalBook.reward(rank:)` is 15 % of the gap to the next rank, rounded to 5, with a minimum of 10. That is
  10 at Sprout, 30 at rank 3 and 150 at the top. Completing all 3 at once adds `tripleBonus(rank:)`, one more reward.
  Pass the rank at Results.
- **Edge rules:**
  - "No dry snaps until dusk/night" needs at least 5 snaps first, so idling to dusk doesn't count.
  - "Catch N before biting a bee" stops counting at the first stinger bite.
  - `isSpoiled` greys a goal that can't be met this run any more.

## Varieties (the Garden)
- `Varieties.all` and `info(_:)` give the name, blurb and unlock for each variety.
- Other calls:
  - `unlocked(rank:completedGoals:)` returns the unlocked varieties in `allCases` order.
  - `isUnlocked(_:rank:completedGoals:)`
  - `newlyUnlocked(rankBefore:goalsBefore:rankAfter:goalsAfter:)` drives the fanfare.
  - `ruleText(_:)` returns "Reach Nibbler" or "Goal: Spare 12 bees in one run".
  - `effective(_:rank:completedGoals:)` falls back to Classic if the chosen variety is locked.
- Pass `book.completedSet` (or `everCompleted`) as `completedGoals`.
- The unlock rules:

| Variety | Unlock |
|---|---|
| Classic | start |
| Red Dragon | rank 2 (Nibbler) |
| Sawtooth | goal `spare12` "Spare 12 bees in one run" (offered from rank 3) |
| B52 | rank 5 |
| Shark Tooth | goal `bite6` "A 6-bug bite" (from rank 6) |
| Cupped Trap | rank 8 |
| Fused Tooth | goal `chain5` "Reach a ×5 chain" (from rank 9) |
| Golden Glow | rank 11 (Bog Monarch), the final unlock |

## Zen
- `SessionOptions.for(.zen)`:
  - `snapsRunOut` false, so the snaps never change and the trap never tires;
  - `hunger` false, so there are no wilts and no hungry hint;
  - `stingCosts` false: a stinger costs no snap, but the bite still scores ×1 and breaks the chain;
  - `waves` true.
- **The day loops** every `Tuning.zenDayWaves` (28) waves, and `TrapRules.paceWave` keeps the bite rule (and the
  pilot) on the loop's wave, so the late-night ramp never starts.
- **No best:** Zen never fires `newBest` (`TrapRules.keepsBest`).
- **Achievements:** `Achievements.earned` skips `zenSkips` for Zen: chain4, night, score10k and nobees. It never gives
  Daily Diner either. Zen still earns the catching and lifetime achievements.
- The Sprout taper never applies in Zen, and the Daily's options are unchanged.
- **Rank (founder call):** `PlantRanks.growth(from: RunResult)` gives a run's lifetime-bug growth for the rank:
  - every bug in Feed and the Daily;
  - in Zen, `Tuning.zenRankShare` (25 %) of its bugs, rounded down per run;
  - nothing for attract and the lesson.
- Zen bugs count in full for the Bug Book and for any-mode goals.
- **Sim, 600 s:** casual catches 325 bugs and perfect 500. Both still catch 50 or more in the last 2 minutes, with 0 wilts
  and the snaps unchanged.

## #19, late night
- **The last light (Feed and the Daily, founder call: the Daily plays Feed rules).** From wave `Tuning.lastLightWave` (85), the hunger clock ticks whatever is in the
  trap, so a hand that never gives up still ends.
  - `TrapSession.inLastLight` reports it.
- **The telegraph:** `TrapRules.nightCue(wave:mode:)` is a `NightCue`. Call it on each `.waveStarted(index:)`:
  - `.nightGetsFast` at wave 31, the first faster wave, in Feed and the Daily ("The night gets fast…");
  - `.lastLight` at wave 85, in Feed and the Daily ("Last light…").
  - In the last light, "Hungry… bite!" also shows with an empty trap. The App may want to word that hint as "Last
    light…" while `inLastLight` is true.

## #15, the halo
- The `.hungry` hint is suppressed while a protected bug sits or hovers low just outside the zone with its halo reaching
  in. The halo is `Tuning.haloScale` 1.6 × r + `haloPad` 4, as `TrapArt` draws it, and the test is
  `TrapRules.haloTouchesTrap`.
- Bees inside the zone keep R5's rule.
- The clock itself is unchanged.

## #13
- The Core part (the score10k "protein" detail) was already fixed in c2c5444.
- Picking the lesson text on the first hinge sample is App-side.

## Balance (16 seeds, 60 Hz, 600 s cap; `node tools/balance-sim.js`). Every target passes.

| run | seconds | wilts | R5 |
|---|---|---|---|
| casual | 141 | 0 | same |
| expert | 327 | 3 | 335 s, 2 |
| perfect | 354 | 4 (target ≤ 5) | 393 s, 2 |
| expert without pilotGiveUp | 427, 0 capped | 11 | 600 s, 14 of 16 capped |
| perfect without pilotGiveUp | 432, 0 capped | 10 | 600 s, 14 of 16 capped |
| novice Sprout runs 1 / 2 / 3 | 101 / 100 / 90 | 0 | same |

- Scores are unchanged: 230 / 4,875 / 25,210 / 42,133.
- **CI's 8 seeds:**
  - expert 327 s with 3 wilts;
  - perfect 350 s with 4 wilts;
  - without pilotGiveUp, 425 s and 446 s.
- **64 seeds:** perfect 3.5 wilts. Without pilotGiveUp every run ends under 550 s.
- **Windows:** 1 of 10 fails, on the casual chain at 6.5. That is the same noise as R5.
- Other checks: crease, crowd, detector and attract all pass, unchanged.
- **Why 85 and not 80:** at 80, perfect wilts reach 4.5 against the target of 5.
- **New targets:**
  - expert ≤ 360 s (median);
  - no run without pilotGiveUp capped;
  - Zen never tires, never wilts, keeps its snaps and still catches late.

## Tests
- **BalanceTests:** `expertRunLength`, `patientRunsEnd(skill:)` (skipped with `SNAP_BAL_NOGIVEUP=0`), and
  `zenBogNeverEnds(skill:)` (casual and perfect, 2 seeds × 600 s, printing `SNAP-BAL zen …`).
- **CoreTests:**
  - Zen: options, free stings, no newBest, the looping day, no score feats.
  - The late night: the night cues, the last light (Feed and the Daily), Zen rank growth, the halo rule (pure, plus 12 seeds of real waves).
  - Goals: the pool's shape per rank, scopes, the tracker on events, progress carried between runs, the deterministic
    draw and repair, Codable, complete / replace / reward / bonus, the variety goals, and events agreeing with the
    RunResult on a real run.
  - Varieties.

## For others
- **App:**
  - Persist `GoalBookState`.
  - Rank growth per run is `PlantRanks.growth(from: result)` plus `up.growth`. Keep the Bug Book on the full
    `caughtBySpecies`.
  - Toast on `ingest`'s return value.
  - Call `complete` on Results and on an abandoned run.
  - Show a banner on `nightCue`.
- **Decided:** Zen counts at 25 % for rank (above).
- **Scene:** nothing new. `Tuning.haloScale` and `haloPad` mirror `TrapArt.protectedRingScale` and the 4 pt pad. Keep
  them equal if the ring changes.
