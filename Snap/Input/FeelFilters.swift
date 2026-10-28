import Foundation

// Smoothing building blocks for the hinge → trap pipeline. Ported from Hush's `Input/FeelFilters.swift` (itself from
// Swoop, Brim and Squish, all battle-tested on a real Duo). Pure value types with explicit times, so every one of them
// is unit-testable without a device.
//
// Snapjaw's twist: the snap is decided on the report that crosses 22° of closure (ARCHITECTURE "Input notes"), so the
// filter on the snap path must add almost no lag on a fast close. `OneEuroSmoother` therefore gained an `escape`: a
// report further than `escape` degrees from the filtered value passes straight through (a deliberate fast move), while
// small steps (slow creeps, report jitter) are smoothed as before.

/// Small pure helpers for the Input and Feedback modules.
enum FeelMath {
    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    /// 0…1, NaN → 0.
    static func clamp01(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }

    /// Hermite smoothstep of `x` clamped to 0…1: 3x² − 2x³ (zero slope at both ends).
    static func smoothstep(_ x: Double) -> Double {
        let u = clamp01(x)
        return u * u * (3 - 2 * u)
    }

    /// A finite, non-negative value (NaN and negatives → 0, +∞ → `cap`).
    static func positive(_ value: Double, cap: Double = 1_000) -> Double {
        guard !value.isNaN else { return 0 }
        return min(max(value, 0), cap)
    }
}

/// One-Euro filter (Casiez et al., CHI 2012): heavy smoothing while the input is slow, low lag while it moves fast.
/// Squish's tuning for the Duo hinge: minCutoff 2.0, β 0.12, dCutoff 1.5; dt clamped to 1/240…0.2 s.
///
/// Snapjaw addition: `escape` (degrees, default ∞ = the classic filter). A sample further than `escape` from the
/// current filtered value is passed through unchanged (the derivative still learns from it), so a fast close reaches
/// the snap rule with zero added lag.
struct OneEuroSmoother {
    var minCutoff: Double
    var beta: Double
    var dCutoff: Double
    var escape: Double

    private(set) var value: Double?
    /// Filtered derivative of the input (units per second).
    private(set) var derivative: Double = 0
    private var lastTime: Double?

    init(minCutoff: Double = 2.0, beta: Double = 0.12, dCutoff: Double = 1.5, escape: Double = .infinity) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
        self.escape = escape
    }

    mutating func reset() {
        value = nil
        derivative = 0
        lastTime = nil
    }

    mutating func filter(_ x: Double, at time: Double) -> Double {
        guard x.isFinite else { return value ?? 0 }
        guard let previous = value, let previousTime = lastTime else {
            value = x
            lastTime = time
            derivative = 0
            return x
        }
        let dt = min(max(time - previousTime, 1.0 / 240.0), 0.2)
        let rawDerivative = (x - previous) / dt
        derivative += (rawDerivative - derivative) * Self.alpha(cutoff: dCutoff, dt: dt)
        let cutoff = minCutoff + beta * abs(derivative)
        var filtered = previous + (x - previous) * Self.alpha(cutoff: cutoff, dt: dt)
        if abs(x - previous) > escape { filtered = x }
        value = filtered
        lastTime = time
        return filtered
    }

    /// The input is known to be at `x` now (the hand has stopped there): jump to it, with no motion.
    mutating func settle(_ x: Double, at time: Double) {
        guard x.isFinite, time.isFinite else { return }
        value = x
        derivative = 0
        lastTime = time
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let r = 2 * Double.pi * cutoff * dt
        return r / (r + 1)
    }
}

/// The hinge at display rate (Squish `HingeTracker`, copied from Swoop/Hush unchanged). The Duo reports 25–30 Hz while
/// moving and nothing while still, so a picture drawn from it must move continuously *between* reports.
///
/// An alpha-beta tracker on the raw samples: between samples it extrapolates at the tracked velocity for about one
/// sample interval, then eases to a stop; each correction is blended in over ~40 ms; once reports stop it glides onto
/// the last raw reading. Jumps larger than `snapDegrees` snap. Drawing only: it never feeds the snap rule.
struct HingePredictor {
    static let alpha = 0.75
    static let beta = 0.35
    static let maxSpeed = 900.0
    static let coast = 1.0
    static let ease = 0.3
    static let horizonMin = 0.03
    static let horizonMax = 0.2
    static let snapDegrees = 90.0
    static let restGlide = 0.05

    /// The tracked (alpha-beta) angle as of the last report.
    private(set) var estimate: Double?
    /// °/s, positive while the angle grows (opening).
    private(set) var velocity = 0.0
    private(set) var lastSampleTime = 0.0
    /// Smoothed time between samples (s).
    private(set) var interval = 1.0 / 30
    private var offset = 0.0
    private var offsetTime = 0.0
    private var lastReading = 180.0

    init() {}

    mutating func reset() {
        estimate = nil
        velocity = 0
        offset = 0
    }

