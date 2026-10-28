import Foundation

// MARK: - The hinge rule: the lid is the jaw (R8, ROUND-8 §1 with the founder's binding hinge rules)
//
// Feed it filtered hinge samples (degrees, 180 = flat) with their sample times and, when known, the hinge status.
// - A shut phone is a closed trap; any opening is open. ARMED (open) once θ ≥ Tuning.armAngle (35°). A phone at 90° is
//   open, never closed.
// - The SHUT ZONE: θ ≤ Tuning.shutAngle (18°), or the status `.closed` with θ ≤ Tuning.statusShutAngle (25°; hardware
//   reads `.closed` from ~85°, so the status alone is never trusted).
// - The open reference = the highest θ over Tuning.refWindow (0.6 s), falling at most Tuning.refFallRate (25 °/s),
//   held (never falling) while a close is under way. closure = reference − θ (≥ 0), continuous.
// - A CLOSE starts when the closure passes Tuning.closeStart (8°) while armed (the crossing time is interpolated). It
//   is abandoned when the closure falls back under Tuning.closeCancel (4°) or the phone opens Tuning.reopenCancel (10°)
//   above the close's lowest θ; the reference then starts again from θ. A partial close, however deep, never bites.
// - THE BITE: once per arm, on the sample that reaches the shut zone while armed: a SnapTrigger with duration = the
//   shut (the interpolated 18° crossing; the sample time for a status shut) − the close's start. A shut with no close
//   start seen (a creep slower than the reference's fall) is Tuning.untimedCloseDuration (a slow close). Then unarmed.
// - RE-ARM at θ ≥ armAngle (the hysteresis: shut ≤ 18°, open ≥ 35°). The reference restarts at θ.
//   R9 (real hardware: about ±5° and noisy reports, `.closed` from ~85°): after a shut the re-arm also needs θ at least
//   Tuning.rearmRise (15°) above the lowest θ since that shut (`rearmAngle`), so a phone hovering where a `.closed`
//   status shut (25°) and the 35° re-arm are only 10° apart can't flap bite–arm–bite on report noise. A full close
//   (lowest ≤ 20°) still re-arms at 35° exactly.
// - While unarmed after a bite the reported closure is measured from the reference at the bite.
// - `requireShut` (a round's start, founder rule 3): the trap is not armed until the phone has been shut once and then
//   opened to the re-arm angle. R9: for the round's start "shut" is lenient (`isStartShut`: the shut zone, or
//   θ ≤ Tuning.startShutAngle 25° whatever the status), so a closed phone that reads a little high can never leave
//   "Close the phone to start" stuck. That starting close never bites (the trap is not armed during it). Without
//   requireShut a fresh detector is armed at once when θ ≥ armAngle (R9: unless it was built with `rearmLow`, which
//   carries an unarmed-after-a-shut state across a restart).
// - R9 `noteFolded(at:)`: independent evidence that the phone is folded (the app is on the outer display): a round
//   waiting for its first close counts as closed, and the latest angle is read as `.closed` (a bite only at ≤ 25°).
// - No samples arrive while the hinge is still, so `input(at:)` advances the reference to the frame time.
// - Founder rule 2 (no pose demands): `tooFlat` is always false.
// Mirrored by SnapDetector in tools/balance-sim.js (`node tools/balance-sim.js detector=1`).

struct SnapDetector {

    /// The highest θ over a sliding window, falling at most `fallRate` °/s when the maximum leaves the window, unless
    /// held.
    private struct RollingMax {
        let window: Double
        let fallRate: Double
        private(set) var value: Double = 0
        private var times: [Double] = []
        private var angles: [Double] = []
        private var last: Double = 0

        init(window: Double, fallRate: Double) {
            self.window = window
            self.fallRate = fallRate
        }

        mutating func reset(time: Double, angle: Double) {
            times = [time]
            angles = [angle]
            value = angle
            last = time
        }

        mutating func add(time: Double, angle: Double, hold: Bool) {
            times.append(time)
            angles.append(angle)
            update(time: time, hold: hold)
        }

