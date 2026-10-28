import CoreGraphics
import Foundation

// MARK: - The simulated player (attract mode, CI frames, balance tests)
//
// It only sees what a player sees (the snapshot) and drives the trap the way hands would. R8 (ROUND-8 §1–§2): it closes
// the whole phone. Its angle is Tuning.pilotIdleAngle (150°) − closure; a close runs at a steady rate so the stretch
// from Tuning.closeStart to the shut (θ = Tuning.shutAngle) takes exactly the planned close time (the SnapTrigger's
// duration, fired at the shut), on to Tuning.pilotShutAngle; it holds shut, then reopens over the reopen time (armed
// again at Tuning.armAngle, idle at the top). Deterministic with its seed.
// - Close times by skill (ROUND-8 §2): novice 0.6–1.1 s, casual 0.35–0.65 s, expert 0.2–0.35 s, perfect 0.18 s; it
//   holds shut 0.3–0.6 / 0.2–0.4 / 0.15–0.3 / 0.15 s and reopens over 0.6–0.8 / 0.5–0.7 / 0.4–0.6 / 0.4 s.
// - Decisions (ROUND-1 "TrapPilot"): R8 novice waits for 2 landed (or 1 after Tuning.novicePatience s); casual waits for
//   3 landed, or 2 with nothing else flying in (or 1 worth ≥ 20, or 7 s); expert waits for 3 it can catch at its speed
//   (TrapRules.modelExposure within the reaction), or value ≥ 120, or 2 with one about to leave, or 6 s; perfect waits
//   for 5, or 3 with nothing else about to land, or value ≥ 400, or 7 s. Each decision waits a human reaction delay and
//   is re-checked before the stroke. R4: expert and perfect also bite any landed bug after Tuning.pilotGiveUp (12 s).
// - Bees: each protected bug in the trap is rolled once: missed (ignored) with novice 0.6, casual 0.25, expert 0.02;
//   perfect never misses and also waits while a protected bug is flying low over the trap.
// - R8: the expert and perfect shoo a bee that has sat in the trap (5 s / at once) with a partial close to
//   Tuning.shooDepth° of closure, held until it has gone (at most Tuning.shooHoldMax), then reopen. It never bites.
// - R3 (REVIEW-2 #21): deterministic. Its only randomness is its SeededRandom and its only clock is the sum of its dt,
//   so the same seed and the same dts give the same run; PilotRun steps a pilot and a session in fixed
//   Tuning.pilotStep steps, so a CI capture is the same run whatever the display's frame times.
// Keep in sync with Pilot in tools/balance-sim.js (same draw order).

enum PilotSkill: String, CaseIterable, Sendable {
    case novice, casual, expert, perfect
}

/// A simulated player: drives the closure (so the scene shows the jaws moving) and fires snaps.
struct PilotOutput: Equatable {
    var input: TrapInput
}

struct TrapPilot {

    private struct Profile {
        var closeMin: Double
        var closeMax: Double
        var delayMin: Double
        var delayMax: Double
        var holdMin: Double
        var holdMax: Double
        var reopenMin: Double
        var reopenMax: Double
        var beeMiss: Double

        static func of(_ skill: PilotSkill) -> Profile {
            switch skill {
            case .novice: return Profile(closeMin: 0.6, closeMax: 1.1, delayMin: 0.35, delayMax: 0.6, holdMin: 0.3,
                                         holdMax: 0.6, reopenMin: 0.6, reopenMax: 0.8, beeMiss: Tuning.noviceBeeMiss)
            case .casual: return Profile(closeMin: 0.35, closeMax: 0.65, delayMin: 0.25, delayMax: 0.45, holdMin: 0.2,
                                         holdMax: 0.4, reopenMin: 0.5, reopenMax: 0.7, beeMiss: Tuning.casualBeeMiss)
            case .expert: return Profile(closeMin: 0.2, closeMax: 0.35, delayMin: 0.15, delayMax: 0.3, holdMin: 0.15,
                                         holdMax: 0.3, reopenMin: 0.4, reopenMax: 0.6, beeMiss: Tuning.expertBeeMiss)
            case .perfect: return Profile(closeMin: 0.18, closeMax: 0.18, delayMin: 0.1, delayMax: 0.1, holdMin: 0.15,
                                          holdMax: 0.15, reopenMin: 0.4, reopenMax: 0.4, beeMiss: 0)
            }
        }
    }

    private enum Stage {
        case idle, down, hold, up, shoo, shooHold
    }

    private struct View {
        var landed: Int = 0
        var maxPoints: Int = 0
        var catchable: Int = 0
        var value: Int = 0
        var arriving: Int = 0
        var restless: Double = 0
    }

