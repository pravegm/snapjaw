import Combine
import Foundation

// MARK: - Stored data (pure value types; tested in SnapTests/AppTests.swift)

/// One day of the Daily Bog: the scored try (one a day) and the best practice score.
struct DailyRecord: Codable, Equatable {
    /// Protein on the day's scored try.
    var score: Int
    /// False when the scored try was left before the trap got tired (the score so far was filed).
    var finished: Bool
    /// The best practice score that day (never on a leaderboard).
    var practiceBest: Int

    init(score: Int = 0, finished: Bool = false, practiceBest: Int = 0) {
        self.score = score
        self.finished = finished
        self.practiceBest = practiceBest
    }

    private enum CodingKeys: String, CodingKey { case score, finished, practiceBest }

    /// Tolerant: a field added later never drops the Daily history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = max((try? c.decodeIfPresent(Int.self, forKey: .score)) ?? 0, 0)
        finished = (try? c.decodeIfPresent(Bool.self, forKey: .finished)) ?? true
        practiceBest = max((try? c.decodeIfPresent(Int.self, forKey: .practiceBest)) ?? 0, 0)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(score, forKey: .score)
        try c.encode(finished, forKey: .finished)
        try c.encode(practiceBest, forKey: .practiceBest)
    }
}

/// What recording a finished run changed, for the Results screen.
struct RecordOutcome: Equatable {
    var isNewBest = false
    /// The best for this mode before the run (0 = none).
    var previousBest = 0
    /// The best for this mode after the run.
    var best = 0
    var rankBefore = 0
    var rankAfter = 0
    var lifetimeBefore = 0
    var lifetimeAfter = 0
    /// Bug Book pages filled by this run (first catch, or first spare for bees and wasps), in Bug Book order.
    var newSpecies: [BugSpecies] = []
    /// Achievements earned by this run.
    var newAchievements: [AchievementDef] = []
    /// Daily: this run was the day's one scored try.
    var dailyCounted = false
    /// Daily practice (not scored).
    var practice = false
    /// Nothing was recorded (attract, lesson).
    var ignored = false
    /// The player's very first recorded run (Results celebrates it: REVIEW-1 #23).
    var firstRun = false
    /// R6: the run was a Zen Bog (no best, no leaderboard; the Bug Book and goals still count).
    var zen = false
    /// R8: the run was a level (its stars are kept apart, no best).
    var level = false
    /// R6 goals: the three goals the run was played with, as they stood at its end (ticked or not), in slot order.
    var goalLines: [GoalLine] = []
    /// R6 goals: the ids completed by this run, and the growth they gave (bugs-equivalent, on the rank bar).
    var goalsDone: [String] = []
    var goalGrowth = 0
    /// R6 goals: all three goals done in one run (the bonus is in `goalGrowth`).
    var goalBonus = false
    /// R6 goals: the goals drawn to replace the done ones.
    var newGoals: [String] = []
    /// R6 Garden: varieties this run unlocked (by rank or goals), in Garden order.
    var newVarieties: [TrapVariety] = []
    /// R6 Daily: the streak after this run (scored Dailies only; 0 otherwise).
    var streak = 0

    /// "New best!" only when an earlier best was beaten (never on the very first score).
    var showsNewBest: Bool { isNewBest && previousBest > 0 }
    /// The very first score of this mode.
    var isFirstScore: Bool { isNewBest && previousBest == 0 && best > 0 }
    var rankedUp: Bool { rankAfter > rankBefore }
}

/// Everything the game remembers. JSON under `ProgressStore.key`, versioned, decoded tolerantly.
struct ProgressData: Codable, Equatable {
    /// v1 (R1). v2 (R6): Core's goal book, the rank's own bug count (Zen counts a quarter), the Garden, the Daily
    /// streak, the chain tip. v0 = a save without a version (never shipped; the migration rule is still tested).
    /// v3 (R8): the levels' stars.
    static let currentVersion = 3

