import Foundation

// MARK: - The snap rule (GAME-DESIGN §3, with the founder's R1 creep reference)
//
// Feed it filtered hinge samples (degrees, 180 = flat) with their sample times.
// - Rest reference `reference` = the highest θ over the last Tuning.refWindow (0.6 s), falling at most
//   Tuning.refFallRate (25 °/s). Closure c = reference − θ.
// - Snap start: c passes Tuning.snapStartDepth (4°) while armed (the crossing time is interpolated between samples).
//   The attempt is abandoned if c falls back below Tuning.snapCancelDepth (2°).
// - Snap: c passes Tuning.snapDepth (22°) during an attempt → a SnapTrigger on that sample, duration = the
//   interpolated 22° crossing time − the 4° crossing time. Then unarmed. One snap per arm.
// - Re-arm: θ rises Tuning.rearmRise (16°) above the lowest point since the snap, or θ ≥ Tuning.rearmAngle (150°) once
//   it has risen at least Tuning.rearmMinRise (4°). On re-arm both references restart at θ (so the next snap is
//   measured from where the player is now, and no stale reference can fire an instant second snap).
// - Creep (founder R1): a slow close never snaps, because the 0.6 s reference follows it down. It is measured against
//   `creepReference` = the highest θ over the last Tuning.creepWindow (3 s), falling at most Tuning.creepRefFallRate
//   (6 °/s). creeping = armed and creepReference − θ > Tuning.creepDepth (6°) for more than Tuning.creepDwell (0.45 s).
//   While creeping the reported closure is max(closure, creep depth), so the jaws visibly close and the session's
//   nerve test (nerve ≤ input.closure) works on the creep depth.
// - While unarmed the reported closure is measured from the reference at the snap (the jaws stay shut until the
//   player opens up), never from the following reference.
// - No samples arrive while the hinge is still, so `input(at:)` advances the references (and the creep timer) to the
//   frame time from the latest sample.
// - R2 (QA-1 #5): after a re-arm, the first sample, or any θ ≥ Tuning.tooFlatAngle, the creep reference is re-seeded
//   to θ on every sample while θ reaches new highs and for Tuning.settleWindow (0.6 s) after the peak. A reopen that
//   overshoots (172°) and settles (165°), or a bend down from flat, is never a creep.
// - R2 (QA-1 #6): while an attempt is open, if the closure rose less than Tuning.snapStartDepth over the last
//   Tuning.attemptWindow (0.25 s), the hand is drifting or holding, not snapping: the start time moves up to now.
//   (A close slower than about 37 °/s can never reach 22°, because the 0.6 s reference follows it, so this never
//   shortens a real snap's duration.)
// Mirrored by SnapDetector in tools/balance-sim.js (`node tools/balance-sim.js detector=1`).

struct SnapDetector {

    /// The highest θ over a sliding window, falling at most `fallRate` °/s when the maximum leaves the window.
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

        mutating func add(time: Double, angle: Double) {
            times.append(time)
            angles.append(angle)
            update(time: time)
        }