    /// R8: the closure at the shut (θ = shutAngle), at the bottom of the close, and at the re-arm (θ = armAngle).
    static var shutClosure: Double { return Tuning.pilotIdleAngle - Tuning.shutAngle }
    static var fullClosure: Double { return Tuning.pilotIdleAngle - Tuning.pilotShutAngle }
    static var armClosure: Double { return Tuning.pilotIdleAngle - Tuning.armAngle }

    let skill: PilotSkill
    /// R5 (REVIEW-4 P2): false switches off the Tuning.pilotGiveUp rule (the player model, not the game). The balance
    /// report runs expert and perfect both ways; everything else keeps the default.
    var givesUp: Bool = true
    /// R8 (ROUND-8 §4): a level goal of one bite of n: wait for n (landed for novice and casual, catchable for expert
    /// and perfect), never bite fewer. 0: off.
    var minBite: Int = 0
    /// R8: a level goal's species: one of them landed (novice, casual) or catchable (expert, perfect) is worth a bite.
    var targets: [BugSpecies] = []
    private let profile: Profile
    private var rng: SeededRandom
    private var stage: Stage = .idle
    private var closure: Double = 0
    private var armed: Bool = true
    private var el: Double = 0
    private var duration: Double = 0.3
    private var hold: Double = 0.2
    private var reopen: Double = 0.5
    private var peak: Double = 0
    private var tStart: Double? = nil
    private var closeSince: Double? = nil
    private var decideAt: Double? = nil
    private var beeSince: Double? = nil
    private var missed: [Int: Bool] = [:]
    private var lastSnap: Double = 0
    private var plannedDuration: Double
    /// R3 (REVIEW-2 #21): the pilot's own clock, the sum of the dt it was stepped with. Every decision runs on it,
    /// never on the caller's (wall-clock) time, so the same seed and the same dts give the same run.
    private var clock: Double = 0

    init(skill: PilotSkill, seed: UInt64) {
        self.skill = skill
        let p: Profile = Profile.of(skill)
        self.profile = p
        self.rng = SeededRandom(seed: seed)
        self.plannedDuration = p.closeMin
    }

    private static func isLanded(_ a: BugActivity) -> Bool {
        switch a {
        case .walking, .sipping: return true
        case .arriving, .hopping, .leaving, .caught, .escaped, .released: return false
        }
    }

    private static func isArriving(_ a: BugActivity) -> Bool {
        if case .arriving = a { return true }
        return false
    }

    /// A draw in lo…hi (no draw when they are equal, as in the sim).
    private mutating func pick(_ lo: Double, _ hi: Double) -> Double {
        if lo == hi { return lo }
        return rng.between(lo, hi)
    }

    private mutating func planDuration() -> Double {
        return pick(profile.closeMin, profile.closeMax)
    }

    /// A protected bug sitting in the trap (landed): what a shoo can clear.
    private func beeSitting(_ snap: TrapSnapshot) -> Bool {
        for b in snap.bugs where b.species.isProtected && b.inTrap {
            if TrapPilot.isLanded(b.activity) { return true }
        }
        return false
    }

    private mutating func beeBlocks(_ snap: TrapSnapshot) -> Bool {
        for b in snap.bugs where b.species.isProtected {
            let a: BugActivity = b.activity
            var hopping: Bool = false
            if case .hopping = a { hopping = true }
            if skill == .perfect {
                if b.inTrap && (TrapPilot.isLanded(a) || hopping
                                || (TrapPilot.isArriving(a) && b.height < Tuning.perfectBeeHeight)) {
                    return true
                }
                continue
            }
            if !b.inTrap { continue }
            if !(TrapPilot.isLanded(a) || hopping || (TrapPilot.isArriving(a) && b.height < Tuning.pilotBeeHeight)) {
                continue
            }
            if missed[b.id] == nil { missed[b.id] = rng.chance(profile.beeMiss) }
            if missed[b.id] != true { return true }
        }
        return false
    }

    /// R8: a bug counts as catchable when the planned close's modelled exposure is within its reaction time.
    private func view(_ snap: TrapSnapshot, _ d: Double) -> View {
        var v = View()
        var sum: Int = 0
        for b in snap.bugs {
            if b.species.isProtected || !b.inTrap { continue }
            let a: BugActivity = b.activity
            let info: BugInfo = BugCatalog.info(b.species)
            if TrapPilot.isLanded(a) {
                v.landed += 1
                v.maxPoints = max(v.maxPoints, info.points)
                v.restless = max(v.restless, b.restless)
            }
            if TrapPilot.isArriving(a) && b.height >= Tuning.catchableHeight {
                v.arriving += 1
                continue
            }
            if !TrapRules.isCandidate(a, height: b.height) { continue }
            if TrapPilot.isArriving(a) { v.arriving += 1 }
            var sipping: Bool = false
            if case .sipping = a { sipping = true }
            // R6: the session's pace wave (the Zen Bog never speeds up).
            let r: Double = TrapRules.reaction(info, sipping: sipping, flying: TrapRules.isFlying(a), onRim: b.onRim,
                                               wave: TrapRules.paceWave(snap.wave, mode: snap.mode))
            if TrapRules.modelExposure(nerve: info.nerve, duration: d) <= r {
                v.catchable += 1
                sum += info.points
            }
        }
        v.value = sum * v.catchable
        return v
    }

