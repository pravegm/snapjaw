import SwiftUI
import UIKit

// MARK: - Demo mode (CI screenshots, design review). Active in DEBUG builds only: `current` is nil in Release.
//
// Launch argument: `-snapDemo "key=value;key;key=value"` (ci/scenarios.txt, ci/duo.sh). Values can't contain `;`.
// Unknown keys are ignored. Every line CI greps starts with `SNAP-` (never rename them).
//
// Keys (design/ROUND-1.md "Demo mode")
// - `screen=home|play|results|book|settings|lesson|pose|cover|icon|daily|badges|garden`
//     home      Home (the title trap follows the hinge, or holds at `closure=`).
//     play      straight into a run of `mode` (default feed). Implied by `mode=` without `screen`.
//     results   the Results screen for `mode`: a REAL run of it played headless at launch by the pilot (`pilot=`,
//               default casual) and recorded into the demo progress, so best, rank and Bug Book are all true.
//     book / settings / daily   those pages.
//     garden    R6: the Garden (the 8 trap varieties; with `progress=mid` three have grown and five are silhouettes
//               with their rule; `late` all but Golden Glow).
//     results   R6: also ticks the run's goals (the pilot really plays them), so Results shows the goals done, their
//               growth and any new variety. `mode=daily` (scored) shows the streak and the Share button (with
//               `progress=mid` or `late` the streak is 3 or 5 days). `mode=zen` plays 150 s, then ends the visit
//               (the pause menu's End): no best, no leaderboard.
//     lesson    the First Bite lesson (at `lessonStep=`, default 1).
//     pose      force the pose card "Hold it open like a book" (over a run of `mode` if given, else Home).
//     cover     force the cover-display card ("Open it up to carry on" and the score): a run of `mode` (default
//               feed) is played headless for 24 s first by the pilot (default casual), so the score is real.
//     icon      render the app icon (AppIconArt) to Documents/AppIcon-1024.png (`SNAP-T icon ok 1024x1024`,
//               `SNAP-ICON <path>`) and show it full screen. `SNAP_ICON=1` in the environment does the same.
//     badges    R3: render the 12 Game Center achievement images, 1024 × 1024 opaque PNGs, to
//               Documents/badges/<id>.png, one `SNAP-BADGE <id> <path>` line each, then `SNAP-T badges done <n>`
//               (Home shows meanwhile).
// - `mode=feed|daily|attract|zen` the run mode (`daily` = today's scored try; `attract`: snaps never run out;
//                                 R6 `zen`: the Zen Bog, no snaps running out, no hunger, no leaderboard).
// - `seed=<n>`                    the run seed (default 7 for feed/attract, so frames are stable; daily = today's).
// - `pilot=novice|casual|expert|perfect`   Core's TrapPilot drives the trap. Without it `screen=play` takes the real
//                                 hinge (Duo CI) or touch.
// - `progress=fresh|mid|late|story`   seeded in-memory progress (fresh: nothing; mid: rank 4, 9 species, best 3,200;
//                                 late: rank 10, 16 species, best 14,800; R7 story: rank 7, 13 species, best 9,400,
//                                 the Garden 5/8). Demo runs never write UserDefaults.
// - `freezeOn=landed|crowd|bee|snap|feast|sting|dusk|night|lastSnap|hungry|wilted|tired|results|firstHint|chain5|
//             costlySting|drySnap|held|feastOpen|bigFeast|goalDone|feastGulp`
//                                 stop stepping the session (the scene keeps drawing) at the first such moment, and
//                                 print `SNAP-T freeze <tag>`. `snap` holds 0.12 s after the bite; `costlySting` (a sting
//                                 that cost snaps) 0.2 s; feast, sting, lastSnap, wilted, chain5 (the chain's 5th step),
//                                 drySnap and held ("×1.5 held") 0.3 s, so their FX are on screen; `hungry` 0.5 s (the
//                                 next snap glyph drains and "Hungry… bite!" shows). `firstHint`: the opening's fold line
//                                 ("Snap the halves together" / "Tap to snap") is on its plate. R5: `tired` holds
//                                 1.0 s into the tired moment (`AppRules.tiredFreezeAt`: the numeral at 0, the banner
//                                 up). R6: `bigFeast` (a FEAST event: 5+ bugs, or a Feast at ×4+) holds 0.45 s, so the
//                                 hit-stop is over and the "FEAST!" banner and the gulp are up; `goalDone` freezes the
//                                 moment a goal's toast ("Goal done! …") is on its plate. R7: `feastGulp` (a clean bite
//                                 of 5+ bugs) holds 0.15 s and pauses the scene at once: mid-gulp, the crowd still in
//                                 the jaws (P02/D02). `tired` now holds 1.6 s (the bite's pops gone, the banner up).
// - `variety=<raw>`               R6: draw this trap variety (`redDragon`, `b52`, …) whatever the progress has
//                                 grown (CI frames of every variety).
// - `firstRun=0|1`                R4: Sprout run 1's rules (14 snaps, no wilt, a free first sting). Unset: only
//                                 `progress=fresh` plays them; every other play demo runs the standard rules.
// - `freezeAfter=<s>`             freeze after s seconds of play (`SNAP-T freeze after`); with `freezeOn`, the moment
//                                 only counts once s seconds have passed.
// - `closure=<deg>`               hold the drawn closure at this many degrees (no pilot, no hinge): static jaw frames.
// - `wave=<n>`                    start the run at wave n: the first waves are played headless with the trap held
//                                 open (no snaps spent), so day-phase frames don't take real minutes.
//                                 `SNAP-T skipped wave <n> t=<s>`.
// - `lessonStep=<1…7>`            start the lesson at that step.
// - `hudLeft=0|1`                 force the HUD side.
// - `fold=1`                      lay out as if a fold exists (phone sims; Duo-layout frames).
// - `sound=0`                     mute.
//
// Log lines: `SNAP-T demo '<args>' starts`, `SNAP-T canvas <w>x<h> fold=<0|1> hudLeft=<0|1>`,
// `SNAP-T input hinge|touch|pilot|fixed`, `SNAP-T trap closure …` (10 Hz in play), `SNAP-T event <name> …`,
// `SNAP-T paused closing`, `SNAP-T resumed`, `SNAP-T paused menu|background|pose`, `SNAP-T freeze <tag>`,
// `SNAP-T frame 120`, `SNAP-T screen <route>`, `SNAP-T pose <pose>`, `SNAP-T lesson step <n> '<line>'`,
// `SNAP-T run score=<n> bugs=<n> snaps=<n> seconds=<s>`, `SNAP-T icon ok|failed`, `SNAP-ICON <path>`.
// R6: `SNAP-T goal done <id>`, `SNAP-T night cue nightGetsFast|lastLight`, `SNAP-T zen end bugs=<n> seconds=<s>`,
// `SNAP-T results goals <n> growth=<n>`, `SNAP-T variety <raw>` (picked), `SNAP-T variety grown <raw,…>`,
// `SNAP-T screen garden`. R7: `SNAP-T too-flat on|off angle=<deg>` (play on a hinge held at ≥ 174°: the plate says
// "Fold it a little").
//
// R6 CI frames (ROUND-6 App list):
//   garden            `screen=garden;progress=mid` (and `progress=late`: two goal-grown cultivars, two still locked)
//   zen play          `mode=zen;pilot=casual;progress=mid;freezeAfter=40`
//   zen results       `screen=results;mode=zen;progress=mid`
//   FEAST event       `mode=feed;pilot=expert;progress=mid;freezeOn=bigFeast`
//   goal toast        `mode=feed;pilot=casual;progress=mid;freezeOn=goalDone`
//   results + goals   `screen=results;mode=feed;pilot=casual;progress=mid`
//   Daily + share     `screen=results;mode=daily;pilot=casual;progress=mid` (🔥 3 days, Share)
//   a variety in play `mode=feed;pilot=casual;progress=late;variety=b52;freezeAfter=20`
// (`SNAP-H <t> <angle>` hinge samples come from Feel's HingeReader.)
//
// R8 (design/notes/app-R8.md): the First Bite lesson is retired (`screen=lesson`, `lessonStep=` are gone: Levels 1–5
// teach). New:
// - `screen=levels`        the level map (3 worlds × 10 levels, stars, locks).
// - `screen=levelIntro`    a level's intro card (`level=`, default 3), held (no pilot: the phone sim waits for Go).
// - `screen=levelResults`  a level really played by the pilot (default perfect) to its goal, then its Results.
//                          `screen=results;mode=level;level=<n>` does the same.
// - `screen=chomp`         the outer display's CHOMP card: a run played by the pilot until a bite of `chomp=`
//                          (`catch` 3+ bugs, default; `sting`; `dry`), then shown shut on it.
// - `screen=shut`          a run just started, shut before its first bite: the outer display's "Open to start".
// - `screen=cover`         R8: the outer display off a run (the closed trap at rest, "Open to play").
// - `mode=level;level=<n>` play level n (with `pilot=`, straight past its intro).
// Log lines: `SNAP-T verdict '<words>' ratio=<r>`, `SNAP-T hinge step shut=<0|1> angle=<deg>`,
// `SNAP-T level intro|go|passed|time up|result …`, `SNAP-T chomp card <kind> …`, `SNAP-T level demo <id> played=<s>`.

