import CoreGraphics
import Foundation

// MARK: - Every number in the game (GAME-DESIGN §3–§6, ROUND-1 "Core engineer")
//
// Nothing is hard-coded elsewhere in Core. tools/balance-sim.js mirrors the balance-relevant values in its `T` table
// (same names) and the detector values in its `D` table: KEEP THEM IDENTICAL. R1 tuning (design/notes/core-R1.md)
// changed some GAME-DESIGN starting values; each change is marked "R1". R2 changes (design/notes/core-R2.md) are
// marked "R2", R3 changes (design/notes/core-R3.md) "R3", R4 changes (design/notes/core-R4.md) "R4", R5 changes
// (design/notes/core-R5.md) "R5", R6 changes (design/notes/core-R6.md) "R6", R7 changes (design/notes/core-R7.md) "R7",
// R8 changes (design/notes/core-R8.md) "R8", R9 changes (design/notes/core-R9.md) "R9" (rearmRise, startShutAngle: the
// detector on real hardware; no economy number changed in R9).
// The R6 goal and halo values are not in the sim (it has no goals or hints); lastLightWave and zenDayWaves are. R7's
// feastMultiplier, night pool weights and late decays are; wellFedScore is not.

enum Tuning {

    // MARK: Hinge: the lid is the jaw (R8, ROUND-8 §1; SnapDetector)

    /// R8 (founder rule 1: a shut phone is a closed trap, any opening is open; a phone at 90° is OPEN): the trap is
    /// armed once θ reaches this, and re-armed here after a bite (the hysteresis above shutAngle).
    static let armAngle: Double = 35
    /// R8: the shut zone, where the bite fires: θ at or below this (while armed) …
    static let shutAngle: Double = 18
    /// … or the hinge status `.closed` with θ at or below this. Hardware reads `.closed` from about 85° (CLAUDE.md), so
    /// the status alone would bite an open phone; this guard keeps "partial closes never bite".
    static let statusShutAngle: Double = 25
    /// R9 (real hardware: about ±5° accuracy and noisy reports): after a shut, the trap re-arms only once θ is also this
    /// far (°) above the lowest θ since that shut (SnapDetector.rearmAngle). A full close (lowest ≤ 20°) re-arms at
    /// armAngle exactly; a `.closed` shut that hovers at 25–30° needs 40–45°, so report noise can't flap bite–arm–bite.
    static let rearmRise: Double = 15
    /// R9 (founder rule 3, never stuck): a round waiting for its first close counts the phone as closed at or below this
    /// (°) whatever the status (SnapDetector.isStartShut). The bite itself still needs the shut zone.
    static let startShutAngle: Double = 25
    /// R8: a close starts when the closure passes this (the bite's duration is timed from here) …
    static let closeStart: Double = 8
    /// … and is abandoned (a partial close opened again) when the closure falls back under this …
    static let closeCancel: Double = 4
    /// … or the phone opens this far (°) above the close's lowest θ ("any opening at all means it is opening").
    static let reopenCancel: Double = 10
    /// R8: a shut with no close start seen (a creep slower than the reference's fall) counts as a close this long (s).
    static let untimedCloseDuration: Double = 2.0
    /// R8: a close still under way this long (s) after its start is a slow close (TrapInput.creeping, the "quick" hint).
    static let slowCloseAfter: Double = 0.6
    /// R8: the degrees of closure from closeStart to the shut on a typical book (the pilot's 150° rest: 150 − 18 − 8).
    /// TrapRules.modelExposure spreads a bite's duration over it.
    static let modelCloseSpan: Double = 124
    /// The open reference: the highest θ over this window (s) …
    static let refWindow: Double = 0.6
    /// … falling at most this fast (°/s); it holds while a close is under way.
    static let refFallRate: Double = 25
    /// R8 (founder rule 2: no pose demands; flat, laptop, any angle plays): no Core rule uses this any more
    /// (TrapInput.tooFlat is always false, Core never hints `.bendALittle`). Kept for App's AppRules.isTooFlat, which
    /// founder rule 2 removes too.
    static let tooFlatAngle: Double = 174
    /// R8: a tap is an instant bite of this duration (s).
    static let touchSnapTime: Double = 0.12
    /// A tap bite re-arms after this (s); the clock is frozen until then.
    static let touchRearmDelay: Double = 0.45

