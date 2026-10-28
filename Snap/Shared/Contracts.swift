import CoreGraphics
import Foundation

// MARK: - Contracts between the modules (owned by the founder; change only in a founder round)
//
// Core     (Snap/Core)      pure Swift game rules: no SpriteKit, no UIKit, no SwiftUI. Deterministic. Unit-tested.
// Input    (Snap/Input)     hinge / touch → TrapInput (closure in degrees, armed, creeping, the snap trigger).
// Scene    (Snap/Scene)     SpriteKit rendering of a TrapSnapshot + cosmetic FX from TrapEvents; forwards touches.
// Feedback (Snap/Feedback)  live audio synth + Core Haptics from TrapEvents + TrapTelemetry.
// App/UI   (Snap/App, Snap/UI, Snap/Persistence) SwiftUI shell, the loop glue, menus, persistence, Game Center.
//
// SCENE SPACE (everyone): points, landscape, origin bottom-left (SpriteKit). On an iPhone Duo held like a book the
// scene is 952 × 670 with the fold running top to bottom at x 456…496 (a 40 pt band). Other iPhones are wider in
// landscape: the scene keeps height 670 and gets WIDER (`ScreenLayout.size.width` = 670 × aspect), so nothing is
// cropped. The trap is always the same size, centred; the extra width is bog. Core works in scene space directly
// (`TrapGeometry` is built from the scene size).
// HUD SIDE: the HUD (score, snaps, chain) lives on the RIGHT half by default (the left half is the one iOS blurs when a
// fold starts from flat). `ScreenLayout.hudOnLeft` mirrors the HUD only; the trap and the game are symmetric.

// MARK: Screen layout

public struct ScreenLayout: Equatable, Sendable {
    public static let canvasWidth: CGFloat = 952
    public static let canvasHeight: CGFloat = 670
    public static let creaseHalfWidth: CGFloat = 20

    /// The scene size: height 670; width 952 on the Duo, wider on longer screens.
    public var size: CGSize
    /// Whether this canvas has a real fold (a hinge was seen). Without one, the fold is drawn as the trap's midrib only.
    public var hasFold: Bool
    /// Settings → "HUD on the left".
    public var hudOnLeft: Bool

    public init(size: CGSize = CGSize(width: canvasWidth, height: canvasHeight), hasFold: Bool, hudOnLeft: Bool = false) {
        self.size = CGSize(width: max(size.width, Self.canvasWidth), height: Self.canvasHeight)
        self.hasFold = hasFold; self.hudOnLeft = hudOnLeft
    }

    /// The layout for a view of `viewSize` points (treated as landscape: width ≥ height).
    public static func make(viewSize: CGSize, hasFold: Bool, hudOnLeft: Bool = false) -> ScreenLayout {
        let w = max(max(viewSize.width, viewSize.height), 1), h = max(min(viewSize.width, viewSize.height), 1)
        let width = max(canvasWidth, (canvasHeight * w / h).rounded())
        return ScreenLayout(size: CGSize(width: width, height: canvasHeight), hasFold: hasFold, hudOnLeft: hudOnLeft)
    }

    public var midX: CGFloat { (size.width / 2).rounded() }
    public var creaseMinX: CGFloat { midX - Self.creaseHalfWidth }
    public var creaseMaxX: CGFloat { midX + Self.creaseHalfWidth }
    /// The half the HUD lives on (scene space).
    public var hudRect: CGRect {
        hudOnLeft ? CGRect(x: 0, y: 0, width: creaseMinX, height: size.height)
                  : CGRect(x: creaseMaxX, y: 0, width: size.width - creaseMaxX, height: size.height)
    }
    public var geometry: TrapGeometry { TrapGeometry(sceneSize: size) }
}

/// Where the trap is (scene space). The trap zone is one ellipse centred on the fold; each half is one lobe.
public struct TrapGeometry: Equatable, Sendable {
    public var sceneSize: CGSize
    public var center: CGPoint
    /// Semi-axes of the trap zone.
    public var a: CGFloat
    public var b: CGFloat
    /// The rim: normalised radius ≥ this (GAME-DESIGN §4: the outer 16 %).
    public static let rimStart: Double = 0.84
    public static let semiAxisX: CGFloat = 432
    public static let semiAxisY: CGFloat = 296

    public init(sceneSize: CGSize) {
        self.sceneSize = sceneSize
        self.center = CGPoint(x: (sceneSize.width / 2).rounded(), y: (sceneSize.height / 2).rounded())
        self.a = Self.semiAxisX; self.b = Self.semiAxisY
    }

