import Foundation

// MARK: - Goals (R6, ROUND-6 founder decision 1; design/notes/core-R6.md)
//
// Three active goals at a time, drawn from a pool of 39 by plant rank. Core owns the pool and the pure evaluation; the
// App persists a GoalBookState, feeds a run's events to a GoalTracker (live ticks and toasts) and calls
// GoalBook.complete at the end of the run (or when it is left early) to bank progress, replace completed goals and
// get the growth to add to the rank bar.
//
//   var book = GoalBook.start(seed: someRandomSeed, rank: rank)        // once; persist `book` (Codable)
//   var tracker = GoalBook.tracker(book, mode: mode)                   // at each run's start
//   let toasts = tracker.ingest(events)                                // every frame: goals met just now
//   let update = GoalBook.complete(book, tracker: tracker, rank: rank) // at Results
//   book = update.state                                                // persist; add update.growth to the rank bar
//
// Deterministic: the same state, rank and events always give the same update (draws come from state.seed and
// state.draws). Varieties.unlocked(rank:completedGoals:) reads state.everCompleted.

/// Which runs count toward a goal.
enum GoalScope: String, Codable, CaseIterable, Sendable {
    /// Feed, the Daily and the Zen Bog ("any mode").
    case anyMode = "any"
    /// Feed and the Daily: runs whose snaps run out (run totals that endless Zen would make trivial).
    case standard
    /// The Daily Bog only (a scored try or a practice one).
    case daily
    /// The Zen Bog only.
    case zen

    /// Attract and the lesson never count.
    func includes(_ mode: RunMode) -> Bool {
        switch mode {
        case .attract, .lesson: return false
        case .feed: return self == .anyMode || self == .standard
        case .daily: return self == .anyMode || self == .standard || self == .daily
        case .zen: return self == .anyMode || self == .zen
        }
    }

    /// A short tag for the goal card (the UI may restyle it).
    var label: String {
        switch self {
        case .anyMode: return "Any mode"
        case .standard: return "Feed or Daily"
        case .daily: return "Daily"
        case .zen: return "Zen"
        }
    }
}

/// How a goal's progress carries between runs.
enum GoalSpan: String, Codable, Sendable {
    /// In one run: the best run so far counts.
    case run
    /// Across runs: the runs add up.
    case total
}

/// What a goal measures. Everything is read from a run's TrapEvents (GoalTracker); RunResult can answer some of it
/// (GoalBook.progress(for:result:)).
enum GoalKind: Equatable, Sendable {
    /// Bugs of this species caught.
    case catchSpecies(BugSpecies)
    /// … caught while the day is in this phase.
    case catchSpeciesAt(BugSpecies, DayPhase)
    /// Any bugs caught while the day is in this phase.
    case catchAt(DayPhase)
    /// Bugs caught.
    case catchAny
    /// Bugs caught before the run's first bite with a stinger in it.
    case catchBeforeSting
    /// How many of these species were caught at least once (the target is usually all of them).
    case catchSet([BugSpecies])
    /// The most bugs in one bite.
    case biteSize
    /// The most different species in one bite.
    case mixedBite
    /// Feasts (clean bites of ≥ Tuning.feastCount).
    case feasts
    /// Feasts while the day is in this phase.
    case feastAt(DayPhase)
    /// The best chain multiplier reached (×2 … ×5; the multiplier the next clean bite gets), rounded down.
    case chain
    /// Protected bugs spared.
    case spare
    /// … of this species.
    case spareSpecies(BugSpecies)
    /// Points scored (the BiteReports' sum).
    case score
    /// 1 when the day reaches this phase with no dry snap so far and at least Tuning.goalMinSnaps snaps.
    case cleanUntil(DayPhase)
    /// 1 when the day reaches this phase.
    case reach(DayPhase)
    /// 1 when the run finishes (the trap tires; a run left early never finishes).
    case finish

    /// Goals of one family are not active together if the draw can help it (two bite-size goals at once is dull).
    var family: String {
        switch self {
        case .catchSpecies, .catchSpeciesAt, .catchSet: return "species"
        case .catchAt, .catchAny, .catchBeforeSting: return "count"
        case .biteSize, .mixedBite: return "bite"
        case .feasts, .feastAt: return "feast"
        case .chain: return "chain"
        case .spare, .spareSpecies: return "spare"
        case .score: return "score"
        case .cleanUntil, .reach, .finish: return "time"
        }
    }
}

