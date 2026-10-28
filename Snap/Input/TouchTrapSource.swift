import Foundation

/// The drawn jaws of a touch bite (pure, so it is testable). GAME-DESIGN §9: the teeth sweep in over `close` s and
/// reopen over `reopen` (0.3 s).
///
/// The close is an ease-in (`depth · u²`): it starts at once and accelerates into the bite, like a real flytrap's
/// snap-buckling lobes. The reopen is a smoothstep (a slow, soft relaxation). Continuous everywhere.
enum FeelTouchJaw {
    /// Seconds the lobes take to reopen after the bite.
    static let reopen = 0.3

    /// Closure in degrees `elapsed` s after the tap: 0 → `depth` over `close` s, then back to 0 over `reopen` s.
    static func closure(elapsed: Double, close: Double, reopen: Double, depth: Double) -> Double {
        guard elapsed.isFinite, elapsed >= 0, depth.isFinite, depth > 0 else { return 0 }
        let c = max(close.isFinite ? close : 0, 0.001)
        if elapsed < c {
            let u = elapsed / c
            return depth * u * u
        }
        let r = max(reopen.isFinite ? reopen : 0, 0.001)
        let v = (elapsed - c) / r
        if v >= 1 { return 0 }
        return depth * (1 - FeelMath.smoothstep(v))
    }
}

/// The no-hinge fallback (GAME-DESIGN §9; R8, ROUND-8 §1 and founder rule 5: first-class): tap anywhere to bite.
///
/// - R8: a tap while armed is an INSTANT bite: the snap fires on the first frame at or after the tap, with
///   `duration = Tuning.touchSnapTime` (0.12 s). Only on touch does the Scene play its own shut animation: the drawn
///   closure sweeps 0 → `Tuning.snapDepth` over 0.12 s and reopens over `FeelTouchJaw.reopen` (0.3 s).
/// - The trap re-arms by itself `Tuning.touchRearmDelay` (0.45 s) after the tap (the session's shut: the clock is
///   frozen until then). Taps before then are ignored (one bite per arm, like the hinge).
/// - A touch round starts open at once (armed), never waiting for a close. Never creeping, never too flat, no angle.
/// - A stale bite (QA-1 #7): if no frame asks until more than `staleSnap` after the tap (a tap just before a pause,
///   Control Centre or the menu), the bite is dropped and the trap is open and armed again. It never lands later on bugs
///   that have moved, and no state is ever stuck.
///
/// Everything is computed from the tap's time, so the answer never depends on how often frames ask.
@MainActor
final class TouchTrapSource: TrapSource {
    /// A bite whose tap is older than this (s) when a frame finally asks is dropped.
    static let staleSnap = 0.25

    /// When the current bite's tap happened (nil: none yet).
    private var tapTime: TimeInterval?
    /// The current bite's snap has been handed to a frame.
    private var delivered = true
    /// Taps that started a bite (diagnostics and tests).
    private(set) var bites = 0
    /// Bites dropped as stale (diagnostics and tests).
    private(set) var staleBites = 0

    init() {}

    /// True when a tap at `time` would bite.
    func isArmed(at time: TimeInterval) -> Bool {
        guard let tap = tapTime else { return true }
        guard time.isFinite else { return false }
        return time - tap >= Tuning.touchRearmDelay
    }

    /// A tap anywhere on the scene (`CACurrentMediaTime()` clock, like the frames). Bites if armed.
    func tap(at time: TimeInterval) {
        guard time.isFinite, isArmed(at: time) else { return }
        tapTime = time
        delivered = false
        bites += 1
    }

    func input(at time: TimeInterval) -> TrapInput {
        guard time.isFinite, let tap = tapTime else { return TrapInput() }
        if !delivered && time - tap > Self.staleSnap {
            // Nobody was playing when the tap came: forget the bite.
            staleBites += 1
            reset()
            return TrapInput()
        }
        var snap: SnapTrigger?
        if !delivered && time >= tap {
            delivered = true
            snap = SnapTrigger(duration: Tuning.touchSnapTime, time: tap)
        }
        let closure = FeelTouchJaw.closure(elapsed: time - tap, close: Tuning.touchSnapTime,
                                           reopen: FeelTouchJaw.reopen, depth: Tuning.snapDepth)
        return TrapInput(closure: closure, armed: isArmed(at: time), creeping: false, snap: snap, tooFlat: false,
                         angle: nil)
    }

    /// Forget the bite in progress (a new run, leaving play): open and armed at once, nothing pending.
    func reset() {
        tapTime = nil
        delivered = true
    }
}
