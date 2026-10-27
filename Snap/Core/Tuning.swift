import CoreGraphics
import Foundation

// MARK: - Every number in the game (GAME-DESIGN §3–§6, ROUND-1 "Core engineer")
//
// Nothing is hard-coded elsewhere in Core. tools/balance-sim.js mirrors the balance-relevant values in its `T` table
// (same names) and the detector values in its `D` table: KEEP THEM IDENTICAL. R1 tuning (design/notes/core-R1.md)
// changed some GAME-DESIGN starting values; each change is marked "R1".

enum Tuning {

    // MARK: Hinge and the snap rule (GAME-DESIGN §3)

    /// Closure (degrees from the rest reference) at which the bite fires.
    static let snapDepth: Double = 22
    /// Closure that starts the snap timer (`ts`).
    static let snapStartDepth: Double = 4
    /// A snap attempt is abandoned when the closure falls back below this (hysteresis below `snapStartDepth`).
    static let snapCancelDepth: Double = 2
    /// Creep depth (against the slow creep reference) that counts as creeping …
    static let creepDepth: Double = 6
    /// … for longer than this (s).
    static let creepDwell: Double = 0.45
    /// Re-arm once θ has risen this far above the lowest point of the last snap …
    static let rearmRise: Double = 16
    /// … or θ is at least this (and has risen `rearmMinRise`, so a snap from a near-flat rest can't re-arm at once).
    static let rearmAngle: Double = 150
    static let rearmMinRise: Double = 4
    /// Rest reference: the highest θ over this window (s) …
    static let refWindow: Double = 0.6
    /// … falling at most this fast (°/s).
    static let refFallRate: Double = 25
    /// Founder change (R1): the slow creep reference, the highest θ over this window (s) …
    static let creepWindow: Double = 3.0
    /// … falling at most this fast (°/s). Reset to θ on each re-arm.
    static let creepRefFallRate: Double = 6
    /// θ at or above this is "too flat" (hint only).
    static let tooFlatAngle: Double = 174
    /// θ below this for `closingDwell` pauses the game (App/Input).
    static let closingAngle: Double = 50
    static let closingDwell: Double = 0.6
    /// A tap snap counts as this fast (s).
    static let touchSnapTime: Double = 0.09
    /// A tap snap re-arms after this (s).
    static let touchRearmDelay: Double = 0.45

    // MARK: Snaps, score and chain (GAME-DESIGN §5)

    static let startSnaps: Int = 10
    static let maxSnaps: Int = 12
    static let snapCost: Int = 1
    /// Caught ≥ feastCount: +feastRefund; caught ≥ bigFeastCount: +bigFeastRefund (instead).
    static let feastCount: Int = 3
    static let feastRefund: Int = 1
    static let bigFeastCount: Int = 5
    static let bigFeastRefund: Int = 2
    static let scarabRefund: Int = 2
    static let ladybirdRefund: Int = 1
    /// Extra snaps lost per bee / bumblebee and per wasp in the bite.
    static let beeCost: Int = 1
    static let waspCost: Int = 2
    /// Each productive clean snap adds this to the multiplier, up to the max.
    static let chainStep: Double = 0.5
    static let chainMaxMultiplier: Double = 4

    // MARK: The bite rule (GAME-DESIGN §4)

    static let sipReactionFactor: Double = 1.35
    static let flyingReactionFactor: Double = 0.55
    static let rimReactionFactor: Double = 0.6
    /// An arriving bug is in the bite only below this height.
    static let catchableHeight: Double = 0.6
    /// After this wave reactions × lateReactionDecay per wave (floor lateReactionFloor).
    static let lateWaveStart: Int = 30
    static let lateReactionDecay: Double = 0.97
    static let lateReactionFloor: Double = 0.6
    /// R1: night lingers shrink the same way after lateWaveStart (floor lateLingerFloor).
    static let lateLingerDecay: Double = 0.98
    static let lateLingerFloor: Double = 0.5

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
    static let nectarReseedWaves: Int = 6
    static let nectarMin: Int = 5
    static let nectarMax: Int = 7
    static let nectarRadiusMin: Double = 12
    static let nectarRadiusMax: Double = 16
    static let nectarSpacing: Double = 110
    static let nectarInner: Double = 0.3
    static let nectarOuter: Double = 0.72
    static let nectarCreaseClearance: Double = 50
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
    static let beeChanceMorning: Double = 0.5
    static let beeChanceNoon: Double = 0.4
    static let beeChanceDusk: Double = 0.5
    static let beeChanceNight: Double = 0.55
    static let beeChanceNight2: Double = 0.15
    /// One more protected bug per wave every this many waves after lateWaveStart (capped).
    static let extraBeeEvery: Int = 8
    static let maxProtectedPerWave: Int = 4
    /// R1: bees drop in for a quicker sip than the bugs.
    static let beeLingerFactor: Double = 0.6
    /// Catchable bugs per wave (R1: smaller than the design's starting values).
    static let sizeFirstMin: Int = 1
    static let sizeFirstMax: Int = 2
    static let sizeMorningMin: Int = 2
    static let sizeMorningMax: Int = 3
    static let sizeNoonMin: Int = 2
    static let sizeNoonMax: Int = 3
    static let sizeDuskMin: Int = 2
    static let sizeDuskMax: Int = 4
    static let sizeNightMin: Int = 2
    static let sizeNightMax: Int = 5
    /// Crowd waves (everything lands close together) from this wave, with this chance.
    static let crowdFromWave: Int = 4
    static let crowdChance: Double = 0.34
    static let crowdSpread: Double = 1.0
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

    // MARK: Session

    static let tiredSeconds: Double = 2.2
    static let caughtSeconds: Double = 0.5
    /// "Open up to reset" after this long unarmed after a snap.
    static let openUpDelay: Double = 1.0
    static let crowdHintCount: Int = 3
    static let maxSubstep: Double = 1.0 / 120.0

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

    static let pilotOvershoot: Double = 6
    static let pilotHold: Double = 0.15
    static let pilotReopen: Double = 0.35
    static let pilotIdleAngle: Double = 160
    static let noviceCreepChance: Double = 0.25
    static let noviceCreepDepth: Double = 12
    static let noviceCreepTime: Double = 1.2
    static let casualPatience: Double = 4
    static let expertPatience: Double = 6
    static let perfectPatience: Double = 7
    static let noviceBeeMiss: Double = 0.6
    static let casualBeeMiss: Double = 0.2
    static let expertBeeMiss: Double = 0.02
    /// Perfect waits while a protected bug in the trap is flying below this height.
    static let perfectBeeHeight: Double = 0.85
    /// Others notice a protected arriving bug below this height.
    static let pilotBeeHeight: Double = 0.75
    /// Expert shoos a bee that has sat in the trap for expertShooAfter s with a slow creep to shooDepth.
    static let shooDepth: Double = 11
    static let shooTime: Double = 0.5
    static let shooHold: Double = 0.1
    static let expertShooAfter: Double = 5
    static let perfectShooAfter: Double = 0
    static let expertValue: Int = 120
    static let perfectValue: Int = 400
    static let perfectRestless: Double = 0.7
    static let expertRestless: Double = 0.6
}
