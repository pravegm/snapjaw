import Foundation

// MARK: - R8: the App's side of Core's levels (ROUND-8 §4; Core owns `Snap/Core/Levels.swift`)
//
// Core owns the 30 levels (`LevelBook.all`: the scripted bog, the goal, the limits), their session
// (`SessionOptions.for(.level(id))`) and their judge (`LevelBook.evaluate`). The App persists the stars, opens the
// levels and the worlds, and shows them. `LevelBridge` is the one place that reads Core's `LevelSpec`.

/// The one place the App reads Core's level types.
enum LevelBridge {
    static var all: [LevelSpec] { LevelBook.all }
    static var count: Int { LevelBook.all.count }

    static func spec(_ id: Int) -> LevelSpec? { LevelBook.level(id) }
    /// The level's fixed session seed (Core's: the same in the balance sim).
    static func seed(_ id: Int) -> UInt64 { LevelBook.seed(id) }
    static func id(_ s: LevelSpec) -> Int { s.id }
    static func world(_ s: LevelSpec) -> Int { s.world }
    static func title(_ s: LevelSpec) -> String { s.title }
    static func goal(_ s: LevelSpec) -> String { s.goalText }
    /// The level's time limit (session s), nil when it has none.
    static func timeLimit(_ s: LevelSpec) -> Double? { s.timeLimit }

    static func evaluate(_ r: RunResult, _ s: LevelSpec) -> LevelJudgement {
        let o = LevelBook.evaluate(r, s)
        return LevelJudgement(stars: min(max(o.stars, 0), 3), passed: o.passed, line: o.line)
    }
}

/// Core's `LevelOutcome` as the App keeps it.
struct LevelJudgement: Equatable {
    var stars: Int
    var passed: Bool
    var line: String
}

/// A level's intro card (R8): its number, its world, its name, its goal in one line.
struct LevelIntro: Equatable {
    var id: Int
    var world: Int
    var title: String
    var goal: String
    /// No hinge: the card waits for a tap ("Tap to start"); on a Duo it waits for the phone to close.
    var touch: Bool
}

/// The levels' words (R8). Pure; tested.
enum LevelWords {
    static func levelName(_ id: Int) -> String { "Level \(max(id, 1))" }

    /// ROUND-8 §4: Morning Bog, Dusk, Night.
    static func worldName(_ world: Int) -> String {
        switch world {
        case 1: return "Morning Bog"
        case 2: return "Dusk"
        default: return "Night"
        }
    }

    static func worldLine(_ world: Int) -> String {
        switch world {
        case 1: return "Learn the bite"
        case 2: return "Moths, wasps and long shadows"
        default: return "Fireflies and fast hands"
        }
    }

    /// "12 more ★ to open Dusk".
    static func unlockLine(_ data: ProgressData, world: Int) -> String {
        let need = max(LevelRules.starsToOpen(world: world) - LevelRules.totalStars(data), 0)
        return "\(need) more ★ to open " + worldName(world)
    }

    /// The intro card's start line.
    static func startLine(touch: Bool) -> String { touch ? "Tap to start" : "Close the phone to start" }

    // MARK: R9: every line about the control is input-aware (phones tap, the Duo closes the phone)

    /// A level's goal in the player's control: Core's line with its control words made right for the input (Core's
    /// goal texts speak of the Duo: "Shut the phone on the fly"). Pure; tested.
    static func goal(_ s: LevelSpec, touch: Bool) -> String { inputAware(LevelBridge.goal(s), touch: touch) }

    /// Core's level-result line in the player's control ("Out of time. Shut it faster" → a phone: "Out of time. Snap
    /// sooner"). Pure; tested.
    static func outcomeLine(_ line: String, touch: Bool) -> String { inputAware(line, touch: touch) }

    /// The control phrases Core's level texts use, and what each says on a phone (a tap) and on the Duo (close the
    /// phone; "shut" reads as a demand for a full slam, "close" is the founder's word). Longest first. An empty phone
    /// form drops the phrase (speed is the Duo's skill: a tap is always quick).
    static let controlPhrases: [(core: String, duo: String, phone: String)] = [
        // R9: Core's Level 1 goal is input-neutral ("Catch the fly"); the first level names the control.
        ("Catch the fly", "Close the phone on the fly", "Tap when the fly lands"),
        ("Shut the phone on the fly","Close the phone on the fly", "Tap when the fly lands"),
        ("Close the phone on the fly", "Close the phone on the fly", "Tap when the fly lands"),
        (". Shut it faster", ". Close it faster", ". Snap sooner"),
        (". Shut it fast", ". Close it fast", ""),
        (". Close it fast", ". Close it fast", ""),
        ("Shut the phone", "Close the phone", "Tap"),
        ("Close the phone", "Close the phone", "Tap"),
        ("Shut it", "Close it", "Tap"),
        ("shut it", "close it", "tap"),
        ("the lid", "the phone", "the trap"),
    ]

