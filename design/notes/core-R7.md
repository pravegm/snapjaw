# Core R7 hand-off (Core engineer, 28 Oct 2026)

This is unverified until CI compiles it; there is no Swift compiler on this host. I did two full read-throughs for
compile errors: Swift 5, exhaustive switches (`GoalTier.label`, `BugActivity` in the keep-out test), no mutating,
rethrowing or key-path calls inside `#expect`, no ambiguous `.nan`, no local shadowing a static, and floats and CGFloats
compared with a tolerance.

`tools/balance-sim.js` stays a line-by-line port. It mirrors `feastMultiplier`, the night pool weights and the R7 late
decays in `T`, has a new `night=1` mode, and keeps the Well Fed check. Keep-out is not in the sim: with an empty
`keepOut`, no draw or position changes. All 37 sim checks pass on 16 seeds, and 0 of 8 eight-seed windows fail.
`Contracts.swift` was not touched. Every change is marked "R7".

Items: SCORE-R6 §4 #3 (founder call: ×2, not a flat bonus), #4 (the Core part: keep-out), #14 (Core), #15 and #10.

## New API for App and Scene (exact)
```swift
// Snap/Core/Tuning.swift
static let feastMultiplier: Double = 2.0       // a clean bite of >= bigFeastCount (5) scores x2
static let nightDayBugWeight: Double = 0.3
static let nightFireflyWeight: Double = 8
static let nightCricketWeight: Double = 6
static let lateReactionDecay: Double = 0.955   // R6 0.96
static let lateLingerDecay: Double = 0.91      // R6 0.92
static let wellFedScore: Int = 10_000          // R6's value, now named (Achievements.score10k uses it)
static let keepOutMargin: Double = 8

// Snap/Core/TrapSession.swift
var keepOut: [CGRect] = []                      // on TrapSession (Scene sets it from hudKeepOut)
// extension TrapRules
static func bitePoints(_ caught: [BugSpecies], chain: Int, stung: Bool) -> Int      // THE scoring function
static func feastBonus(count: Int, stung: Bool) -> Double                          // 2.0 for a clean 5+ bite, else 1
static func keepOutClearance(radius: CGFloat, protected: Bool) -> Double
static func touchesKeepOut(_ rects: [CGRect], _ x: Double, _ y: Double, clearance: Double) -> Bool

// Snap/Core/Goals.swift
enum GoalTier: Int, CaseIterable, Sendable, Comparable { case easy = 0, medium = 1, hard = 2 }
GoalTier.label            // instance var: "Easy" / "Medium" / "Hard" (like GoalScope.label)
GoalSpec.tier: GoalTier   // on every pool goal
```
- **Score (shared contract):** the ×2 is **inside** `BiteReport.points`, so it is also inside `snapshot.score`,
  `RunResult.score` and `bestBitePoints`.
  - For "5 bugs · +N", App reads `caught.count` and `points`, and the chain comes from the snapshot or
    `chainMultiplier`. App must not recompute the score.
  - A "×2 FEAST" tag is shown when `TrapRules.feastBonus(count:stung:) > 1`.
- **Goal ids and achievements are R6's.** `daily2k` and `daily6k` are unchanged, and "Well Fed" is still 10,000.
  No store text changes.
- No new demo keys or freeze tags.

## #3: the FEAST pays ×2 (founder decision)
- **The rule:** `points = round(Σ species points × bugs × chain multiplier × feastBonus)`.
  - `feastBonus` is 2 for a clean bite of ≥ 5 and 1 otherwise.
  - A stung bite is unchanged: ×1 with no ×2, and it is never a FEAST.
- **What it guarantees:**
  - At the same chain, 5 bugs score 50 × the mean points per bug, against 16 × the mean for 4 bugs. So 5 bugs win
    whenever the 4-bug bite's mean is less than 3.1× higher.
  - The tests check equal means and means up to 2.5× higher, over every scoring species, 5–7 bugs, at chains 0–10.
  - There is no whole-range guarantee: four Golden Scarabs (2,400) still beat five gnats (150). This is pinned in the
    test as the founder's call.
- **R6's store frames, reconstructed from species points:**
  - The FEAST "+180" is 3 houseflies and 2 gnats (36 points × 5). It now pays +360 at ×1 and +720 at ×2.
  - The QUAD "+260" is a bluebottle, a grasshopper and 2 houseflies (65 × 4). At ×2 it is "+520".
  - So the FEAST now beats the QUAD at both chains.
- **Tests:** `CoreTests.aFeastOutScoresTheFourBugBitesPlayersCompare` and `aFeastBiteCarriesItsMultiplierInThePoints`.
  The second covers 5 houseflies = 500, 2 snaps back and the `.feast` event, and checks that a 5-bug bite with a bee
  scores 250 with no ×2.
- **Balance** (sim medians, 16 seeds, R6 → R7):

  | Pilot | Score (R6 → R7) | Run length (R6 → R7) |
  |---|---|---|
  | Novice | 230 → 286 | — |
  | Casual | 4,875 → 7,834 | 141 → 122 s |
  | Expert | 25,210 → 40,069 | 327 → 302 s |
  | Perfect | 42,133 → 67,073 | 354 → 341 s |

  - Scores rise about 1.6×. Most of that comes from the ×2: roughly 80% for casual and two-thirds for expert. The
    rest comes from the dearer night bugs.
  - That is the least a ×2 can do while big bites stay common: casual's median biggest bite is 9.
  - All bands hold, and so does the skill order.
