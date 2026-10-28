import CoreHaptics
import Foundation
import os
import QuartzCore
import UIKit

/// One haptic note: a transient tap or a short continuous buzz (times relative to the cue's start).
struct FeelHapticNote: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case transient, continuous }
    var kind: Kind
    var time: Double
    var intensity: Float
    var sharpness: Float
    var duration: Double

    static func tap(_ intensity: Float, _ sharpness: Float, at time: Double = 0) -> FeelHapticNote {
        FeelHapticNote(kind: .transient, time: time, intensity: intensity, sharpness: sharpness, duration: 0)
    }

    static func buzz(_ intensity: Float, _ sharpness: Float, at time: Double = 0, duration: Double) -> FeelHapticNote {
        FeelHapticNote(kind: .continuous, time: time, intensity: intensity, sharpness: sharpness, duration: duration)
    }
}

/// One point of an intensity-control curve.
struct FeelHapticPoint: Sendable, Equatable {
    var time: Double
    var value: Float
}

/// A haptic cue: notes plus an optional intensity-control curve (it scales every note; after its last point the
/// last value holds).
struct FeelHapticCue: Sendable, Equatable {
    var notes: [FeelHapticNote]
    /// Intensity-control points (time, 0…1 multiplier) applied across the cue (≤ 16); empty = none.
    var curve: [FeelHapticPoint]

    init(notes: [FeelHapticNote], curve: [FeelHapticPoint] = []) {
        self.notes = notes
        self.curve = curve
    }

    /// The end of the last note (s).
    var length: Double {
        notes.map { $0.time + $0.duration }.max() ?? 0
    }

    /// The same cue `offset` s later.
    func delayed(by offset: Double) -> FeelHapticCue {
        let shift = offset.isFinite ? max(offset, 0) : 0
        let moved: [FeelHapticNote] = notes.map { (note: FeelHapticNote) -> FeelHapticNote in
            var later = note
            later.time += shift
            return later
        }
        let points: [FeelHapticPoint] = curve.map { (point: FeelHapticPoint) -> FeelHapticPoint in
            FeelHapticPoint(time: point.time + shift, value: point.value)
        }
        return FeelHapticCue(notes: moved, curve: points)
    }
}

/// Normal or Strong haptics (Swoop Round 3, Hush). Strong is the Duo default: the founder found the Duo's Taptic
/// Engine weak (Squish, real Duo), so Strong turns every tap into a short, rounder burst the actuator can actually
/// push and lifts the continuous creep texture. Off is `FeedbackDirector.hapticsOn = false`.
enum FeelHapticProfile: String, Codable, CaseIterable, Sendable {
    case off, normal, strong

    /// The default before the player chooses: Strong on a phone with a fold (a hinge was seen), Normal elsewhere.
    static func defaultFor(hasFold: Bool) -> FeelHapticProfile {
        hasFold ? .strong : .normal
    }
}

/// The haptic vocabulary of Snapjaw (GAME-DESIGN §10). Pure data, so it is testable.
enum FeelHapticBook {
    // MARK: The Strong profile

    /// Strong: continuous intensity × 1.4 (clamped). Every transient becomes a continuous burst this long, at this
    /// sharpness (rounder = more energy on a small actuator), with its intensity × `strongTapGain` (clamped).
    static let strongContinuousGain: Float = 1.4
    static let strongBurst: Double = 0.055
    static let strongBurstSharpness: Float = 0.4
    static let strongTapGain: Float = 1.15

    /// A cue in the given profile: Normal (and Off, which never plays) unchanged; Strong as above. The curve is kept.
    static func adapt(_ cue: FeelHapticCue, to profile: FeelHapticProfile) -> FeelHapticCue {
        guard profile == .strong else { return cue }
        let notes: [FeelHapticNote] = cue.notes.map { (note: FeelHapticNote) -> FeelHapticNote in
            switch note.kind {
            case .transient:
                return .buzz(min(note.intensity * strongTapGain, 1), strongBurstSharpness, at: note.time,
                             duration: strongBurst)
            case .continuous:
                return .buzz(min(note.intensity * strongContinuousGain, 1), note.sharpness, at: note.time,
                             duration: note.duration)
            }
        }
        return FeelHapticCue(notes: notes, curve: cue.curve)
    }