        mutating func update(time: Double) {
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
            } else {
                value = max(w, value - fallRate * dt)
            }
        }
    }

    private var fast = RollingMax(window: Tuning.refWindow, fallRate: Tuning.refFallRate)
    private var slow = RollingMax(window: Tuning.creepWindow, fallRate: Tuning.creepRefFallRate)
    private var hasSample: Bool = false
    private var angle: Double = 0
    /// Closure at the previous sample (for the crossing interpolation).
    private var lastClosure: Double = 0
    private var prevTime: Double = 0
    private(set) var armed: Bool = true
    private var attempt: Bool = false
    private var startTime: Double = 0
    private var lowest: Double = 0
    private var snapReference: Double = 0
    private var pending: SnapTrigger? = nil
    private var creepSince: Double? = nil
    /// R2 (QA-1 #6): armed samples (time, closure) back to the latest one at or before now − attemptWindow.
    private var recentTimes: [Double] = []
    private var recentClosures: [Double] = []
    /// R2 (QA-1 #5): the creep reference follows θ until settleUntil (pushed on by each new high since settling began).
    private var settling: Bool = false
    private var settlePeak: Double = 0
    private var settleUntil: Double = 0

    init() {}

    /// The rest reference θ (the 0.6 s one). 0 before the first sample.
    var reference: Double { return hasSample ? fast.value : 0 }
    /// The slow creep reference θ (3 s). 0 before the first sample.
    var creepReference: Double { return hasSample ? slow.value : 0 }
    /// The latest angle, if any sample arrived.
    var latestAngle: Double? { return hasSample ? angle : nil }

    private mutating func startSettle(time: Double, angle a: Double) {
        settling = true
        settlePeak = a
        settleUntil = time + Tuning.settleWindow
    }

    private mutating func resetRecent(time: Double?) {
        recentTimes.removeAll()
        recentClosures.removeAll()
        if let t = time {
            recentTimes.append(t)
            recentClosures.append(0)
        }
    }

    /// Feed one (filtered) angle sample at `time`. Returns a trigger on the sample where closure passes snapDepth.
    mutating func ingest(angle a: Double, at time: Double) -> SnapTrigger? {
        guard a.isFinite, time.isFinite else { return nil }
        if !hasSample {
            hasSample = true
            fast.reset(time: time, angle: a)
            slow.reset(time: time, angle: a)
            angle = a
            lastClosure = 0
            prevTime = time
            resetRecent(time: time)
            startSettle(time: time, angle: a)
            return nil
        }
        fast.add(time: time, angle: a)
        slow.add(time: time, angle: a)
        var c: Double = fast.value - a
        var fired: SnapTrigger? = nil
        if armed {
            recentTimes.append(time)
            recentClosures.append(c)
            while recentTimes.count >= 2 && recentTimes[1] <= time - Tuning.attemptWindow {
                recentTimes.removeFirst()
                recentClosures.removeFirst()
            }
            let rise: Double = c - (recentClosures.first ?? 0)
            if !attempt {
                if c >= Tuning.snapStartDepth {
                    attempt = true
                    startTime = SnapDetector.crossing(prevTime, lastClosure, time, c, Tuning.snapStartDepth)
                }
            } else if c < Tuning.snapCancelDepth {
                attempt = false
            } else if c < Tuning.snapDepth && rise < Tuning.snapStartDepth {
                // QA-1 #6: not snapping (a drift or a hold): the attempt's clock restarts here.
                startTime = time
            }
            if attempt && c >= Tuning.snapDepth {
                let tc: Double = SnapDetector.crossing(prevTime, lastClosure, time, c, Tuning.snapDepth)
                let trigger = SnapTrigger(duration: max(0, tc - startTime), time: time)
                fired = trigger
                pending = trigger
                armed = false
                attempt = false
                lowest = a
                snapReference = fast.value
                creepSince = nil
                resetRecent(time: nil)
            }
        } else {
            lowest = min(lowest, a)
            let rise: Double = a - lowest
            if rise >= Tuning.rearmRise || (a >= Tuning.rearmAngle && rise >= Tuning.rearmMinRise) {
                armed = true
                attempt = false
                fast.reset(time: time, angle: a)
                slow.reset(time: time, angle: a)
                c = 0
                creepSince = nil
                resetRecent(time: time)
                startSettle(time: time, angle: a)
            }
        }
        // QA-1 #5: the creep reference follows the hand while it opens up and settles.
        if a >= Tuning.tooFlatAngle {
            if !settling { startSettle(time: time, angle: a) }
            settleUntil = max(settleUntil, time + Tuning.settleWindow)
        }
        if settling {
            if a > settlePeak {
                settlePeak = a
                settleUntil = time + Tuning.settleWindow
            }
            if time <= settleUntil {
                slow.reset(time: time, angle: a)
            } else {
                settling = false
            }
        }
        lastClosure = c
        prevTime = time
        angle = a
        updateCreep(time: time)
        return fired
    }

    /// The input for a frame at `time` (closure, armed, creeping, tooFlat; `snap` is whatever `ingest` last returned
    /// and has not been consumed — consumed by this call).
    mutating func input(at time: Double) -> TrapInput {
        if hasSample && time.isFinite {
            fast.update(time: time)
            slow.update(time: time)
            updateCreep(time: time)
        }
        var closure: Double = hasSample ? max(0, fast.value - angle) : 0
        if hasSample && !armed { closure = max(closure, snapReference - angle) }
        var creeping: Bool = false
        if let since = creepSince, time.isFinite, time - since > Tuning.creepDwell { creeping = true }
        if creeping { closure = max(closure, creepDepth) }
        let snap: SnapTrigger? = pending
        pending = nil
        return TrapInput(closure: closure, armed: armed, creeping: creeping, snap: snap,
                         tooFlat: hasSample && angle >= Tuning.tooFlatAngle, angle: hasSample ? angle : nil)
    }

    /// creepReference − θ (≥ 0).
    var creepDepth: Double {
        return hasSample ? max(0, slow.value - angle) : 0
    }

    private mutating func updateCreep(time: Double) {
        guard hasSample else { return }
        if armed && creepDepth > Tuning.creepDepth {
            if creepSince == nil { creepSince = time }
        } else {
            creepSince = nil
        }
    }

    /// The time between (t0, c0) and (t1, c1) where the closure crossed `threshold` (clamped to the interval).
    private static func crossing(_ t0: Double, _ c0: Double, _ t1: Double, _ c1: Double, _ threshold: Double) -> Double {
        if c1 <= c0 { return t1 }
        let t: Double = t0 + (t1 - t0) * (threshold - c0) / (c1 - c0)
        return min(max(t, t0), t1)
    }
}
