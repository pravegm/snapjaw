# Core + Input, R9: difficulty proven, levels retuned, the hinge detector hardened for a real Duo

Brief: ROUND-8 §1/§1b/§2/§4 and the R9 Core brief (difficulty proof, level quality, hardware hardening). **Not compiled
locally** (CI compiles); every number below is from `node tools/balance-sim.js`. Nothing committed.

## Changed APIs, Tuning and strings (read these first)

### Tuning (`Snap/Core/Tuning.swift`)
| new | value | what |
|---|---|---|
| `rearmRise` | 15° | after a shut the re-arm also needs θ ≥ lowest θ since that shut + 15° (a full close still re-arms at 35°) |
| `startShutAngle` | 25° | a round waiting for its first close counts θ ≤ 25° as closed, whatever the status |

**No economy number changed.** Endless already met every R8/R9 target (table below), so start snaps, hunger, lingers,
bees, wasps, chain and refunds are as R8 left them. `tooFlatAngle` / `TrapInput.tooFlat`: left in place (App's
`AppRules.isTooFlat` still references them; removal is not contained).

### Core
- `SnapDetector(requireShut:rearmLow:)` (`rearmLow` new, default nil): a restarted detector that carries an
  unarmed-after-a-shut state. New: `rearmLow: Double?` (read-only), `rearmAngle`, `static isStartShut(angle:status:)`,
  `mutating noteFolded(at:) -> SnapTrigger?` (outer display = folded: clears a waiting round; otherwise re-reads the
  latest angle as `.closed`, so it bites only at ≤ 25°).
- `TrapSession`: **a close starts only on a RISING closure** (`c > prevClosure`). The pilot reported its reopen as a
  closure falling from ~115° after the re-arm, which startled bugs landing then; the hinge never does (its reference
  restarts at the re-arm). New `let reactionScale: Double`.
- `TrapRules.reactionScale(mode:)` (BugCatalog.swift): a level's calm, × every catchable bug's reaction; 1 elsewhere.
- `LevelSpec.reactionScale: Double = 1` (new last field; LevelData passes it). Level 1 = 2.5 (no close, however slow,
  loses its fly); quick Dusk species get 1.4–2.3; a few Morning/Night levels 1.1–1.6.
- `TrapPilot.drawFirstClose()`: the first close drawn like the rest (default keeps closeMin: **the App never calls it,
  so CI demo runs are unchanged**). The level table and BalanceTests' level harness call it.
- `LevelBook.evaluate`: "Out of time. Shut it faster" → **"Out of time. Bite sooner"** (App ask).
- All 30 levels retuned (`tools/levels.js` → `node tools/levels-gen.js` → LevelData.swift). Goal texts are now ≤ 24
  characters and input-neutral (no shut/close/tap/lid/phone): L1 "Catch the fly", L2 "Catch 2 flies", L4 "2 flies.
  Spare the bee", L5 "One bite, 3 bugs", L8 "Ladybird + 3 more", L9 "Catch 4. Let the bee go", L11 "Catch the moth,
  quick", L13 "Catch 5. Spare the wasps", L17 "Catch 5. Mind the bees", L20 "9 in 6 bites. No stings", L29/L30 "7 in
  5/6 bites. No stings". (App's asks from app-R9.md all done.)
- Contracts.swift: comment only (`bendALittle` is never sent).

### Input (`HingeTrapSource`)
- `reset(at:keepsRoundStart: Bool = true)`: a reset **keeps a round's closed start** (closing to start moves the app
  to the outer display → scene re-activation → App's reset mid-close; before R9 the fresh detector armed at once and
  the starting close BIT), and keeps a shut trap unarmed until its re-arm angle. `keepsRoundStart: false` = no round.
- `noteFolded(at:)`: see the asks; logs `SNAP-T shut d=<s> angle <θ> status folded` when it bites.

## Sim results

