# Core R5 hand-off (Core engineer, 28 Oct 2026)

This is unverified until CI compiles it, because there is no Swift compiler on this host. I did two full read-throughs
for compile errors: Swift 5, exhaustive switches, no mutating or rethrowing key-path calls inside `#expect`, no
ambiguous `.nan`, and no locals shadowing properties or test helpers (`run`, `snap`, `report`).

`tools/balance-sim.js` stays a line-by-line port. All 187 shared constants (`T` and `D` against `Tuning`) were
re-checked equal by script. The new CoreTests were mirrored on the sim first, and they all pass there. Every change is
marked "R5" in the code.

## What changed
- **#5, hungry vs bee (founder call).** A protected bug counts as "in the trap" for the hunger clock from its final
  approach. That means it is inside the zone and either landed or lower than `Tuning.creaseAirHeight` (0.5).
  - In practice this is its hover down (0.5 → 0, 0.3–0.6 s), when the halo is drawn.
  - An approach never flies below 0.5, so higher arrivals don't pause the clock, including the deep night's
    always-arriving bees.
  - The rule is in `TrapSession.protectedCountsAsIn(landed:height:)`, which is pure and tested.
  - `.hungry` was already keyed on the live clock, so the hungry hint now drops as a bee starts its hover.
  - On its own this rule moves expert from 3 wilts to 2 and perfect from 3 to 2, with no cap.
- **#8, the Sprout taper (founder call).**
  - Run 1: 14 snaps, no wilt, a free first sting, the calm morning.
  - Run 2: 13 snaps, a free first sting, the calm morning. It wilts.
  - Run 3: 12 snaps and the calm morning.
  - Run 4 on: standard.
  - New `struct SproutPerks` (`run`, `startSnaps`, `noWilt`, `freeSting`, `calmMorning`), with
    `SproutPerks.forFeedRun(_:)`, which returns nil outside 1…3.
  - New `Tuning` values: `sproutRun2Snaps` 13, `sproutRun3Snaps` 12, `sproutTaperRuns` 3. Run 1 keeps
    `firstRunSnaps` 14, and the calm morning keeps `firstRunCalmWaves` 14 and `firstRunWaveGap` 1.6.
  - **`SessionOptions.sproutRun: Int`** (0 = none) and **`SessionOptions.sprout(feedRun:)`**. `feedRun` is 1-based,
    so pass finished Feed runs + 1.
  - `firstRun` is now a computed property, `sproutRun == 1`. Setting it to true sets run 1, so R4 callers and tests
    are unchanged.
  - Feed only: `sproutPerks(for:)` and `TrapSession.sproutPerks` are nil for the Daily, attract and the lesson.
  - The taper's snaps override `startSnaps`, as R4's did. `firstRunPerks` still means run 1.
- **#15, the thumb band.** No bee, bumblebee or wasp entry starts in the outer 90 pt at mid-height on either side.
  - "Mid-height" is strictly between 25 % and 75 % of the scene height. The values are `Tuning.thumbBandWidth`,
    `thumbBandLow` and `thumbBandHigh`.
  - `WaveFactory.thumbSafeEntry` mirrors such a y across the band's nearer edge, so the entry keeps its side and its
    spread. It makes no draws, so the draw order is unchanged.
  - It covers landing bees, bees sitting on the bog and crossing bees. Other bugs are unchanged.
  - Sim: 48 seeds × 60 waves give 1,643 protected entries, 1,041 of them from the sides, and none in the band.
- **`pilotGiveUp` in SNAP-BAL (REVIEW-4 P2).**
  - New `TrapPilot.givesUp` (default true) switches the rule off.
  - BalanceTests also runs expert and perfect without it. These runs are reported only, never asserted, as
    `SNAP-BAL nogiveup …`, with the "with" wilts and cap counts beside them.
  - `SNAP_BAL_NOGIVEUP=0` (CI: `TEST_RUNNER_SNAP_BAL_NOGIVEUP`) skips them. They are mostly 600 s capped runs, so they
    add about 16 long runs at 8 seeds.

## Balance (16 seeds 1000 + 7919·i, 60 Hz, 600 s cap; `node tools/balance-sim.js`)