    /// R8: how many target-species bugs are landed (novice, casual) or catchable at `d` (expert, perfect).
    private func targetCount(_ snap: TrapSnapshot, _ d: Double) -> Int {
        if targets.isEmpty { return 0 }
        var k: Int = 0
        for b in snap.bugs where b.inTrap && targets.contains(b.species) {
            let a: BugActivity = b.activity
            if skill == .novice || skill == .casual {
                if TrapPilot.isLanded(a) { k += 1 }
                continue
            }
            if TrapPilot.isArriving(a) && b.height >= Tuning.catchableHeight { continue }
            if !TrapRules.isCandidate(a, height: b.height) { continue }
            let info: BugInfo = BugCatalog.info(b.species)
            var sipping: Bool = false
            if case .sipping = a { sipping = true }
            let r: Double = TrapRules.reaction(info, sipping: sipping, flying: TrapRules.isFlying(a), onRim: b.onRim,
                                               wave: TrapRules.paceWave(snap.wave, mode: snap.mode))
            if TrapRules.modelExposure(nerve: info.nerve, duration: d) <= r { k += 1 }
        }
        return k
    }

    private mutating func wants(_ snap: TrapSnapshot, _ time: Double) -> Bool {
        let v: View = view(snap, plannedDuration)
        let waited: Double = time - lastSnap
        var want: Bool = false
        if minBite > 0 {
            let count: Int = (skill == .novice || skill == .casual) ? v.landed : v.catchable
            if count < minBite { return false }
            return !beeBlocks(snap)
        }
        if targetCount(snap, plannedDuration) >= 1 { return !beeBlocks(snap) }
        switch skill {
        case .novice:
            want = v.landed >= 2 || (v.landed >= 1 && waited >= Tuning.novicePatience)
        case .casual:
            want = v.landed >= 3 || (v.landed >= 2 && v.arriving == 0) || (v.landed >= 1 && v.maxPoints >= 20)
                || (v.landed >= 1 && waited >= Tuning.casualPatience)
        case .expert:
            want = v.catchable >= 3 || (v.catchable >= 1 && v.value >= Tuning.expertValue)
                || (v.catchable >= 2 && v.restless >= Tuning.expertRestless)
                || (v.catchable >= 1 && waited >= Tuning.expertPatience)
                || (givesUp && v.landed >= 1 && waited >= Tuning.pilotGiveUp)
        case .perfect:
            want = v.catchable >= 5 || (v.catchable >= 3 && v.arriving == 0)
                || (v.catchable >= 3 && v.restless >= Tuning.perfectRestless) || v.value >= Tuning.perfectValue
                || (v.catchable >= 1 && waited >= Tuning.perfectPatience)
                || (givesUp && v.landed >= 1 && waited >= Tuning.pilotGiveUp)
        }
        if !want { return false }
        return !beeBlocks(snap)
    }