    /// R8 legacy (no longer part of any rule): the drawn-closure scale and thresholds Scene, Feel and App used with the
    /// R1–R7 partial snap. Kept so their code compiles until they move to the R8 closure (degrees from the open
    /// reference, up to ~145° at the shut).
    static let snapDepth: Double = 22
    static let snapStartDepth: Double = 4
    static let creepDepth: Double = 6
    static let creepDwell: Double = 0.45

    // MARK: Snaps, score and chain (GAME-DESIGN §5)

    /// R8 (ROUND-8 §2, balance sim): 12 (was 10). The R8 bite is much harder (a whole close, startled bugs flee), so a
    /// novice's run needs the two extra snaps to reach 60–100 s; the expert's length is set by the late night.
    static let startSnaps: Int = 12
    /// R3 (REVIEW-2 #23): two rows of 7, so a Sprout's 12-snap start never caps an early Feast away.
    static let maxSnaps: Int = 14
    /// R4 (REVIEW-3 #11, founder call): a Sprout's first Feed run (SessionOptions.firstRun) starts with the max.
    static let firstRunSnaps: Int = 14
    /// R4: … and a calm first morning: waves 1…firstRunCalmWaves are crowds (one cluster, landing together), and the
    /// gap after each of them is × firstRunWaveGap, so the novice pilot's first run lasts ≥ 90 s (it was 67 s with 14
    /// snaps alone: a hand that bites every landing spends a snap per wave).
    static let firstRunCalmWaves: Int = 14
    static let firstRunWaveGap: Double = 1.6
    /// R5 (REVIEW-4 #8, founder call): the Sprout taper (SproutPerks.forFeedRun). Feed run 1 is the first run above;
    /// run 2 starts with sproutRun2Snaps, a free first sting and the calm morning (it wilts); run 3 with
    /// sproutRun3Snaps and the calm morning. From run sproutTaperRuns + 1 the rules are standard.
    static let sproutRun2Snaps: Int = 13
    static let sproutRun3Snaps: Int = 12
    static let sproutTaperRuns: Int = 3
    static let snapCost: Int = 1
    /// Caught ≥ feastCount: +feastRefund; caught ≥ bigFeastCount: +bigFeastRefund (instead).
    static let feastCount: Int = 3
    static let feastRefund: Int = 1
    static let bigFeastCount: Int = 5
    static let bigFeastRefund: Int = 2
    /// R7 (SCORE-R6 #3, founder call): a clean bite of ≥ bigFeastCount (a FEAST) scores × this on top of the chain
    /// (TrapRules.bitePoints / feastBonus). At the same chain 5 bugs then out-score 4 bugs whose mean points per bug
    /// are up to 50 / 16 = 3.1× higher (5 × 5 × 2 against 4 × 4), so R6's "FEAST +180 next to a QUAD +260" is now
    /// +360 against +260. A stung bite is never a FEAST and scores × 1.
    static let feastMultiplier: Double = 2.0
    static let scarabRefund: Int = 2
    static let ladybirdRefund: Int = 1
    /// Extra snaps lost per bee / bumblebee and per wasp in the bite.
    static let beeCost: Int = 1
    static let waspCost: Int = 2
    /// Each productive clean snap adds this to the multiplier, up to the max.
    static let chainStep: Double = 0.5
    /// R3 (REVIEW-2 #22): ×5, reached at the 8th step (×1, ×1.5 … ×4 at 6 … ×5 at 8).
    static let chainMaxMultiplier: Double = 5
    /// R2 chain rule (GAME-DESIGN §5): only a clean bite of at least this many adds a step; a clean 1-bug bite holds.
    static let chainMinBite: Int = 2
    /// R8 (ROUND-8 §2): any miss breaks the chain: a bite that let a bug escape (or flee its close) breaks it too.
    static let missBreaksChain: Bool = true
    /// R8 (ROUND-8 §2 lever "a dry bite costs more"): extra snaps a dry bite costs. 0: with it on (1) the sim's novice
    /// run fell to 35 s (target 60–100 s); the R8 close already makes dry bites common enough.
    static let dryBiteCost: Int = 0

    // MARK: Hunger (R2, GAME-DESIGN §5 "Hunger")

