import Foundation

/// The drawn jaws of a touch snap (pure, so it is testable). GAME-DESIGN §9: the teeth sweep in over
/// `Tuning.touchSnapTime` (0.09 s) and reopen over `reopen` (0.35 s).
///
/// The close is an ease-in (`depth · u²`): it starts at once and accelerates into the bite, like a real flytrap's
/// snap-buckling lobes. The reopen is a smoothstep (a slow, soft relaxation). Continuous everywhere.
enum FeelTouchJaw {
    /// Seconds the lobes take to reopen after the bite.
    static let reopen = 0.35

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

/// The no-hinge fallback (GAME-DESIGN §9): tap anywhere to snap.
///
/// - A tap while armed starts a bite: the drawn closure sweeps 0 → `Tuning.snapDepth` in `Tuning.touchSnapTime`
///   (0.09 s) and the snap fires **when the jaws meet** (on the first frame at or after tap + 0.09 s), with
///   `duration = Tuning.touchSnapTime`. The CHOMP then lands exactly as the teeth close on screen.
/// - The lobes reopen over 0.35 s, and the trap re-arms by itself `Tuning.touchRearmDelay` (0.45 s) after the tap.
///   Taps before then are ignored (one bite per arm, like the hinge).
/// - Never creeping, never too flat, no angle.
///
/// Everything is computed from the tap's time, so the answer never depends on how often frames ask.
@MainActor
final class TouchTrapSource: TrapSource {
    /// When the current bite's tap happened (nil: none yet).
    private var tapTime: TimeInterval?
    /// The current bite's snap has been handed to a frame.
    private var delivered = true
    /// Taps that started a bite (diagnostics and tests).
    private(set) var bites = 0

    init() {}

    /// True when a tap at `time` would snap.
    func isArmed(at time: TimeInterval) -> Bool {
        guard let tap = tapTime else { return true }
        guard time.isFinite else { return false }
        return time - tap >= Tuning.touchRearmDelay
    }

    /// A tap anywhere on the scene (`CACurrentMediaTime()` clock, like the frames). Snaps if armed.
    func tap(at time: TimeInterval) {
        guard time.isFinite, isArmed(at: time) else { return }
        tapTime = time
        delivered = false
        bites += 1
    }

    func input(at time: TimeInterval) -> TrapInput {
        guard time.isFinite, let tap = tapTime else { return TrapInput() }
        let contact = tap + Tuning.touchSnapTime
        var snap: SnapTrigger?
        if !delivered && time >= contact {
            delivered = true
            snap = SnapTrigger(duration: Tuning.touchSnapTime, time: contact)
        }
        var closure = FeelTouchJaw.closure(elapsed: time - tap, close: Tuning.touchSnapTime,
                                           reopen: FeelTouchJaw.reopen, depth: Tuning.snapDepth)
        if snap != nil { closure = max(closure, Tuning.snapDepth) }
        return TrapInput(closure: closure, armed: isArmed(at: time), creeping: false, snap: snap, tooFlat: false,
                         angle: nil)
    }

    /// Forget the bite in progress (a new run, leaving play): open and armed at once, nothing pending.
    func reset() {
        tapTime = nil
        delivered = true
    }
}