/// One goal in the pool. Ids are stable (persisted).
struct GoalSpec: Equatable, Sendable {
    let id: String
    /// "{n}" is replaced by the target ("Catch {n} dragonflies in one run").
    let template: String
    let kind: GoalKind
    let target: Int
    let span: GoalSpan
    let scope: GoalScope
    /// The plant ranks (0…11) at which it can be drawn.
    let ranks: ClosedRange<Int>
    /// Completing it unlocks this variety (Varieties); such a goal is offered once its band opens and never again.
    let unlocks: TrapVariety?

    /// "Catch 3 dragonflies in one run", "Score 2,000 in the Daily".
    var title: String {
        return template.replacingOccurrences(of: "{n}", with: GoalBook.grouped(target))
    }

    /// "2/3" (progress clamped to the target; "1,250/2,000" for scores).
    func progressLabel(_ progress: Int) -> String {
        return GoalBook.grouped(min(max(progress, 0), target)) + "/" + GoalBook.grouped(target)
    }
}

/// An active goal and its banked progress (run goals: the best run so far; total goals: the sum so far).
struct GoalBookSlot: Codable, Equatable, Sendable {
    var id: String
    var progress: Int

    init(id: String, progress: Int = 0) {
        self.id = id
        self.progress = progress
    }
}

/// What the App persists.
struct GoalBookState: Codable, Equatable, Sendable {
    /// Picked once (any value); the draws come from it and `draws`.
    var seed: UInt64
    /// Draws made so far.
    var draws: Int
    /// Tuning.goalsActive slots (GoalBook.normalized repairs a short or stale list).
    var active: [GoalBookSlot]
    /// Every goal id ever completed, once each, in completion order (Varieties' goal unlocks read it).
    var everCompleted: [String]
    /// The last Tuning.goalRecentMemory goals completed (oldest first): not drawn again yet.
    var recent: [String]
    /// Goals completed in all (repeats count).
    var completedCount: Int
    /// All the growth goals have given (bugs-equivalent).
    var growth: Int

    init(seed: UInt64) {
        self.seed = seed
        self.draws = 0
        self.active = []
        self.everCompleted = []
        self.recent = []
        self.completedCount = 0
        self.growth = 0
    }

    var completedSet: Set<String> {
        return Set(everCompleted)
    }
}

/// What GoalBook.complete did.
struct GoalBookUpdate: Equatable, Sendable {
    /// The new state to persist.
    var state: GoalBookState
    /// The goals completed by this run, in slot order.
    var completed: [GoalSpec]
    /// Their replacements (the same slots), in the same order.
    var added: [GoalSpec]
    /// Growth to add to the rank bar (bugs-equivalent), the bonus included.
    var growth: Int
    /// The part of `growth` that is the all-three-at-once bonus (0 if not).
    var bonus: Int
}

// MARK: - One run's live progress

/// Feed it a run's events (every frame); it knows each active goal's progress and which were met this run.
struct GoalTracker {

    private struct PhaseMark {
        var snaps: Int
        var drySnaps: Int
    }

    let mode: RunMode
    /// The goals it tracks (GoalBook.tracker: the active ones).
    let goals: [GoalSpec]
    /// Banked progress at the run's start, by goal id.
    let carried: [String: Int]
    /// The day phase now.
    private(set) var phase: DayPhase
    /// Goals met during this run (or already met at its start).
    private(set) var met: Set<String> = []

    private var caught: [BugSpecies: Int] = [:]
    private var caughtAt: [DayPhase: [BugSpecies: Int]] = [:]
    private var caughtInPhase: [DayPhase: Int] = [:]
    private var caughtTotal: Int = 0
    private var caughtBeforeSting: Int = 0
    private var stung: Bool = false
    private var biggestBite: Int = 0
    private var mostKinds: Int = 0
    private var feasts: Int = 0
    private var feastsInPhase: [DayPhase: Int] = [:]
    private var bestMultiplier: Double = 1
    private var spared: Int = 0
    private var sparedBy: [BugSpecies: Int] = [:]
    private var score: Int = 0
    private var snaps: Int = 0
    private var drySnaps: Int = 0
    private var marks: [DayPhase: PhaseMark] = [:]
    private var finished: Bool = false