    var version = ProgressData.currentVersion
    /// Best protein in a Feed run.
    var bestFeed = 0
    /// Best scored Daily Bog ever.
    var bestDaily = 0
    var lifetimeScore = 0
    var lifetimeBugs = 0
    var lifetimeSpared = 0
    var runs = 0
    /// R4 (QA-2 #11): Feed runs only (the first Feed run gets Sprout run 1 even after a Daily). A save from before R4
    /// has none on record and takes `runs` (every run counted as Feed: an older player never gets the perks again).
    var feedRuns = 0
    var snaps = 0
    var feasts = 0
    var stings = 0
    var bestBitePoints = 0
    var biggestBite = 0
    var longestChain = 0
    /// Fastest hinge snap ever (s; 0 = none).
    var fastestSnap = 0.0
    /// The Bug Book: `BugSpecies.rawValue` → bugs caught / protected bugs spared, kept for ever.
    var caught: [String: Int] = [:]
    var spared: [String: Int] = [:]
    /// The order species were found in (the Bug Book's "new" badge).
    var foundOrder: [String] = []
    /// Achievement ids earned (`AchievementDef.id`).
    var achievements: Set<String> = []
    /// Daily Bog days (`DailySeed.dayNumber`) → that day's record.
    var daily: [Int: DailyRecord] = [:]
    /// Days whose scored try has STARTED (left early or not): any later try that day is practice.
    var dailyAttempted: Set<Int> = []
    /// The latest day a Daily was played: a clock set back never gives another scored try.
    var lastDailyDay = Int.min
    /// The First Bite lesson was finished or skipped.
    var lessonDone = false
    /// A live run's result so far, saved when the app goes to the background (a kill there never loses its bugs).
    var pendingRun: RunResult?
    /// R6: that run's goal report so far (its goals were toasted, so a kill never loses them).
    var pendingGoals: GoalReport?

    // MARK: R6

    /// Core's goal book (`GoalBookState`: the three active goals, their banked progress, every goal ever done and
    /// the growth they gave). Nil until the first run that counts: Home shows `ProgressRules.goalBook(_:)` meanwhile.
    var goalBook: GoalBookState?
    /// The bugs the plant rank grows from (`PlantRanks.growth(from:)`: Feed and the Daily in full, the Zen Bog a
    /// quarter). A v1 save takes `lifetimeBugs`.
    var rankBugs = 0
    /// The Garden: the chosen trap variety (`TrapVariety.rawValue`).
    var variety = TrapVariety.classic.rawValue
    /// Varieties the player has seen in the Garden (the others wear a "New" tag).
    var varietiesSeen: Set<String> = [TrapVariety.classic.rawValue]
    /// The longest Daily streak ever (days in a row with the scored try played).
    var bestStreak = 0
    /// The one-time chain explainer has shown (#14).
    var chainTipSeen = false

    // MARK: R8

