# Core R3 hand-off (Core engineer, 28 Oct 2026)

Unverified until CI compiles it (no Swift compiler here). Two full read-through passes for compile errors were done.
`tools/balance-sim.js` stays a line-by-line port: all 176 shared constants (`T` and `D` against `Tuning`) were
re-checked equal by script. Every change is marked "R3" in the code.

## What changed
- **No resting on the crease (REVIEW-2 #5).**
  - `TrapRules.creaseGap(radius:)` = `ScreenLayout.creaseHalfWidth` (20) + the bug's radius + `Tuning.creaseClearance`
    (16). Housefly 61.2 pt from the midrib line, bumblebee 75.6.
  - `TrapRules.offCrease` pushes a spot straight out sideways (a point on the line goes right) and pulls y in if that
    leaves `maxR`.
  - The session's `clampIn` (inside `findSpot`) applies it. Every resting spot comes from `findSpot` or is a nectar
    drop: landings, spot-taken fallbacks, wanders, hops, darts, gnat swarm members, moths ("near the fold" still, just
    not on it) and crowd spots.
  - Drops sit ≥ `nectarCreaseClearance` (now 80, was 50) off the line, which clears the biggest sipper (bumblebee).
  - Bugs still cross the midrib in the air or while walking (grasshopper hops, a dash to a drop on the other lobe).
    An ant can end a dash up to its 3 pt wobble off its spot.
  - Checks: `node tools/balance-sim.js crease=1` (459,578 resting frames, 0 too close) and three CoreTests.
- **Hunger (#7).**
  - Wilt times are 18/16/14/12 s.
  - The clock (`hungerRunning`) starts on the first in-trap landing of a **catchable** bug (bees don't count) at the
    run start and after every catching bite.
  - A catch resets it to 0 and stops it. A dry snap, a miss or a bee-only bite does neither.
  - After a wilt it keeps running, because a bug is still about.
  - `snapshot.hunger` stays 0 while the clock waits.
- **Stinger bites (#8).**
  - A bite with any protected bug in it scores **×1**: `BiteReport.chainMultiplier` is 1.
  - It refunds **nothing**: no Feast, scarab or ladybird snaps, `snapsBack` 0, and no `feast` or `luckySnap` events.
  - It doesn't count in `RunResult.feasts`.
  - The sting cost stays, and the chain still breaks.
  - The App's pop "Stung! · +172" can read `lastBite.stingers` and `points`.
- **Sprout run 1 (#9).** The App sets two `SessionOptions` fields:
  - **`hunger = false`** (the existing field): never wilts.
  - **`freeFirstSting = true`** (new, default false): the run's first bite with a stinger costs no extra snap. Its
    `stung` events carry `cost: 0` and `snapsLost` is 0; it still scores ×1, refunds nothing and breaks the chain.
  - Show "Bees cost a snap!" on that `stung(cost: 0)`.
  - Keep passing `startSnaps = 12` while Sprout. `BalanceTests.sproutRunOne` is the exact options set.
- **Nectar clusters (#16).**
  - The ring is 24–30 pt (was 40–48).
  - Over 5,000 seeds, cluster mates are 41.6–60 pt apart, the nearest other drop is ≥ 102.9 pt away, and every drop is
    ≥ 80 pt off the midrib.
  - Crowd waves already go to one anchor cluster (`crowdNear` 60–140 kept: a tighter 40–100 broke the
    1.2 s landing spread).
- **Chain (#22):** the cap is ×5 (`chainMaxMultiplier` 5), reached at step 8.
  - `TrapRules.chainSteps(toReach:)` is new.
  - `Achievements.chainForX4` (7) keeps "Four Times Hungry" at ×4. `chainForMaxMultiplier` is now 9.
- **`maxSnaps` 14 (#23).** `snapshot.snapsMax` is 14, and `startSnaps` is clamped to 1…14.
- **Deterministic pilot (#21).**
  - `TrapPilot` decides on its own clock (the sum of its dts). The `time:` argument only stamps `SnapTrigger.time`, so
    a wall clock can't change a run.
  - New `PilotRun` steps a pilot and a session in fixed `Tuning.pilotStep` (1/60 s) steps, whatever the frame time,
    with at most `pilotMaxStepsPerFrame` (6) per frame and the remainder carried.
  - Use it as `var run = PilotRun(skill:seed:)`, then `run.advance(session, dt:stamp:)` each frame, which returns the
    events; draw from `run.lastInput`.
  - The same seeds give the same run at any frame rate. This is tested against jittery dts and against the plain
    60 Hz loop that BalanceTests and DemoRunner use.
  - GameController still feeds `p.step(dt: step, time: now …)` with variable frame steps. App/CI should switch the
    `.pilot` source to `PilotRun` and freeze on session time or events.

## Re-tuning
Hunger is no longer what ends patient runs. With ≤ 6 wilts, perfect never ended without a ramp, and extra night bees
only turned into wilts (perfect won't bite a bee, so it waits and wilts). The late night ends runs instead:
- `lateReactionDecay` is 0.96 with a floor of 0.25 (was 0.97 / 0.6);
- `lateLingerDecay` is 0.92 with a floor of 0.2 (was 0.98 / 0.5);
- `extraBeeEvery` is 40 (was 8);
- `beeChanceMorning` is 0.35 (was 0.5), because stung bites refund nothing now and casual runs got shorter.

## Balance (16 seeds 1000 + 7919·i, 60 Hz, 600 s cap; `node tools/balance-sim.js`)

| skill | score | seconds | snaps | caught | stings (max) | feasts | longest chain | wilts |
|---|---|---|---|---|---|---|---|---|
| novice | 166 | 44 | 10 | 10 | 1 (3) | 1 | 2 | 0 |
| casual | 4,833 | 134 | 23.5 | 62 | 2 (6) | 10 | 5 | 1.5 |
| expert | 28,763 | 329 | 34 | 124 | 0 (1) | 26 | 29 | 11.5 |
| perfect | 43,378 | 353 (5.9 min) | 43 | 156 | 0 (0) | 27.5 | 28.5 | 5 |
| casual, Sprout run 1 | 5,264 | 154 (p10 102) | 27.5 | 73 | 3 | 12 | 5 | 0 |

- **Every check passes:**
  - casual 100–240 s, 18–45 snaps, longest chain 3–6, wilts ≤ 2;
  - Sprout run 1 ≥ 90 s;
  - perfect 240–480 s, wilts ≤ 6;
  - novice < casual < expert ≤ perfect;
  - perfect never stung;
  - novice stung ≥ 1;
  - no skill capped.
- **Robustness:** `windows=10` and `windows=20` both have 0 windows failing.
- **64-seed medians:** casual 125 s, chain 5, 1 wilt; perfect 342 s, 5 wilts; Sprout run 1 153 s.
- **Other sim checks:** `crowd=1` worst landing spread 1.12 s; `detector=1` all pass; `attract=1` never stalls.
- **`BalanceTests.swift`:**
  - counts `wilted` events (`RunResult` has no wilt count);
  - adds `casualRarelyWilts` and `casualSproutRunOneLasts` (memoised Sprout runs);
  - perfect is now 240–480 s and ≤ 6 wilts.
- **Risks (libm drift between Swift and JS):**
  - The margins are casual wilts 1.5 vs 2, perfect wilts 5 vs 6, and casual chain 5 vs 6.
  - If CI's perfect wilts land at 6.5–7, set `extraBeeEvery` to 60 (sim: perfect 4 wilts, all windows pass).
  - Expert wilts about 11 times per run: the night outruns 0.10–0.15 s hands, and there is no target for it.

## Not done / for others
- **GAME-DESIGN §6 is stale and outside my brief (§5 only):** it still says "reactions × 0.97 per wave (floor 0.6) and
  one more bee every 8 waves". It should say × 0.96 to 0.25, lingers × 0.92 to 0.2, and one more bee every 40 waves.
- **Attract uses the real wave count for the late reaction factor** (unchanged since R1), so after about wave 50 a
  title-screen pilot misses more often. Lingers use the recipe index.
- **App:** `snapshot.snapsMax` is 14 now (`AppModels.snapsMax` already defaults to 14). The "Bees cost a snap!" toast
  keys on the first `stung(cost: 0)` of a run with `freeFirstSting`.
