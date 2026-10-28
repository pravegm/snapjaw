# Core + Input + CI hinge checks, R8: the lid is the jaw, harder, and 30 levels

Brief: `design/ROUND-8.md` §1, §2, §4 (the Core + Input + CI owner) and the founder's binding hinge rules (they override
§1's numbers). **Not compiled locally**: CI compiles. The sim (`tools/balance-sim.js`) was run with `node` for every
number below.

## Final API, numbers and log lines (read these first)

### The hinge rule (founder rules: these numbers override ROUND-8 §1)
| | |
|---|---|
| armed (open) | θ ≥ `Tuning.armAngle` = **35°** (a 90° phone is OPEN) |
| the shut zone (the bite) | θ ≤ `Tuning.shutAngle` = **18°**, or `.closed` status with θ ≤ `Tuning.statusShutAngle` = **25°** (hardware reads `.closed` from ~85°, so the status alone is never trusted) |
| re-arm | θ ≥ 35° (hysteresis 18 / 35) |
| a close | starts at closure ≥ `Tuning.closeStart` 8°; over at closure < `closeCancel` 4° or when the phone opens `reopenCancel` 10° above the close's lowest θ |
| bite duration | the close time: close start → the shut (interpolated); `untimedCloseDuration` 2.0 s for a shut with no close start seen (a creep) |
| open reference | max θ over 0.6 s, falling ≤ 25 °/s, **held while a close is under way**; closure = reference − θ (continuous, up to ~145°) |
| slow close | `TrapInput.creeping` = a close under way > `slowCloseAfter` 0.6 s (the "quick" hint) |
| a round starts closed | `HingeTrapSource.startRound(at:)` / `SnapDetector(requireShut: true)`: not armed until the phone is shut once and opened to 35° |
| no pose demands | `TrapInput.tooFlat` is always false; Core never hints `.bendALittle` |
| touch | a tap is an **instant** bite, `duration = Tuning.touchSnapTime` 0.12 s; re-arm after `touchRearmDelay` 0.45 s; a touch round never waits |

### Contract (`Snap/Shared/Contracts.swift`, all additive)
- `enum TrapHingeStatus { closed, partiallyOpen, fullyOpen, unknown }` (new).
- `TrapSnapshot.shut: Bool` (default false): true from the bite until the input is armed again; the clock is frozen.
- `TrapSnapshot.waitingForClose: Bool` (default false): true from the session's start until the input is first armed
  (hinge: shut once, then open; touch/pilot: at once). Clock frozen, nothing spawns. App shows "Close the phone to
  start".
- `BiteReport.catchRatio: Double` (init param, default 0): caught ÷ the catchable bugs in the trap during the close
  (from its start to the shut, the ones that fled included); 0 when there were none.
- `RunResult.escapes: Int?` (init param, default nil): bugs that escaped a bite or fled a close.
- `RunMode.level(Int)` (new case).
- Docs only: `SnapTrigger.duration` = the close time; `TrapInput.closure/armed/creeping`, `BugInfo.reaction/nerve`
  (nerve = the startle depth, reaction = the flee time), `TrapEvent.bugSpooked` (fled a close), `.snapStarted` (a close
  started), `.snapped` (at the shut), `.rearmed` (reopened).

### Core
- `SnapDetector(requireShut: Bool = false)`, `ingest(angle:at:status:)` (status defaults `.unknown`), `input(at:)`,
  `armed`, `closing`, `waitingForShut`, `reference`, `static isShut(angle:status:)`, `static crossing(...)` (was
  private). Removed: `creepReference`, `creepDepth`, `latestAngle`.
- `TrapRules.modelExposure(nerve:duration:)`: duration × (1 − (nerve − 8) / `modelCloseSpan` 124). The bite catches a
  catchable bug when max(real time since it startled in this close, modelled exposure) ≤ its reaction.
- `TrapRules.lateFactor(wave:)`: × `morningReactionFactor` 1.3 before noon (the sleepy morning).
- `TrapSession`: bug fear (each step: a close starts at 8°; a bug startles when the closure passes its nerve and flees
  after its reaction, `bugSpooked` + escape); the frozen clock while shut / waiting (only caught, escaping, released
  and leaving bugs move); `levelSpec`, `levelEnd: LevelEnd?`. The R1–R7 creep spook is gone.