    /// The levels: level id (1…30) → the best stars ever (1…3; a level never passed has no entry).
    var levelStars: [Int: Int] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, bestFeed, bestDaily, lifetimeScore, lifetimeBugs, lifetimeSpared, runs, snaps, feasts, stings
        case feedRuns
        case bestBitePoints, biggestBite, longestChain, fastestSnap, caught, spared, foundOrder, achievements, daily
        case dailyAttempted, lastDailyDay, lessonDone, pendingRun
        case pendingGoals, goalBook, rankBugs, variety, varietiesSeen, bestStreak, chainTipSeen
        case levelStars
    }

    /// Tolerant: unknown or missing fields fall back to their defaults, never wiping the rest.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 0
        version = ProgressData.currentVersion
        bestFeed = max((try? c.decodeIfPresent(Int.self, forKey: .bestFeed)) ?? 0, 0)
        bestDaily = max((try? c.decodeIfPresent(Int.self, forKey: .bestDaily)) ?? 0, 0)
        lifetimeScore = max((try? c.decodeIfPresent(Int.self, forKey: .lifetimeScore)) ?? 0, 0)
        lifetimeBugs = max((try? c.decodeIfPresent(Int.self, forKey: .lifetimeBugs)) ?? 0, 0)
        lifetimeSpared = max((try? c.decodeIfPresent(Int.self, forKey: .lifetimeSpared)) ?? 0, 0)
        runs = max((try? c.decodeIfPresent(Int.self, forKey: .runs)) ?? 0, 0)
        feedRuns = max((try? c.decodeIfPresent(Int.self, forKey: .feedRuns)) ?? runs, 0)
        snaps = max((try? c.decodeIfPresent(Int.self, forKey: .snaps)) ?? 0, 0)
        feasts = max((try? c.decodeIfPresent(Int.self, forKey: .feasts)) ?? 0, 0)
        stings = max((try? c.decodeIfPresent(Int.self, forKey: .stings)) ?? 0, 0)
        bestBitePoints = max((try? c.decodeIfPresent(Int.self, forKey: .bestBitePoints)) ?? 0, 0)
        biggestBite = max((try? c.decodeIfPresent(Int.self, forKey: .biggestBite)) ?? 0, 0)
        longestChain = max((try? c.decodeIfPresent(Int.self, forKey: .longestChain)) ?? 0, 0)
        let fastest = (try? c.decodeIfPresent(Double.self, forKey: .fastestSnap)) ?? 0
        fastestSnap = fastest.isFinite ? max(fastest, 0) : 0
        caught = (try? c.decodeIfPresent([String: Int].self, forKey: .caught)) ?? [:]
        spared = (try? c.decodeIfPresent([String: Int].self, forKey: .spared)) ?? [:]
        foundOrder = (try? c.decodeIfPresent([String].self, forKey: .foundOrder)) ?? []
        achievements = (try? c.decodeIfPresent(Set<String>.self, forKey: .achievements)) ?? []
        daily = (try? c.decodeIfPresent([Int: DailyRecord].self, forKey: .daily)) ?? [:]
        dailyAttempted = (try? c.decodeIfPresent(Set<Int>.self, forKey: .dailyAttempted)) ?? []
        lastDailyDay = (try? c.decodeIfPresent(Int.self, forKey: .lastDailyDay)) ?? Int.min
        lessonDone = (try? c.decodeIfPresent(Bool.self, forKey: .lessonDone)) ?? false
        pendingRun = (try? c.decodeIfPresent(RunResult.self, forKey: .pendingRun)) ?? nil
        pendingGoals = (try? c.decodeIfPresent(GoalReport.self, forKey: .pendingGoals)) ?? nil
        goalBook = (try? c.decodeIfPresent(GoalBookState.self, forKey: .goalBook)) ?? nil
        rankBugs = max((try? c.decodeIfPresent(Int.self, forKey: .rankBugs)) ?? lifetimeBugs, 0)
        variety = (try? c.decodeIfPresent(String.self, forKey: .variety)) ?? TrapVariety.classic.rawValue
        varietiesSeen = (try? c.decodeIfPresent(Set<String>.self, forKey: .varietiesSeen)) ?? []
        bestStreak = max((try? c.decodeIfPresent(Int.self, forKey: .bestStreak)) ?? 0, 0)
        chainTipSeen = (try? c.decodeIfPresent(Bool.self, forKey: .chainTipSeen)) ?? false
        levelStars = (try? c.decodeIfPresent([Int: Int].self, forKey: .levelStars)) ?? [:]
        ProgressRules.migrate(&self, fromVersion: storedVersion)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(bestFeed, forKey: .bestFeed)
        try c.encode(bestDaily, forKey: .bestDaily)
        try c.encode(lifetimeScore, forKey: .lifetimeScore)
        try c.encode(lifetimeBugs, forKey: .lifetimeBugs)
        try c.encode(lifetimeSpared, forKey: .lifetimeSpared)
        try c.encode(runs, forKey: .runs)
        try c.encode(feedRuns, forKey: .feedRuns)
        try c.encode(snaps, forKey: .snaps)
        try c.encode(feasts, forKey: .feasts)
        try c.encode(stings, forKey: .stings)
        try c.encode(bestBitePoints, forKey: .bestBitePoints)
        try c.encode(biggestBite, forKey: .biggestBite)
        try c.encode(longestChain, forKey: .longestChain)
        try c.encode(fastestSnap, forKey: .fastestSnap)
        try c.encode(caught, forKey: .caught)
        try c.encode(spared, forKey: .spared)
        try c.encode(foundOrder, forKey: .foundOrder)
        try c.encode(achievements, forKey: .achievements)
        try c.encode(daily, forKey: .daily)
        try c.encode(dailyAttempted, forKey: .dailyAttempted)
        try c.encode(lastDailyDay, forKey: .lastDailyDay)
        try c.encode(lessonDone, forKey: .lessonDone)
        try c.encodeIfPresent(pendingRun, forKey: .pendingRun)
        try c.encodeIfPresent(pendingGoals, forKey: .pendingGoals)
        try c.encodeIfPresent(goalBook, forKey: .goalBook)
        try c.encode(rankBugs, forKey: .rankBugs)
        try c.encode(variety, forKey: .variety)
        try c.encode(varietiesSeen, forKey: .varietiesSeen)
        try c.encode(bestStreak, forKey: .bestStreak)
        try c.encode(chainTipSeen, forKey: .chainTipSeen)
        try c.encode(levelStars, forKey: .levelStars)
    }

    // MARK: Derived

    /// R6: what the plant's rank grows from: the rank's bugs (a Zen Bog's at a quarter) plus the goals' growth.
    var growth: Int { max(rankBugs, 0) + max(goalBook?.growth ?? 0, 0) }
    /// R6: the plant rank (from `growth`).
    var rank: Int { PlantRanks.rank(forLifetimeBugs: growth) }
    /// R6: every goal id ever completed (the Garden's goal unlocks).
    var goalsEverDone: Set<String> { goalBook?.completedSet ?? [] }
    /// R6: goals completed in all.
    var goalsDone: Int { goalBook?.completedCount ?? 0 }

    /// R6 Garden: the varieties grown so far (Core's `Varieties`: rank and goals). Classic always.
    var unlockedVarieties: Set<TrapVariety> {
        Set(Varieties.unlocked(rank: rank, completedGoals: goalsEverDone))
    }

    /// R6 Garden: the variety drawn in play, on Home and on Results: the chosen one if it has grown, else Classic.
    var chosenVariety: TrapVariety {
        Varieties.effective(TrapVariety(rawValue: variety) ?? .classic, rank: rank, completedGoals: goalsEverDone)
    }

    func dailyRecord(day: Int) -> DailyRecord? { daily[day] }

    func caughtCount(_ s: BugSpecies) -> Int { max(caught[s.rawValue] ?? 0, 0) }
    func sparedCount(_ s: BugSpecies) -> Int { max(spared[s.rawValue] ?? 0, 0) }

    /// A Bug Book page is filled on the first catch (or the first spare, for bees and wasps).
    func isFound(_ s: BugSpecies) -> Bool {
        s.isProtected ? sparedCount(s) > 0 || caughtCount(s) > 0 : caughtCount(s) > 0
    }

    var speciesFound: Int { BugSpecies.allCases.filter { isFound($0) }.count }
}