    // MARK: The creep texture (the leaf stretching under your fingers)

    /// Creep intensity (0…1): 0 unless creeping; 0.15 at the creep line rising to 0.65 at the snap depth
    /// (GAME-DESIGN §10: "intensity ∝ closure while creeping").
    static func creepLevel(closure: Double, creeping: Bool) -> Float {
        guard creeping, closure.isFinite else { return 0 }
        let span = max(Tuning.snapDepth - Tuning.creepDepth, 1)
        let u = FeelMath.clamp01((closure - Tuning.creepDepth) / span)
        return Float(0.15 + 0.5 * u)
    }

    /// The creep for a profile (Strong × 1.4).
    static func creepLevel(closure: Double, creeping: Bool, profile: FeelHapticProfile) -> Float {
        scaled(creepLevel(closure: closure, creeping: creeping), profile: profile)
    }

    /// Home's title trap: the stretch (0…1, `FeelStretchMeter`) as a lighter texture.
    static func stretchLevel(_ stretch: Double, profile: FeelHapticProfile) -> Float {
        scaled(Float(0.4 * FeelMath.clamp01(stretch)), profile: profile)
    }

    static func scaled(_ level: Float, profile: FeelHapticProfile) -> Float {
        switch profile {
        case .off: return 0
        case .normal: return level
        case .strong: return min(level * strongContinuousGain, 1)
        }
    }

    /// The creep texture's sharpness (rubbery, low) and the jitter added at every send: intensity (as a fraction) and
    /// sharpness (±), the stick-slip of a stretching leaf.
    static let creepSharpness: Float = 0.3
    static let creepSharpnessJitter: Float = 0.08
    static let creepIntensityJitter: Float = 0.2

    // MARK: Moments

    /// A bug lands in the trap: a tick by its size (a gnat is a faint, keen tick; a dragonfly a firmer, rounder one).
    static func landing(_ species: BugSpecies) -> FeelHapticCue {
        let u = Float(FeelSoundBook.sizeUnit(species))
        return FeelHapticCue(notes: [.tap(0.2 + 0.35 * u, 0.9 - 0.4 * u)])
    }

    /// Landing ticks are capped at 12 a second.
    static let landingGap = 1.0 / 12

    /// The rumble under a CHOMP: 90 ms, plus 20 ms per bug (up to 6).
    static func rumbleLength(caught: Int) -> Double {
        0.09 + 0.02 * Double(min(max(caught, 0), 6))
    }

    /// R3: the rumble floor of a 1–2 bug CHOMP (was 0.84 for one bug). Under 0.9, so its held clamp (+0.1) stays below
    /// a big bite's full 1.0: a bigger bite still rumbles harder.
    static let smallBiteStrength: Float = 0.88