### Endless (16 seeds, session s; wall incl. the frozen shut in brackets)
| | novice | casual | expert | perfect |
|---|---|---|---|---|
| median run | **71 s** (80) | **142 s** (154) | **286 s** (299), p90 315 | 328 s (337) |
| target | 60–100 | 120–180 | 240–360 | — |
| catch ratio all / day | 0.28 / 0.34 | 0.54 / 0.81 | 0.65 / 0.97 | 0.66 / 0.98 |
| waves reached | 19 | 38 | 76 | 87.5 |
Nobody reaches the last light (wave 85) but perfect. The novice catches a **median 5.5 bugs in its first 20 s**, the
slowest tenth its first by **7.1 s** (new sim checks). It dies of mistakes: 6 dry bites, 2 stings, a 0.28 catch ratio.
All 44 sim checks pass (0 FAIL); `windows=6 seeds=8` 0/6 failing; crowd, crease, night, attract, zen pass. The sim mirrors the
Swift close (pilot close times 0.6–1.1 / 0.35–0.65 / 0.2–0.35 / 0.18 s, reopen 0.4–0.8 s with the clock frozen until
armed), fear, exposure and pilot line by line (re-checked this round; the only drift found was the falling-closure
startle, now fixed in both).

**CI seed 7 (feed, pilot=expert, pilot seed 108): bite-for-bite identical to R8** (`trace=1 seed=7 skill=expert`:
4-bug bites at 6.1, 9.5, 13.4 s, …); perfect identical; casual identical to 69 s. The rising-closure rule cannot change
the first ~15 s.

### Levels (`levels=1 levelSeeds=24`; passes / 24 and star spread [0★,1★,2★,3★])
| | novice | casual | expert | perfect |
|---|---|---|---|---|
| 1 First Bite | 24 [0,0,0,24] | 24 [0,0,0,24] | 24 | 24 3★ |
| 2 Fast! | 24 [0,1,23,0] | 24 [0,0,6,18] | 24 3★ | 24 3★ |
| 3 Wait for Two | 18 [6,2,16,0] | 24 [0,0,20,4] | 24 [0,0,3,21] | 24 3★ |
| 4 Bee! | 11 [13,0,5,6] | 21 [3,0,0,21] | 24 3★ | 24 3★ |
| 5 A Crowd | 19 [5,0,19,0] | 24 [0,0,20,4] | 24 3★ | 24 3★ |
| 6 Marching Ants | 24 2★ | 24 2★ | 24 [0,0,15,9] | 24 3★ |
| 7 Gnat Cloud | 19 [5,0,19,0] | 24 [0,0,16,8] | 24 [0,0,1,23] | 24 3★ |
| 8 Lucky Ladybird | 24 2★ | 24 2★ | 24 3★ | 24 3★ |
| 9 Bee in the Crowd | 11 [13,5,6,0] | 21 [3,0,15,6] | 24 3★ | 24 3★ |
| 10 Morning Exam | 5 | 21 [3,0,18,3] | 24 3★ | 24 3★ |
| 11 The Moth | 0 | 21 [3,5,16,0] | 24 [0,0,1,23] | 24 3★ |
| 12 Whine | 0 | 21 [3,0,3,18] | 24 [0,0,16,8] | 24 3★ |
| 13 Wasp Watch | 2 | 21 [3,0,21,0] | 24 [0,0,19,5] | 24 3★ |
| 14 Here Be Dragons | 0 | 17 [7,7,1,9] | 24 3★ | 24 3★ |
| 15 Hoppers | 0 | 23 [1,0,19,4] | 24 3★ | 24 3★ |
| 16 Rush Hour | 0 | 24 [0,3,21,0] | 24 [0,0,7,17] | 24 3★ |
| 17 Busy Bees | 0 | 21 [3,0,21,0] | 24 [0,0,20,4] | 24 3★ |
| 18 Bluebottles | 0 | 22 [2,2,12,8] | 24 [0,0,4,20] | 24 3★ |
| 19 Pure Gold | 12 | 21 [3,0,17,4] | 24 3★ | 24 3★ |
| 20 Dusk Exam | 0 | 2 | 24 [0,0,9,15] | 24 3★ |
| 21 Fireflies | 1 | 24 [0,0,13,11] | 22 | 24 3★ |
| 22 Cricket Song | 1 | 23 [1,0,4,19] | 24 | 24 3★ |
| 23 Night Shift | 0 | 17 [7,0,17,0] | 24 | 24 3★ |
| 24 Moonlit Feast | 0 | 9 | 23 | 24 3★ |
| 25 Midnight Rush | 0 | 7 | 24 [0,0,23,1] | 24 3★ |
| 26–30 | 0 | 0 | 21–24 (3★ mostly; 29: 3/24) | 24 3★ |
| **world 1** | pass 75 % | 96 %, mean 22.9 ★, best of 3 tries 25.1 | 29.2 ★ | 30 |
| **world 2** | 6 % | 80 %, 17.2 ★ (21.4) | 26.8 | 30 |
| **world 3** | 1 % | 33 %, 8.0 ★ (10.5) | 26.6 | 30 |
Targets met (all sim checks PASS): novice passes 1–8 (≥ 3/4 each, the bee lesson L4 46 %: the novice pilot ignores
60 % of bees by design, and CI frame 62 needs a failed L4), struggles from Dusk; casual passes ≥ 70 % on 10/10 Morning
and 9/10 Dusk levels, mostly 2★, 3★ in ≥ half its tries on only 1 of levels 3–10 (L4); Night 33 %; expert 3-stars ≥
half its tries on 24/30, misses sometimes on 16 Dusk/Night levels; perfect 3-stars all. **Unlocks**: casual opens Dusk
after one pass through Morning (22.9 ≥ 20) and Night with retries (best of 3: 46.5 ≥ 40; one pass: 40.1).
CI: L1 by the perfect demo pilot = 3★; L4 by the novice demo pilot fails, stung (frame 62).