// MARK: - Rules (pure; tested)

enum ProgressRules {
    /// Brings an older save up to `ProgressData.currentVersion`.
    /// - v0 → v1: a player with runs on record has met the trap, so the First Bite lesson isn't forced on them.
    /// - every version: the found order covers exactly the found species, once each.
    static func migrate(_ data: inout ProgressData, fromVersion version: Int) {
        if version < 1 {
            if data.runs > 0 { data.lessonDone = true }
        }
        if version < 2 {
            // R6: a player who has chained before has met the chain (R4's one-time tag told them).
            if data.longestChain > 0 { data.chainTipSeen = true }
        }
        // Every version (R6): the rank never counts more bugs than were caught; the variety is a real one; Classic is
        // always seen. (The goal book is repaired by Core's `GoalBook.normalized` where it is used.)
        data.rankBugs = min(max(data.rankBugs, 0), max(data.lifetimeBugs, 0))
        if TrapVariety(rawValue: data.variety) == nil { data.variety = TrapVariety.classic.rawValue }
        data.varietiesSeen = data.varietiesSeen.filter { TrapVariety(rawValue: $0) != nil }
        data.varietiesSeen.insert(TrapVariety.classic.rawValue)
        // R8: stars are 1…3 on a real level id.
        data.levelStars = data.levelStars.filter { $0.key >= 1 && $0.key <= 99 && $0.value >= 1 }
            .mapValues { min($0, 3) }
        let found = BugSpecies.allCases.filter { data.isFound($0) }.map(\.rawValue)
        let foundSet = Set(found)
        var seen = Set<String>()
        var order = data.foundOrder.filter { foundSet.contains($0) && seen.insert($0).inserted }
        for raw in found where !seen.contains(raw) {
            order.append(raw)
            seen.insert(raw)
        }
        data.foundOrder = order
    }

    /// One scored Daily try a day: not if that day's try has started, nor on a day before the last one played.
    static func canPlayScoredDaily(_ data: ProgressData, today: Int) -> Bool {
        if data.dailyAttempted.contains(today) { return false }
        if data.lastDailyDay != Int.min && today < data.lastDailyDay { return false }
        return true
    }

    /// The scored try starts: the day is used up from now on (a quit or a crash never gives a second one).
    static func noteDailyStart(_ data: inout ProgressData, day: Int) {
        data.dailyAttempted.insert(day)
        data.lastDailyDay = max(data.lastDailyDay, day)
        if data.daily[day] == nil { data.daily[day] = DailyRecord(score: 0, finished: false, practiceBest: 0) }
        data.bestStreak = max(data.bestStreak, dailyStreak(data, today: day))
    }

    // MARK: R6: the Daily streak

