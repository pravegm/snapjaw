import CoreGraphics
import Foundation

// MARK: - Levels (R8, ROUND-8 §4: the founder chose levels AND endless)
//
// 30 hand-made levels in 3 worlds (1–10 Morning Bog, 11–20 Dusk, 21–30 Night). Each has a scripted bug set (who lands
// where and when, bees and wasps included), one goal, a bite and/or time limit and 1–3 stars. Levels unlock in order
// and the next world at `LevelBook.worldUnlockStars` stars (the App persists progress).
// - The table is generated: tools/levels.js → `node tools/levels-gen.js` → LevelData.swift. tools/balance-sim.js plays
//   every level with the four pilots (`node tools/balance-sim.js levels=1`); BalanceTests does the same in Swift.
// - A level session (`LevelBook.session(id:geometry:)`, or TrapSession(mode: .level(id), …,
//   options: SessionOptions.for(.level(id)))) has no random waves, no hunger, no snap refunds and free stings (a
//   no-sting level fails at once instead). Its bites are snaps (the bite limit). It ends at once when the goal is met,
//   when a bee is bitten in a no-sting level, when the time is up, when the bites run out, or when nothing is left to
//   catch (`Tuning.levelIdleEnd` s): the `tired` → `finished` ending, with `TrapSession.levelEnd` saying why.
// - Stars (`LevelBook.evaluate`): passing is 1 star; at most `twoStarBites` bites used is 2; at most `threeStarBites`
//   (and, where `cleanForThree`, no bug escaped) is 3.

/// One scripted bug: it arrives `at` s after the round opens and lands at (u, v) (−1…1 across and up the trap, at 0.75
/// of its semi-axes; |u| ≥ 0.3 keeps it off the midrib), staying `linger` s. `sip`: it sips the nearest nectar drop on
/// its lobe.
struct LevelBug: Equatable, Sendable {
    var species: BugSpecies
    var at: Double
    var u: Double
    var v: Double
    var linger: Double
    var sip: Bool

    init(_ species: BugSpecies, at: Double, u: Double, v: Double, linger: Double, sip: Bool) {
        self.species = species
        self.at = at
        self.u = u
        self.v = v
        self.linger = linger
        self.sip = sip
    }
}

/// A level's goal: every non-zero part must be met.
struct LevelGoal: Equatable, Sendable {
    /// Bugs caught (any species).
    var catchAny: Int
    /// … and at least `speciesCount` caught of these species.
    var species: [BugSpecies]
    var speciesCount: Int
    /// … and one bite of at least this many.
    var biteOf: Int
    /// … and at least this many protected bugs spared.
    var spare: Int

    /// Is it met by these totals?
    func met(caught: Int, bySpecies: [String: Int], biggestBite: Int, spared: Int) -> Bool {
        var n: Int = 0
        for s in species { n += bySpecies[s.rawValue] ?? 0 }
        return caught >= catchAny && n >= speciesCount && biggestBite >= biteOf && spared >= spare
    }

    func met(_ r: RunResult) -> Bool {
        return met(caught: r.bugsCaught, bySpecies: r.caughtBySpecies, biggestBite: r.biggestBite,
                   spared: r.beesSpared)
    }
}

struct LevelSpec: Equatable, Sendable, Identifiable {
    /// 1…30.
    var id: Int
    /// 1 Morning Bog, 2 Dusk, 3 Night.
    var world: Int
    var title: String
    /// The intro card's one line ("Catch 2 flies"). R9: short (≤ ~24 characters, the in-play badge) and input-neutral
    /// (no "shut", "close", "tap", "lid" or pose: App's LevelWords makes the words right for a phone or a Duo).
    var goalText: String
    var goal: LevelGoal
    /// Biting a bee, bumblebee or wasp fails the level at once.
    var noSting: Bool
    /// Bites allowed (nil: no limit).
    var biteLimit: Int?
    /// Session seconds allowed (nil: no limit; the clock is frozen while shut).
    var timeLimit: Double?
    /// Stars: passing is 1; at most `twoStarBites` bites used is 2; at most `threeStarBites` is 3.
    var twoStarBites: Int
    var threeStarBites: Int
    /// 3 stars also need no bug to have escaped a bite or fled a close.
    var cleanForThree: Bool
    /// The wave the bugs' reactions use (TrapRules.lateFactor: before noon the sleepy morning, then faster from 30).
    var paceWave: Int
    var bugs: [LevelBug]
    /// R9: the level's calm: every catchable bug's reaction (flee time) × this (TrapRules.reactionScale; protected bugs
    /// never change). 1 = as the pace wave says; Level 1's sleepy fly is 2.5, so no close, however slow, loses it.
    var reactionScale: Double = 1

