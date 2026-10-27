# Core R1 hand-off (Core engineer, 27 Oct 2026)

Unverified until CI compiles it (no Swift compiler here). Two full read-through passes for compile errors were done.
`tools/balance-sim.js` is a line-by-line port. Every shared constant was checked equal by script (152 values).

## Files
- `Snap/Core/`:
  - `SeededRandom.swift`: SplitMix64, plus `between(a, b)` (the same draw as `range`, but a reversed range can't trap).
  - `Tuning.swift`: every number.
  - `BugCatalog.swift`: 16 `BugInfo` with jokes, and `BugCatalog.motion(_:)` → `BugMotion` (style, speeds, wobble,
    nectar chance, linger factor, pauses). `TrapRules` holds `reaction`, `lateFactor`, `chainMultiplier`,
    `isCandidate` and `isFlying`.
  - `SnapDetector.swift`, `WaveFactory.swift` (with `WaveSpec`, `SpawnSpec`), `TrapSession.swift` (with
    `SessionOptions`), `TrapPilot.swift`, `DailySeed.swift`.
  - `Progression.swift`: `PlantRanks`, `Achievements`, `AchievementDef`.
- `SnapTests/CoreTests.swift` (45 tests), `SnapTests/BalanceTests.swift`.
- `tools/balance-sim.js`:
  - `node tools/balance-sim.js` runs the balance table and checks.
  - Options: `windows=8`, `attract=1`, `verbose=1`, `detector=1` (the detector checks), and `T.<name>=<v>` overrides.

## Additive API (beyond ARCHITECTURE; please don't rename)
- `SessionOptions.firstWave` (var, default 1): demo `wave=`. The day, the nectar block and the waves start there.
- On `TrapSession`:
  - `partialResult()`: a run left early (answers the App's NEEDS item). Once the run is finished it equals `result`.
  - `telemetry`: a ready-made `TrapTelemetry`. The App builds its own, which is fine.
  - `dayClock`, `geometry`, `options`.
- On `SnapDetector`: `creepReference`, `creepDepth`, `latestAngle`.
- `WaveFactory.delay(seed:index:)`, `waveSeed`, `nectarSeed(seed:block:)`, `lingerRange(phase:index:)`.
- `DailySeed.utcCalendar`. `Achievements.chainForMaxMultiplier` (= 7).

## Founder changes applied
1. **Creep reference.**
   - The 0.6 s rest reference (25 °/s fall) drives `closure` and the snap, as specified.
   - `creepRef` is the max θ over the last 3.0 s, falling at most 6 °/s (`creepWindow`, `creepRefFallRate`), and is
     reset on re-arm.
   - `creeping` = armed, and `creepRef − θ` > 6° for more than 0.45 s. While creeping, `closure` = max(closure,
     creep depth).
   - Tests: 160→128 over 3 s creeps at 1.03 s, ends at closure 32 and never snaps. Resting jitter of ±1.5° never
     creeps.
2. **Achievements** match `docs/appstore/achievements.md` exactly: ids, titles, pre-earned details, order and
   triggers. Every trigger is computable, so there are no substitutions. Chain4 uses `longestChain >= 7`, because the
   7th clean bite in a row is the first one scored ×4 in this Core.
3. **DailySeed** uses a Gregorian UTC calendar by default (`TimeZone(secondsFromGMT: 0)`). It is tested with explicit
   UTC epochs.

## Detector details (beyond GAME-DESIGN §3)
- The 4° and 22° crossing times are interpolated between samples. A 25° close in 0.12 s at 30 Hz fires on the
  crossing sample with d ≈ 0.09 s.
- An attempt is abandoned when c falls below 2° (`snapCancelDepth`).
- **Re-arm.**
  - At θ ≥ 150°, re-arm also needs θ to have risen at least 4° (`rearmMinRise`). Without that, a snap from a 172°
    rest would re-arm on the very sample it fired.
  - On re-arm both references restart at θ, so no stale reference can fire an instant second snap. The drawn
    closure therefore drops to 0 at the re-arm (the Scene may ease it).
- While unarmed, the closure is measured from the reference at the snap, so the jaws stay shut until the player
  opens up.
- A creep followed by a quick close counts its d from the creep's 4° crossing, so it is a slow snap. That is fair,
  because the creep has already spooked the bugs.

## Movement (how bugs read)
- **Flying in.**
  - Bugs fly in on a quadratic arc with a random bend (±25 %) that slows as it lands.
  - Height falls 1 → 0.5, with a sideways wobble that fades out.
  - They then hover 0.3–0.6 s (height 0.5 → 0, a 6 pt circling drift) and land.
  - They become catchable while arriving (height < 0.6) only in about the last third of the flight.
- **Flight speeds (pt/s).**
  - Fast: bluebottle 300, dragonfly 320, mosquito 260, wasp 250, housefly 230, grasshopper 220.
  - Middle: bee 200, cricket 200, fruit fly 190.
  - Slow: gnat 170, ladybird 170, scarab 170, moth 160, firefly 160, bumblebee 160.
  - Ants walk at 42 pt/s.
- **Styles.**
  - **fly:** sips at its drop, or walks in short dashes (0.15 s or more) and pauses (by species, 0.2–1.5 s) around
    its spot, and claims a drop that frees up within 260 pt.
  - **swarm (gnats):** 4–5 land around one spot 0.08 s apart.
  - **walker (ants):** a line of 3–5, 0.6 s apart, walking in from the bottom edge on the same path. They walk out
    again and stay catchable all the while.
  - **hopper:** hops of 120–300 pt lasting 0.5–1.2 s (arc height 0.8), and may cross the fold.
  - **darter (dragonfly):** darts 80–180 pt in 0.25 s at height 0.3. Between darts it hovers (flying factor:
    effectively uncatchable) or perches (0.12 s: a sharp snap).
  - **flutter (moth, firefly):** wobble amplitude 34 / 20 pt. Moths target the fold (±80 × ±180 pt).
- **Spacing and nectar.**
  - Landed bugs keep radius + radius + 4 pt apart, checked at spawn and again just before landing.
  - One bug per drop, reserved at spawn.
  - Nectar is re-seeded every 6 waves. A drop with a sipper stays until its sipper leaves (ids are unique), so
    `snapshot.nectar` can briefly hold more than 7 drops.
- **Leaving.** Bugs leave toward the nearest edge, taking off over 0.4 s. Escaped bugs go at 1.8× speed, released
  bees at 1.3×.
- **Restless** rises over the last 25 % of the linger, and is 1 when a bug is spooked.
- **Passers.** 12 % of single flyers (bees 15 %) are passers. They either cross high (height 0.85, never catchable,
  `landsInTrap` false) or sit on the bog in a corner.

## For other modules
- **Lesson.** Use `TrapSession(mode: .lesson, …, options: .for(.lesson))`. To have a bug sip, call
  `spawnScripted(.housefly, entry: <a point just off the near edge>, target: snapshot.nectar[k].position,
  linger: .infinity)`.
  - A target exactly on a free drop's position makes the bug sip there. Any other target makes it land and walk.
  - It lands in about 1.5–2.5 s, or 4–5 s from the far edge.
  - `linger: 3` gives the bee that leaves after 3 s.
  - `bugArrived` for a scripted spawn comes out of the next `step`.
- **Event names.**
  - `bugLeft` fires when a bug whose linger ran out leaves the screen, and for crossers. It does not fire for spooked,
    escaped or released bugs.
  - `beeSpared` fires at take-off for a protected bug that landed in the trap, including spooked ones.
  - `snapStarted` fires when the closure passes 4° while armed, so a creep fires it too.
  - `rearmed` fires when `input.armed` goes from false to true.
  - `newBest` fires only when `best > 0`.
- **Attract** (`snapsRunOut` false) keeps `snapsLeft` at 10 and loops the day every 28 waves (morning → night →
  morning). Its reactions keep tightening, so the pilots still catch most bugs.
- **Hints:** `beeInside` covers a protected bug sitting or walking in the trap. `crowd` needs 3 sippers and no
  protected bug in the trap at all.
- **dayClock** is continuous: 0 at wave 1, 1 at 7, 2 at 15, 3 at 23, and 4 from wave 31 on.

## Deviations from GAME-DESIGN starting values (all in `Tuning`, each marked R1)
- **Wave sizes** are smaller, to stop 10-bug bites:
  - waves 1–3: 1–2;
  - waves 4–6: 2–3;
  - noon: 2–3;
  - dusk: 2–4;
  - night: 2–5.
  - Groups (a gnat swarm of 4–5, an ant line of 3–5, fruit-fly pairs) count in full.
  - There are at most 7 per wave, plus a scarab and the bees.
- **Bees per wave** are chances, not the design's flat counts:
  - morning from wave 3: 0.5;
  - noon: 0.4;
  - dusk: 0.5;
  - night: 0.55, plus 0.15 for a second.
  - After wave 30 there is one more every 8 waves, capped at 4.
  - Bees linger 0.6× (a quick sip).
  - With the design's "1 per wave at dusk" a bee was always present, and careful play froze.
- **Ants and ladybirds come at noon only** ("day bugs go home at dusk"). Slow ant lines made patient play immortal.
- **Night lingers shrink** after wave 30 (× 0.98 per wave, floor 0.5), alongside the design's reaction ramp (× 0.97,
  floor 0.6).

## Balance (8 seeds 1000 + 7919·i, 60 Hz, 600 s cap; `node tools/balance-sim.js`)

| skill | score (median) | seconds | snaps | caught | stings (max) | feasts | waves | chain |
|---|---|---|---|---|---|---|---|---|
| novice | 277 | 46 | 12 | 10.5 | 1 (2) | 1 | 12.5 | 2 |
| casual | 9,129 | 115 | 23 | 67.5 | 3 (6) | 9.5 | 31 | 11 |
| expert | 29,014 | 600 (capped) | 34 | 118.5 | 0 (2) | 23.5 | 161 | 29.5 |
| perfect | 34,871 | 600 (capped) | 28.5 | 135 | 0 (0) | 22 | 161 | 28 |

- **All ROUND-1 asserts pass:**
  - novice < casual < expert ≤ perfect;
  - casual runs 115 s and 23 snaps;
  - perfect is never stung;
  - novice is stung 1 time (median);
  - novice and casual never hit the cap.
- **Robustness:** across 8 other 8-seed windows, 7 of 8 pass. One casual window had a median of 86 s.
- **Store-kit checks:**
  - Casual reaches wave 23 in 7 of 8 runs (Midnight Snack is fine).
  - Well Fed (10k) sits above the casual median (9.1k) and below the expert's.
  - The casual longest chain is about 11, not the 3–5 the store kit hoped for, so Four Times Hungry will come early.
    Either raise it, or accept it as an early-week goal.
- **Risks:**
  - `noviceGetsStung` sits exactly at a median of 1. The per-seed stings are 2,1,0,2,0,1,2,1.
  - libm drift between Swift and JS could move it. If CI fails there, raise `Tuning.noviceBeeMiss`.

## Open design question for the founder: patient play never ends
- A bite of 3 or more is snap-neutral or better (−1 +1). Once the night fills with bees, a pilot that only takes
  clean feasts never loses a snap, so expert and perfect runs reach the 10-minute cap. Their scores are compared at
  the cap.
- A real human would get bored and bite a bee. But the Best Feast leaderboard can in principle be farmed by
  patience.
- `tools/balance-sim.js` has an experiment that is off by default and not in Swift: `T.wiltSeconds=15`, "a snap
  wilts after 15 s without a bite". With it:
  - perfect ends at about 5.8 min and expert at about 5.5 min, which matches the design's "6–8 minutes";
  - novice and casual are unchanged.
- It needs a TrapEvent and a hint to be fair, so it is a contract change. Please decide in R2.