    /// The days in a row the scored Daily was played, up to today. A streak still counts on a day whose try hasn't
    /// been played yet (it runs to yesterday); a missed day ends it. Pure; tested.
    static func dailyStreak(_ data: ProgressData, today: Int) -> Int {
        var day = data.dailyAttempted.contains(today) ? today : today - 1
        var n = 0
        while data.dailyAttempted.contains(day) && n <= data.dailyAttempted.count {
            n += 1
            day -= 1
        }
        return n
    }

    /// "🔥 4 days" ("🔥 1 day"); nil for no streak. Pure; tested.
    static func streakText(_ n: Int) -> String? {
        guard n > 0 else { return nil }
        return "🔥 \(n) \(n == 1 ? "day" : "days")"
    }

    // MARK: R6: goals (Core's GoalBook; design/notes/core-R6.md)

    /// The seed of a player's first goal book: fixed by the save, so Home and the first run show the same goals before
    /// the book is written. Pure; tested.
    static func bookSeed(_ data: ProgressData) -> UInt64 {
        0x534E_4150_4A41_5721 ^ UInt64(truncatingIfNeeded: data.runs &* 7_919 &+ data.lifetimeScore)
    }

    /// The goal book as it stands: the saved one repaired for the rank (Core's `normalized`), or a fresh one.
    /// Pure; tested.
    static func goalBook(_ data: ProgressData) -> GoalBookState {
        if let b = data.goalBook { return GoalBook.normalized(b, rank: data.rank) }
        return GoalBook.start(seed: bookSeed(data), rank: data.rank)
    }

    /// Writes the book into the save (a run is about to be played with its goals). Returns it.
    @discardableResult
    static func prepareGoals(_ data: inout ProgressData) -> GoalBookState {
        let b = goalBook(data)
        data.goalBook = b
        return b
    }

    /// Home's lines: each active goal with its banked progress (the best run so far, or the sum so far).
    /// Pure; tested.
    static func goalLines(_ book: GoalBookState) -> [GoalLine] {
        book.active.compactMap { slot -> GoalLine? in
            guard let g = GoalBook.def(slot.id) else { return nil }
            return GoalLine.make(g, progress: slot.progress, done: false)
        }
    }

    /// A tracker that stands for a run from its report (a finished run, one left early and one killed in the
    /// background are all filed this way): the report's progress carried in. Pure; tested.
    static func tracker(_ book: GoalBookState, report: GoalReport, mode: RunMode) -> GoalTracker {
        var carried: [String: Int] = [:]
        for slot in book.active { carried[slot.id] = max(slot.progress, report.progress[slot.id] ?? 0) }
        return GoalTracker(goals: GoalBook.activeGoals(book), carried: carried, mode: mode)
    }

    /// Files a run's goals with Core (`GoalBook.complete` at the rank the run reached): the bank, the done goals and
    /// their growth (the three-at-once bonus included), fresh goals in their slots. Fills `outcome`'s goal fields.
    /// Pure; tested.
    static func applyGoals(_ report: GoalReport, mode: RunMode, into data: inout ProgressData,
                           outcome: inout RecordOutcome) {
        let book = goalBook(data)
        let t = tracker(book, report: report, mode: mode)
        outcome.goalLines = t.goals.map { g in
            GoalLine.make(g, progress: t.progress(g), done: t.isMet(g), inPlay: t.counts(g))
        }
        let up = GoalBook.complete(book, tracker: t, rank: data.rank)
        data.goalBook = up.state
        outcome.goalsDone = up.completed.map(\.id)
        outcome.goalGrowth = max(up.growth, 0)
        outcome.goalBonus = up.bonus > 0
        outcome.newGoals = up.added.map(\.id)
    }

    /// The personal best a session shows for `mode` (Feed: the best Feed; Daily: that day's best).
    static func best(for mode: RunMode, in data: ProgressData) -> Int {
        switch mode {
        case .feed: return data.bestFeed
        case let .daily(day, _):
            guard let r = data.daily[day] else { return 0 }
            return max(r.score, r.practiceBest)
        case .attract, .lesson, .zen, .level: return 0
        }
    }

    /// The rank bar: the fraction of the way from `rank`'s threshold to the next (1 at the top rank).
    static func rankProgress(lifetime: Int, rank: Int, threshold: (Int) -> Int = { PlantRanks.threshold($0) },
                             count: Int = PlantRanks.count) -> Double {
        guard rank + 1 < count else { return 1 }
        let lo = threshold(rank)
        let hi = threshold(rank + 1)
        guard hi > lo else { return 1 }
        return min(max(Double(lifetime - lo) / Double(hi - lo), 0), 1)
    }

    /// Default rank rule (Core's PlantRanks).
    static func defaultRank(_ lifetimeBugs: Int) -> Int { PlantRanks.rank(forLifetimeBugs: lifetimeBugs) }