    /// `startPhase`: the day phase the session starts in (WaveFactory.phase(forWave: options.firstWave); morning).
    init(goals: [GoalSpec], carried: [String: Int], mode: RunMode, startPhase: DayPhase = .morning) {
        self.mode = mode
        self.goals = goals
        self.carried = carried
        self.phase = startPhase
        enter(startPhase)
        for g in goals where progress(g) >= g.target {
            met.insert(g.id)
        }
    }

    /// Takes this frame's events. Returns the goals met by them (each once per run): the App's toasts.
    @discardableResult
    mutating func ingest(_ events: [TrapEvent]) -> [GoalSpec] {
        for e in events { apply(e) }
        var fresh: [GoalSpec] = []
        for g in goals {
            if met.contains(g.id) { continue }
            if progress(g) >= g.target {
                met.insert(g.id)
                fresh.append(g)
            }
        }
        return fresh
    }

    /// Does this run count toward `g` (its scope includes the run's mode)?
    func counts(_ g: GoalSpec) -> Bool {
        return g.scope.includes(mode)
    }

    /// This run's own value for `g` (nothing banked), whatever the scope.
    func runValue(_ g: GoalSpec) -> Int {
        switch g.kind {
        case .catchSpecies(let s): return caught[s] ?? 0
        case .catchSpeciesAt(let s, let p): return caughtAt[p]?[s] ?? 0
        case .catchAt(let p): return caughtInPhase[p] ?? 0
        case .catchAny: return caughtTotal
        case .catchBeforeSting: return caughtBeforeSting
        case .catchSet(let list):
            var n: Int = 0
            for s in Set(list) where (caught[s] ?? 0) > 0 { n += 1 }
            return n
        case .biteSize: return biggestBite
        case .mixedBite: return mostKinds
        case .feasts: return feasts
        case .feastAt(let p): return feastsInPhase[p] ?? 0
        case .chain: return Int((bestMultiplier + 1e-9).rounded(.down))
        case .spare: return spared
        case .spareSpecies(let s): return sparedBy[s] ?? 0
        case .score: return score
        case .cleanUntil(let p):
            guard let m = marks[p] else { return 0 }
            return m.drySnaps == 0 && m.snaps >= Tuning.goalMinSnaps ? 1 : 0
        case .reach(let p): return marks[p] != nil ? 1 : 0
        case .finish: return finished ? 1 : 0
        }
    }

    /// The goal's progress with this run included (run goals: the better of the banked best and this run; total
    /// goals: banked + this run). A run whose mode the goal doesn't count leaves it at the banked value.
    func progress(_ g: GoalSpec) -> Int {
        let before: Int = carried[g.id] ?? 0
        if !counts(g) { return before }
        let v: Int = runValue(g)
        switch g.span {
        case .run: return max(before, v)
        case .total: return before + v
        }
    }

    func isMet(_ g: GoalSpec) -> Bool {
        return progress(g) >= g.target
    }

    /// This run can no longer meet `g` (a dry snap before dusk, a bee bitten before the count): the card can grey it.
    func isSpoiled(_ g: GoalSpec) -> Bool {
        if !counts(g) || isMet(g) { return false }
        switch g.kind {
        case .cleanUntil(let p): return marks[p] != nil || drySnaps > 0
        case .catchBeforeSting: return stung
        case .catchSpecies, .catchSpeciesAt, .catchAt, .catchAny, .catchSet, .biteSize, .mixedBite, .feasts,
             .feastAt, .chain, .spare, .spareSpecies, .score, .reach, .finish:
            return false
        }
    }

    private mutating func enter(_ p: DayPhase) {
        phase = p
        for ph in DayPhase.allCases where ph <= p && marks[ph] == nil {
            marks[ph] = PhaseMark(snaps: snaps, drySnaps: drySnaps)
        }
    }