    mutating func sample(_ angle: Double, at time: Double) {
        lastReading = angle
        guard estimate != nil else {
            estimate = angle
            velocity = 0
            lastSampleTime = time
            offset = 0
            offsetTime = time
            return
        }
        let shown = self.angle(at: time)
        let dt = min(max(time - lastSampleTime, 1.0 / 240), 0.5)
        let predicted = raw(at: time)
        let tau = max(0.03, Self.ease * interval)
        let prior = velocity * exp(-max(0, (time - lastSampleTime) - 2 * horizon) / tau)
        interval += (min(dt, 0.25) - interval) * 0.3
        let surprise = angle - predicted
        if abs(surprise) > Self.snapDegrees {
            estimate = angle
            velocity = 0
            lastSampleTime = time
            offset = 0
            offsetTime = time
            return
        }
        estimate = predicted + Self.alpha * surprise
        velocity = FeelMath.clamp(prior + Self.beta / dt * surprise, -Self.maxSpeed, Self.maxSpeed)
        lastSampleTime = time
        offset = shown - raw(at: time)
        offsetTime = time
    }

    var horizon: Double { FeelMath.clamp(Self.coast * interval, Self.horizonMin, Self.horizonMax) }

    private func extrapolation(at time: Double) -> Double {
        let age = max(time - lastSampleTime, 0)
        if age <= horizon { return age }
        let tau = max(0.03, Self.ease * interval)
        return horizon + tau * (1 - exp(-(age - horizon) / tau))
    }

    private func raw(at time: Double) -> Double {
        (estimate ?? 180) + velocity * extrapolation(at: time)
    }

    /// The hinge angle to use at `time` (degrees, 0…180).
    func angle(at time: Double) -> Double {
        guard estimate != nil else { return 180 }
        let blend = exp(-max(time - offsetTime, 0) / max(0.04, 0.35 * interval))
        let moving = FeelMath.clamp(raw(at: time) + offset * blend, 0, 180)
        let rest = horizon + 3 * max(0.03, Self.ease * interval)
        let age = max(time - lastSampleTime, 0)
        guard age > rest else { return moving }
        let k = 1 - exp(-(age - rest) / Self.restGlide)
        return moving + (lastReading - moving) * k
    }

    /// Reports per second, from the smoothed interval.
    var rate: Double { 1 / max(interval, 1e-3) }
}

/// The "phone is closing" gate (GAME-DESIGN §3): closed when the filtered angle stays under `Tuning.closingAngle`
/// (50°) for `Tuning.closingDwell` (0.6 s); it opens again above `closingAngle + reopenMargin` (58°), so ±1° jitter at
/// 50° can't flicker the pause card. Far from 90° on purpose: a hard snap often reaches 90–100° (Swoop's real-Duo
/// lesson). Pure, with explicit times; `isClosing(at:)` lets the dwell mature with time alone (the Duo sends nothing
/// while still).
struct FeelClosingGate {
    static var closingAngle: Double { Tuning.closingAngle }
    static let reopenMargin = 8.0

    static var closeBelow: Double { closingAngle }
    static var dwell: Double { Tuning.closingDwell }
    static var reopenAbove: Double { closingAngle + reopenMargin }

    /// Latched closed (until above `reopenAbove`).
    private(set) var latched = false
    /// When the angle went under `closeBelow` (the dwell running), if it has.
    private(set) var belowSince: Double?

    init() {}

    /// Closed at `time`: latched, or under the closing angle for the whole dwell.
    func isClosing(at time: Double) -> Bool {
        if latched { return true }
        guard let since = belowSince, time.isFinite else { return false }
        return time - since >= Self.dwell
    }

    /// Feed an angle at `time`.
    mutating func update(angle: Double, at time: Double) {
        guard angle.isFinite, time.isFinite else { return }
        if isClosing(at: time) {
            latched = true
            belowSince = nil
        }
        if latched {
            if angle > Self.reopenAbove { latched = false }
            return
        }
        if angle < Self.closeBelow {
            if belowSince == nil { belowSince = time }
        } else {
            belowSince = nil
        }
    }

    mutating func reset() {
        latched = false
        belowSince = nil
    }
}

/// The creep guard (QA-1 #5, ROUND-2 Feel). Core's `SnapDetector` restarts its 3 s creep reference at θ on a re-arm,
/// while the hand is still opening, so a reopen that overshoots the settled rest by more than 6° (open to 172°, settle
/// at 165°), or obeying "Bend it a little" from 178° to 168°, reads as a creep with nobody closing the trap.
///
/// This keeps its own creep reference (the same rule: the highest θ over `Tuning.creepWindow`, falling at most
/// `Tuning.creepRefFallRate`) but **re-seeds it to θ on every sample** during a quiet spell. A quiet spell lasts
/// `quiet` (0.6 s) after:
/// - the first sample, and every re-arm;
/// - any sample where θ is rising (above the previous sample and at least `riseStep` above the lowest θ of the last
///   `riseWindow`), so the reference follows an overshoot back down to where the hand settles;
/// - any sample at or above `Tuning.tooFlatAngle` (the "bend it a little" case).
/// Creeping = armed, not quiet, and reference − θ > `Tuning.creepDepth` for more than `Tuning.creepDwell`.
/// `HingeTrapSource` reports a creep only when both the detector and this guard agree, so it works whether or not Core
/// adds the same re-seed to `SnapDetector` (design/NEEDS.md). Pure, with explicit times.
struct FeelCreepGuard {
    static let quiet = 0.6
    static let riseStep = 1.0
    static let riseWindow = 0.25