    /// "Morning Bog", "Dusk", "Night".
    var worldName: String { return LevelBook.worldName(world) }
    /// The level's fixed session seed (its nectar and its bugs' own moves).
    var seed: UInt64 { return LevelBook.seed(id) }
}

/// What a finished level earned.
struct LevelOutcome: Equatable, Sendable {
    /// 0 (failed) … 3.
    var stars: Int
    var passed: Bool
    /// One plain line for the level results ("3 stars! Perfect", "A bee was bitten").
    var line: String
}

/// Why a level session ended (`TrapSession.levelEnd`).
enum LevelEnd: String, Equatable, Sendable {
    case goal, stung, time, bites, empty
}

enum LevelBook {
    /// The next world opens at this many stars (ROUND-8 §4).
    static let worldUnlockStars: Int = 20
    static let worldCount: Int = 3

    static func worldName(_ world: Int) -> String {
        switch world {
        case 1: return "Morning Bog"
        case 2: return "Dusk"
        default: return "Night"
        }
    }

    /// Level `id`, if there is one.
    static func level(_ id: Int) -> LevelSpec? {
        guard id >= 1 && id <= all.count else { return nil }
        let l: LevelSpec = all[id - 1]
        return l.id == id ? l : all.first { (x: LevelSpec) -> Bool in x.id == id }
    }

    /// The levels of a world (1…3).
    static func levels(inWorld world: Int) -> [LevelSpec] {
        return all.filter { (l: LevelSpec) -> Bool in l.world == world }
    }

    /// A level's fixed session seed (the same in tools/balance-sim.js).
    static func seed(_ id: Int) -> UInt64 {
        return UInt64(0x1E7E1) &* UInt64(truncatingIfNeeded: max(id, 0)) &+ 77
    }

    /// The session options of a level: no waves, hunger or refunds; stings are free (a no-sting level fails instead);
    /// the bite limit is the snaps (no limit: snaps never run out).
    static func options(_ level: LevelSpec) -> SessionOptions {
        var o = SessionOptions(snapsRunOut: level.biteLimit != nil, waves: false, stingCosts: false)
        o.hunger = false
        o.refunds = false
        o.startSnaps = level.biteLimit
        return o
    }

    /// A ready level session (nil for an unknown id).
    static func session(id: Int, geometry: TrapGeometry) -> TrapSession? {
        guard let l = level(id) else { return nil }
        return TrapSession(mode: .level(id), seed: l.seed, best: 0, geometry: geometry, options: options(l))
    }