struct DemoMode: Equatable {
    enum Screen: String, Equatable, CaseIterable {
        case home, play, results, book, settings, pose, cover, icon, daily, badges
        /// R6: the Garden.
        case garden
        /// R8: the level map, a level's intro, a level's Results, the outer display's CHOMP card, the shut state.
        case levels, levelIntro, levelResults, chomp, shut
    }
    enum ModeKey: String, Equatable { case feed, daily, attract, zen, level }

    /// R8: the level a demo plays without `level=`.
    static let defaultLevel = 3
    enum Freeze: String, Equatable, CaseIterable {
        case landed, crowd, bee, snap, feast, sting, dusk, night, lastSnap, hungry, wilted, tired, results
        /// R4 (REVIEW-3 #2, #9, #10, #20): the opening's fold line on its plate; the chain's fifth step; a sting that
        /// cost snaps (the crack and the row flash); a dry snap; a held chain ("×1.5 held").
        case firstHint, chain5, costlySting, drySnap, held
        /// R5 (REVIEW-4 #3): a Feast with the trap open again (0.75 s on), for the store bite shot on phones.
        case feastOpen
        /// R6: a FEAST event (5+ bugs, or ×4+), and a goal's live toast on its plate.
        case bigFeast, goalDone
        /// R7 (CI ask, ci-R7.md #6: P02/D02 mid-gulp): a clean bite of 5+ bugs, held 0.15 s after it with the scene
        /// paused at once, so the first gulps are going into the midrib and the rest of the crowd is still in the jaws.
        case feastGulp

