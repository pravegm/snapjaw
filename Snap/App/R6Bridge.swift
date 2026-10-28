import CoreGraphics
import Foundation

// MARK: - R6: the App's side of Core's goals and the Garden (design/notes/core-R6.md)
//
// Core owns the pool, the draw, the evaluation and the rewards (`GoalBook`, `GoalTracker`, `Varieties`); the App
// persists `GoalBookState`, ticks a `GoalTracker` live, and shows `GoalLine`s. One source of truth: nothing here
// re-decides a goal.

/// One goal as a screen shows it (Home, the pause menu, Results).
struct GoalLine: Equatable, Identifiable {
    var id: String
    var title: String
    var progress: Int
    var target: Int
    var done: Bool
    /// The run being played counts toward it (a Daily goal in the Zen Bog doesn't: it is drawn dimmed).
    var inPlay = true
    /// It can't be met this run any more (a dry snap before dusk): drawn dimmed.
    var spoiled = false
    /// "2/3", "1,250/2,000" (Core's label).
    var countText = ""

    /// 0…1 for the little bar.
    var fraction: Double {
        guard target > 0 else { return done ? 1 : 0 }
        return min(max(Double(progress) / Double(target), 0), 1)
    }

    /// A line for a Core goal at `progress`.
    static func make(_ g: GoalSpec, progress: Int, done: Bool, inPlay: Bool = true, spoiled: Bool = false) -> GoalLine {
        let p = done ? g.target : min(max(progress, 0), g.target)
        return GoalLine(id: g.id, title: g.title, progress: p, target: max(g.target, 1), done: done, inPlay: inPlay,
                        spoiled: spoiled, countText: g.progressLabel(p))
    }
}

/// What a run did to its goals, as the App keeps it (a run killed in the background is filed from it): each tracked
/// goal's progress with the run included (`GoalTracker.progress`), and the ids met during the run, in order.
struct GoalReport: Codable, Equatable {
    var completed: [String] = []
    var progress: [String: Int] = [:]

    init(completed: [String] = [], progress: [String: Int] = [:]) {
        self.completed = completed
        self.progress = progress
    }

    private enum CodingKeys: String, CodingKey { case completed, progress }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completed = (try? c.decodeIfPresent([String].self, forKey: .completed)) ?? []
        progress = (try? c.decodeIfPresent([String: Int].self, forKey: .progress)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(completed, forKey: .completed)
        try c.encode(progress, forKey: .progress)
    }

    var isEmpty: Bool { completed.isEmpty && progress.isEmpty }
}

enum GoalBridge {
    /// Three goals at a time (ROUND-6 founder decision 1).
    static var slots: Int { Tuning.goalsActive }
    /// Every goal in Core's pool (the fit tests render each toast).
    static var allIDs: [String] { GoalBook.pool.map(\.id) }
    static func title(_ id: String) -> String { GoalBook.def(id)?.title ?? "A new goal" }
}

/// A run's live goals: Core's tracker, fed every step's events; says which goals were just met.
struct GoalRun {
    private var tracker: GoalTracker?
    /// The ids met during this run, in the order they were.
    private(set) var completed: [String] = []

    /// No goals (the lesson, the attract bog).
    init() {}

    init(book: GoalBookState, mode: RunMode, startPhase: DayPhase = .morning) {
        switch mode {
        case .feed, .daily, .zen: tracker = GoalBook.tracker(book, mode: mode, startPhase: startPhase)
        case .attract, .lesson: tracker = nil
        }
    }

    var isEmpty: Bool { tracker == nil }

    /// Feeds a step. Returns the goals met by it (each once per run).
    mutating func note(_ events: [TrapEvent]) -> [GoalSpec] {
        guard var t = tracker, !events.isEmpty else { return [] }
        let met = t.ingest(events)
        tracker = t
        for g in met where !completed.contains(g.id) { completed.append(g.id) }
        return met
    }

    /// The run's goals as lines (the pause menu): progress with this run included.
    var lines: [GoalLine] {
        guard let t = tracker else { return [] }
        return t.goals.map { g in
            GoalLine.make(g, progress: t.progress(g), done: t.isMet(g), inPlay: t.counts(g), spoiled: t.isSpoiled(g))
        }
    }

    var report: GoalReport {
        guard let t = tracker else { return GoalReport() }
        var p: [String: Int] = [:]
        for g in t.goals { p[g.id] = t.progress(g) }
        return GoalReport(completed: completed, progress: p)
    }
}

enum VarietyBridge {
    static func name(_ v: TrapVariety) -> String { Varieties.info(v).name }
    static func blurb(_ v: TrapVariety) -> String { Varieties.info(v).blurb }
    /// How a locked one grows ("Reach Nibbler", "Goal: Spare 12 bees in one run").
    static func rule(_ v: TrapVariety) -> String { Varieties.ruleText(v) }
}
