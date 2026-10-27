import CoreGraphics
import Foundation

/// The First Bite lesson (GAME-DESIGN §8), taught by doing: one sentence per step, a scripted bug cast, and a step that
/// passes only when the player has done the thing. Pure (the GameController feeds it each frame's state and events and
/// performs its actions); tested.
struct LessonScript: Equatable {
    enum Step: Int, CaseIterable, Equatable {
        case pose = 1, firstSnap, openAgain, tooSlow, bee, triple, done
    }

    /// One frame of the lesson as the script sees it.
    struct Input {
        /// Session seconds.
        var time: Double
        var angle: Double?
        /// The trap is driven by a hinge (else the pose step is skipped and the texts say "tap").
        var hasHinge: Bool
        var armed: Bool
        var events: [TrapEvent]
        /// Edible bugs on screen still in play (not leaving, caught or escaped).
        var liveFlies: Int
        /// Protected bugs on screen still in play.
        var liveBees: Int

        init(time: Double, angle: Double? = nil, hasHinge: Bool, armed: Bool = true, events: [TrapEvent] = [],
             liveFlies: Int = 0, liveBees: Int = 0) {
            self.time = time; self.angle = angle; self.hasHinge = hasHinge; self.armed = armed; self.events = events
            self.liveFlies = liveFlies; self.liveBees = liveBees
        }
    }

    /// What the controller should do: put a scripted bug in (`slot` = `AppRules.lessonSpot`).
    enum Action: Equatable {
        case spawn(BugSpecies, slot: Int, linger: Double)
    }

    // MARK: Timing

    /// The pose step passes after this long held like a book.
    static let poseHold: Double = 0.6
    static let poseRange: ClosedRange<Double> = 125...176
    /// Praise stays up this long before the next step.
    static let praiseSeconds: Double = 1.3
    /// A bug that flew off comes back after this.
    static let respawnDelay: Double = 1.2
    /// The re-arm step shows at least this long.
    static let openDwell: Double = 0.8
    /// The bee leaves after this long sipping.
    static let beeLinger: Double = 3
    /// A bitten bee is let go and flies off; the next bee comes after this, and the old one's leaving never counts.
    static let stungBeeExit: Double = 2.4

    private(set) var step: Step
    let replay: Bool
    private var entered = false
    private var stepStart: Double = 0
    private var poseSince: Double?
    private(set) var praise: String?
    private(set) var warning: String?
    private var advanceAt: Double?
    private var respawnAt: Double?
    private var ignoreLeavesUntil: Double = -Double.infinity
    /// The step's attempts (a repeat after a sting, a miss…).
    private(set) var attempts = 0

    init(start: Step = .pose, replay: Bool = false) {
        self.step = start
        self.replay = replay
    }

    var isDone: Bool { step == .done }
    /// Skip is offered after step 2 (and always on a replay).
    var allowsSkip: Bool { replay || step.rawValue > Step.firstSnap.rawValue }

    // MARK: Update

    mutating func update(_ i: Input) -> [Action] {
        var actions: [Action] = []
        if step == .pose && !i.hasHinge { enter(.firstSnap) }
        if let at = advanceAt {
            guard i.time >= at else { return actions }
            advanceAt = nil
            enter(next(step))
        }
        if !entered {
            entered = true
            stepStart = i.time
            actions += spawns(step)
        }
        if let r = respawnAt, i.time >= r {
            respawnAt = nil
            actions += respawns(step, i)
        }
        switch step {
        case .pose:
            if let a = i.angle, a.isFinite, Self.poseRange.contains(a) {
                let since = poseSince ?? i.time
                poseSince = since
                if i.time - since >= Self.poseHold { pass("That's it!", at: i.time) }
            } else {
                poseSince = nil
            }
        case .firstSnap:
            if Self.caught(i.events) > 0 {
                pass("CHOMP!", at: i.time)
            } else if Self.snapped(i.events) != nil && i.liveFlies == 0 {
                miss("It got away. Here comes another.", at: i.time)
            } else if i.liveFlies == 0 && respawnAt == nil && i.time - stepStart > 0.5 {
                respawnAt = i.time + Self.respawnDelay
            }
        case .openAgain:
            if i.armed && i.time - stepStart >= Self.openDwell { pass("Ready to bite!", at: i.time) }
        case .tooSlow:
            if Self.caught(i.events) > 0 {
                pass("Quick snap!", at: i.time)
            } else if Self.spooked(i.events) || Self.escaped(i.events) {
                warning = i.hasHinge ? "Snap it — quick!" : "Tap as soon as they sip!"
            }
            if !isPassing && i.liveFlies == 0 && respawnAt == nil && i.time - stepStart > 0.5 {
                respawnAt = i.time + Self.respawnDelay
                attempts += 1
            }
        case .bee:
            if Self.stung(i.events) {
                miss("Bzzt! Never eat a bee.", at: i.time)
                // The bitten bee flies off cross: its leaving is not a spare.
                ignoreLeavesUntil = i.time + Self.stungBeeExit
                respawnAt = i.time + Self.stungBeeExit
            } else if Self.beeLeft(i.events) && warning == nil && i.time >= ignoreLeavesUntil {
                pass("Good. Bees are friends.", at: i.time)
            } else if i.liveBees == 0 && respawnAt == nil && i.time - stepStart > 0.5 && !isPassing {
                respawnAt = i.time + Self.respawnDelay
            }
        case .triple:
            if let report = Self.snapped(i.events) {
                if report.caught.filter({ !$0.isProtected }).count >= 3 {
                    pass("TRIPLE ×3!", at: i.time)
                } else {
                    miss("Wait for all three…", at: i.time)
                }
            } else if i.liveFlies < 3 && respawnAt == nil && i.time - stepStart > 0.5 && !isPassing {
                respawnAt = i.time + Self.respawnDelay
            }
        case .done:
            break
        }
        return actions
    }

