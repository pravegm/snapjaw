import CoreGraphics
import Foundation

/// The First Bite lesson (GAME-DESIGN §8), taught by doing: one sentence per step, a scripted bug cast that lands ON
/// nectar drops (so it sips), and a step that passes only when the player has done the thing. Pure (the GameController
/// feeds it each frame's state and events and performs its actions); tested.
///
/// R2 (QA-1 #3, #10; REVIEW-1 #8, #9, #22):
/// - step 2 passes on any snap with a fly in the trap (a miss is praised too: "Snap! Quicker catches more.");
/// - Skip is offered from step 1;
/// - the pose step moves on after 3 s with no hinge reading;
/// - the bee lingers 6 s, long enough to learn the halo and "Bee! Wait…";
/// - on touch the dead "It opens again" step is merged into step 2's praise, and the visible steps are numbered 1–4.
struct LessonScript: Equatable {
    enum Step: Int, CaseIterable, Equatable {
        case pose = 1, firstSnap, openAgain, tooSlow, bee, triple, done
    }

    /// One frame of the lesson as the script sees it.
    struct Input {
        /// Session seconds.
        var time: Double
        var angle: Double?
        /// The trap is (or will be) driven by a hinge: the pose step applies. Else it is skipped.
        var hasHinge: Bool
        var armed: Bool
        var events: [TrapEvent]
        /// Edible bugs on screen still in play (not leaving, caught or escaped).
        var liveFlies: Int
        /// Protected bugs on screen still in play.
        var liveBees: Int
        /// Edible bugs in play that are inside the trap zone (landed, walking or sipping on a lobe).
        var fliesInTrap: Int
        /// Taps drive the trap (the texts say "tap"; the re-arm step is merged into step 2).
        var touch: Bool

        init(time: Double, angle: Double? = nil, hasHinge: Bool, armed: Bool = true, events: [TrapEvent] = [],
             liveFlies: Int = 0, liveBees: Int = 0, fliesInTrap: Int = 0, touch: Bool? = nil) {
            self.time = time; self.angle = angle; self.hasHinge = hasHinge; self.armed = armed; self.events = events
            self.liveFlies = liveFlies; self.liveBees = liveBees; self.fliesInTrap = fliesInTrap
            self.touch = touch ?? !hasHinge
        }
    }

    /// What the controller should do: put a scripted bug in (`slot` = `AppRules.lessonSpot`, aimed at a real drop).
    enum Action: Equatable {
        case spawn(BugSpecies, slot: Int, linger: Double)
    }

    // MARK: Timing

    /// The pose step passes after this long held like a book.
    static let poseHold: Double = 0.6
    static let poseRange: ClosedRange<Double> = 125...176
    /// With no hinge reading this long into the pose step, the lesson goes on with taps (QA-1 #10).
    static let poseNoHinge: Double = 3
    /// Praise stays up this long before the next step.
    static let praiseSeconds: Double = 1.3
    /// A bug that flew off comes back after this.
    static let respawnDelay: Double = 1.2
    /// The re-arm step shows at least this long.
    static let openDwell: Double = 0.8
    /// The bee leaves after this long on its drop (REVIEW-1 #9: 3 s was gone before it could be learned).
    static let beeLinger: Double = 6
    /// R3 (REVIEW-2 #18): two flies sip beside the bee (the temptation), and stay a little longer than it.
    static let beeFlyLinger: Double = 10
    /// A bitten bee is let go and flies off; the next bee comes after this, and the old one's leaving never counts.
    static let stungBeeExit: Double = 2.4

    // MARK: Words (pure; tested)

    static let praiseCatch = "CHOMP!"
    static let praiseMiss = "Snap! Quicker catches more."
    /// Touch: step 3 ("It opens again by itself") is merged into step 2's praise.
    static let praiseCatchTouch = "CHOMP! It opens again by itself."
    static let praiseMissTouch = "Snap! It opens again by itself."
    static let waitForSip = "Wait till it's sipping…"
    /// R4 (QA-2 #15): held flat (or nearly), the pose step says what to do. R7 (#12): play's words too.
    static let bendALittle = AppRules.tooFlatCopy + ", like a book"
    /// Above this the Duo is too flat to read as a book.
    static let flatAbove: Double = 176

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
    /// Taps drive the trap (latched from the last input).
    private(set) var touch = false

    init(start: Step = .pose, replay: Bool = false) {
        self.step = start
        self.replay = replay
    }

    var isDone: Bool { step == .done }
    /// Skip is offered on every step (QA-1 #3: a first-timer stuck on step 2 had no way out).
    var allowsSkip: Bool { step != .done }

    // MARK: Update