    /// Seconds of hunger before a snap wilts, by day phase. R3 (REVIEW-2 #7): 18/16/14/12 (was 15/14/12/10). R4
    /// (QA-2 #1, REVIEW-3 #12, founder call): night 14, and the clock ticks only while at least one catchable bug has
    /// landed in the trap and no protected bug has, so an empty, bee-only or bee-plus-flies trap never gets hungrier.
    /// A catch resets it. R8 (ROUND-8 §2 "faster hunger from noon on"): 18/14/12/12 (was 18/16/14/14).
    static let wiltMorning: Double = 18
    static let wiltNoon: Double = 14
    static let wiltDusk: Double = 12
    static let wiltNight: Double = 12
    /// `hungry` fires (and the hint shows) this many seconds before a wilt.
    static let hungryWarning: Double = 3

    // MARK: The bite rule (GAME-DESIGN §4)

    /// R8: the morning's bugs (waves before noonWave) flee × this slower: a slow hand still catches something while it
    /// learns (the sim's novice: 32 s without it, 70 s with it).
    static let morningReactionFactor: Double = 1.3
    static let sipReactionFactor: Double = 1.35
    static let flyingReactionFactor: Double = 0.55
    static let rimReactionFactor: Double = 0.6
    /// An arriving bug is in the bite only below this height.
    static let catchableHeight: Double = 0.6
    /// After this wave reactions × lateReactionDecay per wave (floor lateReactionFloor).
    /// R3: the late night is the run-ender now, not hunger: reactions × 0.96 per wave to a floor and lingers × 0.92 to
    /// a 0.2 floor (was 0.97 / 0.6 and 0.98 / 0.5). R4: the floor is 0.2 (was 0.25): at 0.25 a sipping housefly
    /// (0.24 × 1.35 × 0.25 = 81 ms) never outran an 80 ms hand, and with R4's gated hunger nothing else ended a perfect
    /// run. At 0.2 every night bug but the scarab outruns 80 ms by about wave 70.
    /// R7 (#14): 0.955 (was 0.96) and lingers × 0.91 (was 0.92): with the night pool's fireflies and crickets the
    /// expert's longest runs sat near 6 min; the sim's expert p90 is now 330 s on 8 seeds (was 346 s), 332 s on 16.
    static let lateWaveStart: Int = 30
    static let lateReactionDecay: Double = 0.955
    static let lateReactionFloor: Double = 0.2
    /// R1: night lingers shrink the same way after lateWaveStart (floor lateLingerFloor).
    static let lateLingerDecay: Double = 0.91
    static let lateLingerFloor: Double = 0.2

    // MARK: Waves and the day (GAME-DESIGN §6)