    /// 0 at the centre … 1 on the trap's edge (> 1 outside).
    public func normalizedRadius(_ p: CGPoint) -> Double {
        let dx = Double((p.x - center.x) / a), dy = Double((p.y - center.y) / b)
        return (dx * dx + dy * dy).squareRoot()
    }
    public func contains(_ p: CGPoint) -> Bool { normalizedRadius(p) <= 1 }
    public func onRim(_ p: CGPoint) -> Bool { let r = normalizedRadius(p); return r >= Self.rimStart && r <= 1 }
    /// −1 on the left lobe, +1 on the right lobe, 0 on the midrib (the crease band).
    public func lobe(of p: CGPoint) -> Int {
        if p.x < center.x - ScreenLayout.creaseHalfWidth { return -1 }
        if p.x > center.x + ScreenLayout.creaseHalfWidth { return 1 }
        return 0
    }
    /// A point on the zone's edge at angle `t` radians (0 = right, counter-clockwise), scaled by `r` (1 = the edge).
    public func point(angle t: Double, radius r: Double = 1) -> CGPoint {
        CGPoint(x: center.x + a * CGFloat(cos(t) * r), y: center.y + b * CGFloat(sin(t) * r))
    }
}

// MARK: Colours (platform-neutral so Core stays UIKit-free)

public struct RGBA: Codable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    /// 0xRRGGBB
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255, alpha)
    }
    public func mixed(with other: RGBA, _ t: Double) -> RGBA {
        let k = min(max(t, 0), 1)
        return RGBA(r + (other.r - r) * k, g + (other.g - g) * k, b + (other.b - b) * k, a + (other.a - a) * k)
    }
}

// MARK: Bugs

/// The 16 species (the Bug Book). Raw values are stable ids (persisted, Game Center).
public enum BugSpecies: String, Codable, CaseIterable, Sendable {
    case housefly, gnat, fruitFly, bluebottle, ant, ladybird, grasshopper, moth, mosquito, dragonfly, firefly, cricket
    case goldenScarab, bee, bumblebee, wasp

    /// Bees, bumblebees and wasps: never eat (GAME-DESIGN §5).
    public var isProtected: Bool { self == .bee || self == .bumblebee || self == .wasp }
}

/// A species' fixed data (`BugCatalog` in Core holds all 16).
public struct BugInfo: Codable, Hashable, Sendable {
    public var species: BugSpecies
    public var name: String            // "Housefly"
    public var joke: String            // one short line for the Bug Book
    public var points: Int             // 0 for protected bugs
    /// Seconds: a snap faster than this catches it (before the sipping / flying / rim factors).
    public var reaction: Double
    /// Degrees of slow closure (creep) it tolerates before leaving.
    public var nerve: Double
    /// Art radius in points (touch-free; cosmetic and for crowd spacing).
    public var radius: CGFloat
    /// The first day phase it can appear in.
    public var firstPhase: DayPhase
    public init(species: BugSpecies, name: String, joke: String, points: Int, reaction: Double, nerve: Double,
                radius: CGFloat, firstPhase: DayPhase) {
        self.species = species; self.name = name; self.joke = joke; self.points = points; self.reaction = reaction
        self.nerve = nerve; self.radius = radius; self.firstPhase = firstPhase
    }
}

public enum DayPhase: Int, Codable, CaseIterable, Comparable, Sendable {
    case morning = 0, noon, dusk, night
    public static func < (a: DayPhase, b: DayPhase) -> Bool { a.rawValue < b.rawValue }
}

public enum BugActivity: Equatable, Sendable {
    /// Flying in from the edge (or crossing). `height` in the BugState says how high.
    case arriving
    /// On the surface, walking to a spot.
    case walking
    /// Sipping a nectar drop (distracted: reacts slower). `sipProgress` in BugState.
    case sipping
    /// Hopping (grasshopper, cricket): airborne for a moment.
    case hopping
    /// Taking off and flying out (linger over, or spooked).
    case leaving
    /// In the last bite: being squished into the midrib (`elapsed` s into the 0.5 s caught moment).
    case caught(elapsed: Double)
    /// Escaped the last bite (flies off fast; cosmetic "whiff").
    case escaped
    /// A protected bug let go after being bitten (flies off cross).
    case released
}

