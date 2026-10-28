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

    /// "New best!" only when an earlier best was beaten (never on the very first score).
    var showsNewBest: Bool { isNewBest && previousBest > 0 }
    /// The very first score of this mode.
    var isFirstScore: Bool { isNewBest && previousBest == 0 && best > 0 }
    var rankedUp: Bool { rankAfter > rankBefore }
}

/// Everything the game remembers. JSON under `ProgressStore.key`, versioned, decoded tolerantly.
struct ProgressData: Codable, Equatable {
    /// v1 (R1). v0 = a save without a version (never shipped; the migration rule is still tested).
    static let currentVersion = 1

    var version = ProgressData.currentVersion
    /// Best protein in a Feed run.
    var bestFeed = 0
    /// Best scored Daily Bog ever.
    var bestDaily = 0
    var lifetimeScore = 0
    var lifetimeBugs = 0
    var lifetimeSpared = 0
    var runs = 0
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

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, bestFeed, bestDaily, lifetimeScore, lifetimeBugs, lifetimeSpared, runs, snaps, feasts, stings
        case bestBitePoints, biggestBite, longestChain, fastestSnap, caught, spared, foundOrder, achievements, daily
        case dailyAttempted, lastDailyDay, lessonDone, pendingRun
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
    }

    // MARK: Derived

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
    }

    /// The personal best a session shows for `mode` (Feed: the best Feed; Daily: that day's best).
    static func best(for mode: RunMode, in data: ProgressData) -> Int {
        switch mode {
        case .feed: return data.bestFeed
        case let .daily(day, _):
            guard let r = data.daily[day] else { return 0 }
            return max(r.score, r.practiceBest)
        case .attract, .lesson: return 0
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
    static func record(_ result: RunResult, into data: inout ProgressData, today: Int,
                       rankFor: (Int) -> Int = ProgressRules.defaultRank,
                       earn: (RunResult, Int, Int, Int, Set<String>) -> [AchievementDef] = ProgressRules.defaultEarn)
        -> RecordOutcome {
        var outcome = RecordOutcome()
        let score = max(result.score, 0)
        switch result.mode {
        case .attract, .lesson:
            outcome.ignored = true
            outcome.rankBefore = rankFor(data.lifetimeBugs)
            outcome.rankAfter = outcome.rankBefore
            outcome.lifetimeBefore = data.lifetimeBugs
            outcome.lifetimeAfter = data.lifetimeBugs
            return outcome
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
        }
        let bugs = max(result.bugsCaught, 0)
        let spared = max(result.beesSpared, 0)
        outcome.lifetimeBefore = data.lifetimeBugs
        outcome.rankBefore = rankFor(data.lifetimeBugs)
        data.lifetimeBugs += bugs
        data.lifetimeSpared += spared
        data.lifetimeScore += score
        outcome.lifetimeAfter = data.lifetimeBugs
        outcome.rankAfter = rankFor(data.lifetimeBugs)
        outcome.firstRun = data.runs == 0
        data.runs += 1
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
        let earned = earn(result, data.lifetimeBugs, data.lifetimeSpared, data.speciesFound, data.achievements)
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
                                rankFor: (Int) -> Int = ProgressRules.defaultRank,
                                earn: (RunResult, Int, Int, Int, Set<String>) -> [AchievementDef]
                                    = ProgressRules.defaultEarn) -> RecordOutcome {
        let outcome = record(result, into: &data, today: today, rankFor: rankFor, earn: earn)
        if case let .daily(day, scored) = result.mode, scored, var r = data.daily[day] {
            r.finished = false
            data.daily[day] = r
        }
        if max(result.score, 0) == 0 && result.bugsCaught <= 0, !outcome.ignored { data.runs = max(data.runs - 1, 0) }
        return outcome
    }

    /// Worth filing when left early: something was caught, spared or scored.
    static func worthRecording(_ result: RunResult) -> Bool {
        switch result.mode {
        case .attract, .lesson: return false
        case .feed, .daily: return result.score > 0 || result.bugsCaught > 0 || result.beesSpared > 0
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

    var rank: Int { PlantRanks.rank(forLifetimeBugs: data.lifetimeBugs) }

    func best(for mode: RunMode) -> Int { ProgressRules.best(for: mode, in: data) }
    func canPlayScoredDaily(today: Int) -> Bool { ProgressRules.canPlayScoredDaily(data, today: today) }

    func startDaily(day: Int) {
        var d = data
        ProgressRules.noteDailyStart(&d, day: day)
        commit(d)
    }

    func record(_ result: RunResult, today: Int) -> RecordOutcome {
        var d = data
        d.pendingRun = nil
        let outcome = ProgressRules.record(result, into: &d, today: today)
        commit(d)
        return outcome
    }

    func recordAbandoned(_ result: RunResult, today: Int) -> RecordOutcome {
        var d = data
        d.pendingRun = nil
        let outcome = ProgressRules.recordAbandoned(result, into: &d, today: today)
        commit(d)
        return outcome
    }

    func saveCheckpoint(_ result: RunResult) {
        var d = data
        d.pendingRun = result
        commit(d)
    }

    func clearCheckpoint() {
        guard data.pendingRun != nil else { return }
        var d = data
        d.pendingRun = nil
        commit(d)
    }

    /// At launch: a run killed in the background is filed as left early. Returns it (for Game Center) or nil.
    func recoverPendingRun(today: Int) -> (RunResult, RecordOutcome)? {
        guard let pending = data.pendingRun else { return nil }
        let outcome = recordAbandoned(pending, today: today)
        return (pending, outcome)
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
