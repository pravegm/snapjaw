import CoreGraphics
import Foundation

// MARK: - The simulated player (attract mode, CI frames, balance tests)
//
// It only sees what a player sees (the snapshot) and drives the trap's closure the way hands would: a snap is a
// linear close at 18° per `duration` (so the 4° → 22° crossing takes exactly `duration`), an overshoot to 28°, a
// 0.15 s hold and a 0.35 s reopen; it re-arms 16° above the peak, like the detector. Deterministic with its seed.
// - Decisions (ROUND-1 "TrapPilot"): novice snaps on any landed bug; casual waits for 2 (or 1 worth ≥ 20, or 4 s);
//   expert waits for 3 it can catch at its speed, or value ≥ 120, or 2 with one about to leave, or 6 s; perfect waits
//   for 5, or 3 with nothing else about to land, or value ≥ 400, or 7 s. Each decision waits a human reaction delay
//   and is re-checked before the stroke.
// - Bees: each protected bug in the trap is rolled once: missed (ignored) with novice 0.6, casual 0.2, expert 0.02;
//   perfect never misses and also waits while a protected bug is flying low over the trap.
// - The novice sometimes creeps (a slow 12° close over 1.2 s before finishing the snap). The expert shoos a bee that
//   has sat in the trap for 5 s with a slow 11° creep (bugs with nerve ≤ the creep depth leave) and reopens.
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
        var durationMin: Double
        var durationMax: Double
        var delayMin: Double
        var delayMax: Double
        var beeMiss: Double

        static func of(_ skill: PilotSkill) -> Profile {
            switch skill {
            case .novice: return Profile(durationMin: 0.22, durationMax: 0.40, delayMin: 0.35, delayMax: 0.6,
                                         beeMiss: Tuning.noviceBeeMiss)
            case .casual: return Profile(durationMin: 0.14, durationMax: 0.24, delayMin: 0.25, delayMax: 0.45,
                                         beeMiss: Tuning.casualBeeMiss)
            case .expert: return Profile(durationMin: 0.10, durationMax: 0.15, delayMin: 0.15, delayMax: 0.3,
                                         beeMiss: Tuning.expertBeeMiss)
            case .perfect: return Profile(durationMin: 0.08, durationMax: 0.08, delayMin: 0.1, delayMax: 0.1,
                                          beeMiss: 0)
            }
        }
    }

    private enum Stage {
        case idle, down, hold, up, shoo
    }

    private struct View {
        var landed: Int = 0
        var maxPoints: Int = 0
        var catchable: Int = 0
        var value: Int = 0
        var arriving: Int = 0
        var restless: Double = 0
    }

    let skill: PilotSkill
    private let profile: Profile
    private var rng: SeededRandom
    private var stage: Stage = .idle
    private var closure: Double = 0
    private var armed: Bool = true
    private var el: Double = 0
    private var duration: Double = 0.2
    private var creepy: Bool = false
    private var peak: Double = 0
    private var t4: Double? = nil
    private var t6: Double? = nil
    private var decideAt: Double? = nil
    private var beeSince: Double? = nil
    private var missed: [Int: Bool] = [:]
    private var lastSnap: Double = 0
    private var plannedDuration: Double

    init(skill: PilotSkill, seed: UInt64) {
        self.skill = skill
        let p: Profile = Profile.of(skill)
        self.profile = p
        self.rng = SeededRandom(seed: seed)
        self.plannedDuration = p.durationMin
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

    private mutating func planDuration() -> Double {
        if profile.durationMin == profile.durationMax { return profile.durationMin }
        return rng.between(profile.durationMin, profile.durationMax)
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
            let r: Double = TrapRules.reaction(info, sipping: sipping, flying: TrapRules.isFlying(a), onRim: b.onRim,
                                               wave: snap.wave)
            if d <= r {
                v.catchable += 1
                sum += info.points
            }
        }
        v.value = sum * v.catchable
        return v
    }

    private mutating func wants(_ snap: TrapSnapshot, _ time: Double) -> Bool {
        let v: View = view(snap, plannedDuration)
        let waited: Double = time - lastSnap
        var want: Bool = false
        switch skill {
        case .novice:
            want = v.landed >= 1
        case .casual:
            want = v.landed >= 2 || (v.landed >= 1 && v.maxPoints >= 20)
                || (v.landed >= 1 && waited >= Tuning.casualPatience)
        case .expert:
            want = v.catchable >= 3 || (v.catchable >= 1 && v.value >= Tuning.expertValue)
                || (v.catchable >= 2 && v.restless >= Tuning.expertRestless)
                || (v.catchable >= 1 && waited >= Tuning.expertPatience)
        case .perfect:
            want = v.catchable >= 5 || (v.catchable >= 3 && v.arriving == 0)
                || (v.catchable >= 3 && v.restless >= Tuning.perfectRestless) || v.value >= Tuning.perfectValue
                || (v.catchable >= 1 && waited >= Tuning.perfectPatience)
        }
        if !want { return false }
        return !beeBlocks(snap)
    }

    mutating func step(dt: Double, time: Double, snapshot: TrapSnapshot) -> PilotOutput {
        let h: Double = dt.isFinite ? max(0, dt) : 0
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
                    peak = Tuning.shooDepth
                    decideAt = nil
                    beeSince = nil
                } else if let at = decideAt {
                    if time >= at {
                        decideAt = nil
                        if wants(snapshot, time) {
                            stage = .down
                            el = 0
                            duration = plannedDuration
                            t4 = nil
                            creepy = skill == .novice && rng.chance(Tuning.noviceCreepChance)
                            peak = Tuning.snapDepth + Tuning.pilotOvershoot
                            plannedDuration = planDuration()
                        }
                    }
                } else if wants(snapshot, time) {
                    let delay: Double = profile.delayMin == profile.delayMax ? profile.delayMin
                        : rng.between(profile.delayMin, profile.delayMax)
                    decideAt = time + delay
                }
            }
        case .shoo:
            el += h
            closure = min(peak, peak * el / Tuning.shooTime)
            if let since = t6, time - since >= Tuning.creepDwell + Tuning.shooHold {
                stage = .up
                el = 0
            }
        case .down:
            el += h
            let rate: Double = (Tuning.snapDepth - Tuning.snapStartDepth) / max(1e-6, duration)
            if creepy && closure < Tuning.noviceCreepDepth && el <= Tuning.noviceCreepTime {
                closure = min(Tuning.noviceCreepDepth, Tuning.noviceCreepDepth * el / Tuning.noviceCreepTime)
            } else {
                closure = min(peak, closure + rate * h)
            }
            if t4 == nil && closure >= Tuning.snapStartDepth {
                t4 = time - h + h * (Tuning.snapStartDepth - prev) / max(1e-9, closure - prev)
            }
            if armed && closure >= Tuning.snapDepth {
                let t22: Double = time - h + h * (Tuning.snapDepth - prev) / max(1e-9, closure - prev)
                let start: Double = t4 ?? t22
                fired = SnapTrigger(duration: max(0, t22 - start), time: time)
                armed = false
                lastSnap = time
            }
            if closure >= peak {
                stage = .hold
                el = 0
            }
        case .hold:
            el += h
            if el >= Tuning.pilotHold {
                stage = .up
                el = 0
            }
        case .up:
            el += h
            closure = max(0, peak * (1 - el / Tuning.pilotReopen))
            if !armed && closure <= peak - Tuning.rearmRise { armed = true }
            if closure <= 0 {
                stage = .idle
                closure = 0
                armed = true
            }
        }
        if closure > Tuning.creepDepth && armed {
            if t6 == nil { t6 = time }
        } else {
            t6 = nil
        }
        var creeping: Bool = false
        if let since = t6, armed, time - since >= Tuning.creepDwell { creeping = true }
        let input = TrapInput(closure: closure, armed: armed, creeping: creeping, snap: fired, tooFlat: false,
                              angle: Tuning.pilotIdleAngle - closure)
        return PilotOutput(input: input)
    }
}
