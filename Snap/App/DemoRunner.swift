import CoreGraphics
import Foundation

/// Headless play for demo scenarios: a session is really played, step by step, by Core's TrapPilot, so every number on
/// a demo frame (protein, bugs, the Results card) is true.
enum DemoRunner {
    /// The headless frame step (s).
    static let step: Double = 1.0 / 60.0

    /// Plays `session` with a `skill` pilot for up to `seconds` of session time, or until it finishes. Returns the
    /// seconds played.
    @discardableResult
    static func play(_ session: TrapSession, skill: PilotSkill, seed: UInt64, seconds: Double,
                     onEvent: (TrapEvent) -> Void = { _ in }) -> Double {
        var pilot = TrapPilot(skill: skill, seed: seed &+ 101)
        var played = 0.0
        while played < seconds && !session.isFinished {
            let snapshot = session.snapshot
            let out = pilot.step(dt: step, time: snapshot.time, snapshot: snapshot)
            let events = session.step(dt: step, input: out.input)
            for e in events { onEvent(e) }
            played += step
        }
        return played
    }

    /// A whole run played to its end (a 900 s cap guards a pilot that never finishes).
    @discardableResult
    static func playToEnd(_ session: TrapSession, skill: PilotSkill, seed: UInt64, maxSeconds: Double = 900,
                          onEvent: (TrapEvent) -> Void = { _ in }) -> Double {
        play(session, skill: skill, seed: seed, seconds: maxSeconds, onEvent: onEvent)
    }

    /// Demo `wave=`: plays with the trap held open (no snaps, nothing spent) until wave `wave` has started, or
    /// `maxSeconds` pass. Returns the seconds played.
    @discardableResult
    static func skip(_ session: TrapSession, toWave wave: Int, maxSeconds: Double = 600,
                     onEvent: (TrapEvent) -> Void = { _ in }) -> Double {
        var played = 0.0
        let open = TrapInput(closure: 0, armed: true, creeping: false, snap: nil, tooFlat: false, angle: nil)
        while played < maxSeconds && !session.isFinished && session.snapshot.wave < wave {
            let events = session.step(dt: step, input: open)
            for e in events { onEvent(e) }
            played += step
        }
        return played
    }
}