    static let firstWaveTime: Double = 1.2
    static let waveDelayMin: Double = 3.0
    static let waveDelayMax: Double = 4.5
    static let noonWave: Int = 7
    static let duskWave: Int = 15
    static let nightWave: Int = 23
    /// dayClock reaches 4 ("deep night") here.
    static let deepNightWave: Int = 31
    /// The attract mode's day repeats after this many waves.
    static let attractDayWaves: Int = 28
    /// R6: the Zen Bog's day repeats after this many waves (below lateWaveStart, so Zen never speeds up).
    static let zenDayWaves: Int = 28
    /// R6 (#19, REVIEW-5 P2-5): the last light (Feed and the Daily). From this wave the hunger clock ticks whatever is in the
    /// trap (empty, or a bee in it), so even a hand that never gives up waiting ends by about 7 minutes (it reached
    /// the 10-minute cap in 14 of 16 seeds in R5). TrapRules.nightCue tells the HUD here and at lateWaveStart + 1.
    static let lastLightWave: Int = 85
    static let nectarReseedWaves: Int = 6
    /// R2 (REVIEW-1 #19): 6–8 drops in clusters of 2–3, the clusters alternating between the lobes.
    static let nectarMin: Int = 6
    static let nectarMax: Int = 8
    static let nectarRadiusMin: Double = 12
    static let nectarRadiusMax: Double = 16
    static let nectarClusterMin: Int = 2
    static let nectarClusterMax: Int = 3
    /// A cluster's drops sit on a ring of this radius (pt) round its centre, evenly spaced. R3 (REVIEW-2 #16): 24–30
    /// (was 40–48), so a cluster's 2–3 drops read as one group (cluster mates 42–60 pt apart, other clusters > 100).
    static let nectarRingMin: Double = 24
    static let nectarRingMax: Double = 30
    /// Cluster centres keep this far apart (pt), at these normalised radii, at least nectarArcMargin rad from the
    /// vertical. A lobe with two clusters puts the first in its upper half and the second in its lower half, each at
    /// least nectarHalfGap rad from the horizontal.
    static let nectarClusterGap: Double = 190
    static let nectarArcMargin: Double = 0.25
    static let nectarHalfGap: Double = 0.45
    static let nectarClusterInner: Double = 0.32
    static let nectarClusterOuter: Double = 0.55
    /// A re-seeded drop this close (pt) to a drop that is still being sipped is skipped.
    static let nectarKeptClearance: Double = 60
    /// R3: a drop sits at least this far (pt) from the midrib line, so even a bumblebee sipping it keeps
    /// creaseHalfWidth + radius + creaseClearance (75.6 pt) off the crease (was 50).
    static let nectarCreaseClearance: Double = 80
    static let nectarTries: Int = 30
    static let lingerMorningMin: Double = 6
    static let lingerMorningMax: Double = 8
    static let lingerNoonMin: Double = 5
    static let lingerNoonMax: Double = 7
    static let lingerDuskMin: Double = 4
    static let lingerDuskMax: Double = 6
    static let lingerNightMin: Double = 3.5
    static let lingerNightMax: Double = 5
    /// Protected bugs per wave (R1: chances, not the design's flat counts; see core-R1.md).
    static let beeFromWave: Int = 3
    /// R3: 0.35 (was 0.5): stinger bites refund nothing now, so the morning is a little kinder.
    static let beeChanceMorning: Double = 0.35
    static let beeChanceNoon: Double = 0.4
    static let beeChanceDusk: Double = 0.5
    static let beeChanceNight: Double = 0.55
    static let beeChanceNight2: Double = 0.15
    /// One more protected bug per wave every this many waves after lateWaveStart (capped). R3: 40 (was 8): extra bees
    /// made the late night a wilt machine for patient players; the reaction and linger ramp ends runs instead.
    static let extraBeeEvery: Int = 40
    static let maxProtectedPerWave: Int = 4
    /// R1: bees drop in for a quicker sip than the bugs.
    static let beeLingerFactor: Double = 0.6
    /// Catchable bugs per wave (R1: smaller than the design's starting values; R2: the morning and noon a little
    /// bigger again, so bigger bugs still make crowds).
    static let sizeFirstMin: Int = 2
    static let sizeFirstMax: Int = 3
    static let sizeMorningMin: Int = 2
    static let sizeMorningMax: Int = 4
    static let sizeNoonMin: Int = 2
    static let sizeNoonMax: Int = 4
    static let sizeDuskMin: Int = 2
    static let sizeDuskMax: Int = 4
    static let sizeNightMin: Int = 2
    static let sizeNightMax: Int = 5
    /// R7 (SCORE-R6 #14): night is fireflies and crickets. At night the day bugs' pool weights (housefly, fruit fly,
    /// gnat, bluebottle, grasshopper) are × nightDayBugWeight, and fireflies and crickets weigh these (R6: 3 and 2.5).
    /// Over waves 23–90 the firefly is the commonest bug landing in the trap and the pair are ~45% of them (R6: 13%,
    /// gnats first). Same draws, so the draw order never changes.
    static let nightDayBugWeight: Double = 0.3
    static let nightFireflyWeight: Double = 8
    static let nightCricketWeight: Double = 6
    /// Crowd waves (everything lands close together) from this wave, with this chance.
    static let crowdFromWave: Int = 3
    static let crowdChance: Double = 0.45
    /// R2: a crowd's flyers are timed to land together (each starts late by how much quicker its flight is than the
    /// slowest one's), plus 0…crowdSpread s of jitter: they land within 1.2 s (hover and group steps included).
    static let crowdSpread: Double = 0.1
    /// R2: a crowd goes to one cluster: its random spots lie crowdNearMin…crowdNearMax pt from the anchor drop.
    static let crowdNearMin: Double = 60
    static let crowdNearMax: Double = 140
    /// Non-crowd waves: each group starts slot × (trickleMin…trickleMax) s after the wave.
    static let trickleMin: Double = 0.6
    static let trickleMax: Double = 1.2
    static let beeSpread: Double = 2.5
    /// Single flyers that never land in the trap (cross the screen or sit on the bog).
    static let passerChance: Double = 0.12
    static let beePasserChance: Double = 0.15
    static let maxWaveBugs: Int = 7
    static let maxBugsOnScreen: Int = 18
    static let scarabFromWave: Int = 7
    static let scarabChance: Double = 1.0 / 12.0
    static let gnatFromWave: Int = 4
    /// Random landing spots lie within this normalised radius.
    static let spotRadius: Double = 0.75
    /// R3 (REVIEW-2 #5): no bug rests (lands, sips, pauses, ends a hop) with its centre closer to the midrib line than
    /// ScreenLayout.creaseHalfWidth + its radius + this (pt). See TrapRules.creaseGap(radius:).
    static let creaseClearance: Double = 16
    /// R4 (REVIEW-3 #14): over the trap, a bug whose centre is within creaseHalfWidth + its radius of the midrib line
    /// is at least this high (airborne). Ground moves (walks, wanders, nectar dashes, hops, darts) and the hover keep
    /// to the bug's own lobe, and a walker walks in on its spot's side, so only approaches (height ≥ 0.5), crossers
    /// (0.85), take-offs and the caught slide ever pass over the crease.
    static let creaseAirHeight: Double = 0.5
    /// R5 (REVIEW-4 #15): the Duo's book-pose thumbs rest on the outer edges at mid-height. No protected bug's entry
    /// lies within thumbBandWidth pt of either outer edge with its y strictly between thumbBandLow and thumbBandHigh
    /// of the scene height (WaveFactory.thumbSafeEntry mirrors such a y out of the band; no extra draws).
    static let thumbBandWidth: Double = 90
    static let thumbBandLow: Double = 0.25
    static let thumbBandHigh: Double = 0.75