    /// Default achievement rule (Core's Achievements): (run, lifetime bugs, lifetime spared, species found, earned).
    static func defaultEarn(_ run: RunResult, _ bugs: Int, _ spared: Int, _ species: Int,
                            _ earned: Set<String>) -> [AchievementDef] {
        Achievements.earned(after: run, lifetimeBugs: bugs, lifetimeSpared: spared, speciesFound: species,
                            alreadyEarned: earned)
    }

    /// Files a finished run. `rankFor` and `earn` are injectable so the tests don't lean on Core's catalogues.
    /// R6: `goals` is the run's goal report (the App's live tracking), filed with Core's `GoalBook.complete`. The rank
    /// grows from `ProgressData.growth` (`PlantRanks.growth(from:)`'s bugs, a Zen Bog's at a quarter, plus the goals'
    /// growth), so `lifetimeBefore`/`lifetimeAfter` are growth.
    static func record(_ result: RunResult, into data: inout ProgressData, today: Int, goals: GoalReport = GoalReport(),
                       rankFor: (Int) -> Int = ProgressRules.defaultRank,
                       earn: (RunResult, Int, Int, Int, Set<String>) -> [AchievementDef] = ProgressRules.defaultEarn)
        -> RecordOutcome {
        var outcome = RecordOutcome()
        let score = max(result.score, 0)
        let goalsBefore = data.goalsEverDone
        switch result.mode {
        case .attract, .lesson:
            outcome.ignored = true
            outcome.rankBefore = rankFor(data.growth)
            outcome.rankAfter = outcome.rankBefore
            outcome.lifetimeBefore = data.growth
            outcome.lifetimeAfter = data.growth
            return outcome
        case .zen:
            // R6: no best and no leaderboard; the bugs, the Bug Book, the rank and the goals still count.
            outcome.zen = true
        case .level:
            // R8: a level keeps its stars (`LevelRules.record`), not a best; its bugs fill the Bug Book and the rank.
            outcome.level = true
        case .feed:
            outcome.previousBest = data.bestFeed
            if score > data.bestFeed {
                outcome.isNewBest = true
                data.bestFeed = score
            }
            outcome.best = data.bestFeed
        case let .daily(day, scored):
            var record = data.daily[day] ?? DailyRecord()
            if scored {
                outcome.dailyCounted = true
                outcome.previousBest = data.bestDaily
                record.score = max(record.score, score)
                record.finished = true
                if score > data.bestDaily {
                    outcome.isNewBest = true
                    data.bestDaily = score
                }
                outcome.best = data.bestDaily
                data.dailyAttempted.insert(day)
                data.lastDailyDay = max(data.lastDailyDay, day)
            } else {
                outcome.practice = true
                outcome.previousBest = record.practiceBest
                if score > record.practiceBest {
                    outcome.isNewBest = true
                    record.practiceBest = score
                }
                outcome.best = record.practiceBest
            }
            data.daily[day] = record
            if scored {
                outcome.streak = dailyStreak(data, today: day)
                data.bestStreak = max(data.bestStreak, outcome.streak)
            }
        }
        let bugs = max(result.bugsCaught, 0)
        let spared = max(result.beesSpared, 0)
        outcome.lifetimeBefore = data.growth
        outcome.rankBefore = rankFor(data.growth)
        let plantRankBefore = data.rank
        data.lifetimeBugs += bugs
        data.lifetimeSpared += spared
        // R6 (founder rule): the rank grows by Core's share of the run's bugs (a Zen Bog's count a quarter); the Bug
        // Book and the lifetime tally count every bug.
        data.rankBugs += max(PlantRanks.growth(from: result), 0)
        if !outcome.zen { data.lifetimeScore += score }
        // R6: the goals (their growth lands on the rank bar with the bugs).
        applyGoals(goals, mode: result.mode, into: &data, outcome: &outcome)
        outcome.lifetimeAfter = data.growth
        outcome.rankAfter = rankFor(data.growth)
        outcome.newVarieties = Varieties.newlyUnlocked(rankBefore: plantRankBefore, goalsBefore: goalsBefore,
                                                       rankAfter: data.rank, goalsAfter: data.goalsEverDone)
        outcome.firstRun = data.runs == 0
        data.runs += 1
        if case .feed = result.mode { data.feedRuns += 1 }
        data.snaps += max(result.snaps, 0)
        data.feasts += max(result.feasts, 0)
        data.stings += max(result.stings, 0)
        data.bestBitePoints = max(data.bestBitePoints, result.bestBitePoints)
        data.biggestBite = max(data.biggestBite, result.biggestBite)
        data.longestChain = max(data.longestChain, result.longestChain)
        if result.fastestSnap.isFinite && result.fastestSnap > 0 {
            data.fastestSnap = data.fastestSnap > 0 ? min(data.fastestSnap, result.fastestSnap) : result.fastestSnap
        }
        data.lessonDone = true
        // The Bug Book, in its own order.
        for species in BugSpecies.allCases {
            let wasFound = data.isFound(species)
            let c = max(result.caughtBySpecies[species.rawValue] ?? 0, 0)
            let s = max(result.sparedBySpecies[species.rawValue] ?? 0, 0)
            if c > 0 { data.caught[species.rawValue] = data.caughtCount(species) + c }
            if s > 0 { data.spared[species.rawValue] = data.sparedCount(species) + s }
            if !wasFound && data.isFound(species) {
                outcome.newSpecies.append(species)
                data.foundOrder.append(species.rawValue)
            }
        }
        // R6: the rank badge follows the rank the player sees (bugs plus the goals' growth).
        let earned = earn(result, data.growth, data.lifetimeSpared, data.speciesFound, data.achievements)
        for def in earned where !data.achievements.contains(def.id) {
            data.achievements.insert(def.id)
            outcome.newAchievements.append(def)
        }
        return outcome
    }

