import Foundation
import QuartzCore

/// The trap on the iPhone Duo (R8, ROUND-8 §1 with the founder's hinge rules: the lid is the jaw): hinge reports in
/// (from `HingeReader`, with the hinge status), `TrapInput` out once per frame.
///
/// Pipeline (ARCHITECTURE "Input API"):
///   raw reports (25–30 Hz while moving, none while still, about ±5° absolute accuracy, and `DeviceHinge.status`)
///   → the filter: a One-Euro (minCutoff 1.2 Hz, β 0.5, dCutoff 4 Hz) with a 2° `escape`, so any report more than 2°
///     from the filtered value (every report of a real close moves 5–20°) passes straight through: **zero added lag**
///     where it matters, light smoothing for report jitter
///   → Core's `SnapDetector.ingest(angle:at:status:)` **per report, with the report's own time** (close timing uses
///     sample times, never frame times).
///
/// The rule (Core's SnapDetector): open = armed at θ ≥ `Tuning.armAngle` (35°); the bite fires once per arm at the SHUT
/// (θ ≤ `Tuning.shutAngle`, 18°, or the status `.closed` at θ ≤ `Tuning.statusShutAngle`, 25°), its duration the close
/// time; a partial close never bites; re-armed at ≥ 35°. `startRound(at:)` makes the trap closed until the phone has
/// been shut once and opened (founder rule 3: every round starts closed).
///
/// The still hinge: the Duo sends nothing while the hand holds still. So that the detector's open reference (the
/// highest θ over the last 0.6 s) never ages out during a still hold, every frame that comes `settleAfter` (50 ms) or
/// more after the last report feeds the detector the still angle again, at most every `keepAlive` (1/30 s), stamped
/// with the frame's time. The first of these also *settles* the filter onto the last raw reading (the hand really is
/// there), so a hand that stops just inside the shut zone still bites.
///
/// Between reports `input(at:)` reports the detector's latest state. A display-rate prediction is available for drawing
/// only (`predictedAngle(at:)`, Swoop's `HingePredictor`); it never feeds the rule.
///
/// Stale bites (QA-1 #2, #7): a trigger that no frame consumed within `staleSnap` is dropped, so a clap made on Results,
/// in a menu or while paused never fires on the first frame of the next run. R8: 1.5 s (was 0.25 s), because the shut
/// is also the moment iOS moves the app to the cover display and frames can stall; `reset`/`startRound` clear it anyway.
///
/// R8: the closing pause is gone (closed is the bite, not a pause), and so is the creep guard (the creep rule is gone).
/// No pose demands: `tooFlat` is always false.
///
/// Log lines (`-snapDemo`): `SNAP-T hinge closure <c> armed <0|1> creep <0|1> angle <θ> ref <θ>` (2 Hz),
/// `SNAP-T hinge snap d=<s> angle <θ>` and `SNAP-T shut d=<s> angle <θ> status <s>` at the bite,
/// `SNAP-T reopened angle <θ>` at each re-arm after a bite, `SNAP-T round open angle <θ>` when a round's first opening
/// arms the trap, `SNAP-T hinge stale snap dropped age <s>`.
@MainActor
final class HingeTrapSource: TrapSource {
    /// The filter (see the type comment).
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
    /// A bite older than this (s) when a frame finally asks is dropped (nobody was playing).
    static let staleSnap = 1.5
    /// No measured close is shorter than one Duo report interval (it reports every 33–40 ms while moving). A whole close
    /// inside one report (the simulator's hinge CLI, or a dropped report) is clamped to this instead.
    static let minSnapDuration = 1.0 / 30

    private var detector = SnapDetector()
    private var snapFilter = OneEuroSmoother(minCutoff: 1.2, beta: 0.5, dCutoff: 4.0, escape: 2.0)
    private var predictor = HingePredictor()
    /// A trigger `ingest` returned that no frame has consumed yet (two reports inside one frame can't lose it).
    private var pendingSnap: SnapTrigger?
    /// The time of the detector's newest sample (real or still).
    private var lastDetectorTime: Double?
    /// True once the filter has been settled onto the last raw report (until the next report).
    private var settled = true
    private var lastQuery: TimeInterval?
    private var lastInput = TrapInput()
    private var lastLog: TimeInterval = -Double.infinity
    /// The detector's arm state after its previous sample (the shut / reopened log lines).
    private var wasArmed = false
    private var biteSinceArm = false
    /// A round was started and its first opening has not armed the trap yet (the `SNAP-T round open` line).
    private var roundOpenPending = false

