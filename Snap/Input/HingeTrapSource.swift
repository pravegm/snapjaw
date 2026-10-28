import Foundation
import QuartzCore

/// The trap on the iPhone Duo (GAME-DESIGN §3): hinge reports in (from `HingeReader`), `TrapInput` out once per frame.
///
/// Pipeline (ARCHITECTURE "Input API"):
///   raw reports (25–30 Hz while moving, none while still, about ±5° absolute accuracy)
///   → the snap filter: a One-Euro (minCutoff 1.2 Hz, β 0.5, dCutoff 4 Hz) with a 2° `escape`, so any report more than
///     2° from the filtered value (every report of a real snap moves 5–8°) passes straight through: **zero added lag**
///     where it matters, light smoothing for slow creeps and report jitter
///   → Core's `SnapDetector.ingest(angle:at:)` **per report, with the report's own time** (snap timing uses sample
///     times, never frame times).
///
/// The still hinge: the Duo sends nothing while the hand holds still. So that the detector's rest reference (the
/// highest θ over the last 0.6 s) never ages out during a still hold, every frame that comes `settleAfter` (50 ms) or
/// more after the last report feeds the detector the still angle again, at most every `keepAlive` (1/30 s), stamped
/// with the frame's time. The first of these also *settles* the filter onto the last raw reading (the hand really is
/// there), so a hand that stops just past 22° still bites, ≤ ~42 ms later, instead of never.
///
/// Between reports `input(at:)` reports the detector's latest state. The drawn closure is the detector's (truthful:
/// Core's creep rule reads `closure` too). A display-rate prediction is available for drawing only
/// (`predictedAngle(at:)`, Swoop's `HingePredictor`); it never feeds the snap rule.
///
/// Creep (QA-1 #5): the detector's creep is reported only when `FeelCreepGuard` agrees (no creep while θ is rising,
/// within 0.6 s of a re-arm or the first sample, or just after the hinge was too flat). When the guard vetoes it, the
/// closure is the plain rest-reference closure.
///
/// Stale snaps (QA-1 #2, #7): a trigger that no frame consumed within `staleSnap` (0.25 s) is dropped, so a clap made
/// on Results, in a menu or while paused never fires on the first frame of the next run.
///
/// The closing pause: `isClosing` is the filtered angle under `Tuning.closingAngle` (50°) for `Tuning.closingDwell`
/// (0.6 s), clearing above 58°. Never near 90° (a hard snap often reaches 90–100°).
///
/// Never use the hinge's `status` (it reads `.closed` at ~85° on hardware); everything here is the angle.
@MainActor
final class HingeTrapSource: TrapSource {
    /// The snap filter (see the type comment).
    static let snapMinCutoff = 1.2
    static let snapBeta = 0.5
    static let snapDCutoff = 4.0
    static let snapEscape = 2.0
    /// A frame this long (s) after the last report treats the hinge as still (the Duo reports every 33–40 ms while
    /// moving).
    static let settleAfter = 0.05
    /// While still, the detector hears the still angle this often (s).
    static let keepAlive = 1.0 / 30
    /// `SNAP-T hinge` diagnostic lines: at most one per this many seconds.
    static let logInterval = 0.5
    /// A snap trigger older than this (s) when a frame finally asks is dropped (nobody was playing).
    static let staleSnap = 0.25
    /// No measured snap is shorter than one Duo report interval (it reports every 33–40 ms while moving). A ≥ 22° jump
    /// inside one report (the simulator's hinge CLI, or a dropped report) interpolates both crossings into one gap and
    /// would read as a ~10 ms snap that catches everything; it is clamped to this instead (Duo sim run 40603497021).
    static let minSnapDuration = 1.0 / 30

    private var detector = SnapDetector()
    private var snapFilter = OneEuroSmoother(minCutoff: 1.2, beta: 0.5, dCutoff: 4.0, escape: 2.0)
    private var predictor = HingePredictor()
    private var gate = FeelClosingGate()
    private var creepGuard = FeelCreepGuard()
    /// A trigger `ingest` returned that no frame has consumed yet (two reports inside one frame can't lose it).
    private var pendingSnap: SnapTrigger?
    /// The time of the detector's newest sample (real or still).
    private var lastDetectorTime: Double?
    /// True once the filter has been settled onto the last raw report (until the next report).
    private var settled = true
    private var lastQuery: TimeInterval?
    private var lastInput = TrapInput()
    private var lastLog: TimeInterval = -Double.infinity