    /// Rewrites `text`'s control words for the input (see `controlPhrases`). Pure; tested.
    static func inputAware(_ text: String, touch: Bool) -> String {
        var out = text
        for p in controlPhrases where out.contains(p.core) {
            out = out.replacingOccurrences(of: p.core, with: touch ? p.phone : p.duo)
        }
        return out
    }

    /// Words a phone (no hinge) must never be told: it has nothing to close. Pure; tested.
    static func speaksOfTheHinge(_ text: String) -> Bool {
        let t = text.lowercased()
        return ["close the phone", "close it", "shut", "the phone", "lid"].contains { t.contains($0) }
    }
}

/// The levels' rules on the save (R8): ids 1…30, ten a world; a level opens once the one before it is passed (a
/// world's first once the world is open); world w opens at (w − 1) × 20 stars in all (Core's `LevelBook` rules, so the
/// map and the sim agree). Pure; tested.
enum LevelRules {
    static let perWorld = 10
    static var worlds: Int { LevelBook.worldCount }
    /// ROUND-8 §4: "the next world unlocks at 20 stars".
    static var worldUnlockStars: Int { LevelBook.worldUnlockStars }

    /// The stars in all that open `world`.
    static func starsToOpen(world: Int) -> Int { max(world - 1, 0) * worldUnlockStars }

    static var lastID: Int { max(min(LevelBridge.count, perWorld * worlds), 1) }

    static func world(of id: Int) -> Int { min(max((max(id, 1) - 1) / perWorld + 1, 1), worlds) }
    static func ids(world: Int) -> ClosedRange<Int> {
        let w = min(max(world, 1), worlds)
        return ((w - 1) * perWorld + 1)...(w * perWorld)
    }

    static func stars(_ d: ProgressData, _ id: Int) -> Int { min(max(d.levelStars[id] ?? 0, 0), 3) }
    static func passed(_ d: ProgressData, _ id: Int) -> Bool { stars(d, id) > 0 }

    static func worldStars(_ d: ProgressData, world: Int) -> Int {
        guard world >= 1 && world <= worlds else { return 0 }
        return ids(world: world).reduce(0) { $0 + stars(d, $1) }
    }

    static func totalStars(_ d: ProgressData) -> Int {
        (1...worlds).reduce(0) { $0 + worldStars(d, world: $1) }
    }

    static func isWorldOpen(_ d: ProgressData, world: Int) -> Bool {
        guard world <= worlds else { return false }
        return LevelBook.worldUnlocked(world, best: d.levelStars)
    }

    static func isOpen(_ d: ProgressData, _ id: Int) -> Bool {
        guard id >= 1 && id <= lastID else { return false }
        return LevelBook.levelUnlocked(id, best: d.levelStars)
    }

    /// Home's Play: the first open level not passed yet, else the first open one short of 3 stars (to earn a world),
    /// else nil (every level done: Play is Endless).
    static func next(_ d: ProgressData) -> Int? {
        let open = (1...lastID).filter { isOpen(d, $0) }
        if let fresh = open.first(where: { !passed(d, $0) }) { return fresh }
        return open.first(where: { stars(d, $0) < 3 })
    }

    /// The level results' Next: the level after `id` when it is open, nil otherwise.
    static func nextAfter(_ id: Int, in d: ProgressData) -> Int? {
        let n = id + 1
        return n <= lastID && isOpen(d, n) ? n : nil
    }

    /// Keeps a try's stars (the best ever). Returns the best before and after, and a world this try opened.
    static func record(_ d: inout ProgressData, id: Int, stars: Int) -> (before: Int, after: Int, opened: Int?) {
        let before = self.stars(d, id)
        let openBefore = (1...worlds).filter { isWorldOpen(d, world: $0) }.count
        let after = max(before, min(max(stars, 0), 3))
        if after > 0 { d.levelStars[id] = after }
        let openAfter = (1...worlds).filter { isWorldOpen(d, world: $0) }.count
        return (before, after, openAfter > openBefore ? openAfter : nil)
    }
}