    private mutating func apply(_ e: TrapEvent) {
        switch e {
        case .waveStarted(index: _, phase: let p):
            if p != phase { enter(p) }
        case .dayPhaseChanged(let p):
            enter(p)
        case .snapped(let r):
            snaps += 1
            score += r.points
            let n: Int = r.caught.count
            biggestBite = max(biggestBite, n)
            mostKinds = max(mostKinds, Set(r.caught).count)
            if r.stingers.isEmpty {
                if !stung { caughtBeforeSting += n }
            } else {
                stung = true
            }
        case .bugCaught(id: _, species: let s, position: _):
            caught[s, default: 0] += 1
            caughtAt[phase, default: [:]][s, default: 0] += 1
            caughtInPhase[phase, default: 0] += 1
            caughtTotal += 1
        case .feast:
            feasts += 1
            feastsInPhase[phase, default: 0] += 1
        case .chainUp(count: _, multiplier: let m):
            bestMultiplier = max(bestMultiplier, m)
        case .beeSpared(let s):
            spared += 1
            sparedBy[s, default: 0] += 1
        case .drySnap:
            drySnaps += 1
        case .finished:
            finished = true
        case .bugArrived, .bugLanded, .bugSipping, .bugHopped, .bugLeft, .bugSpooked, .snapStarted, .bugEscaped,
             .stung, .luckySnap, .chainBroken, .rearmed, .lastSnap, .hungry, .wilted, .tired, .newBest:
            break
        }
    }
}

// MARK: - The book

enum GoalBook {

    /// The goals that unlock varieties (Varieties reads these ids).
    static let sawtoothGoal: String = "spare12"
    static let sharkToothGoal: String = "bite6"
    static let fusedToothGoal: String = "chain5"

    private static func g(_ id: String, _ template: String, _ kind: GoalKind, _ target: Int, _ span: GoalSpan,
                          _ scope: GoalScope, _ ranks: ClosedRange<Int>, unlocks: TrapVariety? = nil) -> GoalSpec {
        return GoalSpec(id: id, template: template, kind: kind, target: target, span: span, scope: scope, ranks: ranks,
                       unlocks: unlocks)
    }

    /// The pool (39). Bands overlap so every rank has a dozen or more to draw from.
    static let pool: [GoalSpec] = [
        // Bite sizes
        g("bite3", "A 3-bug bite", .biteSize, 3, .run, .anyMode, 0...1),
        g("bite4", "A 4-bug bite", .biteSize, 4, .run, .anyMode, 0...4),
        g("bite5", "A 5-bug bite", .biteSize, 5, .run, .anyMode, 2...8),
        g(sharkToothGoal, "A 6-bug bite", .biteSize, 6, .run, .anyMode, 6...11, unlocks: .sharkTooth),
        g("bite7", "A 7-bug bite", .biteSize, 7, .run, .anyMode, 8...11),
        g("mixed3", "One bite, {n} kinds of bug", .mixedBite, 3, .run, .anyMode, 1...8),
        // Feasts
        g("feast2", "Feast twice in one run", .feasts, 2, .run, .standard, 0...4),
        g("feast6", "Feast {n} times in one run", .feasts, 6, .run, .standard, 5...11),
        g("feastMorning", "Feast before noon", .feastAt(.morning), 1, .run, .anyMode, 0...5),
        // Chains
        g("chain2", "Reach a ×{n} chain", .chain, 2, .run, .anyMode, 0...2),
        g("chain3", "Reach a ×{n} chain", .chain, 3, .run, .anyMode, 1...6),
        g("chain4", "Reach a ×{n} chain", .chain, 4, .run, .standard, 4...10),
        g(fusedToothGoal, "Reach a ×{n} chain", .chain, 5, .run, .standard, 9...11, unlocks: .fusedTooth),
        // Sparing
        g("spare3", "Spare {n} bees in one run", .spare, 3, .run, .standard, 0...2),
        g("spare8", "Spare {n} bees in one run", .spare, 8, .run, .standard, 2...7),
        g(sawtoothGoal, "Spare {n} bees in one run", .spare, 12, .run, .standard, 3...11, unlocks: .sawtooth),
        g("spare100", "Spare {n} bees", .spare, 100, .total, .anyMode, 5...11),
        g("wasp2", "Spare {n} wasps in one run", .spareSpecies(.wasp), 2, .run, .standard, 3...11),
        g("clean25", "Catch {n} bugs before biting a bee", .catchBeforeSting, 25, .run, .standard, 2...8),
        // Species hunts
        g("ladybird2", "Catch {n} ladybirds in one run", .catchSpecies(.ladybird), 2, .run, .standard, 0...5),
        g("flyTrio", "Catch a housefly, a fruit fly and a bluebottle in one run",
          .catchSet([.housefly, .fruitFly, .bluebottle]), 3, .run, .anyMode, 0...4),
        g("dragonfly1", "Catch a dragonfly", .catchSpecies(.dragonfly), 1, .run, .anyMode, 1...4),
        g("dragonfly3", "Catch {n} dragonflies in one run", .catchSpecies(.dragonfly), 3, .run, .standard, 4...11),
        g("fireflyNight", "Catch a firefly at night", .catchSpeciesAt(.firefly, .night), 1, .run, .anyMode, 2...6),
        g("firefly5", "Catch {n} fireflies at night", .catchSpeciesAt(.firefly, .night), 5, .run, .standard,
          6...11),
        g("nightShift", "Catch a firefly, a cricket and a moth in one run", .catchSet([.firefly, .cricket, .moth]),
          3, .run, .anyMode, 4...11),
        g("scarab", "Catch a Golden Scarab", .catchSpecies(.goldenScarab), 1, .run, .anyMode, 2...11),
        // Time of day
        g("cleanToDusk", "No dry snaps until dusk", .cleanUntil(.dusk), 1, .run, .standard, 1...7),
        g("cleanToNight", "No dry snaps until night", .cleanUntil(.night), 1, .run, .standard, 6...11),
        g("night", "Keep your trap going until night", .reach(.night), 1, .run, .standard, 1...3),
        g("dusk10", "Catch {n} bugs at dusk", .catchAt(.dusk), 10, .run, .standard, 2...6),
        g("night20", "Catch {n} bugs at night", .catchAt(.night), 20, .run, .standard, 5...11),
        // Run totals
        g("catch20", "Catch {n} bugs in one run", .catchAny, 20, .run, .standard, 0...2),
        g("catch60", "Catch {n} bugs in one run", .catchAny, 60, .run, .standard, 3...8),
        // The Daily
        g("dailyFinish", "Finish a Daily Bog", .finish, 1, .run, .daily, 0...11),
        g("daily2k", "Score {n} in the Daily", .score, 2_000, .run, .daily, 0...4),
        g("daily6k", "Score {n} in the Daily", .score, 6_000, .run, .daily, 4...11),
        // The Zen Bog
        g("zenCatch50", "Catch {n} bugs in the Zen Bog", .catchAny, 50, .run, .zen, 0...11),
        g("zenSpare15", "Spare {n} bees in the Zen Bog", .spare, 15, .run, .zen, 0...11),
    ]