public struct BugState: Equatable, Sendable, Identifiable {
    public var id: Int                  // unique within the run
    public var species: BugSpecies
    public var position: CGPoint        // scene space
    /// Radians, the way it faces (0 = right).
    public var heading: Double
    public var activity: BugActivity
    /// 0 = on the surface … 1 = high in the air (drawn larger with a shadow offset).
    public var height: Double
    /// 0…1 while sipping (the gold ring), else 0.
    public var sipProgress: Double
    public var inTrap: Bool
    public var onRim: Bool
    /// 0…1: how close to leaving (linger used up, or creep alarm). Cosmetic tells (twitching wings).
    public var restless: Double
    public init(id: Int, species: BugSpecies, position: CGPoint, heading: Double, activity: BugActivity, height: Double,
                sipProgress: Double = 0, inTrap: Bool, onRim: Bool, restless: Double = 0) {
        self.id = id; self.species = species; self.position = position; self.heading = heading; self.activity = activity
        self.height = height; self.sipProgress = sipProgress; self.inTrap = inTrap; self.onRim = onRim
        self.restless = restless
    }
}

/// A glistening nectar drop on a lobe (bugs land on these to sip).
public struct NectarDrop: Equatable, Sendable, Identifiable {
    public var id: Int
    public var position: CGPoint        // scene space, inside the trap zone
    public var radius: CGFloat
    /// The bug sipping here, if any.
    public var occupant: Int?
    public init(id: Int, position: CGPoint, radius: CGFloat, occupant: Int? = nil) {
        self.id = id; self.position = position; self.radius = radius; self.occupant = occupant
    }
}

// MARK: Modes

public enum RunMode: Codable, Hashable, Sendable {
    /// The main mode: waves until the snaps run out. A fresh seed each run.
    case feed
    /// Everyone's bog for that day (days since 2026-01-01, `DailySeed.dayNumber(for:)`). `scored` = the counted try.
    case daily(day: Int, scored: Bool)
    /// Title screen / CI frames: snaps never run out.
    case attract
    /// The First Bite lesson (the App drives the script with `SessionOptions` and `spawnScripted`).
    case lesson
}

// MARK: Input

/// A snap as detected by the input (hinge: `SnapDetector`; touch: a tap).
public struct SnapTrigger: Equatable, Sendable {
    /// Seconds from the snap start (closure 4°) to the bite (closure `Tuning.snapDepth`). Touch: `Tuning.touchSnapTime`.
    public var duration: Double
    /// The time it fired (CACurrentMediaTime clock).
    public var time: Double
    public init(duration: Double, time: Double) { self.duration = duration; self.time = time }
}

/// The trap as the game sees it, once per frame.
public struct TrapInput: Equatable, Sendable {
    /// Degrees closed from the player's rest reference (0 = open). Drives the drawn teeth.
    public var closure: Double
    /// The trap is open and ready to bite.
    public var armed: Bool
    /// Closing slowly (closure > 6° for > 0.45 s without a snap): twitchy bugs leave.
    public var creeping: Bool
    /// Non-nil on the one frame a snap fired.
    public var snap: SnapTrigger?
    /// θ ≥ 174° (flat): the "bend it a little" hint.
    public var tooFlat: Bool
    /// The filtered hinge angle, if there is a hinge (telemetry, logs).
    public var angle: Double?
    public init(closure: Double = 0, armed: Bool = true, creeping: Bool = false, snap: SnapTrigger? = nil,
                tooFlat: Bool = false, angle: Double? = nil) {
        self.closure = closure; self.armed = armed; self.creeping = creeping; self.snap = snap; self.tooFlat = tooFlat
        self.angle = angle
    }
}

// MARK: Live state

public enum RunPhase: Equatable, Sendable {
    /// The trap is open and bugs come and go.
    case playing
    /// Snaps reached 0: "Your trap is tired." `elapsed` s into the 2.2 s ending, then `.finished`.
    case tired(elapsed: Double)
    case finished
}

/// One short instruction the HUD shows (Core decides which applies; UI owns the words).
public enum TrapHint: String, Codable, Sendable {
    case bendALittle      // tooFlat: "Bend it a little, like a book"
    case quick            // creeping: "Snap it — quick!"
    case openUp           // not armed for > 1 s after a snap: "Open up to reset"
    case beeInside        // a protected bug is sipping in the trap: "Bee! Wait…"
    case crowd            // ≥ 3 bugs sipping and no bee: "Now!"
    case lastSnap         // 1 snap left: "Last snap — make it count"
    case hungry           // R2: a snap wilts within 3 s: "Hungry… bite!"
}