    // MARK: Session

    /// R2 (REVIEW-1 #4): bug radii (BugInfo.radius) are the R1 art radii × this, for the art and the rules alike.
    static let bugRadiusScale: Double = 1.8

    /// R6 (#15): a protected bug's halo as the Scene draws it (TrapArt.protectedRingScale × radius + this pad, pt).
    static let haloScale: Double = 1.6
    static let haloPad: Double = 4

    /// R8 (ROUND-8 §4): a level whose script has nothing left to catch (nothing pending, no bug that isn't leaving)
    /// ends after this long (s).
    static let levelIdleEnd: Double = 2.5
    static let tiredSeconds: Double = 2.2
    static let caughtSeconds: Double = 0.5
    /// "Open up to reset" after this long unarmed after a snap.
    static let openUpDelay: Double = 1.0
    static let crowdHintCount: Int = 3
    static let maxSubstep: Double = 1.0 / 120.0
    /// R3 (REVIEW-2 #21): the fixed step (s) of a deterministic pilot run (PilotRun), whatever the display's frame time.
    static let pilotStep: Double = 1.0 / 60.0
    /// … and at most this many fixed steps per display frame (after a long hitch the run falls behind, it never jumps).
    static let pilotMaxStepsPerFrame: Int = 6
    /// R7 (SCORE-R6 #4): a resting bug's centre keeps its radius (a protected bug: its halo, haloScale × radius +
    /// haloPad) plus this (pt) from every TrapSession.keepOut rect. Not in the sim (it has no keep-out).
    static let keepOutMargin: Double = 8

    // MARK: Movement (ROUND-1 "Movement")