    /// A run left early (Home, Restart, a kill in the background) files its result so far like any other run (its
    /// bugs fill the Bug Book, its catches count for the rank), and a scored Daily left early keeps its score as the
    /// day's score, marked unfinished. A run with nothing in it doesn't count as a run.
    static func recordAbandoned(_ result: RunResult, into data: inout ProgressData, today: Int,
                                goals: GoalReport = GoalReport(),
                                rankFor: (Int) -> Int = ProgressRules.defaultRank,
                                earn: (RunResult, Int, Int, Int, Set<String>) -> [AchievementDef]
                                    = ProgressRules.defaultEarn) -> RecordOutcome {
        let outcome = record(result, into: &data, today: today, goals: goals, rankFor: rankFor, earn: earn)
        if case let .daily(day, scored) = result.mode, scored, var r = data.daily[day] {
            r.finished = false
            data.daily[day] = r
        }
        if max(result.score, 0) == 0 && result.bugsCaught <= 0, !outcome.ignored {
            data.runs = max(data.runs - 1, 0)
            if case .feed = result.mode { data.feedRuns = max(data.feedRuns - 1, 0) }
        }
        return outcome
    }

    /// Worth filing when left early: something was caught, spared or scored (R6: or a goal was done).
    static func worthRecording(_ result: RunResult, goals: GoalReport = GoalReport()) -> Bool {
        switch result.mode {
        case .attract, .lesson: return false
        case .feed, .daily, .zen, .level:
            return result.score > 0 || result.bugsCaught > 0 || result.beesSpared > 0 || !goals.completed.isEmpty
        }
    }
}

// MARK: - The store

/// The player's progress for SwiftUI. `defaults` nil = in-memory (demo runs and tests): nothing is written.
@MainActor
final class ProgressStore: ObservableObject {
    static let key = "snap.progress"
    /// Where a save that can't be decoded is kept. Never overwritten: a second, different bad save goes to
    /// `snap.progress.bak.<unix time>`.
    static let backupKey = "snap.progress.bak"