| run | seconds | snaps | wilts | target | verdict |
|---|---|---|---|---|---|
| novice (standard) | 48 | 10.5 | 0 | — | — |
| casual | 141 | 24 | 0 | 100–240 s, ≤ 2 wilts, chain 3–6 (5) | ✔ |
| expert | 335 | 43 | 2 | ≤ 6 wilts | ✔ |
| perfect | 393 | 43 | 2 | 240–480 s, ≤ 5 wilts, never stung | ✔ |
| novice, Sprout run 1 | 101 (p10 89) | 18 | 0 | ≥ 90 s, never wilts | ✔ |
| casual, Sprout run 1 | 166 | 28 | 0 | ≥ 90 s, never wilts | ✔ |
| **novice, Sprout run 2** | **100 (p10 84)** | 17 | 0 | **≥ 75 s** | ✔ |
| **novice, Sprout run 3** | **90 (p10 75)** | 15 | 0 | **≥ 60 s** | ✔ |
| expert without `pilotGiveUp` | 600 (14 of 16 capped) | 34 | 8 | report only | — |
| perfect without `pilotGiveUp` | 600 (14 of 16 capped) | 36.5 | 5 | report only | — |

- Without the taper, the novice's run 2 (12 snaps, standard rules) lasts 54 s. That is the cliff REVIEW-4 #8 predicted.
- Scores: novice 230, casual 4,875, expert 25,210, perfect 42,133. The order holds: novice < casual < expert ≤ perfect.
- Every R4 target still passes, and no skill reaches the cap.
- **CI's 8 seeds** also pass:
  - casual 128 s, chain 5;
  - expert 2 wilts;
  - perfect 389 s, 2.5 wilts;
  - novice Sprout runs 1 / 2 / 3: 98 / 95 / 85 s.
- **Robustness.** 64-seed medians:
  - casual 128 s;
  - perfect 380 s, 2 wilts;
  - novice Sprout runs 1 / 2 / 3: 104 / 101 / 90 s.
- **Windows.** With `windows=20`, 2 of 20 windows fail a check, against 0 in R4. Both failures are casual chain 6.5,
  just over the 3–6 band. The R4 sim also shows 6.5 in some 8-seed windows. It is noise from #15 re-rolling the bee
  paths, and the 16- and 8-seed medians are 5.
- **Other checks:**
  - `crease=1`: 0 low frames in the band and 0 resting too close;
  - `crowd=1`: worst spread 0.94 s;
  - `detector=1`: 6 / 6;
  - `attract=1`: never stalls.
- **Risk (libm drift).** The novice Sprout run 1 margin is now 101 against 90 (98 on CI's 8 seeds); it was 105 in R4.
  If CI lands under 90, raise `firstRunWaveGap` to 1.8. That also lifts runs 2 and 3.

## BalanceTests
- New rows `SNAP-BAL sprout2` and `sprout3` (novice). They are built as the App builds them:
  `SessionOptions.sprout(feedRun:)` plus `startSnaps` 12.
- New test `sproutTaperRunLasts(run:)`: run 2 ≥ 75 s and run 3 ≥ 60 s (median), and neither reaches the cap.
- New rows `SNAP-BAL nogiveup expert / perfect`, reported only.
- `sproutRunOne` is now `sproutRun(1)`.

## CoreTests (new or changed)
- Changed: the tuning test checks the taper and thumb-band numbers.
- New:
  - `aBeeOnItsFinalApproachPausesTheClock`: high in the zone the clock ticks and the hungry hint stays; below 0.5 it is
    paused with no hungry hint; once landed it shows `.beeInside`.
  - `theSproutPerksTaperOverThreeFeedRuns`: the perks, `sprout(feedRun:)` and `firstRun` round trips; for runs 1–4,
    start snaps 14 / 13 / 12 / 12, a free bee in runs 1–2, wilting in runs 2+, and the Daily ignoring the taper.
  - `sproutRunsOneToThreeHaveTheCalmMorning`: the gaps are × 1.6 in runs 1–3 and standard in run 4.
  - `beeEntriesNeverStartUnderAThumb`: the pure rule, plus 48 seeds × 60 real waves.

## For others
- **App (wiring the taper):**
  - Build Feed options with `SessionOptions.sprout(feedRun: store.data.feedRuns + 1)`, or set
    `options.sproutRun = feedRuns + 1`. Use a Feed-only count, as now.
  - Keep R4's run-1 switches (`hunger = false`, `freeFirstSting = true`) for run 1 only. Setting `hunger = false` or
    `freeFirstSting = true` on run 2 or 3 would undo the taper.
  - The lesson's row can show `SproutPerks.forFeedRun(n)?.startSnaps ?? startSnaps`.
  - Results' "First run!" is still `firstRunPerks` / run 1.
  - Whether runs 2–3 also need the Sprout rank is the App's call: Core applies whatever `sproutRun` it is given.
- **Scene:** the halo already shows below `creaseAirHeight`, so nothing new is needed. The hunger clock now agrees with
  it.
- **Founder:** the calm morning now runs through Sprout run 3. It is still invisible: no copy and no UI. GAME-DESIGN §5
  should list the taper. I left it alone because it is outside Core's folders.