        mutating func update(time: Double, hold: Bool) {
            while times.count > 1 && times[0] < time - window {
                times.removeFirst()
                angles.removeFirst()
            }
            var w: Double = -Double.infinity
            for a in angles where a > w { w = a }
            let dt: Double = max(0, time - last)
            last = max(last, time)
            if w >= value {
                value = w
            } else if !hold {
                value = max(w, value - fallRate * dt)
            }
        }
    }

    private var ref = RollingMax(window: Tuning.refWindow, fallRate: Tuning.refFallRate)
    private var hasSample: Bool = false
    private var angle: Double = 0
    /// Closure at the previous sample (for the crossing interpolation).
    private var lastClosure: Double = 0
    private var prevTime: Double = 0
    private(set) var armed: Bool = false
    /// A close is under way (closure passed closeStart while armed).
    private(set) var closing: Bool = false
    private var closeStartAt: Double = 0
    private var lowest: Double = 0
    private var snapReference: Double = 0
    private var biteSeen: Bool = false
    private var pending: SnapTrigger? = nil
    /// True until the phone has been shut once (only when built with `requireShut`).
    private(set) var waitingForShut: Bool
    /// R9: the lowest θ since the trap was last shut (a bite, a round's starting close, or a fresh detector on a shut
    /// phone) while it is not yet armed again; nil while armed or before any shut.
    private(set) var rearmLow: Double?

    /// `requireShut`: a round's start (the trap is closed until the phone is shut once and opened). R9 `rearmLow`: a
    /// restarted detector that carries an unarmed-after-a-shut state (HingeTrapSource's reset), so a restart never
    /// re-arms a shut trap below its re-arm angle. Ignored with requireShut.
    init(requireShut: Bool = false, rearmLow: Double? = nil) {
        self.waitingForShut = requireShut
        var low: Double? = nil
        if !requireShut, let l = rearmLow, l.isFinite { low = l }
        self.rearmLow = low
    }

    /// R9: the angle the trap (re-)arms at now: Tuning.armAngle, or rearmLow + Tuning.rearmRise when that is higher.
    var rearmAngle: Double {
        guard let low = rearmLow else { return Tuning.armAngle }
        return max(Tuning.armAngle, low + Tuning.rearmRise)
    }

    /// The open reference θ. 0 before the first sample.
    var reference: Double { return hasSample ? ref.value : 0 }
    /// The latest angle, if any sample arrived.
    var latestAngle: Double? { return hasSample ? angle : nil }

    /// Is (θ, status) in the shut zone?
    static func isShut(angle a: Double, status: TrapHingeStatus) -> Bool {
        if a <= Tuning.shutAngle { return true }
        switch status {
        case .closed: return a <= Tuning.statusShutAngle
        case .partiallyOpen, .fullyOpen, .unknown: return false
        }
    }

    /// R9: closed enough to start a round (founder rule 3): the shut zone, or θ ≤ Tuning.startShutAngle whatever the
    /// status. Only the round's start uses it; the bite needs `isShut`.
    static func isStartShut(angle a: Double, status: TrapHingeStatus) -> Bool {
        return a <= Tuning.startShutAngle || SnapDetector.isShut(angle: a, status: status)
    }