    @Published private(set) var data: ProgressData
    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        if let raw = defaults?.data(forKey: Self.key) {
            if let decoded = Self.decode(raw) {
                data = decoded
            } else {
                // One bad write (or a future format) must never wipe progress for good: keep the raw bytes first.
                if let defaults { Self.backUp(raw, in: defaults) }
                data = ProgressData()
            }
        } else {
            data = ProgressData()
        }
    }

    init(inMemory data: ProgressData) {
        self.defaults = nil
        self.data = data
    }

    /// Copies an undecodable save aside without overwriting an earlier copy. Returns the key used.
    @discardableResult
    nonisolated static func backUp(_ raw: Data, in defaults: UserDefaults, now: Date = Date()) -> String {
        if let existing = defaults.data(forKey: backupKey) {
            if existing == raw { return backupKey }
            let key = "\(backupKey).\(Int(now.timeIntervalSince1970))"
            defaults.set(raw, forKey: key)
            return key
        }
        defaults.set(raw, forKey: backupKey)
        return backupKey
    }

    nonisolated static func encode(_ data: ProgressData) -> Data? { try? JSONEncoder().encode(data) }
    nonisolated static func decode(_ raw: Data) -> ProgressData? {
        try? JSONDecoder().decode(ProgressData.self, from: raw)
    }

    /// The plant rank (R6: from the bugs plus the goals' growth).
    var rank: Int { data.rank }

    func best(for mode: RunMode) -> Int { ProgressRules.best(for: mode, in: data) }
    func canPlayScoredDaily(today: Int) -> Bool { ProgressRules.canPlayScoredDaily(data, today: today) }

    /// R6: the Daily streak as of `today`.
    func streak(today: Int) -> Int { ProgressRules.dailyStreak(data, today: today) }

    /// R6: the goal book as Home shows it (Core's, repaired for the rank; written only when a run starts).
    var goalBook: GoalBookState { ProgressRules.goalBook(data) }

    /// R6: a run starts with the goals shown on Home: the book is written now, so the run and its Results agree.
    @discardableResult
    func prepareGoals() -> GoalBookState {
        var d = data
        let book = ProgressRules.prepareGoals(&d)
        commit(d)
        return book
    }

    /// R6 Garden: picks a grown variety (a locked one is ignored). Returns whether it changed.
    @discardableResult
    func chooseVariety(_ v: TrapVariety) -> Bool {
        guard data.unlockedVarieties.contains(v), data.variety != v.rawValue else { return false }
        var d = data
        d.variety = v.rawValue
        d.varietiesSeen.insert(v.rawValue)
        commit(d)
        return true
    }

    /// R6 Garden: the grown varieties have been seen (their "New" tags go).
    func markVarietiesSeen() {
        let all = Set(data.unlockedVarieties.map(\.rawValue))
        guard !all.isSubset(of: data.varietiesSeen) else { return }
        var d = data
        d.varietiesSeen.formUnion(all)
        commit(d)
    }

    /// R6 (#14): the one-time chain explainer has shown.
    func markChainTipSeen() {
        guard !data.chainTipSeen else { return }
        var d = data
        d.chainTipSeen = true
        commit(d)
    }

    func startDaily(day: Int) {
        var d = data
        ProgressRules.noteDailyStart(&d, day: day)
        commit(d)
    }

    func record(_ result: RunResult, today: Int, goals: GoalReport = GoalReport()) -> RecordOutcome {
        var d = data
        d.pendingRun = nil
        d.pendingGoals = nil
        let outcome = ProgressRules.record(result, into: &d, today: today, goals: goals)
        commit(d)
        return outcome
    }

    func recordAbandoned(_ result: RunResult, today: Int, goals: GoalReport = GoalReport()) -> RecordOutcome {
        var d = data
        d.pendingRun = nil
        d.pendingGoals = nil
        let outcome = ProgressRules.recordAbandoned(result, into: &d, today: today, goals: goals)
        commit(d)
        return outcome
    }

    func saveCheckpoint(_ result: RunResult, goals: GoalReport = GoalReport()) {
        var d = data
        d.pendingRun = result
        d.pendingGoals = goals.completed.isEmpty && goals.progress.isEmpty ? nil : goals
        commit(d)
    }

    func clearCheckpoint() {
        guard data.pendingRun != nil || data.pendingGoals != nil else { return }
        var d = data
        d.pendingRun = nil
        d.pendingGoals = nil
        commit(d)
    }

    /// At launch: a run killed in the background is filed as left early. Returns it (for Game Center) or nil.
    func recoverPendingRun(today: Int) -> (RunResult, RecordOutcome)? {
        guard let pending = data.pendingRun else { return nil }
        let outcome = recordAbandoned(pending, today: today, goals: data.pendingGoals ?? GoalReport())
        return (pending, outcome)
    }

    /// R8: keeps a level try's stars (the best ever). Returns the best before and after, and a world it opened.
    @discardableResult
    func recordLevel(_ id: Int, stars: Int) -> (before: Int, after: Int, opened: Int?) {
        var d = data
        let kept = LevelRules.record(&d, id: id, stars: stars)
        commit(d)
        return kept
    }

    func markLessonDone() {
        guard !data.lessonDone else { return }
        var d = data
        d.lessonDone = true
        commit(d)
    }

    /// Demo presets (in-memory stores write nothing anyway).
    func replace(_ newData: ProgressData) { commit(newData) }

    private func commit(_ newData: ProgressData) {
        if newData != data { data = newData }
        guard let defaults, let raw = Self.encode(newData) else { return }
        defaults.set(raw, forKey: Self.key)
    }
}