        /// Event moments hold a beat after the event; state moments freeze at once.
        var isEvent: Bool {
            switch self {
            case .snap, .feast, .sting, .lastSnap, .hungry, .wilted, .chain5, .costlySting, .drySnap, .held, .feastOpen,
                 .bigFeast, .feastGulp:
                return true
            case .landed, .crowd, .bee, .dusk, .night, .tired, .results, .firstHint, .goalDone: return false
            }
        }

        /// R7: the scene is paused the moment the session freezes (not `GameController.sceneHoldDelay` later), so a
        /// moment that moves on its own scene clock (the gulps) stays as it was.
        var holdsSceneAtOnce: Bool {
            switch self {
            case .feastGulp: return true
            case .landed, .crowd, .bee, .snap, .feast, .sting, .dusk, .night, .lastSnap, .hungry, .wilted, .tired,
                 .results, .firstHint, .chain5, .costlySting, .drySnap, .held, .feastOpen, .bigFeast, .goalDone:
                return false
            }
        }

        /// The beat after an event moment (s of play). R4 (ROUND-4): `hungry` +0.5 (the glyph drains and the numeral
        /// goes red), `wilted` +0.3 (the "Too slow! −1 snap" pop rises), `costlySting` +0.2 (the crack, before the
        /// numeral drops).
        var holdDelay: Double {
            switch self {
            case .snap: return 0.12
            case .costlySting: return 0.2
            case .feast, .sting, .lastSnap, .wilted, .chain5, .drySnap, .held: return 0.3
            case .hungry: return 0.5
            case .feastOpen: return 0.75
            case .bigFeast: return 0.45
            case .feastGulp: return 0.15
            case .landed, .crowd, .bee, .dusk, .night, .tired, .results, .firstHint, .goalDone: return 0
            }
        }
    }
    /// R7 (CI ask, ci-R7.md #9): `story` sits between `mid` and `late` (rank 7, 13 species, the Garden 5 of 8), so a
    /// store set can show one player with pages still to find.
    enum Preset: String, Equatable { case fresh, mid, late, story }