    static func def(_ id: String) -> GoalSpec? {
        for d in pool where d.id == id { return d }
        return nil
    }

    private static func clampRank(_ rank: Int) -> Int {
        return min(max(rank, 0), PlantRanks.count - 1)
    }

    /// The goals that can be drawn at `rank` (before the draw's other rules).
    static func eligible(rank: Int) -> [GoalSpec] {
        let r: Int = clampRank(rank)
        return pool.filter { (d: GoalSpec) -> Bool in d.ranks.contains(r) }
    }

    /// A completed goal's growth at `rank`: Tuning.goalRewardShare of the gap to the next rank (the top rank uses the
    /// last gap), rounded to Tuning.goalRewardRound, at least Tuning.goalRewardMin. 10 at Sprout … 150 at the top.
    static func reward(rank: Int) -> Int {
        let r: Int = clampRank(rank)
        let gap: Int
        if r + 1 < PlantRanks.count {
            gap = PlantRanks.threshold(r + 1) - PlantRanks.threshold(r)
        } else {
            gap = PlantRanks.threshold(r) - PlantRanks.threshold(r - 1)
        }
        let steps: Double = Double(gap) * Tuning.goalRewardShare / Double(Tuning.goalRewardRound)
        return max(Tuning.goalRewardMin, Int(steps.rounded()) * Tuning.goalRewardRound)
    }

    /// The extra growth for completing every active goal in one run.
    static func tripleBonus(rank: Int) -> Int {
        return reward(rank: rank) * Tuning.goalTripleBonus
    }

    /// A fresh book: Tuning.goalsActive goals for `rank`.
    static func start(seed: UInt64, rank: Int) -> GoalBookState {
        return normalized(GoalBookState(seed: seed), rank: rank)
    }

    /// Drops unknown and repeated ids (a goal removed in an update), trims to Tuning.goalsActive and draws any
    /// missing slots. Call it when loading a persisted book.
    static func normalized(_ state: GoalBookState, rank: Int) -> GoalBookState {
        var s: GoalBookState = state
        var seen: Set<String> = []
        var kept: [GoalBookSlot] = []
        for slot in s.active {
            if def(slot.id) == nil || seen.contains(slot.id) { continue }
            seen.insert(slot.id)
            kept.append(GoalBookSlot(id: slot.id, progress: max(0, slot.progress)))
        }
        if kept.count > Tuning.goalsActive { kept = Array(kept.prefix(Tuning.goalsActive)) }
        s.active = kept
        var guardCount: Int = 0
        while s.active.count < Tuning.goalsActive && guardCount < Tuning.goalsActive * 2 {
            guardCount += 1
            if let d = draw(&s, rank: rank) { s.active.append(GoalBookSlot(id: d.id)) }
        }
        return s
    }