    /// True once any real hinge sample has arrived (never goes back to false).
    private(set) var hasHinge = false
    /// The filtered hinge angle (180 = flat), as the snap rule sees it; nil before any sample.
    private(set) var angle: Double?
    /// The last raw reading and when it arrived (diagnostics).
    private(set) var lastRawAngle: Double?
    private(set) var lastSampleTime: TimeInterval?
    /// Snaps the detector has fired (diagnostics and tests).
    private(set) var snapsFired = 0
    /// Snaps dropped as stale (diagnostics and tests).
    private(set) var staleSnapsDropped = 0
    /// Frames where the detector said "creeping" and the creep guard vetoed it (diagnostics and tests).
    private(set) var creepsVetoed = 0

    /// The clock `isClosing` judges its dwell against (the hinge samples' clock). Tests set their own.
    var clock: () -> TimeInterval = { CACurrentMediaTime() }

    init() {}

    /// The latest time anything has told us about: the clock, the last frame, the last report.
    private var now: TimeInterval {
        max(clock(), lastQuery ?? -Double.infinity, lastSampleTime ?? -Double.infinity)
    }

    /// The detector's rest reference θ (the highest filtered θ over the last 0.6 s), once there is a hinge.
    var reference: Double? {
        guard hasHinge else { return nil }
        let ref = detector.reference
        return ref.isFinite ? ref : nil
    }

    /// The trap is open and ready to bite (the detector's arm state). True without a hinge.
    var armed: Bool {
        hasHinge ? detector.armed : true
    }

    /// True while the phone is closing: the filtered angle stayed under 50° for 0.6 s (it clears above 58°). While
    /// frames run it is judged on the frames; while they don't (the game paused) on the reports. The dwell matures
    /// with the clock even when no frame or report arrives.
    var isClosing: Bool {
        closing(at: now)
    }

    /// `isClosing` judged at `time`.
    func closing(at time: TimeInterval) -> Bool {
        hasHinge && gate.isClosing(at: time)
    }

    /// One hinge report: degrees (180 = flat), stamped on receipt with `CACurrentMediaTime()`.
    func ingest(angleDegrees: Double, at time: TimeInterval) {
        guard angleDegrees.isFinite, time.isFinite else { return }
        let raw = FeelMath.clamp(angleDegrees, 0, 180)
        // Never let a sample go back in time (the filters' dt and the detector's windows need order).
        var stamp = time
        if let last = lastSampleTime { stamp = max(stamp, last) }
        if let last = lastDetectorTime { stamp = max(stamp, last) }
        hasHinge = true
        lastRawAngle = raw
        lastSampleTime = stamp
        settled = false
        predictor.sample(raw, at: stamp)
        let filtered = snapFilter.filter(raw, at: stamp)
        feedDetector(filtered, at: stamp)
        // Keep the closing gate fresh while no frame asks (the pause card, menus). Frames take over at once.
        let framesLive = stamp - (lastQuery ?? -Double.infinity) <= 0.1
        if !framesLive { gate.update(angle: filtered, at: stamp) }
    }

    /// The trap for the frame at `time` (`CACurrentMediaTime()` clock). No hinge yet: an open, armed trap.
    func input(at time: TimeInterval) -> TrapInput {
        guard hasHinge, time.isFinite else { return TrapInput() }
        // Asked twice for the same frame (or an older one): the same answer, and a snap is never delivered twice.
        if let previous = lastQuery, time <= previous {
            var again = lastInput
            again.snap = nil
            return again
        }
        lastQuery = time
        keepAlive(at: time)
        var input = detector.input(at: time)
        if input.snap == nil { input.snap = pendingSnap }
        pendingSnap = nil
        if let snap = input.snap { input.snap = Self.sane(snap) }
        if let snap = input.snap, time - snap.time > Self.staleSnap {
            input.snap = nil
            staleSnapsDropped += 1
            if FeelDemoLog.isEnabled {
                FeelDemoLog.line(String(format: "SNAP-T hinge stale snap dropped age %.2f", time - snap.time))
            }
        }
        creepGuard.update(at: time)
        if input.creeping {
            if creepGuard.isCreeping(at: time) {
                // Both agree: the deeper of the rest closure and the guard's (re-seeded) creep depth.
                input.closure = max(max(0, detector.reference - (angle ?? 0)), creepGuard.depth)
            } else {
                input.creeping = false
                input.closure = max(0, detector.reference - (angle ?? 0))
                creepsVetoed += 1
            }
        }
        if !input.closure.isFinite { input.closure = 0 }
        input.angle = angle
        if let a = angle { gate.update(angle: a, at: time) }
        lastInput = input
        log(input, at: time)
        return input
    }

