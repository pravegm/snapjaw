import Foundation

// MARK: - The Garden: trap varieties (R6, ROUND-6 founder decision 2; design/notes/core-R6.md)
//
// Eight cosmetic varieties (TrapVariety in the contract). The rules are identical for all of them; the Scene and
// TrapArt draw them. Classic is there from the start. The others unlock about every 1.5 plant ranks: four by rank and
// three by a named goal (GoalBook offers that goal as soon as its rank band opens, until it is done). Golden Glow,
// at the top rank, is the final unlock. Pure; tested.

/// How a variety unlocks.
enum VarietyUnlock: Equatable, Sendable {
    /// From the start.
    case start
    /// At this plant rank (0…11, PlantRanks).
    case rank(Int)
    /// By completing this goal (a GoalSpec id in GoalBook.pool whose `unlocks` is the variety).
    case goal(String)
}

struct VarietyInfo: Equatable, Sendable {
    var variety: TrapVariety
    /// "Red Dragon"
    var name: String
    /// One short line for the Garden.
    var blurb: String
    var unlock: VarietyUnlock
}

enum Varieties {

    static let all: [VarietyInfo] = [
        VarietyInfo(variety: .classic, name: "Classic", blurb: "Lime lips, a crimson heart. The bog's own.",
                    unlock: .start),
        VarietyInfo(variety: .redDragon, name: "Red Dragon", blurb: "Crimson inside and out. Even the stem blushes.",
                    unlock: .rank(2)),
        VarietyInfo(variety: .b52, name: "B52", blurb: "Big, wide lobes and chunky cilia.",
                    unlock: .rank(5)),
        VarietyInfo(variety: .sawtooth, name: "Sawtooth", blurb: "Short, jagged teeth, like a bread knife.",
                    unlock: .goal(GoalBook.sawtoothGoal)),
        VarietyInfo(variety: .sharkTooth, name: "Shark Tooth", blurb: "Triangular teeth. Strictly for show.",
                    unlock: .goal(GoalBook.sharkToothGoal)),
        VarietyInfo(variety: .fusedTooth, name: "Fused Tooth", blurb: "Its teeth grew together into a frill.",
                    unlock: .goal(GoalBook.fusedToothGoal)),
        VarietyInfo(variety: .cupped, name: "Cupped Trap", blurb: "A deep, glossy cup of a trap.",
                    unlock: .rank(8)),
        VarietyInfo(variety: .goldenGlow, name: "Golden Glow", blurb: "A gold sheen no bog has seen. Fit for a Monarch.",
                    unlock: .rank(11)),
    ]

    static func info(_ v: TrapVariety) -> VarietyInfo {
        switch v {
        case .classic: return all[0]
        case .redDragon: return all[1]
        case .b52: return all[2]
        case .sawtooth: return all[3]
        case .sharkTooth: return all[4]
        case .fusedTooth: return all[5]
        case .cupped: return all[6]
        case .goldenGlow: return all[7]
        }
    }

    /// Is `v` unlocked at plant `rank` with these goal ids ever completed (GoalBookState.everCompleted)?
    static func isUnlocked(_ v: TrapVariety, rank: Int, completedGoals: Set<String>) -> Bool {
        switch info(v).unlock {
        case .start: return true
        case .rank(let r): return rank >= r
        case .goal(let id): return completedGoals.contains(id)
        }
    }

    /// Every unlocked variety, in TrapVariety.allCases order (Classic always first).
    static func unlocked(rank: Int, completedGoals: Set<String>) -> [TrapVariety] {
        return TrapVariety.allCases.filter { (v: TrapVariety) -> Bool in
            isUnlocked(v, rank: rank, completedGoals: completedGoals)
        }
    }

    /// The varieties a change of rank and goals unlocked (for the fanfare), in allCases order.
    static func newlyUnlocked(rankBefore: Int, goalsBefore: Set<String>, rankAfter: Int,
                              goalsAfter: Set<String>) -> [TrapVariety] {
        return TrapVariety.allCases.filter { (v: TrapVariety) -> Bool in
            !isUnlocked(v, rank: rankBefore, completedGoals: goalsBefore)
                && isUnlocked(v, rank: rankAfter, completedGoals: goalsAfter)
        }
    }

    /// The Garden's line under a locked silhouette: "Reach Nibbler" or "Goal: Spare 12 bees in one run".
    static func ruleText(_ v: TrapVariety) -> String {
        switch info(v).unlock {
        case .start: return "Your first trap"
        case .rank(let r): return "Reach " + PlantRanks.title(r)
        case .goal(let id): return "Goal: " + (GoalBook.def(id)?.title ?? id)
        }
    }

    /// The variety to draw: the chosen one if it is unlocked, else Classic (a stale or tampered choice never shows a
    /// locked trap).
    static func effective(_ chosen: TrapVariety, rank: Int, completedGoals: Set<String>) -> TrapVariety {
        return isUnlocked(chosen, rank: rank, completedGoals: completedGoals) ? chosen : .classic
    }
}
