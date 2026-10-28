# Core R4 hand-off (Core engineer, 28 Oct 2026)

Unverified until CI compiles it (no Swift compiler here). Two full read-through passes for compile errors were done.
`tools/balance-sim.js` stays a line-by-line port: all 181 shared constants (`T` and `D` against `Tuning`) were
re-checked equal by script, and the new CoreTests were mirrored on the sim first (all pass there). Every change is
marked "R4" in the code.

## What changed
- **Hunger (QA-2 #1, REVIEW-3 #12, founder call).**
  - The clock ticks only while **at least one catchable bug has landed in the trap and no protected bug has**
    (`TrapSession.hungerTicks()`: `landed && inTrap`, so leaving, escaping, released and caught bugs don't count).
    An empty, bee-only or bee-plus-flies trap never gets hungrier.
  - A pause keeps the level. Only a catch resets it, as before. After a wilt it goes on while food sits there.
  - `hungerRunning` is gone. The R3 rule ("from the first landing") is replaced, not layered.
  - "In the trap" for a bee means *landed*, the same as the `beeInside` hint. A bee still flying in doesn't pause the
    clock. I tried "in the bite" (arriving low counts too): at deep night bees are nearly always arriving, so a
    patient perfect hand never wilted and never had to bite, and 2 of 64 runs never ended.
  - Night wilt **14 s** (18/16/14/14).
  - The `.hungry` hint shows only while the clock ticks (`hungrySent && hungerLive`). The `hungry` event still fires
    once per cycle.
- **First run (REVIEW-3 #11, QA-2 #11).** New field **`SessionOptions.firstRun`** (default false).
  - The run starts with `Tuning.firstRunSnaps` (**14**), whatever `startSnaps` says. It never wilts, and its first
    stinger bite is free (as `freeFirstSting`, so the `stung(cost: 0)` toast still works).
  - **Feed only:** `SessionOptions.firstRunApplies(to:)` is false for the Daily, attract and the lesson, and
    `TrapSession.firstRunPerks` exposes the result. This is the rules side of the Daily-first case: a Daily session
    given `firstRun` plays standard. The App decides "first Feed run" on a Feed-only count (it already does:
    `feedRuns`).
  - **A calm first morning (my addition; flag for the founder).** 14 snaps alone gave the novice pilot 67 s, not 90:
    a hand that bites every landing spends about a snap per wave, and the refunds never come. So, in a first run
    only, waves 1–14 are crowds (`WaveFactory.wave(…, calm:)`; the crowd chance is still drawn, so the draw order
    and waves 15+ are unchanged) and the gap after each is × 1.6 (`firstRunCalmWaves` 14, `firstRunWaveGap` 1.6).
    It is invisible: no copy, no UI. To remove it, set `firstRunCalmWaves` to 0, and the novice is back at 67 s.
- **The crease (REVIEW-3 #14).** Nothing walks, rests or hovers low within ±(20 + r) of the midrib
  (`Tuning.creaseAirHeight` 0.5: below that height, a bug over the trap must be outside the band).
  - Ground moves keep to the bug's own lobe: wanders, hops, darts, the hover's landing re-check, and nectar dashes
    (only drops on the same side).
  - `findSpot` and `clampIn` take a `side`: a point across the line is mirrored back, and
    `TrapRules.offCrease(…, side:)` pushes it out on that side.
  - A walker (ant) walks in on its spot's side: its entry x is mirrored or pushed out.
  - Only approaches (height ≥ 0.5), crossers (0.85), take-offs and the caught slide ever pass over the crease, which
    covers the Home attract session too.
  - Sim `crease=1`: 6,089 low frames in 8 seeds before, 0 now in 16 (123,229 frames over the band). The resting
    check is still 0.
  - The badges (`AchievementArt`) are App/UI's.
- **Two re-tunes the R4 rules forced.** Flag both to the founder: the first departs from ROUND-4's §6 listing.
  - **`lateReactionFloor` 0.2 (was 0.25).** At 0.25 a sipping housefly reacts in 0.24 × 1.35 × 0.25 = 81 ms, so an
    80 ms hand was never outrun. R3 runs ended on wilts; with gated hunger, 3 of 64 perfect runs hit the 10-minute
    cap. At 0.2 every night bug but the scarab outruns 80 ms by about wave 70. Decay 0.96, lingers 0.92 / 0.2 and a
    bee every 40 are as listed.
  - **The pilot gives up waiting (`Tuning.pilotGiveUp` 12 s).** After 12 s without a snap, expert and perfect bite
    any landed bug even when they judge it too quick. Before, the expert stopped biting at about wave 50 and sat for
    7 minutes, because a fed trap no longer wilts it out (16 of 16 capped). This changes the pilot (the player
    model), not the game.
- **GAME-DESIGN §5–§6** now match Tuning: hunger, first runs, the run-length line, the late night (0.96 / 0.2,
  0.92 / 0.2, a bee every 40), the crease, and the grasshopper "hops about its lobe".

## Balance (16 seeds 1000 + 7919·i, 60 Hz, 600 s cap; `node tools/balance-sim.js`)

| skill | score | seconds | snaps | caught | stings (max) | feasts | longest chain | wilts |
|---|---|---|---|---|---|---|---|---|
| novice | 191 | 45 | 10 | 12 | 1 (3) | 1 | 2 | 0 |
| casual | 5,206 | 147 | 24.5 | 70.5 | 2.5 (6) | 11 | 5 | 0 |
| expert | 28,763 | 326 | 43 | 125 | 0 (1) | 26 | 29.5 | 3 |
| perfect | 42,761 | 377 (6.3 min) | 43 | 147 | 0 (0) | 26 | 28.5 | 3 |
| novice, Sprout run 1 | 698 | 105 (p10 82) | 18.5 | 22 | 2 | 3.5 | 2 | 0 |
| casual, Sprout run 1 | 5,187 | 165 (p10 139) | 29 | 67 | 4 | 10.5 | 6 | 0 |

- **Every check passes:**
  - casual 100–240 s, 18–45 snaps, longest chain 3–6, wilts ≤ 2;
  - expert wilts ≤ 6 (R3: 11.5);
  - perfect 240–480 s, wilts ≤ 5;
  - novice and casual Sprout run 1 ≥ 90 s, never wilting;
  - novice < casual < expert ≤ perfect;
  - perfect never stung;
  - novice stung;
  - no skill capped.
- **CI's 8 seeds:** casual 128 s, chain 5, 0 wilts; expert 3 wilts; perfect 366 s, 2 wilts; novice Sprout run 1
  101 s. All pass.
- **Robustness:** `windows=10` 0/10 failing. 64-seed medians: casual 129 s, perfect 367 s, 2 wilts, none capped;
  novice Sprout run 1 96.5 s.
- **Other sim checks:** `crowd=1` worst landing spread 0.94 s; `detector=1` all pass; `attract=1` never stalls.
- **Risks (libm drift):**
  - The novice Sprout run 1 margin is 105 vs 90 (16 seeds) and 101 (8 seeds).
  - The casual chain is 5 vs 6, and on the 8-seed windows one in 20 shows chain 6.5.
  - If CI's novice Sprout run lands under 90, raise `firstRunWaveGap` to 1.8.

## BalanceTests
- Every run (4 skills plus the novice and casual Sprout run 1) is simulated once, in parallel
  (`DispatchQueue.concurrentPerform`), the first time any balance test asks.
- The whole table is printed then as **one block**, from `SNAP-BAL ==== table …` to `SNAP-BAL ==== end ====`, so it
  sits at the start of the balance section of the CI log and the summary's grep keeps it in order.
- Lines now carry `p10s` (the 10th-percentile seconds).
- New tests: `expertWiltsAtMostSixTimes` and `sproutRunOneLasts(skill:)` (novice and casual). `perfectRunLength` now
  checks ≤ 5 wilts.

## CoreTests (new or changed)
- Changed:
  - the tuning test (night 14, floor 0.2, the first-run and crease numbers);
  - `onlyACatchFeedsTheTrapAndAnEmptyTrapPausesTheClock` (replaces `…StopsTheClock`: an empty trap after a miss
    holds the level, and a landing carries on from it).
- New:
  - `aBeeInTheTrapPausesTheClock` (including the QA-2 #1 fly-leaves-the-bee-stays case);
  - `theHungryHintShowsOnlyWhileTheClockTicks`;
  - `firstRunGivesTheSproutPerksInFeedOnly` (14 snaps over `startSnaps`, no wilt, the free sting, the Daily
    standard);
  - `aFirstRunHasACalmMorning` (gaps × 1.6 for waves 1–14, crowds, waves 15+ identical);
  - `nothingWalksOrHoversLowOverTheCrease` (feed casual and perfect plus attract, real waves);
  - `groundMovesKeepToTheirLobe` (an ant sent across, a grasshopper, a wanderer).

## For others
- **App:**
  - Pass `options.firstRun = true` for the first Feed run. `GameController.applyFirstRun` already does, and its R3
    switches (`hunger = false`, `freeFirstSting`, `startSnaps = 14`) are harmless alongside it.
  - Key the hunger HUD on `snapshot.hint == .hungry`, not on the `hungry` event (QA-2 #10): the hint now drops while
    the clock is paused, and the event isn't re-sent when it resumes. `snapshot.hunger` holds its level while paused.
- **Scene:** nothing new to draw. The caught slide still runs to the seam, and only flyers cross the crease now.
- **CI:** the table block is printed once per test run, from whichever balance test runs first.