    /// Feed one (filtered) angle sample at `time`. Returns a trigger on the sample that reaches the shut zone while
    /// armed.
    mutating func ingest(angle a: Double, at time: Double, status: TrapHingeStatus = .unknown) -> SnapTrigger? {
        guard a.isFinite, time.isFinite else { return nil }
        let shutNow: Bool = SnapDetector.isShut(angle: a, status: status)
        if !hasSample {
            hasSample = true
            ref.reset(time: time, angle: a)
            angle = a
            lastClosure = 0
            prevTime = time
            if waitingForShut && SnapDetector.isStartShut(angle: a, status: status) {
                waitingForShut = false
                rearmLow = a
            } else if !waitingForShut && (shutNow || rearmLow != nil) {
                rearmLow = min(rearmLow ?? a, a)
            }
            armed = !waitingForShut && a >= rearmAngle && !shutNow
            if armed { rearmLow = nil }
            return nil
        }
        let prevAngle: Double = angle
        ref.add(time: time, angle: a, hold: armed && closing)
        var c: Double = max(0, ref.value - a)
        var fired: SnapTrigger? = nil
        if !armed {
            if waitingForShut && SnapDetector.isStartShut(angle: a, status: status) {
                waitingForShut = false
                rearmLow = a
            }
            if let low = rearmLow { rearmLow = min(low, a) }
            if !waitingForShut && a >= rearmAngle {
                armed = true
                rearmLow = nil
                closing = false
                ref.reset(time: time, angle: a)
                c = 0
            }
        } else {
            if !closing {
                if c >= Tuning.closeStart {
                    closing = true
                    lowest = a
                    closeStartAt = SnapDetector.crossing(prevTime, lastClosure, time, c, Tuning.closeStart)
                }
            } else {
                lowest = min(lowest, a)
                if c < Tuning.closeCancel || a - lowest >= Tuning.reopenCancel {
                    // Opened again: the close is over, and the reference starts again from here.
                    closing = false
                    ref.reset(time: time, angle: a)
                    c = 0
                }
            }
            if shutNow {
                var tShut: Double = time
                if a <= Tuning.shutAngle && prevAngle > Tuning.shutAngle {
                    tShut = SnapDetector.crossing(prevTime, -prevAngle, time, -a, -Tuning.shutAngle)
                }
                let d: Double = closing ? max(0, tShut - closeStartAt) : Tuning.untimedCloseDuration
                let trigger = SnapTrigger(duration: d, time: time)
                fired = trigger
                pending = trigger
                armed = false
                closing = false
                biteSeen = true
                snapReference = ref.value
                rearmLow = a
            }
        }
        lastClosure = c
        prevTime = time
        angle = a
        return fired
    }

    /// R9: the phone is folded by other evidence (the app is on the outer display) with no shut report seen. A round
    /// waiting for its first close counts as closed (never a bite); otherwise the latest angle is fed again as
    /// `.closed` at `time` (a bite if armed and θ ≤ Tuning.statusShutAngle, exactly as that status would be). Returns
    /// the trigger, if any. No sample yet: nothing.
    mutating func noteFolded(at time: Double) -> SnapTrigger? {
        guard hasSample, time.isFinite else { return nil }
        if waitingForShut {
            waitingForShut = false
            armed = false
            closing = false
            rearmLow = angle
            return nil
        }
        return ingest(angle: angle, at: max(time, prevTime), status: .closed)
    }

    /// The input for a frame at `time` (closure, armed, creeping = a slow close; `snap` is whatever `ingest` last
    /// returned and has not been consumed — consumed by this call). No sample yet: an open, armed trap.
    mutating func input(at time: Double) -> TrapInput {
        if hasSample && time.isFinite {
            ref.update(time: time, hold: armed && closing)
        }
        var closure: Double = 0
        if hasSample {
            if armed {
                closure = max(0, ref.value - angle)
            } else if biteSeen {
                closure = max(0, snapReference - angle)
            }
        }
        var creeping: Bool = false
        if hasSample && armed && closing && time.isFinite && time - closeStartAt > Tuning.slowCloseAfter {
            creeping = true
        }
        let snap: SnapTrigger? = pending
        pending = nil
        return TrapInput(closure: closure, armed: hasSample ? armed : true, creeping: creeping, snap: snap,
                         tooFlat: false, angle: hasSample ? angle : nil)
    }

    /// The time between (t0, c0) and (t1, c1) where a rising value crossed `threshold` (clamped to the interval).
    static func crossing(_ t0: Double, _ c0: Double, _ t1: Double, _ c1: Double, _ threshold: Double) -> Double {
        if c1 <= c0 { return t1 }
        let t: Double = t0 + (t1 - t0) * (threshold - c0) / (c1 - c0)
        return min(max(t, t0), t1)
    }
}