    static let defaultSeed: UInt64 = 7
    /// R7 (#10): `screen=results;mode=zen` without `seed=` plays this seed (frame 47 showed the Feed demo's best bite
    /// and chain: seed 7's first 150 s are Feed's best moments too).
    static let zenResultsSeed: UInt64 = 23

    /// The seed a demo run plays without `seed=`: 7, or the Zen Results seed. Pure; tested.
    static func seed(for mode: RunMode, screen: Screen?) -> UInt64 {
        if mode == .zen && screen == .results { return zenResultsSeed }
        return defaultSeed
    }

    var raw: String
    var screen: Screen?
    var mode: ModeKey?
    var seed: UInt64?
    var pilot: PilotSkill?
    var progress: Preset?
    var freezeOn: Freeze?
    /// `freezeAfter=` (the field is named apart from the key: a TestFlight demo guard may grep Release for the key).
    var holdAfter: Double?
    var closure: Double?
    var wave: Int?
    /// R8: `level=`: the level a demo plays (1…30).
    var level: Int?
    /// R8: `chomp=catch|sting|dry`: the CHOMP card's bite.
    var chomp: ChompInfo.Kind?
    var hudLeft: Bool?
    var fold = false
    var sound = true
    /// R4 (REVIEW-3 #2): `firstRun=1` plays Sprout run 1's rules (14 snaps, no wilt, a free first sting); `firstRun=0`
    /// never does. Unset: only `progress=fresh` does, so every other play demo runs the standard rules.
    var firstRun: Bool?
    /// R6: `variety=`: the trap variety drawn (nil: the progress's chosen one).
    var variety: TrapVariety?

    /// Whether a demo run gets the first-run rules.
    var playsFirstRun: Bool { AppRules.demoFirstRun(firstRun: firstRun, progress: progress) }

    init(raw: String) { self.raw = raw }

    /// The screen the app opens on.
    var effectiveScreen: Screen {
        if let screen { return screen }
        return mode == nil ? .home : .play
    }

    /// The run `mode=` asks for (`daily` = today's scored try; default feed).
    func runMode(today: Int) -> RunMode {
        switch mode ?? .feed {
        case .feed: return .feed
        case .daily: return .daily(day: today, scored: true)
        case .attract: return .attract
        case .zen: return .zen
        case .level: return .level(level ?? Self.defaultLevel)
        }
    }

    /// R8: `chomp=` (pure; tested).
    static func chompKind(_ value: String) -> ChompInfo.Kind? {
        switch value.lowercased() {
        case "catch", "chomp": return .catchBite
        case "sting", "bee": return .sting
        case "dry", "empty": return .dry
        default: return nil
        }
    }

    #if DEBUG
    private static func flag(_ value: String) -> Bool {
        let v = value.lowercased()
        return v.isEmpty || v == "1" || v == "on" || v == "true" || v == "yes"
    }

    private static func number(_ value: String) -> Double? {
        guard let d = Double(value), d.isFinite else { return nil }
        return d
    }

    /// Parses `key=value;key` (pure; tested).
    static func parse(_ raw: String) -> DemoMode {
        var config = DemoMode(raw: raw)
        for part in raw.split(separator: ";") {
            let pieces = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let key = pieces.first, !key.isEmpty else { continue }
            let value = pieces.count > 1 ? pieces[1] : ""
            switch key {
            case "screen": config.screen = Screen.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
            case "mode": config.mode = ModeKey(rawValue: value.lowercased())
            case "seed": config.seed = UInt64(value)
            case "pilot": config.pilot = PilotSkill(rawValue: value.lowercased())
            case "progress": config.progress = Preset(rawValue: value.lowercased())
            case "freezeOn":
                config.freezeOn = Freeze.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
            case "freezeAfter":
                if let s = number(value) { config.holdAfter = max(s, 0) }
            case "closure":
                if let c = number(value) { config.closure = min(max(c, 0), 60) }
            case "wave":
                if let n = Int(value) { config.wave = min(max(n, 1), 200) }
            case "level":
                if let n = Int(value) { config.level = min(max(n, 1), 30) }
            case "chomp": config.chomp = chompKind(value)
            case "hudLeft": config.hudLeft = flag(value)
            case "fold": config.fold = flag(value)
            case "sound": config.sound = flag(value)
            case "firstRun": config.firstRun = flag(value)
            case "variety":
                config.variety = TrapVariety.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
            default: break
            }
        }
        return config
    }
    #endif