    /// The active goals' definitions, in slot order.
    static func activeGoals(_ state: GoalBookState) -> [GoalSpec] {
        return state.active.compactMap { (slot: GoalBookSlot) -> GoalSpec? in def(slot.id) }
    }

    /// A tracker for one run of `mode` over the book's active goals (their banked progress carried in).
    static func tracker(_ state: GoalBookState, mode: RunMode, startPhase: DayPhase = .morning) -> GoalTracker {
        var carried: [String: Int] = [:]
        for slot in state.active { carried[slot.id] = slot.progress }
        return GoalTracker(goals: activeGoals(state), carried: carried, mode: mode, startPhase: startPhase)
    }

    /// A goal's progress from one run's events alone (nothing banked): 0 when the run's mode doesn't count.
    static func progress(for goal: GoalSpec, mode: RunMode, events: [TrapEvent]) -> Int {
        var t = GoalTracker(goals: [goal], carried: [:], mode: mode)
        t.ingest(events)
        return t.progress(goal)
    }

    /// What a RunResult alone says about a goal (nil when it can't: day-phase goals, the before-a-sting count, Zen's
    /// looping night, finishing). 0 when the run's mode doesn't count. Events (GoalTracker) are the source of truth.
    static func progress(for goal: GoalSpec, result r: RunResult) -> Int? {
        if !goal.scope.includes(r.mode) { return 0 }
        switch goal.kind {
        case .catchSpecies(let s): return r.caughtBySpecies[s.rawValue] ?? 0
        case .catchAny: return r.bugsCaught
        case .catchSet(let list):
            var n: Int = 0
            for s in Set(list) where (r.caughtBySpecies[s.rawValue] ?? 0) > 0 { n += 1 }
            return n
        case .biteSize: return r.biggestBite
        case .feasts: return r.feasts
        case .chain: return Int((TrapRules.chainMultiplier(r.longestChain) + 1e-9).rounded(.down))
        case .spare: return r.beesSpared
        case .spareSpecies(let s): return r.sparedBySpecies[s.rawValue] ?? 0
        case .score: return r.score
        case .reach(let p):
            switch r.mode {
            case .zen, .attract, .lesson: return nil
            case .feed, .daily: return WaveFactory.phase(forWave: r.waves) >= p && r.waves > 0 ? 1 : 0
            }
        case .catchSpeciesAt, .catchAt, .catchBeforeSting, .mixedBite, .feastAt, .cleanUntil, .finish:
            return nil
        }
    }

    /// Banks a run: each active goal's progress is updated from the tracker; met goals are completed and replaced in
    /// their slots (a draw for `rank`); growth is reward(rank:) per goal, plus tripleBonus(rank:) when all
    /// Tuning.goalsActive were completed at once. A tracker for another book's goals only banks the goals they share.
    static func complete(_ state: GoalBookState, tracker: GoalTracker, rank: Int) -> GoalBookUpdate {
        var s: GoalBookState = normalized(state, rank: rank)
        var doneSlots: [Int] = []
        var done: [GoalSpec] = []
        var k: Int = 0
        while k < s.active.count {
            if let d = def(s.active[k].id) {
                let tracked: Bool = tracker.goals.contains { (x: GoalSpec) -> Bool in x.id == d.id }
                let p: Int = tracked ? max(tracker.progress(d), s.active[k].progress) : s.active[k].progress
                if p >= d.target {
                    doneSlots.append(k)
                    done.append(d)
                } else {
                    s.active[k].progress = p
                }
            }
            k += 1
        }
        for d in done {
            if !s.everCompleted.contains(d.id) { s.everCompleted.append(d.id) }
            s.recent.append(d.id)
            s.completedCount += 1
        }
        if s.recent.count > Tuning.goalRecentMemory {
            s.recent.removeFirst(s.recent.count - Tuning.goalRecentMemory)
        }
        var added: [GoalSpec] = []
        var removed: [Int] = []
        for i in doneSlots {
            if let d = draw(&s, rank: rank) {
                s.active[i] = GoalBookSlot(id: d.id)
                added.append(d)
            } else {
                removed.append(i)
            }
        }
        for i in removed.reversed() { s.active.remove(at: i) }
        let each: Int = reward(rank: rank)
        let bonus: Int = done.count >= Tuning.goalsActive ? tripleBonus(rank: rank) : 0
        let growth: Int = each * done.count + bonus
        s.growth += growth
        return GoalBookUpdate(state: s, completed: done, added: added, growth: growth, bonus: bonus)
    }