/// The last bite, for the HUD callout and the results.
public struct BiteReport: Equatable, Sendable {
    public var caught: [BugSpecies]
    public var escaped: Int
    /// Protected bugs in the bite (let go).
    public var stingers: [BugSpecies]
    public var points: Int              // after the count and chain multipliers
    public var countMultiplier: Int     // = caught.count
    public var chainMultiplier: Double
    public var snapsBack: Int           // Feast / scarab / ladybird refunds
    public var snapsLost: Int           // stinger costs (beyond the 1 every snap costs)
    public var duration: Double         // the snap's duration
    public var time: Double             // session time of the bite
    public init(caught: [BugSpecies], escaped: Int, stingers: [BugSpecies], points: Int, countMultiplier: Int,
                chainMultiplier: Double, snapsBack: Int, snapsLost: Int, duration: Double, time: Double) {
        self.caught = caught; self.escaped = escaped; self.stingers = stingers; self.points = points
        self.countMultiplier = countMultiplier; self.chainMultiplier = chainMultiplier; self.snapsBack = snapsBack
        self.snapsLost = snapsLost; self.duration = duration; self.time = time
    }
}

/// Everything the scene, HUD and feedback need for one frame. Value type.
public struct TrapSnapshot: Equatable, Sendable {
    public var phase: RunPhase
    public var mode: RunMode
    public var time: Double                 // s since the session began
    public var bugs: [BugState]             // every bug on screen (including caught/escaped ones finishing their moment)
    public var nectar: [NectarDrop]
    public var closure: Double              // degrees (from the input)
    public var armed: Bool
    public var creeping: Bool
    public var snapsLeft: Int
    public var snapsMax: Int
    public var score: Int
    public var best: Int                    // personal best for this mode (0 = none)
    public var chain: Int                   // consecutive productive clean snaps
    public var chainMultiplier: Double      // what the NEXT productive snap gets
    public var wave: Int                    // waves started so far
    public var dayPhase: DayPhase
    /// 0 … 4 continuous through the day (0 morning start, 1 noon start, 2 dusk, 3 night, 4 = deep night) for lighting.
    public var dayClock: Double
    public var lastBite: BiteReport?
    public var hint: TrapHint?
    public var bugsCaught: Int
    public var beesSpared: Int              // protected bugs that came into the trap and left uneaten
    /// R2 hunger: 0 just fed … 1 a snap wilts (GAME-DESIGN §5 "Hunger"). Drives the draining snap glyph.
    public var hunger: Double
    public init(phase: RunPhase = .playing, mode: RunMode = .feed, time: Double = 0, bugs: [BugState] = [],
                nectar: [NectarDrop] = [], closure: Double = 0, armed: Bool = true, creeping: Bool = false,
                snapsLeft: Int = 0, snapsMax: Int = 12, score: Int = 0, best: Int = 0, chain: Int = 0,
                chainMultiplier: Double = 1, wave: Int = 0, dayPhase: DayPhase = .morning, dayClock: Double = 0,
                lastBite: BiteReport? = nil, hint: TrapHint? = nil, bugsCaught: Int = 0, beesSpared: Int = 0,
                hunger: Double = 0) {
        self.phase = phase; self.mode = mode; self.time = time; self.bugs = bugs; self.nectar = nectar
        self.closure = closure; self.armed = armed; self.creeping = creeping; self.snapsLeft = snapsLeft
        self.snapsMax = snapsMax; self.score = score; self.best = best; self.chain = chain
        self.chainMultiplier = chainMultiplier; self.wave = wave; self.dayPhase = dayPhase; self.dayClock = dayClock
        self.lastBite = lastBite; self.hint = hint; self.bugsCaught = bugsCaught; self.beesSpared = beesSpared
        self.hunger = hunger
    }
}

public enum TrapEvent: Equatable, Sendable {
    case waveStarted(index: Int, phase: DayPhase)
    case dayPhaseChanged(DayPhase)
    case bugArrived(id: Int, species: BugSpecies)       // entered the screen
    case bugLanded(id: Int, species: BugSpecies, position: CGPoint, inTrap: Bool)
    case bugSipping(id: Int, species: BugSpecies)
    case bugHopped(id: Int, species: BugSpecies)
    case bugLeft(id: Int, species: BugSpecies)          // flew off the screen (linger over)
    case bugSpooked(id: Int, species: BugSpecies)       // took off because of a creep
    case snapStarted                                    // closure passed 4° while armed (feedback: whoosh)
    /// The bite. Fires with the caught/escaped/released details below in the same step.
    case snapped(BiteReport)
    case bugCaught(id: Int, species: BugSpecies, position: CGPoint)
    case bugEscaped(id: Int, species: BugSpecies)
    case stung(id: Int, species: BugSpecies, cost: Int) // a protected bug was in the bite (let go)
    case drySnap                                        // nothing caught (and no stinger)
    case feast(count: Int, snapsBack: Int)              // ≥ 3 caught
    case luckySnap(species: BugSpecies)                 // ladybird / scarab refund
    case chainUp(count: Int, multiplier: Double)
    case chainBroken(count: Int)                        // a chain of ≥ 2 ended
    case rearmed
    case beeSpared(species: BugSpecies)                 // a protected bug left the trap uneaten
    case lastSnap                                       // snapsLeft reached 1
    /// R2 hunger: 3 s before a snap wilts (once per hunger cycle).
    case hungry(secondsLeft: Double)
    /// R2 hunger: no catching bite for the phase's wilt time, so a snap wilted.
    case wilted(snapsLeft: Int)
    case tired                                          // snapsLeft reached 0
    case newBest                                        // passed the personal best (once per run)
    case finished
}