How 3 stars take skill (the R9 design rules): every level from 2 is `clean3`; a quick bug sits in the crowd (a sitting
bluebottle flees a close slower than ~0.4 s in the sleepy morning), so a casual 0.35–0.65 s close usually loses it (2★)
while an expert's 0.2–0.35 s keeps it (3★); spare bugs let a slow hand still pass; Dusk adds moths that leave, wasps,
mosquitoes/dragonflies/hoppers (calmed so casual can pass), Night the fast pace and bite budgets.

## Detector hardening and tests
- Re-arm hysteresis can't flap: a `.closed` phone hovering at 30° ± 6° bit–armed–bit before R9 (sim: 1 of 200
  traces failed with `T.rearmRise=0`); with `rearmRise` 0/200.
- "Close the phone to start" can't stick: θ ≤ 25° clears it whatever the status; a phone launched shut on the outer
  display starts the round on its opening; a reset never re-opens a waiting round; `noteFolded` covers reports that
  stop at the handover.
- Starting close never bites; a very slow close (8°/s creep, 40°/s with stops) bites once at the shut; partial closes
  to 40°/60° with `.closed` never bite; any opening ≥ 35° plays (opened only to 45°); +8° bias: one bite a close; the
  clock is frozen while shut.
- Sim: `detector=1` adds 10 noisy-trace checks × 200 seeds (25–45 ms reports, 5 % 150 ms gaps, ±3–6° noise,
  hardware status) + noteFolded: 20/20 PASS.
- Swift: `SnapTests/CoreTests.swift` `CoreR9Tests` (detector traces × 40 seeds, re-arm angle, restart carry,
  noteFolded, session frozen clock and starting close driven by a noisy detector, falling closure, Level 1's fly vs a 2 s
  close, goal texts); `SnapTests/InputTests.swift` `InputR9Tests` (reset during the starting close, reset while shut,
  noteFolded, launched shut, noisy reports through the filter); `BalanceTests.theLevelCurveRampsAndEveryWorldOpens`
  (bands around the level table).

## Asks
- **App** (`GameController`): (1) call `hinge.noteFolded(at:)` when the outer display takes over during a live hinge
  round (pose → `.cover`); harmless if shut reports do arrive. (2) Pass `keepsRoundStart: false` to `hinge.reset` when
  going Home (line ~984) and on scene activation when not in a round (line ~568); otherwise Home's trap waits for one
  close–open after a round quit while waiting. (3) Optional: log the last hinge angle at each cover handover
  (`SNAP-T cover angle <θ>`) so the founder's first device log shows where iOS hands over.
- **CI**: `ci/duo-scenarios.txt` 29's caption quotes L4's old goal ("Catch 2 flies. Never bite the bee"; now "2 flies.
  Spare the bee"); scenario 61 (L5 crowd) now has a bluebottle sitting with the three flies.
- **Lead**: CoreR8Tests (not in my file list) still pass by design: L1 one bug / 3 bites / stars 2,1; L3 biteOf 2; L4
  noSting + bee; L5 biteOf 3 catchable at 6 s; L15 clean3 grasshoppers; L16 10 in 40 s; L27 spare 2 / catch 5.

## Unsure
- Real hinge noise and whether reports arrive below ~30° after the cover handover are unknown; `noteFolded` is the
  fallback if they don't. The pilot models remain proxies; star thresholds want the founder's hands.
- Swift is not bit-identical to the sim; BalanceTests uses bands.