    /// The scenario for this launch: DEBUG builds with `-snapDemo` (or `SNAP_ICON=1`) only; nil otherwise.
    static let current: DemoMode? = {
        #if DEBUG
        let raw = UserDefaults.standard.string(forKey: "snapDemo")
        let icon = ProcessInfo.processInfo.environment["SNAP_ICON"] == "1"
        let flagged = ProcessInfo.processInfo.arguments.contains("-snapDemo")
        guard raw != nil || icon || flagged else { return nil }
        // CI redirects stdout to a file (fully buffered); line-buffer it so the scripts see SNAP- lines on time.
        setvbuf(stdout, nil, _IOLBF, 0)
        var config = DemoMode.parse(raw ?? "")
        if icon { config.screen = .icon }
        return config
        #else
        return nil
        #endif
    }()
}

// MARK: - Seeded progress (`progress=`)

/// Every number a seeded profile shows agrees with every other one: the lifetime bugs (so the rank), the Bug Book,
/// the bests and the achievements all come from one small made-up history, and the achievements are Core's own rules
/// applied to that history's best run (never "the first n").
enum DemoPresets {
    struct Profile: Equatable {
        var runs: Int
        var rank: Int
        var species: Int
        var best: Int
        var biggestBite: Int
        var longestChain: Int
        var dailies: [Int]
        /// R6: goal ids done so far (Core's pool; `late` has done two of the Garden's goals).
        var goalsDone: [String]
        /// R8: stars per level, Level 1 first (the levels after the list never played).
        var levels: [Int] = []
    }

    /// R8: mid has played into the Morning Bog (Level 7 next); late has opened the Night; story stands at Dusk's door.
    static let mid = Profile(runs: 14, rank: 4, species: 9, best: 3_200, biggestBite: 4, longestChain: 3,
                             dailies: [2_640, 1_980], goalsDone: ["bite3", "spare3", "catch20", "feast2"],
                             levels: [3, 3, 2, 3, 1, 2])
    static let late = Profile(runs: 90, rank: 10, species: 16, best: 14_800, biggestBite: 6, longestChain: 7,
                              dailies: [11_200, 9_350, 12_900, 8_740],
                              goalsDone: ["bite4", "chain3", GoalBook.sawtoothGoal, "dragonfly3",
                                          GoalBook.sharkToothGoal, "scarab"],
                              levels: [3, 3, 3, 3, 3, 2, 3, 3, 2, 3, 3, 2, 3, 3, 2, 3, 2, 3, 3, 2, 2, 3, 1])

    /// R7: rank 7, 13 species, best 9,400; Sawtooth and Shark Tooth grown by goal, so the Garden is 5 of 8 (Classic,
    /// Red Dragon and B52 by rank).
    static let story = Profile(runs: 48, rank: 7, species: 13, best: 9_400, biggestBite: 6, longestChain: 5,
                               dailies: [7_300, 6_120, 8_050], goalsDone: ["bite4", GoalBook.sawtoothGoal, "chain3",
                                                                          GoalBook.sharkToothGoal],
                               levels: [3, 3, 3, 2, 3, 2, 3, 2, 2, 3, 2, 1])

    static func progress(_ preset: DemoMode.Preset?, today: Int) -> ProgressData {
        switch preset ?? .fresh {
        case .fresh: return ProgressData()
        case .mid: return make(mid, today: today)
        case .late: return make(late, today: today)
        case .story: return make(story, today: today)
        }
    }

    /// The lifetime bugs a third of the way through `rank` (Core's thresholds).
    static func lifetimeBugs(rank: Int) -> Int {
        let r = min(max(rank, 0), PlantRanks.count - 1)
        let lo = PlantRanks.threshold(r)
        guard r + 1 < PlantRanks.count else { return lo + 40 }
        let hi = PlantRanks.threshold(r + 1)
        return lo + max((hi - lo) / 3, 1)
    }