    private var isPassing: Bool { advanceAt != nil }

    private mutating func pass(_ text: String, at time: Double) {
        praise = text
        warning = nil
        respawnAt = nil
        advanceAt = time + Self.praiseSeconds
    }

    /// The step repeats: a warning line, and the cast comes back.
    private mutating func miss(_ text: String, at time: Double) {
        warning = text
        attempts += 1
        if respawnAt == nil { respawnAt = time + Self.respawnDelay }
    }

    private mutating func enter(_ s: Step) {
        step = s
        entered = false
        poseSince = nil
        praise = nil
        warning = nil
        respawnAt = nil
        advanceAt = nil
        attempts = 0
    }

    private func next(_ s: Step) -> Step {
        Step(rawValue: s.rawValue + 1) ?? .done
    }

    /// The cast a step starts with.
    private func spawns(_ s: Step) -> [Action] {
        switch s {
        case .firstSnap: return [.spawn(.housefly, slot: 0, linger: .infinity)]
        case .tooSlow: return [.spawn(.housefly, slot: 1, linger: .infinity), .spawn(.housefly, slot: 2, linger: .infinity)]
        case .bee: return [.spawn(.bee, slot: 0, linger: Self.beeLinger)]
        case .triple:
            return [.spawn(.housefly, slot: 3, linger: .infinity), .spawn(.housefly, slot: 4, linger: .infinity),
                    .spawn(.housefly, slot: 5, linger: .infinity)]
        case .pose, .openAgain, .done: return []
        }
    }

    /// After a miss: the cast tops back up.
    private mutating func respawns(_ s: Step, _ i: Input) -> [Action] {
        switch s {
        case .firstSnap:
            return i.liveFlies == 0 ? [.spawn(.housefly, slot: 0, linger: .infinity)] : []
        case .tooSlow:
            let need = max(2 - i.liveFlies, 0)
            return (0..<need).map { k -> Action in .spawn(.housefly, slot: 1 + k, linger: .infinity) }
        case .bee:
            warning = nil
            return i.liveBees == 0 ? [.spawn(.bee, slot: 0, linger: Self.beeLinger)] : []
        case .triple:
            let need = max(3 - i.liveFlies, 0)
            return (0..<need).map { k -> Action in .spawn(.housefly, slot: 3 + k, linger: .infinity) }
        case .pose, .openAgain, .done:
            return []
        }
    }

    // MARK: Event reading (pure)

    static func caught(_ events: [TrapEvent]) -> Int {
        var n = 0
        for e in events {
            if case let .bugCaught(_, species, _) = e, !species.isProtected { n += 1 }
        }
        return n
    }

    static func snapped(_ events: [TrapEvent]) -> BiteReport? {
        for e in events {
            if case let .snapped(report) = e { return report }
        }
        return nil
    }

    static func stung(_ events: [TrapEvent]) -> Bool {
        events.contains { e in
            if case .stung = e { return true }
            return false
        }
    }

    static func spooked(_ events: [TrapEvent]) -> Bool {
        events.contains { e in
            if case .bugSpooked = e { return true }
            return false
        }
    }

    static func escaped(_ events: [TrapEvent]) -> Bool {
        events.contains { e in
            if case .bugEscaped = e { return true }
            return false
        }
    }

    /// A bee left the trap uneaten (spared, or flew off).
    static func beeLeft(_ events: [TrapEvent]) -> Bool {
        events.contains { e in
            switch e {
            case .beeSpared: return true
            case let .bugLeft(_, species): return species.isProtected
            default: return false
            }
        }
    }

    // MARK: Display

    func display(touch: Bool) -> LessonDisplay {
        let total = Step.done.rawValue - 1
        let shown = min(step.rawValue, total)
        return LessonDisplay(step: step.rawValue, stepOf: "Step \(shown) of \(total)", line: Self.line(step, touch: touch),
                             praise: praise, warning: warning, allowsSkip: allowsSkip && step != .done,
                             isFinal: step == .done)
    }

    /// One sentence per step (GAME-DESIGN §8). Pure; tested (≤ 8 words each).
    static func line(_ s: Step, touch: Bool) -> String {
        switch s {
        case .pose: return "Hold it open like a book."
        case .firstSnap: return touch ? "When it's sipping… tap to snap!" : "When it's sipping… snap shut!"
        case .openAgain: return touch ? "It opens again by itself." : "Open up to reset the trap."
        case .tooSlow: return touch ? "Two flies. Tap to snap!" : "Quick snaps catch more."
        case .bee: return "Never eat a bee. Wait…"
        case .triple: return touch ? "Wait for a crowd… now tap!" : "Wait for a crowd… now!"
        case .done: return "Snaps run out. Big bites earn them back."
        }
    }
}

/// What the lesson card shows.
struct LessonDisplay: Equatable {
    var step: Int
    var stepOf: String
    var line: String
    var praise: String?
    var warning: String?
    var allowsSkip: Bool
    var isFinal: Bool
}