    /// The guard's creep reference θ (0 before any sample).
    private(set) var reference: Double = 0
    /// The latest θ.
    private(set) var angle: Double = 0
    /// No creep before this time.
    private(set) var quietUntil: Double = -Double.infinity
    private(set) var hasSample = false
    private var armed = true
    private var since: Double?
    private var lastTime: Double = 0
    /// The reference window's samples (times, angles), oldest first.
    private var times: [Double] = []
    private var angles: [Double] = []
    /// The last `riseWindow` s of samples, for the rise test.
    private var recentTimes: [Double] = []
    private var recentAngles: [Double] = []

    init() {}

    mutating func reset() {
        self = FeelCreepGuard()
    }

    /// reference − θ (≥ 0).
    var depth: Double {
        hasSample ? max(0, reference - angle) : 0
    }

    /// Creeping at `time` (as of the latest `sample` / `update`).
    func isCreeping(at time: Double) -> Bool {
        guard let since, time.isFinite else { return false }
        return time - since > Tuning.creepDwell
    }

    /// One sample the detector heard (filtered θ, its time) and the detector's arm state after it.
    mutating func sample(_ a: Double, at time: Double, armed nowArmed: Bool) {
        guard a.isFinite, time.isFinite else { return }
        guard hasSample else {
            hasSample = true
            armed = nowArmed
            angle = a
            quietUntil = time + Self.quiet
            reseed(a, at: time)
            remember(a, at: time)
            updateCreep(at: time)
            return
        }
        let t = max(time, lastTime)
        if nowArmed && !armed { quietUntil = max(quietUntil, t + Self.quiet) }
        armed = nowArmed
        remember(a, at: t)
        var low = a
        for value in recentAngles where value < low { low = value }
        // Rising: still going up (above the previous sample) and at least `riseStep` above the recent low.
        if a > angle && a - low >= Self.riseStep { quietUntil = max(quietUntil, t + Self.quiet) }
        if a >= Tuning.tooFlatAngle { quietUntil = max(quietUntil, t + Self.quiet) }
        angle = a
        if t < quietUntil {
            reseed(a, at: t)
        } else {
            times.append(t)
            angles.append(a)
            advance(to: t)
        }
        updateCreep(at: t)
    }

    /// A frame with no new sample: the reference window and the creep timer move on to `time`.
    mutating func update(at time: Double) {
        guard hasSample, time.isFinite, time >= lastTime else { return }
        if time < quietUntil {
            reseed(angle, at: time)
        } else {
            advance(to: time)
        }
        updateCreep(at: time)
    }

    private mutating func reseed(_ a: Double, at t: Double) {
        times = [t]
        angles = [a]
        reference = a
        lastTime = t
    }

    private mutating func remember(_ a: Double, at t: Double) {
        recentTimes.append(t)
        recentAngles.append(a)
        while recentTimes.count > 1 && recentTimes[0] < t - Self.riseWindow {
            recentTimes.removeFirst()
            recentAngles.removeFirst()
        }
    }

    /// The rolling maximum at `t`, falling at most `Tuning.creepRefFallRate` once the peak leaves the window.
    private mutating func advance(to t: Double) {
        while times.count > 1 && times[0] < t - Tuning.creepWindow {
            times.removeFirst()
            angles.removeFirst()
        }
        var top = -Double.infinity
        for value in angles where value > top { top = value }
        let dt = max(0, t - lastTime)
        lastTime = max(lastTime, t)
        if top >= reference {
            reference = top
        } else {
            reference = max(top, reference - Tuning.creepRefFallRate * dt)
        }
    }

    private mutating func updateCreep(at t: Double) {
        if armed && t >= quietUntil && depth > Tuning.creepDepth {
            if since == nil { since = t }
        } else {
            since = nil
        }
    }
}

/// `SNAP-T …` demo/timing lines for CI, only in DEBUG builds launched with the `-snapDemo` argument (Release carries
/// neither the check nor the string). Flushed at once.
enum FeelDemoLog {
    #if DEBUG
    static let isEnabled: Bool = ProcessInfo.processInfo.arguments.contains("-snapDemo")
    #else
    static let isEnabled: Bool = false
    #endif

    /// Prints `s` (which should start with `SNAP-`) when enabled.
    static func line(_ s: String) {
        guard isEnabled else { return }
        print(s)
        fflush(stdout)
    }

    /// Same as `line(_:)` (Swoop's name, for copied code).
    static func emit(_ s: String) {
        line(s)
    }
}