- `SessionOptions.refunds: Bool = true` (false: no Feast/scarab/ladybird snaps); `SessionOptions.for(.level(id))`.
- `TrapPilot`: R8 close model; `minBite: Int`, `targets: [BugSpecies]` (a level's goal). Close times by skill: novice
  0.6–1.1 s, casual 0.35–0.65, expert 0.2–0.35, perfect 0.18; hold shut 0.3–0.6 / 0.2–0.4 / 0.15–0.3 / 0.15; reopen
  0.6–0.8 / 0.5–0.7 / 0.4–0.6 / 0.4. Novice now waits for 2 landed (or 1 after `novicePatience` 6 s).
- `Snap/Core/Levels.swift`: `LevelBug`, `LevelGoal` (`catchAny`, `species` + `speciesCount`, `biteOf`, `spare`;
  `met(_:)`), `LevelSpec` (id, world 1–3, title, goalText, goal, noSting, biteLimit, timeLimit, twoStarBites,
  threeStarBites, cleanForThree, paceWave, bugs, `worldName`, `seed`), `LevelOutcome` (stars 0–3, passed, line),
  `LevelEnd` (goal, stung, time, bites, empty), `LevelBook` (`all` (30), `level(_:)`, `levels(inWorld:)`,
  `worldName(_:)`, `worldCount` 3, `worldUnlockStars` 20, `seed(_:)`, `options(_:)`, `session(id:geometry:)`,
  `spawnSpec(_:geometry:nectar:)`, `evaluate(_:_:)`, `totalStars(_:)`, `worldUnlocked(_:best:)`,
  `levelUnlocked(_:best:)`). `Snap/Core/LevelData.swift` is GENERATED from `tools/levels.js` by
  `node tools/levels-gen.js`: never edit it by hand.
- A level session: no waves, hunger or refunds; stings free (a no-sting level fails at once instead); bites = snaps.
  It ends (tired → finished) at the goal, a sting in a no-sting level, the time limit, out of bites, or nothing left to
  catch for `levelIdleEnd` 2.5 s. Stars: pass = 1, ≤ twoStarBites = 2, ≤ threeStarBites (+ no escapes where
  cleanForThree) = 3.

### Tuning (R8)
`startSnaps` 12 (was 10), `maxSnaps` 14, wilts 18/14/12/12 (was 18/16/14/14), `missBreaksChain` true (any bite with an
escape breaks the chain), `dryBiteCost` 0 (the lever exists; 1 put the novice at 35 s), `morningReactionFactor` 1.3,
`touchSnapTime` 0.12, pilot `pilotIdleAngle` 150 / `pilotShutAngle` 5, `shooDepth` 30 / `shooTime` 0.4 /
`shooHoldMax` 1.6. Species reaction / nerve: housefly 0.50/12, gnat 0.65/16, fruit fly 0.55/12, bluebottle 0.32/10, ant
0.90/45, ladybird 0.55/40, grasshopper 0.40/22, moth 0.50/25, mosquito 0.25/8, dragonfly 0.22/8, firefly 0.45/30,
cricket 0.55/30, scarab 0.70/50, bee 1.0/20, bumblebee 1.0/28, wasp 1.0/14.
Removed: `closingAngle`, `closingDwell`, `snapCancelDepth`, `rearmRise`, `rearmAngle`, `rearmMinRise`, `creepWindow`,
`creepRefFallRate`, `settleWindow`, `attemptWindow`, `pilotOvershoot`, `pilotHold`, `pilotReopen`, `noviceCreep*`,
`casualFumble*`, `shooHold`. Kept as **legacy** (no rule uses them; other modules' visuals did): `snapDepth` 22,
`snapStartDepth` 4, `creepDepth` 6, `creepDwell` 0.45, `tooFlatAngle` 174.

### Input
- `HingeTrapSource`: `ingest(angleDegrees:at:status:)`, `startRound(at:)`, `isShut`, `waitingForShut`, `lastStatus`;
  `staleSnap` 1.5 s (was 0.25: the shut is also when frames stall); a pending bite survives `reset` (not
  `startRound`). Removed: `isClosing`, `closing(at:)`, `creepsVetoed`, the creep guard and the closing gate
  (`FeelClosingGate`, `FeelCreepGuard` deleted from FeelFilters.swift).
- `HingeReader(onSample: (angle, time, TrapHingeStatus) -> Void, …)`; the old `onUpdate:` init still compiles.
- `TouchTrapSource`: instant bite; `FeelTouchJaw.reopen` 0.3 s.

### Log lines (new, Input, `-snapDemo` only)
`SNAP-T shut d=<s> angle <θ> status <closed|partiallyOpen|fullyOpen|unknown>` (at each bite, beside the kept
`SNAP-T hinge snap d=… angle …`), `SNAP-T reopened angle <θ>` (re-armed after a bite), `SNAP-T round open angle <θ>`
(a started round's first opening). `SNAP-T hinge closure …` and `SNAP-T hinge stale snap dropped age <s>` are kept.
CI also reads the App's `SNAP-T event snapped caught=<n> escaped=<n> …`, `SNAP-T event rearmed`,
`SNAP-T event waveStarted|bugArrived|bugSpooked|bugSipping`, `SNAP-T trap closure …`, `SNAP-T level result …`,
`SNAP-T chomp card …`, `SNAP-T screen levels`, `SNAP-T level intro <id>`.

## App / UI call sites I touched (minimal; the App engineer owns them)
- `Snap/App/GameController.swift`: `hingeSample(angle:time:status:)` gains `status: TrapHingeStatus = .unknown` and
  passes it to `hinge.ingest`; the run start calls `hinge.startRound(at:)` instead of `hinge.reset(at:)` (founder
  rule 3: every hinge round starts closed).
- `Snap/UI/RootView.swift`: `HingeReader(onSample:)` passing the status to `hingeSample`.
- `SnapTests/FeelTests.swift`: the Input tests (the fake hinge, the snap path, the closing gate, the creep guard, touch,
  stale/insane snaps) moved to the new `SnapTests/InputTests.swift`; nothing else in FeelTests changed.
- No App `.level` sites needed me: the App engineer had already added `.level` to every App/UI/Persistence/Feedback
  switch (ProgressStore, GameController, AppRules, R6Bridge, GameCenterManager, DemoMode, FeelSoundBook).
- **For the App owner**: `Tuning.tooFlatAngle` is kept only for `AppRules.isTooFlat` (app-R8.md says it is removed;
  if so it can go). `AppTests` that call removed APIs (`AppRules.mayResume`) are the App owner's.

## Sim results (16 seeds, `node tools/balance-sim.js`; session seconds, the frozen shut excluded; wall in brackets)
| | novice | casual | expert | perfect |
|---|---|---|---|---|
| median run | **71 s** (81) | **145 s** (156) | **283 s** (298), p90 320 | 326 s (335) |
| target | 60–100 | 120–180 | 240–360 | (240–480) |
| catch ratio (day) | 0.28 (0.36) | 0.52 (0.79) | 0.64 (**0.97**) | 0.65 (**0.98**) |
| score | 486 | 6,154 | 18,063 | 32,676 |
8 seeds: 71 / 147 / 306 (p90 322) / 327 s. `windows=6 seeds=8`: every window passes the run-length checks. Sprout
runs 1/2/3 (novice) 115/112/99 s. Without pilotGiveUp: expert 379 s, perfect 393 s, never capped. Zen unchanged
(never tires; catches late). All 42 sim checks PASS; `detector=1` 9/9; `crowd=1`, `crease=1`, `night=1` pass.
Levels (`levels=1`, 8 and 16 pilot seeds): the expert wins every level ≥ half the time, the novice levels 1–5, the
perfect pilot reaches 3 stars on every level, and the expert misses 3 stars (≥ 30 % of tries) on 5 Dusk/Night levels.

## CI (`ci/duo.sh`, `ci/duo-scenarios.txt`)
- Hinge checks: **BITE** (150 → 5 in 0.3 s, snapped caught ≥ 1), **COVER** (the cover panel shot while shut is lit),
  **REOPEN** (rearmed after the reopen, no waveStarted/bugArrived between the bite and the re-arm over a ~15 s shut),
  **SLOW-CLOSE** (a fresh launch, the same seed, 150 → 5 over 2.5 s: fewer caught than BITE or escaped ≥ 1),
  **NO-BITE-DEEP** (150 → 60 → 150: no snapped). Every hinge launch starts with `round_open` (shut, open: ROUND INFO).
  The rig hardening (fresh Duos, whole-check retries, SIMULATOR/HINGE-TOOL FAIL, INCONCLUSIVE on a dead rig) is kept.
- Gone: SNAP, CREEP, CREEP-FAST, REARM, CLOSE-PAUSE, NO-PAUSE-95, the lesson launches, LESSON-HINGE.
- UI pass: the level map, a level intro, a level's results, **"Close the phone to start"** (+ ROUND-OPEN), a flat Duo
  playing, the **outer-display CHOMP card** (`screen=chomp`, the Duo shut). Frames pass: round_open first, the bite's
  shut shot on the cover panel (`duo-03-bite-shut`), SHUT-FRAMES INFO.
- `duo-scenarios.txt`: lesson frames 14/15/22/23 removed; 26 close-to-start, 27 CHOMP card (cover), 28 level map,
  29 level intro, 30 level results, 31 the sting CHOMP card; captions of 04/17/18/20 updated.

## Unsure / for review
- `DeviceHinge.Status` equality (`hinge.status == .closed`) is from Apple's docs and Squish's research (a struct,
  Equatable as in Apple's sample); not compiled here.
- The Swift sim is not bit-identical: BalanceTests' level checks are "winnable" (≥ 1 of 8), not the sim's ≥ 4 of 8.
- The level table is a first cut tuned on pilots; the founder's hands should re-tune star thresholds.
- The CI checks assume attract play waits for a close (the App calls `startRound`) and that a scene frame or the App's
  `stepFromHinge` steps the bite at the shut; REOPEN's frozen-clock proxy is "no spawns while shut".
- Bees "mixed into crowds from wave 3": already the case (a crowd's bee aims at the next-nearest nectar drop); not
  changed. "A dry bite costs more": the lever exists but is 0 (see Tuning).
