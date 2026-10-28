import Foundation

// MARK: - Plant rank (GAME-DESIGN §7): 12 ranks by lifetime bugs caught

enum PlantRanks {

    /// Lifetime bugs needed for each rank. A casual run catches about 60–80 bugs, so the first ranks come every run
    /// or two and Bog Monarch (5,000) takes a few weeks of play (docs/appstore/achievements.md).
    static let thresholds: [Int] = [0, 30, 90, 200, 400, 700, 1_100, 1_600, 2_300, 3_100, 4_000, 5_000]

    static let titles: [String] = ["Sprout", "Seedling", "Nibbler", "Snapper", "Fly Catcher", "Gnat Gobbler",
                                   "Midrib Muncher", "Bog Gourmand", "Marsh Jaws", "Swamp Glutton",
                                   "Carnivore Royal", "Bog Monarch"]

    static let count: Int = 12

    /// 0…11.
    static func rank(forLifetimeBugs bugs: Int) -> Int {
        var r: Int = 0
        var i: Int = 0
        while i < count {
            if bugs >= thresholds[i] { r = i }
            i += 1
        }
        return r
    }

    /// R6 (founder call): the lifetime-bug growth a run adds to the rank: every bug in Feed and the Daily, the Zen
    /// Bog's bugs × Tuning.zenRankShare rounded down (per run), nothing for attract and the lesson. (Goal growth,
    /// GoalBookUpdate.growth, is added on top by the App.)
    static func growth(from run: RunResult) -> Int {
        let bugs: Int = max(run.bugsCaught, 0)
        switch run.mode {
        // R8: a level's bugs count in full, as in Feed.
        case .feed, .daily, .level: return bugs
        case .zen: return Int((Double(bugs) * Tuning.zenRankShare + 1e-9).rounded(.down))
        case .attract, .lesson: return 0
        }
    }

    /// "Sprout" … "Bog Monarch" (clamped).
    static func title(_ rank: Int) -> String {
        return titles[min(max(rank, 0), count - 1)]
    }

    /// Lifetime bugs needed for `rank` (clamped).
    static func threshold(_ rank: Int) -> Int {
        return thresholds[min(max(rank, 0), count - 1)]
    }
}

// MARK: - Achievements (docs/appstore/achievements.md, exactly). Ids are Game Center ids: "snap.ach.<key>"

struct AchievementDef: Hashable {
    let id: String
    let title: String
    let detail: String
}

enum Achievements {

    private static func def(_ key: String, _ title: String, _ detail: String) -> AchievementDef {
        return AchievementDef(id: "snap.ach." + key, title: title, detail: detail)
    }

    static let feast = def("feast", "First Feast", "Catch 3 bugs or more in one bite.")
    static let bite5 = def("bite5", "Mouthful", "Catch 5 bugs or more in one bite.")
    static let chain4 = def("chain4", "Four Times Hungry", "Score a bite at x4: seven bites of 2+ bugs, without an empty snap or biting a bee.")
    static let scarab = def("scarab", "Pure Gold", "Catch a Golden Scarab.")
    static let dragonfly = def("dragonfly", "Here Be Dragonflies", "Catch a dragonfly.")
    static let spare50 = def("spare50", "Bee Kind", "Spare 50 bees, bumblebees or wasps.")
    static let bugbook = def("bugbook", "Every Bug in the Book", "Fill all 16 pages of the Bug Book.")
    static let monarch = def("monarch", "Bog Monarch", "Reach the top plant rank: Bog Monarch.")
    static let night = def("night", "Midnight Snack", "Keep your trap going until night falls.")
    static let daily = def("daily", "Daily Diner", "Finish a scored Daily Bog.")
    static let score10k = def("score10k", "Well Fed", "Score 10,000 in one run.")
    static let nobees = def("nobees", "Bee-Free Diet", "Catch 30 bugs in one run without biting a bee or wasp.")

    /// Exactly 12, in the store kit's order.
    static let all: [AchievementDef] = [feast, bite5, chain4, scarab, dragonfly, spare50, bugbook, monarch, night,
                                        daily, score10k, nobees]

    /// The chain length whose last bite is the first scored at ×4 (×1, ×1.5, … : the 7th clean bite in a row). The
    /// "Four Times Hungry" achievement stays at ×4 now that the cap is ×5 (R3).
    static var chainForX4: Int {
        return TrapRules.chainSteps(toReach: 4) + 1
    }

    /// R3: the chain length whose last bite is the first scored at the cap (×5: the 9th clean bite in a row).
    static var chainForMaxMultiplier: Int {
        return TrapRules.chainSteps(toReach: Tuning.chainMaxMultiplier) + 1
    }

    /// R6: what a Zen Bog run can never earn: the feats that only mean something when snaps run out, hunger bites
    /// and stingers cost (a long chain, lasting to night, a 10,000 score, 30 bugs without a bee). Zen still earns the
    /// catching feats (Feast, Mouthful, the scarab, the dragonfly) and the lifetime ones (bees spared, the Bug Book,
    /// Bog Monarch), from whatever lifetime totals the App passes.
    static let zenSkips: Set<String> = [chain4.id, night.id, score10k.id, nobees.id]

    /// Newly earned after `run`, given lifetime totals that already include the run and what's already earned.
    /// Attract and lesson runs earn nothing. R6: a Zen run earns nothing in `zenSkips` (and never "Daily Diner").
    static func earned(after run: RunResult, lifetimeBugs: Int, lifetimeSpared: Int, speciesFound: Int,
                       alreadyEarned: Set<String>) -> [AchievementDef] {
        var scoredDaily: Bool = false
        var zen: Bool = false
        switch run.mode {
        case .attract, .lesson: return []
        case .feed: break
        case .daily(day: _, scored: let scored): scoredDaily = scored
        // R8: a level is short and scripted, so it earns what a Zen run earns (never the run-length feats).
        case .zen, .level: zen = true
        }
        var out: [AchievementDef] = []
        func check(_ a: AchievementDef, _ met: Bool) {
            if zen && zenSkips.contains(a.id) { return }
            if met && !alreadyEarned.contains(a.id) { out.append(a) }
        }
        check(feast, run.feasts >= 1)
        check(bite5, run.biggestBite >= 5)
        check(chain4, run.longestChain >= chainForX4)
        check(scarab, (run.caughtBySpecies[BugSpecies.goldenScarab.rawValue] ?? 0) >= 1)
        check(dragonfly, (run.caughtBySpecies[BugSpecies.dragonfly.rawValue] ?? 0) >= 1)
        check(spare50, lifetimeSpared >= 50)
        check(bugbook, speciesFound >= BugSpecies.allCases.count)
        check(monarch, PlantRanks.rank(forLifetimeBugs: lifetimeBugs) == PlantRanks.count - 1)
        check(night, run.waves >= Tuning.nightWave)
        check(daily, scoredDaily)
        check(score10k, run.score >= Tuning.wellFedScore)
        check(nobees, run.bugsCaught >= 30 && run.stings == 0)
        return out
    }
}