    /// Pure; tested (Home's rank = the rank of the lifetime, the Bug Book count = species, best ≤ lifetime score).
    static func make(_ p: Profile, today: Int) -> ProgressData {
        var data = ProgressData()
        data.runs = p.runs
        data.feedRuns = max(p.runs - p.dailies.count, 0)
        data.bestFeed = p.best
        data.lifetimeBugs = lifetimeBugs(rank: p.rank)
        data.lifetimeScore = max(p.best + (p.runs - 1) * p.best / 3, p.best)
        data.snaps = p.runs * 28
        data.feasts = p.runs * 2
        data.stings = p.runs / 2
        data.bestBitePoints = p.best / 5
        data.biggestBite = p.biggestBite
        data.longestChain = p.longestChain
        data.fastestSnap = 0.11
        // The Bug Book: the first `species` pages in Bug Book order.
        let found = Array(BugSpecies.allCases.prefix(min(max(p.species, 0), BugSpecies.allCases.count)))
        let edible = found.filter { !$0.isProtected }
        let protected = found.filter { $0.isProtected }
        if !edible.isEmpty {
            // Varied counts (REVIEW-2 #19: not "Caught 27" on every page): common bugs many, rare ones few, and the
            // total is exactly the lifetime.
            let weights: [Double] = edible.enumerated().map { pair -> Double in
                let base = 1 / (1 + 0.55 * Double(pair.offset))
                let wobble = 1 + 0.18 * Double((pair.offset * 37 + 11) % 5) / 4
                let rare: Double = pair.element == .goldenScarab ? 0.15 : (pair.element == .dragonfly ? 0.4 : 1)
                return base * wobble * rare
            }
            let total = max(weights.reduce(0, +), 0.0001)
            var counts = weights.map { max(Int(Double(data.lifetimeBugs) * $0 / total), 1) }
            let over = counts.reduce(0, +) - data.lifetimeBugs
            counts[0] = max(counts[0] - over, 1)
            for (i, s) in edible.enumerated() { data.caught[s.rawValue] = counts[i] }
        }
        data.lifetimeSpared = protected.isEmpty ? p.runs : p.runs * 2
        for (i, s) in protected.enumerated() {
            data.spared[s.rawValue] = max(data.lifetimeSpared / (protected.count + i), 1)
        }
        data.foundOrder = found.map(\.rawValue)
        data.lessonDone = true
        for (i, score) in p.dailies.enumerated() {
            let day = today - 1 - i
            data.daily[day] = DailyRecord(score: score, finished: true, practiceBest: score / 2)
            data.dailyAttempted.insert(day)
            data.bestDaily = max(data.bestDaily, score)
        }
        if !p.dailies.isEmpty { data.lastDailyDay = today - 1 }
        // The history's best run, as Core's achievement rules see it.
        var caughtInBest: [String: Int] = [:]
        for s in edible.prefix(4) { caughtInBest[s.rawValue] = 3 }
        var sparedInBest: [String: Int] = [:]
        for s in protected.prefix(1) { sparedInBest[s.rawValue] = 2 }
        let bestRun = RunResult(mode: .feed, seed: 1, score: p.best, seconds: 170, snaps: 32,
                                bugsCaught: caughtInBest.values.reduce(0, +), caughtBySpecies: caughtInBest,
                                sparedBySpecies: sparedInBest, bestBitePoints: p.best / 5,
                                biggestBite: p.biggestBite, longestChain: p.longestChain,
                                beesSpared: sparedInBest.values.reduce(0, +), stings: 0, feasts: 2, waves: 24,
                                drySnaps: 3, fastestSnap: 0.11)
        let earned = Achievements.earned(after: bestRun, lifetimeBugs: data.lifetimeBugs,
                                         lifetimeSpared: data.lifetimeSpared, speciesFound: data.speciesFound,
                                         alreadyEarned: [])
        data.achievements = Set(earned.map(\.id))
        // R6: the Daily streak (the dailies are the days just before today), the goals done (no growth, so the rank
        // stays the profile's), the goals drawn for the rank, and every grown variety already seen in the Garden.
        data.bestStreak = p.dailies.count
        data.chainTipSeen = p.longestChain > 0
        data.rankBugs = data.lifetimeBugs
        var book = GoalBookState(seed: UInt64(truncatingIfNeeded: p.runs &* 104_729 &+ p.best))
        let done = p.goalsDone.filter { GoalBook.def($0) != nil }
        book.everCompleted = done
        book.recent = Array(done.suffix(Tuning.goalRecentMemory))
        book.completedCount = done.count
        data.goalBook = GoalBook.normalized(book, rank: data.rank)
        data.varietiesSeen = Set(data.unlockedVarieties.map(\.rawValue))
        // R8: the levels played so far.
        for (i, s) in p.levels.enumerated() where s > 0 { data.levelStars[i + 1] = min(s, 3) }
        return data
    }
}