- **Rescales reverted, none needed.**
  - "Well Fed" at 10,000 still sits above the casual median (7.8k) and at or below the expert's (40k), as
    achievements.md asks. That is now asserted in `BalanceTests.wellFedSitsBetweenCasualAndExpert` and in the sim.
  - The Daily goals 2,000 and 6,000 are R6's. The ×2 lowers their ratio to the casual median (about 0.26× and 0.77×,
    R6 0.41× and 1.23×), but both still separate players: casual p10 is 3.6k. That is not reason enough to move
    persisted ids.

## #4 (Core part): keep-out is decided by Core
- **What Scene does:** set `session.keepOut` once, before the first wave, to the HUD rects, Home buttons and edge
  margins. They go in the session's own coordinates: scene space, the `geometry.sceneSize` the session was built with,
  the same space as `BugState.position`.
  - y = 0 is the bottom edge (walkers enter there). Convert from view or SpriteKit space if yours differs.
  - Then **stop nudging or hiding bugs**: their drawn position is the judged one.
  - A change applies to the next spot each bug picks. A drop already reserved inside a new rect is released.
- **The clearance:** every resting spot keeps its centre `TrapRules.keepOutClearance` from every rect: the radius plus
  8 pt, or for a protected bug its halo (radius × 1.6 + 4) plus 8 pt, so halos stay clear too. Resting spots are:
  - spawn and landing spots (`findSpot`, `landingSpot`);
  - wander, walk, hop and dart targets;
  - sips at nectar drops;
  - bog sitters' perches outside the trap.
- **The fallback works like the midrib's.**
  - Like `offCrease`, a spot is pushed straight out across the nearest edge of the rect it touches.
  - The pushed spot must stay inside `maxR`, off the crease, on its lobe and clear of every rect. A perch must stay
    inside the scene.
  - `spotScore` also rejects keep-out spots, so `findSpot`'s tries prefer clear ones.
  - Nectar drops too close to a rect are never reserved or walked to.
  - No random draws are added, so an empty `keepOut` changes nothing (the existing tests and the sim are unaffected).
- **Test:** `CoreTests.noBugRestsInAKeepOutRect`. A corner rect (560, 360, 392 × 310) on seed 1000 runs 60 s with waves
  and no snaps.
  - Without `keepOut`, bugs rest inside it. With `keepOut`, no still, resting bug (sipping, on the ground, perched or
    dart-hovering) comes within its clearance; the tolerance is 3.5 pt for an ant's dash wobble.
  - The test also checks the clearance values and `touchesKeepOut`.
- Moving bugs (approaches, crossers, take-offs) may pass over a rect. Only resting is barred.

## #14 (Core): night is fireflies and crickets
- **The new night pool:** at night the day bugs' weights are × 0.3, the firefly weighs 8 and the cricket 6 (R6: 3 and
  2.5). The draws are the same, so the draw order is unchanged.
- **What lands at night:** over waves 23–90 the firefly is the commonest bug landing in the trap, and fireflies and
  crickets are 45.6% of landings. In R6 they were 13%, and gnats were the commonest.
  - Tested in `CoreTests.nightIsFirefliesAndCrickets` and in `balance-sim.js night=1`.
- **Pacing:** the expert p90 was 346 s on CI's 8 seeds, a thin margin, so I tuned the late night slightly.
  - Reactions are now × 0.955 per late wave (was 0.96) and lingers × 0.91 (was 0.92).
  - The expert p90 is now 330 s on 8 seeds and 332 s on 16. The median is 302 s, and perfect is 341 s.
  - The last light alone (wave 80 or 78) moved the p90 by less than 5 s.
  - `BalanceTests.expertRunLength` asserts p90 ≤ 360 s. The tuning tests were updated to 0.955 / 0.91.
- **Casual run length:** the casual median is 122 s (R6 141 s), because there are fewer gnat swarms. The worst
  eight-seed window is 100 s, right at the band's floor.

## #15: goal tiers
- **Counts:** 12 easy, 16 medium and 11 hard.
  - **Easy:** bite3, bite4, feast2, chain2, spare3, flyTrio, night, dusk10, catch20, dailyFinish, daily2k, zenCatch50.
  - **Hard:** bite6, bite7, feast6, chain4, chain5, spare12, dragonfly3, firefly5, cleanToNight, night20, daily6k.
  - The rest are medium.
- **Rules,** tested in `goalsHaveSensibleTiers`:
  - no hard goal opens below rank 3;
  - every easy goal opens by rank 2;
  - within one kind, span and scope, a bigger target is never an easier tier;
  - the variety goals are hard;
  - every rank has a non-hard goal.
- The draw does not use tiers.

## #10: Zen scoring is one function (Core done; the rest is App's)
- Every mode scores through `TrapRules.bitePoints`. `snapshot.score`, the sum of the run's `BiteReport.points` and
  `RunResult.score` are the same number.
  - Tested in `everyModeScoresWithTheOneFunction`: Feed and Zen with the casual pilot, every frame.
- **For App:** `ResultsView` shows `r.bugsCaught` as the Zen hero number, while the Zen HUD shows the score.
  - Either show `RunResult.score` on Zen Results, or hide the score in the Zen HUD.
  - The Zen Results demo should come from a real `.zen` run.

## For others
- **Scene:** night frames 35 and P05 will show more fireflies with no change on your side. Seeded night scenarios will
  see different species.
- **Store and App:** demo scores and FEAST pops read about 1.6× higher after a re-shoot. No achievement or leaderboard
  text changes.
- **Founder:** `design/GAME-DESIGN.md` §5's formula should gain the ×2 FEAST.