    /// The CHOMP: the strongest transient the phone has (1.0), then (R2) a deep, held **clamp** for the Scene's 50 ms
    /// hit-stop (the lobes pressed shut), the second tooth's tap on the sound's clack, and a heavy rumble that fades in
    /// three steps after the hit-stop (90 ms + 20 ms per bug, stronger with more bugs); one keen crunch tap per caught
    /// bug (up to 5, on the sound's crunches, after the hit-stop); the gulp's soft thud. No intensity curve (it would
    /// scale the later taps too): the fade is built from the steps.
    static func chomp(caught: Int) -> FeelHapticCue {
        let n = min(max(caught, 0), 8)
        let rumble = rumbleLength(caught: n)
        let small = n >= 1 && n <= FeelSoundBook.smallBite
        var strength = min(0.8 + 0.04 * Float(n), 1)
        // R3: a small bite still has weight (a firmer rumble floor, and a settle tap on the sound's "nom").
        if small { strength = max(strength, smallBiteStrength) }
        let third = rumble / 3
        let hold = Double(FeelSoundBook.hitStop)
        let clack = Double(FeelSoundBook.clackAt + FeelSoundBook.clackGap)
        var notes: [FeelHapticNote] = [
            .tap(1.0, 0.55),
            .buzz(min(strength + 0.1, 1), 0.05, duration: hold),
            .buzz(strength, 0.12, at: hold, duration: third),
            .buzz(strength * 0.7, 0.12, at: hold + third, duration: third),
            .buzz(strength * 0.4, 0.12, at: hold + 2 * third, duration: third),
            .tap(0.75, 0.9, at: clack),
        ]
        if small {
            notes.append(.tap(0.6, 0.35, at: hold))
        }
        for index in 0..<min(n, 5) {
            notes.append(.tap(0.35, 1.0, at: Double(FeelSoundBook.crunchDelay(index: index))))
        }
        if n > 0 {
            notes.append(.tap(0.3, 0.2, at: Double(FeelSoundBook.gulpAt)))
        }
        return FeelHapticCue(notes: notes)
    }

    /// The empty clap: firm but lighter than any CHOMP, short.
    static let drySnap = FeelHapticCue(notes: [
        .tap(0.8, 0.6), .tap(0.5, 0.9, at: Double(FeelSoundBook.clackAt + FeelSoundBook.clackGap)),
        .buzz(0.4, 0.15, duration: 0.04),
    ])

    /// Feast: a double tap with the sparkle.
    static let feast = FeelHapticCue(notes: [
        .tap(0.7, 0.8, at: Double(FeelSoundBook.feastAt)), .tap(0.85, 0.9, at: Double(FeelSoundBook.feastAt) + 0.1),
    ])