    /// True once any real hinge sample has arrived (never goes back to false).
    private(set) var hasHinge = false
    /// The filtered hinge angle (180 = flat), as the rule sees it; nil before any sample.
    private(set) var angle: Double?
    /// The last raw reading, its status, and when it arrived (diagnostics).
    private(set) var lastRawAngle: Double?
    private(set) var lastStatus: TrapHingeStatus = .unknown
    private(set) var lastSampleTime: TimeInterval?
    /// Bites the detector has fired (diagnostics and tests).
    private(set) var snapsFired = 0
    /// Bites dropped as stale (diagnostics and tests).
    private(set) var staleSnapsDropped = 0

    /// The clock `reset(at:)` defaults to (the hinge samples' clock). Tests set their own.
    var clock: () -> TimeInterval = { CACurrentMediaTime() }

    init() {}

    /// The detector's open reference θ (the highest filtered θ over the last 0.6 s), once there is a hinge.
    var reference: Double? {
        guard hasHinge else { return nil }
        let ref = detector.reference
        return ref.isFinite ? ref : nil
    }

    /// The trap is open and ready to bite (the detector's arm state). True without a hinge.
    var armed: Bool {
        hasHinge ? detector.armed : true
    }

    /// R8: the shut zone right now (θ ≤ 18°, or `.closed` at θ ≤ 25°). False without a hinge.
    var isShut: Bool {
        guard hasHinge, let a = angle else { return false }
        return SnapDetector.isShut(angle: a, status: lastStatus)
    }

    /// R8 (founder rule 3): the round is waiting for its first close (`startRound` and no shut since). False without a
    /// hinge.
    var waitingForShut: Bool {
        hasHinge && detector.waitingForShut
    }

    /// One hinge report: degrees (180 = flat), stamped on receipt with `CACurrentMediaTime()`, and the hinge status
    /// (R8; `.unknown` when the caller has none).
    func ingest(angleDegrees: Double, at time: TimeInterval, status: TrapHingeStatus = .unknown) {
        guard angleDegrees.isFinite, time.isFinite else { return }
        let raw = FeelMath.clamp(angleDegrees, 0, 180)
        // Never let a sample go back in time (the filters' dt and the detector's windows need order).
        var stamp = time
        if let last = lastSampleTime { stamp = max(stamp, last) }
        if let last = lastDetectorTime { stamp = max(stamp, last) }
        hasHinge = true
        lastRawAngle = raw
        lastStatus = status
        lastSampleTime = stamp
        settled = false
        predictor.sample(raw, at: stamp)
        let filtered = snapFilter.filter(raw, at: stamp)
        feedDetector(filtered, at: stamp)
    }

    /// The trap for the frame at `time` (`CACurrentMediaTime()` clock). No hinge yet: an open, armed trap.
    func input(at time: TimeInterval) -> TrapInput {
        guard hasHinge, time.isFinite else { return TrapInput() }
        // Asked twice for the same frame (or an older one): the same answer, and a bite is never delivered twice.
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
        if !input.closure.isFinite { input.closure = 0 }
        input.angle = angle
        input.tooFlat = false
        lastInput = input
        log(input, at: time)
        return input
    }

    /// The hinge angle predicted at display rate (Swoop's `HingePredictor`): for drawing only (never the rule).
    func predictedAngle(at time: TimeInterval) -> Double? {
        guard hasHinge, time.isFinite else { return nil }
        return predictor.angle(at: time)
    }

    /// Forget the motion history and start a fresh detector from the last reading (keeps `hasHinge`). Call it when a
    /// paused run resumes and when the app becomes active again, so a stale reference can't make the first frames
    /// bite. The fresh detector is armed at once if the phone is open (≥ 35°). `time` defaults to the clock.
    /// R9 (real hardware): a reset never skips a round's closed start, and never re-arms a shut trap early. With
    /// `keepsRoundStart` (the default) a detector still waiting for the round's first close keeps waiting: closing the
    /// phone to start moves the app to the outer display, which re-activates the scene (a reset) mid-close, and without
    /// this the fresh detector armed at once and that starting close BIT. A trap that is shut (unarmed since a bite)
    /// stays unarmed until the phone opens past its re-arm angle. Pass `keepsRoundStart: false` when no round is in
    /// play (going Home), so Home's trap never waits.
    func reset(at time: TimeInterval? = nil, keepsRoundStart: Bool = true) {
        restart(requireShut: keepsRoundStart && detector.waitingForShut, at: time)
    }