    static let hoverMin: Double = 0.3
    static let hoverMax: Double = 0.6
    static let hoverHeight: Double = 0.5
    static let hoverCircle: Double = 6
    static let approachHeightDrop: Double = 0.5
    static let approachPathFactor: Double = 1.1
    static let minFlightTime: Double = 0.6
    static let arcBend: Double = 0.25
    /// Landed bugs keep at least radius + radius + this apart.
    static let landSpacing: Double = 4
    static let landMaxRadius: Double = 0.8
    static let spotTries: Int = 10
    static let takeoffTime: Double = 0.4
    static let exitMargin: Double = 40
    static let leaveSpeedFactor: Double = 1.2
    static let escapeSpeedFactor: Double = 1.8
    static let releaseSpeedFactor: Double = 1.3
    static let walkerEscapeFactor: Double = 3
    static let wanderMin: Double = 25
    static let wanderMax: Double = 70
    static let nectarSeekRadius: Double = 260
    static let hopMin: Double = 120
    static let hopMax: Double = 300
    static let hopSpeed: Double = 300
    static let hopTimeMin: Double = 0.5
    static let hopTimeMax: Double = 1.2
    static let hopHeight: Double = 0.8
    static let dartMin: Double = 80
    static let dartMax: Double = 180
    static let dartTime: Double = 0.25
    static let dartHeight: Double = 0.3
    static let darterHoverChance: Double = 0.5
    static let crossHeight: Double = 0.85
    /// Restless (cosmetic tell) from this fraction of the linger.
    static let restlessFrom: Double = 0.75

    // MARK: TrapPilot (ROUND-1 "TrapPilot")

    /// R8: the pilot holds the book here and closes to pilotShutAngle (its closure is pilotIdleAngle − θ).
    static let pilotIdleAngle: Double = 150
    static let pilotShutAngle: Double = 5
    /// R8: the novice waits for 2 landed bugs, or 1 after this long (s) since its last bite.
    static let novicePatience: Double = 6
    static let casualPatience: Double = 7
    static let expertPatience: Double = 6
    static let perfectPatience: Double = 7
    static let noviceBeeMiss: Double = 0.6
    static let casualBeeMiss: Double = 0.25
    static let expertBeeMiss: Double = 0.02
    /// Perfect waits while a protected bug in the trap is flying below this height.
    static let perfectBeeHeight: Double = 0.85
    /// Others notice a protected arriving bug below this height.
    static let pilotBeeHeight: Double = 0.75
    /// Expert shoos a bee that has sat in the trap for expertShooAfter s: R8, a partial close to shooDepth° of closure
    /// over shooTime, held until the bee has gone (at most shooHoldMax s), then the reopen. It never bites.
    static let shooDepth: Double = 30
    static let shooTime: Double = 0.4
    static let shooHoldMax: Double = 1.6
    static let expertShooAfter: Double = 5
    static let perfectShooAfter: Double = 0
    static let expertValue: Int = 120
    static let perfectValue: Int = 400
    static let perfectRestless: Double = 0.7
    static let expertRestless: Double = 0.6
    /// R4: expert and perfect bite a landed bug after this long (s) without a snap even when they judge it too quick
    /// (a hand never waits for ever; with R4's gated hunger an unfed trap only wilts slowly).
    static let pilotGiveUp: Double = 12

    // MARK: Rank growth (R6, founder call; PlantRanks.growth(from:))

    /// A Zen Bog run grows the plant rank by this share of its bugs (rounded down per run); Feed and the Daily count
    /// every bug. The Bug Book and any-mode goals count Zen bugs in full.
    static let zenRankShare: Double = 0.25

    /// R7: the "Well Fed" achievement's run score (Achievements.score10k), R6's 10,000 named. With the ×2 FEAST it still
    /// sits above the casual median (~7,800) and at or below the expert's (~40,000), as docs/appstore/achievements.md
    /// asks; BalanceTests checks it.
    static let wellFedScore: Int = 10_000

    // MARK: Goals (R6, Goals.swift; not in the sim)

    /// Active goals at a time.
    static let goalsActive: Int = 3
    /// A completed goal's growth (bugs-equivalent on the rank bar): this share of the gap from the current rank to
    /// the next (the top rank uses the last gap), rounded to goalRewardRound, at least goalRewardMin.
    static let goalRewardShare: Double = 0.15
    static let goalRewardMin: Int = 10
    static let goalRewardRound: Int = 5
    /// Completing all goalsActive at once adds this many more rewards.
    static let goalTripleBonus: Int = 1
    /// A completed goal is not drawn again until this many other goals have been completed.
    static let goalRecentMemory: Int = 6
    /// "No dry snaps until …" goals need at least this many snaps before that phase.
    static let goalMinSnaps: Int = 5
}