    /// A sting: a buzzy wobble (six 35 ms segments alternating strong and weak, keen) after a firm tap. R3: `heavy` (a
    /// sting that cost snaps) hits harder: a firmer tap, a deeper wobble, and a low thud as the snap goes.
    /// R5 (REVIEW-4 #7): `wasp` wobbles heavier (see `waspSting`).
    static func sting(at start: Double = 0, heavy: Bool = false, wasp: Bool = false) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        if wasp { return waspSting(at: begin, heavy: heavy) }
        var notes: [FeelHapticNote] = [.tap(heavy ? 0.85 : 0.6, heavy ? 0.45 : 0.5, at: begin)]
        for index in 0..<6 {
            let strong = index % 2 == 0
            let level: Float = strong ? (heavy ? 0.95 : 0.85) : (heavy ? 0.45 : 0.35)
            notes.append(.buzz(level, heavy ? 0.75 : 0.9, at: begin + 0.035 * Double(index), duration: 0.035))
        }
        if heavy {
            notes.append(.buzz(0.6, 0.1, at: begin + 0.21, duration: 0.08))
        }
        return FeelHapticCue(notes: notes)
    }

    /// R5: the wasp's second zap, this long after its first (FeelSoundBook.sting zaps a wasp twice, 0.14 s apart).
    static let waspZapGap: Double = 0.14
    /// R5: a wasp's wobble segments (each `waspSegment` s; four per zap).
    static let waspSegment: Double = 0.035

    /// R5 (REVIEW-4 #7): a wasp's sting is heavier than a bee's, so the −2 is felt: a firmer, rounder tap on each of
    /// its two zaps; eight deeper, rounder wobble segments (four per zap) where a bee has six; and, when it cost snaps
    /// (`heavy`), two low thuds as its two snaps go.
    static func waspSting(at begin: Double, heavy: Bool) -> FeelHapticCue {
        var notes: [FeelHapticNote] = []
        for zap in 0..<2 {
            let zapStart = begin + waspZapGap * Double(zap)
            notes.append(.tap(heavy ? 0.95 : 0.75, 0.4, at: zapStart))
            for index in 0..<4 {
                let strong = index % 2 == 0
                let level: Float = strong ? (heavy ? 1.0 : 0.9) : (heavy ? 0.55 : 0.45)
                notes.append(.buzz(level, heavy ? 0.6 : 0.7, at: zapStart + waspSegment * Double(index),
                                   duration: waspSegment))
            }
        }
        if heavy {
            let end = begin + waspZapGap + 4 * waspSegment
            notes.append(.buzz(0.7, 0.1, at: end, duration: 0.08))
            notes.append(.buzz(0.55, 0.1, at: end + 0.12, duration: 0.08))
        }
        return FeelHapticCue(notes: notes)
    }

    /// R3: the loss blip's touch: two falling taps (firm then duller) on its two notes.
    static func snapLost(at start: Double = 0) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        return FeelHapticCue(notes: [.tap(0.6, 0.6, at: begin),
                                     .tap(0.5, 0.25, at: begin + Double(FeelSoundBook.lostSpacing))])
    }

    /// R3: the free first bee's "oops": two light taps that end keener (nothing lost).
    static func oops(at start: Double = 0) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        return FeelHapticCue(notes: [.tap(0.25, 0.6, at: begin), .tap(0.3, 0.9, at: begin + 0.11)])
    }

    /// R3: the chain's ×5 flare: four quick taps rising in strength and keenness with the chord's roll.
    static func chainFlare(at start: Double = 0) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        var notes: [FeelHapticNote] = []
        for index in 0..<4 {
            let u = Float(index) / 3
            notes.append(.tap(0.45 + 0.4 * u, 0.7 + 0.3 * u, at: begin + 0.035 * Double(index)))
        }
        return FeelHapticCue(notes: notes)
    }

    /// A lucky refund: two keen sparkle taps.
    static func lucky(at start: Double = Double(FeelSoundBook.luckyAt)) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        return FeelHapticCue(notes: [.tap(0.5, 1.0, at: begin), .tap(0.4, 1.0, at: begin + 0.07)])
    }

    /// Re-armed: one light, low tick.
    static let rearm = FeelHapticCue(notes: [.tap(0.25, 0.4)])
    /// A bee spared: the faintest keen "thank you".
    static let spared = FeelHapticCue(notes: [.tap(0.22, 0.9)])

    /// The last snap: two soft low nudges.
    static func lastSnap(at start: Double = 0) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        return FeelHapticCue(notes: [.tap(0.45, 0.3, at: begin), .tap(0.45, 0.3, at: begin + 0.16)])
    }

    /// Tired: a slow, sinking hum (three fading steps).
    static func tired(at start: Double = 0) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        return FeelHapticCue(notes: [
            .buzz(0.4, 0.1, at: begin, duration: 0.2), .buzz(0.25, 0.1, at: begin + 0.2, duration: 0.2),
            .buzz(0.12, 0.1, at: begin + 0.4, duration: 0.2),
        ])
    }

    static func newBest(at start: Double = 0) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        return FeelHapticCue(notes: [.tap(0.4, 0.8, at: begin), .tap(0.5, 0.9, at: begin + 0.085),
                                     .tap(0.65, 0.95, at: begin + 0.17)])
    }

    // MARK: Hunger (R2)

    /// Hungry: a stomach rumble. Four soft, very round grumbles (low sharpness), uneven like a real tummy.
    static let hungry = FeelHapticCue(notes: [
        .buzz(0.35, 0.05, duration: 0.14), .buzz(0.18, 0.05, at: 0.16, duration: 0.1),
        .buzz(0.4, 0.08, at: 0.3, duration: 0.2), .buzz(0.2, 0.05, at: 0.52, duration: 0.12),
    ])

    /// Wilted: a weak, sinking droop. R3: clearer, on the sound's two sighs: a soft round tap and a short step on the
    /// first, then three fading soft steps on the second. Weaker than the last-snap nudges.
    static func wilted(at start: Double = 0) -> FeelHapticCue {
        let begin = start.isFinite ? max(start, 0) : 0
        let second = begin + Double(FeelSoundBook.wiltSecondSigh)
        return FeelHapticCue(notes: [
            .tap(0.38, 0.25, at: begin), .buzz(0.25, 0.1, at: begin, duration: 0.1),
            .buzz(0.32, 0.1, at: second, duration: 0.12), .buzz(0.18, 0.1, at: second + 0.12, duration: 0.14),
            .buzz(0.08, 0.1, at: second + 0.26, duration: 0.16),
        ])
    }

    // MARK: One frame, one pattern (QA-1 #18)

    /// Every cue without an intensity curve folded into one cue (notes in time order), so a bite frame builds one
    /// pattern and one player instead of about seven. Cues with a curve stay separate (a curve scales its whole
    /// pattern). Empty cues are dropped.
    static func merge(_ cues: [FeelHapticCue]) -> [FeelHapticCue] {
        var plain: [FeelHapticNote] = []
        var curved: [FeelHapticCue] = []
        for cue in cues where !cue.notes.isEmpty {
            if cue.curve.isEmpty {
                plain.append(contentsOf: cue.notes)
            } else {
                curved.append(cue)
            }
        }
        var merged: [FeelHapticCue] = []
        if !plain.isEmpty {
            let sorted = plain.sorted { (a: FeelHapticNote, b: FeelHapticNote) -> Bool in a.time < b.time }
            merged.append(FeelHapticCue(notes: sorted))
        }
        merged.append(contentsOf: curved)
        return merged
    }

    static let uiTap = FeelHapticCue(notes: [.tap(0.35, 0.7)])
    static let uiConfirm = FeelHapticCue(notes: [.tap(0.5, 0.8), .tap(0.4, 0.9, at: 0.06)])
    static let celebrate = FeelHapticCue(notes: [.tap(0.5, 0.6), .tap(0.6, 0.7, at: 0.09), .tap(0.75, 0.8, at: 0.18),
                                                 .tap(0.95, 0.9, at: 0.3)])
}

