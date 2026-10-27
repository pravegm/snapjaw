import SwiftUI
import UIKit

// MARK: - Demo mode (CI screenshots, design review). Active in DEBUG builds only: `current` is nil in Release.
//
// Launch argument: `-snapDemo "key=value;key;key=value"` (ci/scenarios.txt, ci/duo.sh). Values can't contain `;`.
// Unknown keys are ignored. Every line CI greps starts with `SNAP-` (never rename them).
//
// Keys (design/ROUND-1.md "Demo mode")
// - `screen=home|play|results|book|settings|lesson|pose|cover|icon|daily`
//     home      Home (the title trap follows the hinge, or holds at `closure=`).
//     play      straight into a run of `mode` (default feed). Implied by `mode=` without `screen`.
//     results   the Results screen for `mode`: a REAL run of it played headless at launch by the pilot (`pilot=`,
//               default casual) and recorded into the demo progress, so best, rank and Bug Book are all true.
//     book / settings / daily   those pages.
//     lesson    the First Bite lesson (at `lessonStep=`, default 1).
//     pose      force the pose card "Hold it open like a book" (over a run of `mode` if given, else Home).
//     cover     force the cover-display card ("Open to carry on").
//     icon      render the app icon (AppIconArt) to Documents/AppIcon-1024.png (`SNAP-T icon ok 1024x1024`,
//               `SNAP-ICON <path>`) and show it full screen. `SNAP_ICON=1` in the environment does the same.
// - `mode=feed|daily|attract`     the run mode (`daily` = today's scored try; `attract`: snaps never run out).
// - `seed=<n>`                    the run seed (default 7 for feed/attract, so frames are stable; daily = today's).
// - `pilot=novice|casual|expert|perfect`   Core's TrapPilot drives the trap. Without it `screen=play` takes the real
//                                 hinge (Duo CI) or touch.
// - `progress=fresh|mid|late`     seeded in-memory progress (fresh: nothing; mid: rank 4, 9 species, best 3,200;
//                                 late: rank 10, 16 species, best 14,800). Demo runs never write UserDefaults.
// - `freezeOn=landed|crowd|bee|snap|feast|sting|dusk|night|lastSnap|tired|results`
//                                 stop stepping the session (the scene keeps drawing) at the first such moment, and
//                                 print `SNAP-T freeze <tag>`. `snap` holds 0.12 s after the bite; the other event
//                                 moments (feast, sting, lastSnap) 0.3 s, so their FX are on screen.
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
// (`SNAP-H <t> <angle>` hinge samples come from Feel's HingeReader.)

struct DemoMode: Equatable {
    enum Screen: String, Equatable, CaseIterable {
        case home, play, results, book, settings, lesson, pose, cover, icon, daily
    }
    enum ModeKey: String, Equatable { case feed, daily, attract }
    enum Freeze: String, Equatable, CaseIterable {
        case landed, crowd, bee, snap, feast, sting, dusk, night, lastSnap, tired, results

        /// Event moments hold a beat after the event; state moments freeze at once.
        var isEvent: Bool {
            switch self {
            case .snap, .feast, .sting, .lastSnap: return true
            case .landed, .crowd, .bee, .dusk, .night, .tired, .results: return false
            }
        }

        /// The beat after an event moment (s of play).
        var holdDelay: Double {
            switch self {
            case .snap: return 0.12
            case .feast, .sting, .lastSnap: return 0.3
            case .landed, .crowd, .bee, .dusk, .night, .tired, .results: return 0
            }
        }
    }
    enum Preset: String, Equatable { case fresh, mid, late }

    static let defaultSeed: UInt64 = 7

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
    var lessonStep: Int?
    var hudLeft: Bool?
    var fold = false
    var sound = true

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
            case "screen": config.screen = Screen(rawValue: value.lowercased())
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
            case "lessonStep":
                if let n = Int(value) { config.lessonStep = min(max(n, 1), LessonScript.Step.done.rawValue) }
            case "hudLeft": config.hudLeft = flag(value)
            case "fold": config.fold = flag(value)
            case "sound": config.sound = flag(value)
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
    }

    static let mid = Profile(runs: 14, rank: 4, species: 9, best: 3_200, biggestBite: 4, longestChain: 3,
                             dailies: [2_640, 1_980])
    static let late = Profile(runs: 90, rank: 10, species: 16, best: 14_800, biggestBite: 6, longestChain: 7,
                              dailies: [11_200, 9_350, 12_900, 8_740])

    static func progress(_ preset: DemoMode.Preset?, today: Int) -> ProgressData {
        switch preset ?? .fresh {
        case .fresh: return ProgressData()
        case .mid: return make(mid, today: today)
        case .late: return make(late, today: today)
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
            let share = max(data.lifetimeBugs / (2 * edible.count), 1)
            var left = data.lifetimeBugs
            for (i, s) in edible.enumerated() {
                let n = i == 0 ? max(data.lifetimeBugs - share * (edible.count - 1), 1) : share
                let count = min(n, max(left, 1))
                data.caught[s.rawValue] = count
                left -= count
            }
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