    /// One frame of `dt` s. `time` only stamps SnapTrigger.time; every decision uses the pilot's own clock (R3).
    mutating func step(dt: Double, time stamp: Double, snapshot: TrapSnapshot) -> PilotOutput {
        let h: Double = dt.isFinite ? max(0, dt) : 0
        let time: Double = clock
        clock += h
        var fired: SnapTrigger? = nil
        let prev: Double = closure
        var playing: Bool = false
        if case .playing = snapshot.phase { playing = true }
        switch stage {
        case .idle:
            closure = 0
            if playing && armed {
                var shooAfter: Double = 0
                if skill == .perfect { shooAfter = Tuning.perfectShooAfter }
                if skill == .expert { shooAfter = Tuning.expertShooAfter }
                if beeSitting(snapshot) {
                    if beeSince == nil { beeSince = time }
                } else {
                    beeSince = nil
                }
                if shooAfter > 0, let since = beeSince, time - since >= shooAfter {
                    stage = .shoo
                    el = 0
                    decideAt = nil
                    beeSince = nil
                } else if let at = decideAt {
                    if time >= at {
                        decideAt = nil
                        if wants(snapshot, time) {
                            stage = .down
                            el = 0
                            duration = plannedDuration
                            tStart = nil
                            hold = pick(profile.holdMin, profile.holdMax)
                            reopen = pick(profile.reopenMin, profile.reopenMax)
                            plannedDuration = planDuration()
                        }
                    }
                } else if wants(snapshot, time) {
                    decideAt = time + pick(profile.delayMin, profile.delayMax)
                }
            }
        case .shoo:
            el += h
            closure = min(Tuning.shooDepth, Tuning.shooDepth * el / Tuning.shooTime)
            if el >= Tuning.shooTime {
                stage = .shooHold
                el = 0
            }
        case .shooHold:
            el += h
            if !beeSitting(snapshot) || el >= Tuning.shooHoldMax {
                stage = .up
                el = 0
                peak = closure
                reopen = pick(profile.reopenMin, profile.reopenMax)
            }
        case .down:
            el += h
            let rate: Double = (TrapPilot.shutClosure - Tuning.closeStart) / max(1e-6, duration)
            closure = min(TrapPilot.fullClosure, closure + rate * h)
            if tStart == nil && closure >= Tuning.closeStart {
                tStart = SnapDetector.crossing(time - h, prev, time, closure, Tuning.closeStart)
            }
            if armed && closure >= TrapPilot.shutClosure {
                let tShut: Double = SnapDetector.crossing(time - h, prev, time, closure, TrapPilot.shutClosure)
                let start: Double = tStart ?? tShut
                fired = SnapTrigger(duration: max(0, tShut - start), time: stamp.isFinite ? stamp : time)
                armed = false
                lastSnap = time
            }
            if closure >= TrapPilot.fullClosure {
                stage = .hold
                el = 0
            }
        case .hold:
            el += h
            if el >= hold {
                stage = .up
                el = 0
                peak = closure
            }
        case .up:
            el += h
            closure = max(0, peak * (1 - el / max(1e-6, reopen)))
            if !armed && closure <= TrapPilot.armClosure { armed = true }
            if closure <= 0 {
                stage = .idle
                closure = 0
                armed = true
            }
        }
        if armed && closure >= Tuning.closeStart {
            if closeSince == nil { closeSince = time }
        } else {
            closeSince = nil
        }
        var creeping: Bool = false
        if let since = closeSince, time - since > Tuning.slowCloseAfter { creeping = true }
        let input = TrapInput(closure: closure, armed: armed, creeping: creeping, snap: fired, tooFlat: false,
                              angle: Tuning.pilotIdleAngle - closure)
        return PilotOutput(input: input)
    }
}

// MARK: - R3 (REVIEW-2 #21): a deterministic pilot run

/// Steps a pilot and a session in fixed `Tuning.pilotStep` steps of session time, whatever the display's frame time:
/// feed it each frame's dt and it runs as many whole steps as the time buys (the remainder carries to the next frame;
/// at most `Tuning.pilotMaxStepsPerFrame` per frame, so after a long hitch the run falls behind instead of jumping).
/// The run itself is the same sequence of fixed steps every time, so the same session seed and pilot seed give the
/// same bites, scores and Results on any device and any frame rate. CI freezes should key on session time
/// (`snapshot.time`) or on events, never on wall time.
struct PilotRun {
    private(set) var pilot: TrapPilot
    /// Frame time not yet spent on a whole step (s).
    private(set) var carry: Double = 0
    /// The pilot's latest input (draw the jaws from it between steps).
    private(set) var lastInput: TrapInput = TrapInput()
    /// Fixed steps run so far.
    private(set) var stepsRun: Int = 0

    init(pilot: TrapPilot) {
        self.pilot = pilot
    }

    init(skill: PilotSkill, seed: UInt64) {
        self.pilot = TrapPilot(skill: skill, seed: seed)
    }

    /// How many whole fixed steps `dt` s of frame time buys now (the rest is carried).
    mutating func steps(for dt: Double) -> Int {
        let d: Double = dt.isFinite ? max(0, dt) : 0
        carry += d
        var n: Int = Int((carry / Tuning.pilotStep + 1e-9).rounded(.down))
        if n > Tuning.pilotMaxStepsPerFrame {
            n = Tuning.pilotMaxStepsPerFrame
            carry = 0
        } else {
            carry = max(0, carry - Double(n) * Tuning.pilotStep)
        }
        return n
    }

    /// Advances `session` by `dt` s of frame time in fixed steps. Returns every step's events, in order. `stamp` only
    /// stamps SnapTrigger.time.
    mutating func advance(_ session: TrapSession, dt: Double, stamp: Double = 0) -> [TrapEvent] {
        let n: Int = steps(for: dt)
        var out: [TrapEvent] = []
        var i: Int = 0
        while i < n && !session.isFinished {
            let o: PilotOutput = pilot.step(dt: Tuning.pilotStep, time: stamp, snapshot: session.snapshot)
            lastInput = o.input
            out.append(contentsOf: session.step(dt: Tuning.pilotStep, input: o.input))
            stepsRun += 1
            i += 1
        }
        return out
    }
}