/// Core Haptics for Snapjaw: one looping advanced player carries the continuous feel (the creep texture, steered by
/// dynamic parameters at ≤ 30 Hz with ramps, so there is no zipper), and every moment plays as its own short pattern.
/// Self-healing after stops and server resets (Squish's/Brim's/Swoop's/Hush's pattern). Phones without Core Haptics
/// fall back to `UIImpactFeedbackGenerator` for the moments.
@MainActor
final class FeelHaptics {
    private static let log = Logger(subsystem: "com.pravegm.snapjaw", category: "haptics")

    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            if enabled {
                guard wantsStart else { return }
                if engine == nil { start() } else { restart() }
            } else {
                // Switched off mid-session: the hardware goes to sleep at once.
                setContinuous(level: 0, now: CACurrentMediaTime(), force: true)
                stopPlayers()
                if let engine, isRunning { engine.stop(completionHandler: nil) }
                isRunning = false
            }
        }
    }

    /// Normal or Strong (Off is `enabled = false`, set by the director).
    var profile: FeelHapticProfile = .normal

    /// Menus and long pauses: no looping player, and the engine may shut the hardware down by itself. A cue still
    /// plays (the engine is started again for it). Off: the player is rebuilt at once.
    var idle = false {
        didSet {
            guard oldValue != idle else { return }
            if idle {
                stopPlayers()
                engine?.isAutoShutdownEnabled = true
            } else {
                engine?.isAutoShutdownEnabled = false
                if engine != nil && (!isRunning || creepPlayer == nil) { restart() }
            }
        }
    }

    private let supportsHaptics: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var creepPlayer: CHHapticAdvancedPatternPlayer?
    private var isRunning = false
    private var wantsStart = false
    private var lastRecovery: CFTimeInterval = 0
    private var lastSend: CFTimeInterval = 0
    private var lastLevel: Float = 0
    private var dice = FeelDice(seed: 0x534E_4150)
    private var fallbackLight: UIImpactFeedbackGenerator?
    private var fallbackMedium: UIImpactFeedbackGenerator?
    private var fallbackHeavy: UIImpactFeedbackGenerator?
    private(set) var lastError: String?

    init() {}

    /// Idempotent. Does nothing while haptics are off (it starts when they are switched on).
    func start() {
        wantsStart = true
        guard enabled else { return }
        guard supportsHaptics else {
            prepareFallback()
            return
        }
        guard engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = idle
            // Both handlers arrive on an engine-internal queue: hop to the main actor.
            engine.stoppedHandler = { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.creepPlayer = nil
                }
            }
            engine.resetHandler = { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.creepPlayer = nil
                    self.restart()
                }
            }
            self.engine = engine
            restart()
        } catch {
            record("Couldn't create the haptic engine", error)
            engine = nil
        }
    }

    /// The app became active again: the system stops the engine on suspension.
    func resume() {
        guard supportsHaptics, enabled, wantsStart else { return }
        if engine == nil {
            start()
        } else if !isRunning || (!idle && creepPlayer == nil) {
            restart()
        }
    }

    /// Throttled recovery from the frame loop.
    func heal() {
        guard enabled, engine != nil, !isRunning || (!idle && creepPlayer == nil) else { return }
        guard UIApplication.shared.applicationState != .background else { return }
        restart()
    }

    private func restart() {
        guard enabled, let engine else { return }
        do {
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
            record("Couldn't start the haptic engine", error)
            return
        }
        creepPlayer = nil
        // Menus have no trap in play: no looping player to keep the hardware awake.
        if idle { return }
        do {
            creepPlayer = try makeLoopingPlayer(sharpness: FeelHapticBook.creepSharpness)
            lastLevel = 0
        } catch {
            record("Couldn't build the continuous haptics", error)
        }
    }

    private func stopPlayers() {
        if let player = creepPlayer { try? player.stop(atTime: CHHapticTimeImmediate) }
        creepPlayer = nil
        lastLevel = 0
    }

    /// One looping continuous event at intensity 1; the intensity control scales it (starts at 0).
    private func makeLoopingPlayer(sharpness: Float) throws -> CHHapticAdvancedPatternPlayer? {
        guard let engine else { return nil }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: 30
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makeAdvancedPlayer(with: pattern)
        player.loopEnabled = true
        let zero = [CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0, relativeTime: 0)]
        try player.sendParameters(zero, atTime: CHHapticTimeImmediate)
        try player.start(atTime: CHHapticTimeImmediate)
        try player.sendParameters(zero, atTime: CHHapticTimeImmediate)
        return player
    }

    // MARK: - Per frame

    /// The continuous feel: call every frame with the creep (or Home stretch) level, already profile-scaled (0 fades
    /// it out). Sends at most ~30 times a second, ramping between values (no zipper); while on, every send carries a
    /// little intensity and sharpness jitter (the stretching leaf's stick-slip).
    func update(level: Float, now: CFTimeInterval) {
        let wanted: Float = enabled && level.isFinite ? min(max(level, 0), 1) : 0
        setContinuous(level: wanted, now: now, force: false)
    }

    /// Fade the continuous feel to nothing.
    func quiet(now: CFTimeInterval) {
        setContinuous(level: 0, now: now, force: false)
    }

    private func setContinuous(level: Float, now: CFTimeInterval, force: Bool) {
        guard isRunning, let creepPlayer else { return }
        let silencing = level == 0 && lastLevel > 0
        let changed = level > 0
        guard force || silencing || changed else { return }
        guard force || silencing || now - lastSend >= 1.0 / 30 else { return }
        lastSend = now
        var intensity = level
        var keen = FeelHapticBook.creepSharpness
        if level > 0 {
            intensity = min(max(level * (1 + FeelHapticBook.creepIntensityJitter * Float(dice.range(-1, 1))), 0), 1)
            keen = min(max(keen + FeelHapticBook.creepSharpnessJitter * Float(dice.range(-1, 1)), 0), 1)
        }
        let ramp: TimeInterval = silencing ? 0.06 : 1.0 / 30
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: lastLevel),
                CHHapticParameterCurve.ControlPoint(relativeTime: ramp, value: intensity),
            ],
            relativeTime: 0
        )
        try? creepPlayer.scheduleParameterCurve(curve, atTime: CHHapticTimeImmediate)
        // Sharpness control is an offset from the event's own sharpness.
        try? creepPlayer.sendParameters([CHHapticDynamicParameter(parameterID: .hapticSharpnessControl,
                                                                  value: keen - FeelHapticBook.creepSharpness,
                                                                  relativeTime: 0)],
                                        atTime: CHHapticTimeImmediate)
        lastLevel = intensity
    }

    // MARK: - Moments

    func play(_ cue: FeelHapticCue) {
        guard enabled, !cue.notes.isEmpty else { return }
        guard supportsHaptics else {
            playFallback(cue)
            return
        }
        if !isRunning || engine == nil {
            let now = CACurrentMediaTime()
            if now - lastRecovery > 0.5 {
                lastRecovery = now
                resume()
            }
        }
        guard let engine, isRunning else { return }
        do {
            let player = try engine.makePlayer(with: try Self.pattern(for: cue))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            record("Couldn't play a haptic", error)
        }
    }

    /// The Core Haptics pattern for a cue.
    private static func pattern(for cue: FeelHapticCue) throws -> CHHapticPattern {
        let events: [CHHapticEvent] = cue.notes.map { (note: FeelHapticNote) -> CHHapticEvent in
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(note.intensity, 0), 1))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(note.sharpness, 0), 1))
            switch note.kind {
            case .transient:
                return CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness],
                                     relativeTime: note.time)
            case .continuous:
                return CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness],
                                     relativeTime: note.time, duration: max(note.duration, 0.01))
            }
        }
        var curves: [CHHapticParameterCurve] = []
        if !cue.curve.isEmpty {
            var points: [CHHapticParameterCurve.ControlPoint] = []
            for point in cue.curve.prefix(16) {
                points.append(CHHapticParameterCurve.ControlPoint(relativeTime: point.time, value: point.value))
            }
            curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points,
                                                 relativeTime: 0))
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }

    // MARK: - Fallback (no Core Haptics)

    private func prepareFallback() {
        if fallbackLight == nil { fallbackLight = UIImpactFeedbackGenerator(style: .light) }
        if fallbackMedium == nil { fallbackMedium = UIImpactFeedbackGenerator(style: .medium) }
        if fallbackHeavy == nil { fallbackHeavy = UIImpactFeedbackGenerator(style: .heavy) }
        fallbackLight?.prepare()
        fallbackMedium?.prepare()
        fallbackHeavy?.prepare()
    }

    /// Up to three notes of the cue as impacts (a buzz plays as one impact at its start).
    private func playFallback(_ cue: FeelHapticCue) {
        prepareFallback()
        let notes = Array(cue.notes.sorted { $0.time < $1.time }.prefix(3))
        for note in notes {
            let intensity = CGFloat(min(max(note.intensity, 0.05), 1))
            let generator: UIImpactFeedbackGenerator?
            if note.intensity >= 0.75 {
                generator = fallbackHeavy
            } else if note.intensity >= 0.4 {
                generator = fallbackMedium
            } else {
                generator = fallbackLight
            }
            guard let generator else { continue }
            if note.time <= 0.005 {
                generator.impactOccurred(intensity: intensity)
            } else {
                let delay = UInt64(note.time * 1_000_000_000)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: delay)
                    generator.impactOccurred(intensity: intensity)
                }
            }
        }
    }

    private func record(_ what: String, _ error: Error) {
        let nsError = error as NSError
        let message = "\(what): \(nsError.localizedDescription) (code \(nsError.code))"
        lastError = message
        Self.log.error("\(message, privacy: .public)")
    }
}