    /// R9: the app is showing on the outer (cover) display during a hinge round: the phone is folded, whether or not a
    /// shut report has arrived (iOS hands the app over before the hinge reaches the shut zone, and reports can stop
    /// there). A round waiting for its first close counts as closed now (never a bite); otherwise the latest angle is
    /// read as `.closed`, so it bites only when that angle is at or below `Tuning.statusShutAngle` (25°), exactly as the
    /// hardware status would. Safe to call on every handover.
    func noteFolded(at time: TimeInterval? = nil) {
        guard hasHinge else { return }
        var stamp = time ?? clock()
        if !stamp.isFinite { stamp = lastSampleTime ?? 0 }
        if let last = lastDetectorTime { stamp = max(stamp, last) }
        if let last = lastSampleTime { stamp = max(stamp, last) }
        lastDetectorTime = stamp
        let fired = detector.noteFolded(at: stamp)
        if let found = fired {
            let trigger = Self.sane(found)
            pendingSnap = trigger
            snapsFired += 1
            biteSinceArm = true
            if FeelDemoLog.isEnabled {
                FeelDemoLog.line(String(format: "SNAP-T shut d=%.3f angle %.1f status folded", trigger.duration,
                                        angle ?? -1))
            }
        }
        wasArmed = detector.armed
    }

    /// R8 (founder rule 3): a round's start. Like `reset`, but the trap is closed until the phone has been shut once and
    /// opened again (`TrapSnapshot.waitingForClose` stays true until then). Without a hinge it changes nothing (a touch
    /// round starts open at once).
    func startRound(at time: TimeInterval? = nil) {
        restart(requireShut: true, at: time)
    }

    // MARK: Private

    private func restart(requireShut: Bool, at time: TimeInterval?) {
        // R8: a bite still waiting for its frame survives a `reset` (shutting the Duo moves the app to the cover
        // display, which can re-activate the scene right after the bite); the stale rule still drops an old one. A new
        // round never inherits one.
        let keep: SnapTrigger? = requireShut ? nil : pendingSnap
        // R9: a plain reset of a shut trap (unarmed since a bite) keeps it shut until the phone opens past its re-arm
        // angle (`SnapDetector.rearmLow`); a new round starts from scratch.
        let carriedLow: Double? = requireShut ? nil : (detector.armed ? nil : detector.rearmLow)
        detector = SnapDetector(requireShut: requireShut, rearmLow: carriedLow)
        snapFilter.reset()
        predictor.reset()
        pendingSnap = nil
        lastQuery = nil
        lastDetectorTime = nil
        settled = true
        lastInput = TrapInput()
        wasArmed = false
        biteSinceArm = false
        roundOpenPending = requireShut
        defer { pendingSnap = keep }
        guard let raw = lastRawAngle else { return }
        var stamp = time ?? clock()
        if !stamp.isFinite { stamp = lastSampleTime ?? 0 }
        if let last = lastSampleTime { stamp = max(stamp, last) }
        lastSampleTime = stamp
        predictor.sample(raw, at: stamp)
        let filtered = snapFilter.filter(raw, at: stamp)
        // A fresh detector never fires on its first sample (and `keep` replaces anything pending).
        feedDetector(filtered, at: stamp)
    }

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
        let fired = detector.ingest(angle: value, at: time, status: lastStatus)
        if let found = fired {
            let trigger = Self.sane(found)
            pendingSnap = trigger
            snapsFired += 1
            biteSinceArm = true
            if FeelDemoLog.isEnabled {
                FeelDemoLog.line(String(format: "SNAP-T hinge snap d=%.3f angle %.1f", trigger.duration, value))
                FeelDemoLog.line(String(format: "SNAP-T shut d=%.3f angle %.1f status ", trigger.duration, value)
                                 + Self.name(lastStatus))
            }
        }
        let nowArmed = detector.armed
        if nowArmed && !wasArmed && FeelDemoLog.isEnabled {
            if biteSinceArm {
                FeelDemoLog.line(String(format: "SNAP-T reopened angle %.1f", value))
            } else if roundOpenPending {
                FeelDemoLog.line(String(format: "SNAP-T round open angle %.1f", value))
            }
        }
        if nowArmed && !wasArmed {
            biteSinceArm = false
            roundOpenPending = false
        }
        wasArmed = nowArmed
    }

    private static func name(_ s: TrapHingeStatus) -> String {
        switch s {
        case .closed: return "closed"
        case .partiallyOpen: return "partiallyOpen"
        case .fullyOpen: return "fullyOpen"
        case .unknown: return "unknown"
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