    /// A scripted bug as a SpawnSpec: the spot at 0.75 of the trap's semi-axes; a sipper aims at the nearest nectar
    /// drop on its lobe; flyers enter from their lobe's side edge, walkers from the bottom; a protected bug never
    /// enters under a thumb (WaveFactory.thumbSafeEntry).
    static func spawnSpec(_ b: LevelBug, geometry g: TrapGeometry, nectar: [NectarDrop]) -> SpawnSpec {
        let cx: Double = Double(g.center.x)
        let cy: Double = Double(g.center.y)
        var tx: Double = cx + b.u * Double(g.a) * 0.75
        var ty: Double = cy + b.v * Double(g.b) * 0.75
        let m: BugMotion = BugCatalog.motion(b.species)
        if b.sip && m.nectarChance > 0 && !nectar.isEmpty {
            let side: Double = b.u < 0 ? -1 : 1
            var best: NectarDrop? = nil
            var bd: Double = Double.infinity
            for d in nectar {
                let ds: Double = Double(d.position.x) < cx ? -1 : 1
                if ds != side { continue }
                let dd: Double = hypot(Double(d.position.x) - tx, Double(d.position.y) - ty)
                if dd < bd {
                    bd = dd
                    best = d
                }
            }
            if let d = best {
                tx = Double(d.position.x)
                ty = Double(d.position.y)
            }
        }
        let w: Double = Double(g.sceneSize.width)
        let h: Double = Double(g.sceneSize.height)
        var entry: CGPoint
        if m.style == .walker {
            entry = CGPoint(x: min(max(tx, 40), w - 40), y: -20)
        } else {
            entry = CGPoint(x: b.u < 0 ? -30 : w + 30, y: min(max(ty + 90 * b.v, 40), h - 40))
        }
        if b.species.isProtected { entry = WaveFactory.thumbSafeEntry(entry, sceneSize: g.sceneSize) }
        return SpawnSpec(species: b.species, entry: entry, target: CGPoint(x: tx, y: ty), linger: b.linger,
                         landsInTrap: true, groupOffset: 0)
    }

    /// The stars and the line for a finished level run (Core's `TrapSession.result`). Passed: the goal met, no sting
    /// in a no-sting level, within the bite and time limits. 1 star for passing, 2 at most `twoStarBites` bites, 3 at
    /// most `threeStarBites` (and no escapes where `cleanForThree`).
    static func evaluate(_ result: RunResult, _ level: LevelSpec) -> LevelOutcome {
        let goalMet: Bool = level.goal.met(result)
        let stung: Bool = level.noSting && result.stings > 0
        var inTime: Bool = true
        if let t = level.timeLimit { inTime = result.seconds <= t + 1e-6 }
        var inBites: Bool = true
        if let b = level.biteLimit { inBites = result.snaps <= b }
        let passed: Bool = goalMet && !stung && inTime && inBites
        if !passed {
            var line: String = "They got away. Try again"
            if stung {
                line = "You bit a bee. Wait for it to go"
            } else if !inTime || (level.timeLimit != nil && !goalMet
                                  && result.seconds >= (level.timeLimit ?? 0) - 1e-6) {
                line = "Out of time. Bite sooner"
            } else if let b = level.biteLimit, result.snaps >= b {
                line = "Out of bites. Wait for a crowd"
            }
            return LevelOutcome(stars: 0, passed: false, line: line)
        }
        let escapes: Int = result.escapes ?? 0
        let clean: Bool = !level.cleanForThree || escapes == 0
        if result.snaps <= level.threeStarBites && clean {
            return LevelOutcome(stars: 3, passed: true, line: "3 stars! Perfect")
        }
        if result.snaps <= level.twoStarBites {
            let hint: String = result.snaps <= level.threeStarBites ? "Let none escape for 3" : "Fewer bites for 3"
            return LevelOutcome(stars: 2, passed: true, line: "2 stars. " + hint)
        }
        return LevelOutcome(stars: 1, passed: true, line: "Passed! Fewer bites for more stars")
    }

    /// Stars over a progress map (level id → best stars), for the world unlocks.
    static func totalStars(_ best: [Int: Int]) -> Int {
        var n: Int = 0
        for (_, s) in best { n += min(max(s, 0), 3) }
        return n
    }

    /// Is `world` open with these best stars (world 1 always; world w at (w − 1) × worldUnlockStars)?
    static func worldUnlocked(_ world: Int, best: [Int: Int]) -> Bool {
        if world <= 1 { return true }
        return totalStars(best) >= (world - 1) * worldUnlockStars
    }

    /// Is level `id` open (its world is, and it is the world's first or the one before it has a star)?
    static func levelUnlocked(_ id: Int, best: [Int: Int]) -> Bool {
        guard let l = level(id) else { return false }
        if !worldUnlocked(l.world, best: best) { return false }
        if id == 1 { return true }
        if let first = levels(inWorld: l.world).first, first.id == id { return true }
        return (best[id - 1] ?? 0) >= 1
    }
}