    mutating func update(_ i: Input) -> [Action] {
        var actions: [Action] = []
        touch = i.touch
        if step == .pose && !i.hasHinge { enter(.firstSnap) }
        if step == .openAgain && i.touch && advanceAt == nil { enter(.tooSlow) }
        if let at = advanceAt {
            guard i.time >= at else { return actions }
            advanceAt = nil
            enter(Self.next(step, touch: i.touch))
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
                if warning == Self.bendALittle { warning = nil }
                let since = poseSince ?? i.time
                poseSince = since
                if i.time - since >= Self.poseHold { pass("That's it!", at: i.time) }
            } else {
                poseSince = nil
                if let a = i.angle, a.isFinite {
                    let flat = a > Self.flatAbove
                    if flat && warning == nil && !isPassing { warning = Self.bendALittle }
                    if !flat && warning == Self.bendALittle { warning = nil }
                }
                if i.angle == nil && i.time - stepStart >= Self.poseNoHinge && !isPassing {
                    // No hinge reading at all: carry on with taps rather than wait for ever.
                    enter(.firstSnap)
                    entered = true
                    stepStart = i.time
                    actions += spawns(.firstSnap)
                }
            }
        case .firstSnap:
            guard !isPassing else { break }
            if let report = Self.snapped(i.events) {
                // Any snap with a fly in the trap passes (GAME-DESIGN §8: the first snap can be any speed).
                if Self.caught(i.events) > 0 {
                    pass(i.touch ? Self.praiseCatchTouch : Self.praiseCatch, at: i.time)
                } else if report.escaped > 0 || i.fliesInTrap > 0 {
                    pass(i.touch ? Self.praiseMissTouch : Self.praiseMiss, at: i.time)
                } else {
                    warning = Self.waitForSip
                }
            } else if i.liveFlies == 0 && respawnAt == nil && i.time - stepStart > 0.5 {
                respawnAt = i.time + Self.respawnDelay
            }
        case .openAgain:
            if i.armed && i.time - stepStart >= Self.openDwell && !isPassing { pass("Ready to bite!", at: i.time) }
        case .tooSlow:
            guard !isPassing else { break }
            let caught = Self.caught(i.events)
            // Touch: "Two flies. Get both in one bite." Hinge: any catch (the lesson is speed).
            let need = i.touch ? 2 : 1
            if caught >= need {
                pass(caught >= 2 ? "Double ×2!" : "Quick snap!", at: i.time)
            } else if caught > 0 {
                warning = "Wait for both…"
            } else if Self.spooked(i.events) || Self.escaped(i.events) {
                warning = i.touch ? "Tap as soon as they sip!" : "Snap it — quick!"
            }
            if !isPassing && i.liveFlies < 2 && respawnAt == nil && i.time - stepStart > 0.5 {
                respawnAt = i.time + Self.respawnDelay
                attempts += 1
            }
        case .bee:
            guard !isPassing else { break }
            if Self.stung(i.events) {
                miss("Bzzt! Never eat a bee.", at: i.time)
                // The bitten bee flies off cross: its leaving is not a spare.
                ignoreLeavesUntil = i.time + Self.stungBeeExit
                respawnAt = i.time + Self.stungBeeExit
            } else if Self.beeLeft(i.events) && warning == nil && i.time >= ignoreLeavesUntil {
                pass("Good. Bees are friends.", at: i.time)
            } else if i.liveBees == 0 && respawnAt == nil && i.time - stepStart > 0.5 {
                respawnAt = i.time + Self.respawnDelay
            }
        case .triple:
            guard !isPassing else { break }
            if let report = Self.snapped(i.events) {
                if report.caught.filter({ !$0.isProtected }).count >= 3 {
                    pass("TRIPLE ×3!", at: i.time)
                } else {
                    miss("Wait for all three…", at: i.time)
                }
            } else if i.liveFlies < 3 && respawnAt == nil && i.time - stepStart > 0.5 {
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

    /// The next step: on touch the re-arm step is skipped (taps re-arm by themselves). Pure; tested.
    static func next(_ s: Step, touch: Bool) -> Step {
        let n = Step(rawValue: s.rawValue + 1) ?? .done
        if touch && n == .openAgain { return .tooSlow }
        return n
    }

    /// The cast a step starts with.
    private func spawns(_ s: Step) -> [Action] {
        switch s {
        case .firstSnap: return [.spawn(.housefly, slot: 0, linger: .infinity)]
        case .tooSlow: return [.spawn(.housefly, slot: 1, linger: .infinity), .spawn(.housefly, slot: 2, linger: .infinity)]
        case .bee:
            // The bee first, so it gets the drop nearest its slot; a fly sips beside it, another on the other lobe.
            return [.spawn(.bee, slot: 0, linger: Self.beeLinger), .spawn(.housefly, slot: 1, linger: Self.beeFlyLinger),
                    .spawn(.housefly, slot: 2, linger: Self.beeFlyLinger)]
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
            warning = nil
            return i.liveFlies == 0 ? [.spawn(.housefly, slot: 0, linger: .infinity)] : []
        case .tooSlow:
            let need = max(2 - i.liveFlies, 0)
            return (0..<need).map { k -> Action in .spawn(.housefly, slot: 1 + k, linger: .infinity) }
        case .bee:
            warning = nil
            var cast: [Action] = i.liveBees == 0 ? [.spawn(.bee, slot: 0, linger: Self.beeLinger)] : []
            for k in 0..<max(2 - i.liveFlies, 0) {
                cast.append(.spawn(.housefly, slot: 1 + k, linger: Self.beeFlyLinger))
            }
            return cast
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

    /// The steps a player sees, in order: on touch there is no pose step and no re-arm step (REVIEW-1 #22).
    static func visibleSteps(touch: Bool, hasPose: Bool) -> [Step] {
        Step.allCases.filter { s in
            switch s {
            case .done: return false
            case .pose: return hasPose
            case .openAgain: return !touch
            case .firstSnap, .tooSlow, .bee, .triple: return true
            }
        }
    }

    /// R5 (REVIEW-4 #11: the phone showed "Step n of 4", the Duo "Step 1 of 5" and "Step 2 of 6"): the taught steps
    /// are numbered the same way on every launch of a device, and the pose step is "Get ready" (never counted).
    /// R7 (#12, duo-ui-lesson-3-hinge-128: "STEP 1 OF 4 · Open up to reset the trap."): on a hinge the re-arm step is
    /// a step of its own, so the counter moves on with its words: five steps on the Duo, four on phones (taps re-arm
    /// by themselves, so phones have no re-arm step).
    static let numberedSteps: [Step] = [.firstSnap, .tooSlow, .bee, .triple]
    static let numberedStepsHinge: [Step] = [.firstSnap, .openAgain, .tooSlow, .bee, .triple]
    static let readyLabel = "Get ready"

    /// The numbered steps for an input (`touch`: phones). Pure; tested.
    static func numbered(touch: Bool) -> [Step] { touch ? numberedSteps : numberedStepsHinge }

    /// "Step 2 of 4" on phones, "Step 2 of 5" on the Duo (`hasPose` never changes it). Pure; tested.
    static func stepLabel(_ s: Step, touch: Bool, hasPose: Bool) -> String {
        let steps = numbered(touch: touch)
        let n = steps.count
        let shown: Step
        switch s {
        case .pose: return readyLabel
        case .openAgain: shown = touch ? .firstSnap : .openAgain
        case .done: shown = .triple
        case .firstSnap, .tooSlow, .bee, .triple: shown = s
        }
        let index = (steps.firstIndex(of: shown) ?? 0) + 1
        return "Step \(min(index, n)) of \(n)"
    }

    /// `hasPose`: the pose step counts (a hinge drives, or a Duo-shaped layout is waiting for one).
    func display(touch: Bool, hasPose: Bool) -> LessonDisplay {
        LessonDisplay(step: step.rawValue, stepOf: Self.stepLabel(step, touch: touch, hasPose: hasPose),
                      line: Self.line(step, touch: touch), praise: praise, warning: warning,
                      allowsSkip: allowsSkip, isFinal: step == .done, showsSnaps: Self.showsSnaps(step),
                      showsClap: !touch && step == .firstSnap)
    }

    /// R3 (REVIEW-2 #12): the snaps row is on screen from step 3 (the re-arm step; on touch, the two-fly step) to
    /// the last card, which rings it. Pure; tested.
    static func showsSnaps(_ s: Step) -> Bool { s.rawValue >= Step.openAgain.rawValue }

    /// One sentence per step (GAME-DESIGN §8). Pure; tested (≤ 8 words each).
    static func line(_ s: Step, touch: Bool) -> String {
        switch s {
        case .pose: return "Hold it open like a book."
        case .firstSnap: return touch ? "When it's sipping… tap to snap!" : "When it's sipping… snap shut!"
        case .openAgain: return touch ? "It opens again by itself." : "Open up to reset the trap."
        case .tooSlow: return touch ? "Two flies. Get both in one bite." : "Quick snaps catch more."
        case .bee: return "Never eat a bee. Wait…"
        // R7 (SCORE-R6 D2 #3: the card's "…now tap!" doubled the "Now!" plate): the card says wait, the plate says now.
        case .triple: return "Wait for a crowd of three…"
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
    /// The snaps row shows (R3, REVIEW-2 #12).
    var showsSnaps = false
    /// Step 2 on a hinge: the card shows the 160° → 138° clap (ROUND-3 founder call).
    var showsClap = false
}