    /// The hinge angle predicted at display rate (Swoop's `HingePredictor`): for drawing only (never the snap rule).
    func predictedAngle(at time: TimeInterval) -> Double? {
        guard hasHinge, time.isFinite else { return nil }
        return predictor.angle(at: time)
    }

    /// Forget the motion history and start a fresh snap detector from the last reading (keeps `hasHinge` and the
    /// closing latch). Call it when a paused run resumes and when the app becomes active again, so a stale reference
    /// can't make the first frames snap or creep. `time` defaults to the clock.
    func reset(at time: TimeInterval? = nil) {
        detector = SnapDetector()
        snapFilter.reset()
        predictor.reset()
        creepGuard.reset()
        pendingSnap = nil
        lastQuery = nil
        lastDetectorTime = nil
        settled = true
        lastInput = TrapInput()
        guard let raw = lastRawAngle else { return }
        var stamp = time ?? clock()
        if !stamp.isFinite { stamp = lastSampleTime ?? 0 }
        if let last = lastSampleTime { stamp = max(stamp, last) }
        lastSampleTime = stamp
        predictor.sample(raw, at: stamp)
        let filtered = snapFilter.filter(raw, at: stamp)
        feedDetector(filtered, at: stamp)
        // A fresh detector never fires on its first sample; make sure nothing stale leaks out regardless.
        pendingSnap = nil
    }

    // MARK: Private

    /// A trigger with a finite duration of at least `minSnapDuration`.
    static func sane(_ trigger: SnapTrigger) -> SnapTrigger {
        var clean = trigger
        if !clean.duration.isFinite || !(clean.duration >= Self.minSnapDuration) {
            clean.duration = Self.minSnapDuration
        }
        return clean
    }

    private func feedDetector(_ value: Double, at time: Double) {
        angle = value
        lastDetectorTime = time
        let fired = detector.ingest(angle: value, at: time)
        creepGuard.sample(value, at: time, armed: detector.armed)
        if let found = fired {
            let trigger = Self.sane(found)
            pendingSnap = trigger
            snapsFired += 1
            if FeelDemoLog.isEnabled {
                FeelDemoLog.line(String(format: "SNAP-T hinge snap d=%.3f angle %.1f", trigger.duration, value))
            }
        }
    }

    /// The still hinge (see the type comment): settle the filter onto the last raw reading, and keep the detector's
    /// windows fed with the still angle.
    private func keepAlive(at time: TimeInterval) {
        guard let last = lastSampleTime, let raw = lastRawAngle else { return }
        guard time - last >= Self.settleAfter else { return }
        let previous = lastDetectorTime ?? last
        guard time - previous >= Self.keepAlive else { return }
        if !settled {
            snapFilter.settle(raw, at: time)
            settled = true
        }
        feedDetector(snapFilter.value ?? raw, at: max(time, previous))
    }

    private func log(_ input: TrapInput, at time: TimeInterval) {
        guard FeelDemoLog.isEnabled, time - lastLog >= Self.logInterval else { return }
        lastLog = time
        let ref = reference.map { String(format: "%.1f", $0) } ?? "-"
        let a = angle.map { String(format: "%.1f", $0) } ?? "-"
        let flags = " armed \(input.armed ? 1 : 0) creep \(input.creeping ? 1 : 0)"
        FeelDemoLog.line(String(format: "SNAP-T hinge closure %.1f", input.closure) + flags + " angle " + a
                         + " ref " + ref)
    }
}