    /// The same from a run's whole event list.
    static func complete(_ state: GoalBookState, mode: RunMode, events: [TrapEvent], rank: Int) -> GoalBookUpdate {
        var t: GoalTracker = tracker(normalized(state, rank: rank), mode: mode)
        t.ingest(events)
        return complete(state, tracker: t, rank: rank)
    }

    // MARK: The draw

    private static func isModeGoal(_ d: GoalSpec) -> Bool {
        return d.scope == .daily || d.scope == .zen
    }

    /// The next goal for `rank`, given the active ones. In order:
    /// 1. a variety's goal whose band is open and that was never completed, if no variety goal is active;
    /// 2. otherwise a seeded pick among the eligible goals that are not active, not recent, not of an active goal's
    ///    family, and not a second Daily-or-Zen goal; each rule is relaxed in turn if nothing is left.
    /// Every draw advances `state.draws`.
    private static func draw(_ state: inout GoalBookState, rank: Int) -> GoalSpec? {
        let r: Int = clampRank(rank)
        let activeIDs: Set<String> = Set(state.active.map { (s: GoalBookSlot) -> String in s.id })
        let activeDefs: [GoalSpec] = activeGoals(state)
        let everDone: Set<String> = Set(state.everCompleted)
        let recent: Set<String> = Set(state.recent)
        let n: UInt64 = UInt64(truncatingIfNeeded: state.draws)
        state.draws += 1
        let open: [GoalSpec] = pool.filter { (d: GoalSpec) -> Bool in
            !activeIDs.contains(d.id) && !(d.unlocks != nil && everDone.contains(d.id))
        }
        let inBand: [GoalSpec] = open.filter { (d: GoalSpec) -> Bool in d.ranks.contains(r) }
        let varietyActive: Bool = activeDefs.contains { (d: GoalSpec) -> Bool in d.unlocks != nil }
        if !varietyActive {
            if let v = inBand.first(where: { (d: GoalSpec) -> Bool in d.unlocks != nil }) { return v }
        }
        let plain: [GoalSpec] = inBand.filter { (d: GoalSpec) -> Bool in d.unlocks == nil }
        let families: Set<String> = Set(activeDefs.map { (d: GoalSpec) -> String in d.kind.family })
        let modeActive: Bool = activeDefs.contains { (d: GoalSpec) -> Bool in isModeGoal(d) }
        let fresh: [GoalSpec] = plain.filter { (d: GoalSpec) -> Bool in !recent.contains(d.id) }
        let varied: [GoalSpec] = fresh.filter { (d: GoalSpec) -> Bool in !families.contains(d.kind.family) }
        let best: [GoalSpec] = varied.filter { (d: GoalSpec) -> Bool in !(modeActive && isModeGoal(d)) }
        let anyRank: [GoalSpec] = open.filter { (d: GoalSpec) -> Bool in d.unlocks == nil }
        let tiers: [[GoalSpec]] = [best, varied, fresh, plain, anyRank]
        var rng = SeededRandom(seed: state.seed ^ (n &* 0x9E37_79B9_7F4A_7C15) ^ 0x474F_414C)
        for t in tiers where !t.isEmpty {
            return t[rng.int(0...(t.count - 1))]
        }
        return nil
    }

    // MARK: Text

    /// 2000 → "2,000" (no locale: titles are stable).
    static func grouped(_ value: Int) -> String {
        let negative: Bool = value < 0
        var x: Int = negative ? -value : value
        var parts: [String] = []
        repeat {
            let chunk: Int = x % 1000
            x /= 1000
            var text: String = String(chunk)
            if x > 0 {
                while text.count < 3 { text = "0" + text }
            }
            parts.append(text)
        } while x > 0
        return (negative ? "-" : "") + parts.reversed().joined(separator: ",")
    }
}