/// What a finished run produced. Persisted and fed to ranks / achievements / Game Center.
public struct RunResult: Codable, Equatable, Sendable {
    public var mode: RunMode
    public var seed: UInt64
    public var score: Int
    public var seconds: Double
    public var snaps: Int                       // snaps made
    public var bugsCaught: Int
    public var caughtBySpecies: [String: Int]   // BugSpecies.rawValue → count (protected bugs: never present)
    public var sparedBySpecies: [String: Int]   // protected species spared
    public var bestBitePoints: Int
    public var biggestBite: Int                 // most bugs in one bite
    public var longestChain: Int
    public var beesSpared: Int
    public var stings: Int
    public var feasts: Int
    public var waves: Int
    public var drySnaps: Int
    public var fastestSnap: Double              // seconds (hinge only; touch runs report 0)
    public init(mode: RunMode, seed: UInt64, score: Int, seconds: Double, snaps: Int, bugsCaught: Int,
                caughtBySpecies: [String: Int], sparedBySpecies: [String: Int], bestBitePoints: Int, biggestBite: Int,
                longestChain: Int, beesSpared: Int, stings: Int, feasts: Int, waves: Int, drySnaps: Int,
                fastestSnap: Double) {
        self.mode = mode; self.seed = seed; self.score = score; self.seconds = seconds; self.snaps = snaps
        self.bugsCaught = bugsCaught; self.caughtBySpecies = caughtBySpecies; self.sparedBySpecies = sparedBySpecies
        self.bestBitePoints = bestBitePoints; self.biggestBite = biggestBite; self.longestChain = longestChain
        self.beesSpared = beesSpared; self.stings = stings; self.feasts = feasts; self.waves = waves
        self.drySnaps = drySnaps; self.fastestSnap = fastestSnap
    }
}

// MARK: Feedback telemetry (continuous, every frame)

public struct TrapTelemetry: Equatable, Sendable {
    public var closure: Double              // degrees
    public var creeping: Bool
    /// Bugs on screen, for the panned buzz layer: (species, x pan −1…1, height 0…1, activity is flying-ish).
    public var buzzers: [Buzzer]
    public var chain: Int
    public var dayClock: Double
    public var playing: Bool                // false in menus, pauses and the tired moment
    public init(closure: Double = 0, creeping: Bool = false, buzzers: [Buzzer] = [], chain: Int = 0,
                dayClock: Double = 0, playing: Bool = false) {
        self.closure = closure; self.creeping = creeping; self.buzzers = buzzers; self.chain = chain
        self.dayClock = dayClock; self.playing = playing
    }
}

public struct Buzzer: Equatable, Sendable {
    public var id: Int
    public var species: BugSpecies
    public var pan: Double                  // −1 left … 1 right
    public var height: Double               // 0 landed … 1 high
    public var flying: Bool
    public init(id: Int, species: BugSpecies, pan: Double, height: Double, flying: Bool) {
        self.id = id; self.species = species; self.pan = pan; self.height = height; self.flying = flying
    }
}

// MARK: Cross-module protocols

/// Where the trap input comes from (hinge, touch, pilot). Called once per frame on the main actor.
@MainActor public protocol TrapSource: AnyObject {
    func input(at time: TimeInterval) -> TrapInput
}

/// The scene asks the App's controller to advance the game once per frame and forwards taps to it.
@MainActor public protocol SceneDriver: AnyObject {
    /// Advance by `dt` (clamped by the driver) and return the frame to draw plus this frame's events.
    func advance(dt: TimeInterval, now: TimeInterval) -> (TrapSnapshot, [TrapEvent])
    /// A tap anywhere on the scene (scene space). Snaps when there is no hinge; ignored otherwise.
    func sceneTapped(at point: CGPoint, time: TimeInterval)
}

/// Consumes events + telemetry (audio, haptics).
@MainActor public protocol FeedbackSink: AnyObject {
    func handle(_ events: [TrapEvent], telemetry: TrapTelemetry)
}
