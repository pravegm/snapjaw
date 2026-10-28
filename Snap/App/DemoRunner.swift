import CoreGraphics
import Foundation

/// Headless play for demo scenarios: a session is really played, step by step, by Core's TrapPilot, so every number on
/// a demo frame (protein, bugs, the Results card) is true.
enum DemoRunner {
    /// The headless frame step (s).
    static let step: Double = 1.0 / 60.0

    /// R9 (frames 08, 62: a perfect pilot scored 0 on Level 1): a pilot for a run of `mode`. In a level it reads the
    /// goal as the balance sim's pilot does (a one-bite goal's size, the goal's species), or it waits for crowds that a
    /// scripted level never sends. Pure; tested.
    static func pilot(skill: PilotSkill, seed: UInt64, mode: RunMode) -> TrapPilot {
        var p = TrapPilot(skill: skill, seed: seed)
        if case let .level(id) = mode, let spec = LevelBridge.spec(id) {
            p.minBite = spec.goal.biteOf
            p.targets = spec.goal.species
        }
        return p
    }

    /// Plays `session` with a `skill` pilot for up to `seconds` of session time, or until it finishes. Returns the
    /// seconds played.
    /// R6: `onStep` gets each step's events with the snapshot after them (the goals tick from both).
    @discardableResult
    static func play(_ session: TrapSession, skill: PilotSkill, seed: UInt64, seconds: Double,
                     onEvent: (TrapEvent) -> Void = { _ in },
                     onStep: ([TrapEvent], TrapSnapshot) -> Void = { _, _ in }) -> Double {
        var p = pilot(skill: skill, seed: seed &+ 101, mode: session.mode)
        return play(session, pilot: &p, seconds: seconds, onEvent: onEvent, onStep: onStep)
    }

    /// R9: plays on with the same pilot (a search in short slices must keep one pilot: a fresh one each slice forgets
    /// its clock and drops every close it was in the middle of, so it never bites).
    @discardableResult
    static func play(_ session: TrapSession, pilot: inout TrapPilot, seconds: Double,
                     onEvent: (TrapEvent) -> Void = { _ in },
                     onStep: ([TrapEvent], TrapSnapshot) -> Void = { _, _ in }) -> Double {
        var played = 0.0
        while played < seconds && !session.isFinished {
            let snapshot = session.snapshot
            let out = pilot.step(dt: step, time: snapshot.time, snapshot: snapshot)
            let events = session.step(dt: step, input: out.input)
            for e in events { onEvent(e) }
            onStep(events, session.snapshot)
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