// MARK: - App icon render (`screen=icon`, `SNAP_ICON=1`)

@MainActor
enum IconExport {
    static let side: CGFloat = 1024
    static let fileName = "AppIcon-1024.png"

    /// Renders AppIconArt at 1024 × 1024 px, flattened onto an opaque RGB PNG with no alpha (ITMS-90717), to
    /// Documents/AppIcon-1024.png (CI copies it into Snap/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png),
    /// plus the small-size checks AppIcon-180/60/40.png.
    static func render() {
        let renderer = ImageRenderer(content: AppIconArt().frame(width: side, height: side))
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage else {
            AppTrace.t("SNAP-T icon failed: renderer returned no image")
            return
        }
        guard let data = opaquePNG(cgImage, side: side),
              let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppTrace.t("SNAP-T icon failed: no PNG data")
            return
        }
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            AppTrace.t("SNAP-T icon ok \(cgImage.width)x\(cgImage.height) rgb=\(SnapPNG.colorType(data) == 2 ? 1 : 0)")
            AppTrace.t("SNAP-ICON \(url.path)")
        } catch {
            AppTrace.t("SNAP-T icon failed: \(error.localizedDescription)")
        }
        var written: [String] = []
        for size in [180, 60, 40] {
            let s = CGFloat(size)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let small = UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: format).image { _ in
                UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: s, height: s))
            }
            if let smallCG = small.cgImage, let png = SnapPNG.encode(smallCG),
               (try? png.write(to: directory.appendingPathComponent("AppIcon-\(size).png"))) != nil {
                written.append("\(size)")
            }
        }
        AppTrace.t("SNAP-T icon sizes \(written.joined(separator: ","))")
    }

    /// Redraws into an opaque 1× context and writes an RGB PNG with NO alpha channel.
    static func opaquePNG(_ cgImage: CGImage, side: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        guard let flat = image.cgImage else { return nil }
        return SnapPNG.encode(flat)
    }
}

// MARK: - Game Center badges (`screen=badges`, R3)

@MainActor
enum BadgeExport {
    /// Game Center achievement images: 1024 × 1024 (tools/appstore/badges.swift checks it).
    static let side: CGFloat = 1024

    /// Renders every achievement's AchievementBadge to Documents/badges/<id>.png (opaque RGB, no alpha), printing
    /// `SNAP-BADGE <id> <path>` per image and `SNAP-T badges done <n>` at the end (Swoop's `screen=badges`).
    static func renderAll() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppTrace.t("SNAP-T badges done 0 (no Documents directory)")
            return
        }
        let directory = documents.appendingPathComponent("badges", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written = 0
        for id in GameCenterManager.achievementIDs {
            let renderer = ImageRenderer(content: AchievementBadge(id: id, side: side).frame(width: side, height: side))
            renderer.proposedSize = ProposedViewSize(width: side, height: side)
            renderer.scale = 1
            renderer.isOpaque = true
            guard let cgImage = renderer.cgImage, let data = IconExport.opaquePNG(cgImage, side: side) else {
                AppTrace.t("SNAP-T badges failed \(id): no image")
                continue
            }
            let url = directory.appendingPathComponent("\(id).png")
            do {
                try data.write(to: url)
                written += 1
                AppTrace.t("SNAP-BADGE \(id) \(url.path)")
            } catch {
                AppTrace.t("SNAP-T badges failed \(id): \(error.localizedDescription)")
            }
        }
        AppTrace.t("SNAP-T badges done \(written)")
    }
}
