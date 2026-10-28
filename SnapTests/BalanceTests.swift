import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Headless balance playtest (Round 7)
//
// R7 (design/notes/core-R7.md): the ×2 FEAST (a clean bite of 5+ scores × Tuning.feastMultiplier), the night pool
// (fireflies and crickets lead) and the late decays 0.955 / 0.91. tools/balance-sim.js predicts on these 16 seeds:
//   novice  286 score     /  48 s / 10.5 snaps / 1 sting / 0 wilts
//   casual  7,834         / 122 s / 22 snaps   / 3 stings / longest chain 5 / 0 wilts
//   expert  40,069        / 302 s (p90 332 s) / 39.5 snaps / 0 stings / 2 wilts
//   perfect 67,073        / 341 s / 37.5 snaps / never stung / 3 wilts
//   without pilotGiveUp: expert 387 s, perfect 423 s, none capped; Sprout run 1: novice 101 s, casual 156 s;
//   taper: novice run 2 100 s, run 3 90 s; Zen 600 s: casual 333 bugs, perfect 485, ≥ 52 in the last 2 minutes.
//   (8 seeds: casual 124 s, chain 5; expert 315 s, p90 330 s; perfect 341 s; novice Sprout 1 / 2 / 3 98 / 95 / 85 s.)
// R7 targets added: expert p90 ≤ 360 s; casual median < Tuning.wellFedScore (10,000) ≤ expert median.
// The R6 numbers below are history.
//
// Every PilotSkill plays real TrapSessions (mode .feed, SNAP_BAL_SEEDS seeds, default 16; CI sets 8) at 60 Hz, the
// pilot fed the previous frame's snapshot the way GameController feeds it. Each run is capped at 10 min. R4: every
// run (the four skills plus the novice and casual pilots' Sprout run 1) is simulated once, in parallel, the first time
// any balance test asks, and the whole table is printed then as ONE block between "SNAP-BAL ==== table" and
// "SNAP-BAL ==== end", so it sits at the start of the balance section of the CI log:
//   SNAP-BAL skill=casual score=5206 p10=… p90=… seconds=147.4 snaps=24.5 caught=70.5 stings=2.5 maxStings=6 …
// tools/balance-sim.js (a line-by-line port) predicts on these 16 seeds (design/notes/core-R6.md):
//   novice  230 score      /  48 s / 10.5 snaps / 1 sting (median) / 0 wilts
//   casual  4,875          / 141 s / 24 snaps   / 3 stings / longest chain 5 / 0 wilts
//   expert  25,210         / 327 s / 42.5 snaps / 0 stings / 3 wilts
//   perfect 42,133         / 354 s / 41.5 snaps / never stung / 4 wilts
//   R6 (#19): the last light (Feed, wave 85 on: the hunger clock ticks whatever is in the trap) ends every run, so the
//   expert / perfect without pilotGiveUp end too: 427 / 432 s, none capped (R5: 14 of 16 capped at 600 s).
//   R6 Zen Bog (SessionOptions.for(.zen), 600 s): never tires or wilts, snaps never change; casual catches ~325 bugs,
//   perfect ~500, and both still catch ≥ 50 in the last 2 minutes (the day loops, so the night never outruns them).
//   Sprout run 1 (SessionOptions.sprout(feedRun: 1): 14 snaps, no wilting, the first sting free, a calm morning):
//   novice 101 s, casual 166 s. R5 taper: novice Sprout run 2 (13 snaps, free sting, calm) 100 s; run 3 (12, calm) 90 s.
//   R5 (REVIEW-4 P2): expert / perfect without Tuning.pilotGiveUp (TrapPilot.givesUp false). SNAP_BAL_NOGIVEUP=0
//   skips those runs. R6: asserted never capped (64-seed sim max < 550 s).
// (8 seeds: casual 128 s, chain 5, 0 wilts; expert 327 s, 3 wilts; perfect 350 s, 4 wilts; novice Sprout runs
// 1 / 2 / 3 98 / 95 / 85 s; without pilotGiveUp expert 425 s, perfect 446 s, none capped.)
// R4 targets (asserted on medians): perfect runs 4–8 min (240–480 s) with ≤ 5 wilts; expert ≤ 6 wilts; casual runs
// 100–240 s and 18–45 snaps, with a longest chain of 3–6 and ≤ 2 wilts; the novice and casual pilots' Sprout run 1
// lasts ≥ 90 s and never wilts; R5: the novice's Sprout run 2 lasts ≥ 75 s and run 3 ≥ 60 s; R6: expert ≤ 360 s and
// no run without pilotGiveUp capped; plus R1's: novice < casual < expert ≤ perfect, perfect never stung, novice stung (R3:
// median ≥ 0.5). The late night (reactions × 0.96 per wave to 0.2, lingers × 0.92 to 0.2) ends every run, so no skill
// may hit the 10-minute cap.

struct SnapBalanceRun {
    var score: Int
    var seconds: Double
    var snaps: Int
    var caught: Int
    var stings: Int
    var feasts: Int
    var waves: Int
    var longestChain: Int
    var beesSpared: Int
    /// R3: `wilted` events (RunResult has no wilt count).
    var wilts: Int
    var capped: Bool
}

/// The parallel runs' results (one lock; written from DispatchQueue.concurrentPerform's workers).
final class SnapBalanceBox: @unchecked Sendable {
    private let lock = NSLock()
    private var done: [Int: SnapBalanceRun] = [:]

    func put(_ k: Int, _ r: SnapBalanceRun) {
        lock.lock()
        done[k] = r
        lock.unlock()
    }

    func all() -> [Int: SnapBalanceRun] {
        lock.lock()
        defer { lock.unlock() }
        return done
    }
}

/// R4: every balance run, simulated once (in parallel) and printed as one table the first time a test asks.
final class SnapBalanceMemo: @unchecked Sendable {
    static let shared = SnapBalanceMemo()

    private let lock = NSLock()
    private var built: Bool = false
    private var results: [PilotSkill: [SnapBalanceRun]] = [:]
    private var sprout: [PilotSkill: [SnapBalanceRun]] = [:]
    /// R5: the novice's Sprout runs 2 and 3, by run.
    private var taper: [Int: [SnapBalanceRun]] = [:]
    /// R5: expert and perfect without Tuning.pilotGiveUp (reported only).
    private var stubbornRuns: [PilotSkill: [SnapBalanceRun]] = [:]

    /// The skills whose Sprout run 1 is simulated too.
    static let sproutSkills: [PilotSkill] = [.novice, .casual]
    /// R5 (REVIEW-4 #8): the taper runs simulated for the novice pilot.
    static let taperRunNumbers: [Int] = [2, 3]
    /// R5 (REVIEW-4 P2): the skills whose pilotGiveUp rule is reported both ways.
    static let giveUpSkills: [PilotSkill] = [.expert, .perfect]

    static var reportsNoGiveUp: Bool {
        return ProcessInfo.processInfo.environment["SNAP_BAL_NOGIVEUP"] != "0"
    }

    func runs(_ skill: PilotSkill) -> [SnapBalanceRun] {
        build()
        lock.lock()
        defer { lock.unlock() }
        return results[skill] ?? []
    }

    /// R3/R4: the pilot's Sprout run 1 on every seed (SnapBalanceHarness.sproutRunOne).
    func sproutRuns(_ skill: PilotSkill) -> [SnapBalanceRun] {
        build()
        lock.lock()
        defer { lock.unlock() }
        return sprout[skill] ?? []
    }

    /// R6: the expert / perfect runs without Tuning.pilotGiveUp (empty when SNAP_BAL_NOGIVEUP=0).
    func noGiveUpRuns(_ skill: PilotSkill) -> [SnapBalanceRun] {
        build()
        lock.lock()
        defer { lock.unlock() }
        return stubbornRuns[skill] ?? []
    }

    /// R5: the novice's Sprout run `run` (2 or 3) on every seed.
    func taperRunResults(_ run: Int) -> [SnapBalanceRun] {
        build()
        lock.lock()
        defer { lock.unlock() }
        return taper[run] ?? []
    }

    private enum Kind {
        case plain
        /// Sprout Feed run n (1, 2 or 3).
        case sprout(Int)
        /// R5: the pilot without Tuning.pilotGiveUp.
        case noGiveUp
    }

    private struct Job {
        var skill: PilotSkill
        var kind: Kind
        var index: Int
    }

    private func build() {
        lock.lock()
        defer { lock.unlock() }
        if built { return }
        let n: Int = SnapBalanceHarness.seedCount
        var jobs: [Job] = []
        for s in PilotSkill.allCases {
            var i: Int = 0
            while i < n {
                jobs.append(Job(skill: s, kind: .plain, index: i))
                i += 1
            }
        }
        for s in SnapBalanceMemo.sproutSkills {
            var i: Int = 0
            while i < n {
                jobs.append(Job(skill: s, kind: .sprout(1), index: i))
                i += 1
            }
        }
        for run in SnapBalanceMemo.taperRunNumbers {
            var i: Int = 0
            while i < n {
                jobs.append(Job(skill: .novice, kind: .sprout(run), index: i))
                i += 1
            }
        }
        if SnapBalanceMemo.reportsNoGiveUp {
            for s in SnapBalanceMemo.giveUpSkills {
                var i: Int = 0
                while i < n {
                    jobs.append(Job(skill: s, kind: .noGiveUp, index: i))
                    i += 1
                }
            }
        }
        let box = SnapBalanceBox()
        let list: [Job] = jobs
        DispatchQueue.concurrentPerform(iterations: list.count) { (k: Int) in
            let j: Job = list[k]
            var options: SessionOptions = SessionOptions.for(.feed)
            var givesUp: Bool = true
            switch j.kind {
            case .plain: break
            case .sprout(let run): options = SnapBalanceHarness.sproutRun(run)
            case .noGiveUp: givesUp = false
            }
            let r: SnapBalanceRun = SnapBalanceHarness.runOne(j.skill, seed: SnapBalanceHarness.seed(j.index),
                                                              options: options, givesUp: givesUp)
            box.put(k, r)
        }
        let done: [Int: SnapBalanceRun] = box.all()
        var plain: [PilotSkill: [SnapBalanceRun]] = [:]
        var first: [PilotSkill: [SnapBalanceRun]] = [:]
        var later: [Int: [SnapBalanceRun]] = [:]
        var stubborn: [PilotSkill: [SnapBalanceRun]] = [:]
        var k: Int = 0
        while k < list.count {
            let j: Job = list[k]
            if let r = done[k] {
                switch j.kind {
                case .plain:
                    plain[j.skill, default: []].append(r)
                case .sprout(let run):
                    if run == 1 {
                        first[j.skill, default: []].append(r)
                    } else {
                        later[run, default: []].append(r)
                    }
                case .noGiveUp:
                    stubborn[j.skill, default: []].append(r)
                }
            }
            k += 1
        }
        results = plain
        sprout = first
        taper = later
        stubbornRuns = stubborn
        built = true
        // One write, so the table is one block in the log (unbuffered: it survives a later crash of the runner).
        var lines: [String] = []
        lines.append("SNAP-BAL ==== table (\(n) seeds per skill, 60 Hz, 600 s cap; tools/balance-sim.js predicts it) ====")
        for s in PilotSkill.allCases {
            lines.append(SnapBalanceHarness.report(s, plain[s] ?? []))
        }
        for s in SnapBalanceMemo.sproutSkills {
            lines.append("SNAP-BAL sprout1 " + SnapBalanceHarness.report(s, first[s] ?? [], prefix: ""))
        }
        // R5 (REVIEW-4 #8): the novice's Sprout runs 2 and 3 (the taper).
        for run in SnapBalanceMemo.taperRunNumbers {
            lines.append("SNAP-BAL sprout" + String(run) + " "
                         + SnapBalanceHarness.report(.novice, later[run] ?? [], prefix: ""))
        }
        // R5 (REVIEW-4 P2): pilotGiveUp is the player model, not the game: the same expert and perfect runs without it.
        if SnapBalanceMemo.reportsNoGiveUp {
            for s in SnapBalanceMemo.giveUpSkills {
                let withWilts: [Double] = (plain[s] ?? []).map { (r: SnapBalanceRun) -> Double in Double(r.wilts) }
                let withCapped: Int = (plain[s] ?? []).filter { (r: SnapBalanceRun) -> Bool in r.capped }.count
                let note: String = String(format: " (with pilotGiveUp: wilts=%.1f capped=%d)",
                                          SnapBalanceHarness.percentile(withWilts, 0.5), withCapped)
                lines.append("SNAP-BAL nogiveup " + SnapBalanceHarness.report(s, stubborn[s] ?? [], prefix: "") + note)
            }
        } else {
            lines.append("SNAP-BAL nogiveup skipped (SNAP_BAL_NOGIVEUP=0)")
        }
        lines.append("SNAP-BAL ==== end ====")
        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }
}

enum SnapBalanceHarness {
    static let frameDt: Double = 1.0 / 60.0
    static let capSeconds: Double = 600

    static var seedCount: Int {
        if let raw = ProcessInfo.processInfo.environment["SNAP_BAL_SEEDS"], let n = Int(raw), n > 0 { return n }
        return 16
    }

    /// The same seeds as tools/balance-sim.js.
    static func seed(_ i: Int) -> UInt64 {
        return UInt64(1000 + i * 7919)
    }

    /// R4: what the App passes for a Sprout's first Feed run: `startSnaps` 12 (every Sprout Feed run) and
    /// `firstRun`, which overrides it (14 snaps, no wilting, the first stinger bite free, a calm first morning).
    static var sproutRunOne: SessionOptions {
        return sproutRun(1)
    }

    /// R5 (REVIEW-4 #8): Sprout Feed run `run` as the App builds it: SessionOptions.sprout(feedRun:) plus the Sprout
    /// rank's `startSnaps` 12 (the taper's own snaps override it).
    static func sproutRun(_ run: Int) -> SessionOptions {
        var o: SessionOptions = SessionOptions.sprout(feedRun: run)
        o.startSnaps = 12
        return o
    }

    /// R5: `givesUp` false runs the pilot without Tuning.pilotGiveUp (TrapPilot.givesUp).
    static func runOne(_ skill: PilotSkill, seed: UInt64,
                       options: SessionOptions = SessionOptions.for(.feed), givesUp: Bool = true) -> SnapBalanceRun {
        let geometry = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let session = TrapSession(mode: .feed, seed: seed, best: 0, geometry: geometry, options: options)
        var pilot = TrapPilot(skill: skill, seed: seed &* 7 &+ 1)
        pilot.givesUp = givesUp
        var t: Double = 0
        var frames: Int = 0
        var wilts: Int = 0
        let maxFrames: Int = Int(capSeconds / frameDt)
        while !session.isFinished && frames < maxFrames {
            let out: PilotOutput = pilot.step(dt: frameDt, time: t, snapshot: session.snapshot)
            for e in session.step(dt: frameDt, input: out.input) {
                if case .wilted = e { wilts += 1 }
            }
            t += frameDt
            frames += 1
        }
        let capped: Bool = session.result == nil
        let r: RunResult = session.partialResult()
        return SnapBalanceRun(score: r.score, seconds: r.seconds, snaps: r.snaps, caught: r.bugsCaught,
                              stings: r.stings, feasts: r.feasts, waves: r.waves, longestChain: r.longestChain,
                              beesSpared: r.beesSpared, wilts: wilts, capped: capped)
    }

    /// R6: what a Zen Bog run did in `seconds` (SessionOptions.for(.zen), 60 Hz).
    struct ZenRun {
        var finished: Bool
        var tired: Bool
        var snapsChanged: Int
        var wilts: Int
        var caught: Int
        var caughtLate: Int
        var stings: Int
        var longestChain: Int
        var morningsAfterNight: Int
    }

    /// R6: a Zen Bog run of `seconds`; `caughtLate` counts the catches in the last `lateSeconds`.
    static func runZen(_ skill: PilotSkill, seed: UInt64, seconds: Double, lateSeconds: Double) -> ZenRun {
        let geometry = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let session = TrapSession(mode: .zen, seed: seed, best: 1, geometry: geometry,
                                  options: SessionOptions.for(.zen))
        var pilot = TrapPilot(skill: skill, seed: seed &* 7 &+ 1)
        let start: Int = session.snapshot.snapsLeft
        var t: Double = 0
        var frames: Int = 0
        var tired: Bool = false
        var changed: Int = 0
        var wilts: Int = 0
        var caught: Int = 0
        var late: Int = 0
        var mornings: Int = 0
        var lastPhase: DayPhase = .morning
        let maxFrames: Int = Int((seconds / frameDt).rounded())
        let lateFrom: Int = maxFrames - Int((lateSeconds / frameDt).rounded())
        while !session.isFinished && frames < maxFrames {
            let out: PilotOutput = pilot.step(dt: frameDt, time: t, snapshot: session.snapshot)
            for e in session.step(dt: frameDt, input: out.input) {
                switch e {
                case .tired: tired = true
                case .wilted: wilts += 1
                case .bugCaught:
                    caught += 1
                    if frames >= lateFrom { late += 1 }
                case .dayPhaseChanged(let ph):
                    if ph == .morning && lastPhase == .night { mornings += 1 }
                    lastPhase = ph
                default: break
                }
            }
            if session.snapshot.snapsLeft != start { changed += 1 }
            t += frameDt
            frames += 1
        }
        let r: RunResult = session.partialResult()
        return ZenRun(finished: session.isFinished, tired: tired, snapsChanged: changed, wilts: wilts, caught: caught,
                      caughtLate: late, stings: r.stings, longestChain: r.longestChain, morningsAfterNight: mornings)
    }

    static func percentile(_ values: [Double], _ p: Double) -> Double {
        if values.isEmpty { return 0 }
        let sorted: [Double] = values.sorted()
        let pos: Double = Double(sorted.count - 1) * p
        let lo: Int = Int(pos.rounded(.down))
        let hi: Int = min(sorted.count - 1, lo + 1)
        let f: Double = pos - Double(lo)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * f
    }

    static func median(_ runs: [SnapBalanceRun], _ value: (SnapBalanceRun) -> Double) -> Double {
        return percentile(runs.map(value), 0.5)
    }

    static func medianScore(_ skill: PilotSkill) -> Double {
        return median(SnapBalanceMemo.shared.runs(skill)) { (r: SnapBalanceRun) -> Double in Double(r.score) }
    }

    static func report(_ skill: PilotSkill, _ runs: [SnapBalanceRun], prefix: String = "SNAP-BAL ") -> String {
        let score: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.score) }
        let secs: [Double] = runs.map { (r: SnapBalanceRun) -> Double in r.seconds }
        let snaps: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.snaps) }
        let caught: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.caught) }
        let stings: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.stings) }
        let feasts: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.feasts) }
        let waves: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.waves) }
        let chains: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.longestChain) }
        let spared: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.beesSpared) }
        let wilts: [Double] = runs.map { (r: SnapBalanceRun) -> Double in Double(r.wilts) }
        let maxStings: Int = runs.map { (r: SnapBalanceRun) -> Int in r.stings }.max() ?? 0
        let capped: Int = runs.filter { (r: SnapBalanceRun) -> Bool in r.capped }.count
        let head: String = String(format: "skill=%@ score=%.0f p10=%.0f p90=%.0f seconds=%.1f p10s=%.1f snaps=%.1f",
                                  skill.rawValue, percentile(score, 0.5), percentile(score, 0.1),
                                  percentile(score, 0.9), percentile(secs, 0.5), percentile(secs, 0.1),
                                  percentile(snaps, 0.5))
        let tail: String = String(format: " caught=%.1f stings=%.1f maxStings=%d feasts=%.1f waves=%.1f chain=%.1f spared=%.1f wilts=%.1f capped=%d n=%d",
                                  percentile(caught, 0.5), percentile(stings, 0.5), maxStings,
                                  percentile(feasts, 0.5), percentile(waves, 0.5), percentile(chains, 0.5),
                                  percentile(spared, 0.5), percentile(wilts, 0.5), capped, runs.count)
        return prefix + head + tail
    }
}

struct BalanceTests {

    @Test(arguments: PilotSkill.allCases)
    func skillReport(skill: PilotSkill) {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(skill)
        let line: String = SnapBalanceHarness.report(skill, runs)
        #expect(runs.count == SnapBalanceHarness.seedCount)
        // R2/R3: every run ends (R3: the late night outruns every hand), so no skill reaches the cap.
        let capped: Int = runs.filter { (r: SnapBalanceRun) -> Bool in r.capped }.count
        #expect(capped == 0, "\(line)")
    }

    @Test func casualRunLengthAndSnaps() {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.casual)
        let line: String = SnapBalanceHarness.report(.casual, runs)
        let seconds: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in r.seconds }
        let snaps: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.snaps) }
        #expect(seconds >= 100 && seconds <= 240, "casual seconds \(seconds): \(line)")
        #expect(snaps >= 18 && snaps <= 45, "casual snaps \(snaps): \(line)")
    }

    @Test func casualLongestChain() {
        // R2 chain rule: only bites of ≥ 2 add a step, so a casual run's longest chain is 3–6.
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.casual)
        let line: String = SnapBalanceHarness.report(.casual, runs)
        let chain: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.longestChain) }
        #expect(chain >= 3 && chain <= 6, "casual longest chain \(chain): \(line)")
    }

    @Test func casualRarelyWilts() {
        // R4 (QA-2 #1): the clock ticks only while food sits in the trap with no bee: a casual run wilts ≤ 2 times.
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.casual)
        let line: String = SnapBalanceHarness.report(.casual, runs)
        let wilts: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.wilts) }
        #expect(wilts <= 2, "casual wilts \(wilts): \(line)")
    }

    @Test func expertWiltsAtMostSixTimes() {
        // R4 (REVIEW-3 #12): the expert wilted 11.5 times per run in R3; real Duo hands are in this band.
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.expert)
        let line: String = SnapBalanceHarness.report(.expert, runs)
        let wilts: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.wilts) }
        #expect(wilts <= 6, "expert wilts \(wilts): \(line)")
    }

    @Test(arguments: SnapBalanceMemo.sproutSkills)
    func sproutRunOneLasts(skill: PilotSkill) {
        // R3/R4 (REVIEW-2 #9, REVIEW-3 #11): a first run (14 snaps, no wilting, the first sting free, a calm first
        // morning) lasts ≥ 90 s for the novice and the casual pilot. The novice's was 75 s in R3's CI log 20.
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.sproutRuns(skill)
        let line: String = "sprout1 " + SnapBalanceHarness.report(skill, runs)
        let seconds: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in r.seconds }
        let wilts: Int = runs.map { (r: SnapBalanceRun) -> Int in r.wilts }.max() ?? 0
        let capped: Int = runs.filter { (r: SnapBalanceRun) -> Bool in r.capped }.count
        #expect(runs.count == SnapBalanceHarness.seedCount)
        #expect(seconds >= 90, "Sprout run 1 seconds \(seconds): \(line)")
        #expect(wilts == 0, "Sprout run 1 never wilts: \(line)")
        #expect(capped == 0, "\(line)")
    }

    /// R5 (REVIEW-4 #8, founder call): the taper keeps a weak hand's second and third Feed runs long: the novice
    /// pilot's Sprout run 2 (13 snaps, a free sting, the calm morning) lasts ≥ 75 s and run 3 (12 snaps, the calm
    /// morning) ≥ 60 s (median). Neither reaches the cap.
    @Test(arguments: SnapBalanceMemo.taperRunNumbers)
    func sproutTaperRunLasts(run: Int) {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.taperRunResults(run)
        let line: String = "sprout" + String(run) + " " + SnapBalanceHarness.report(.novice, runs)
        let seconds: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in r.seconds }
        let target: Double = run == 2 ? 75 : 60
        let capped: Int = runs.filter { (r: SnapBalanceRun) -> Bool in r.capped }.count
        #expect(runs.count == SnapBalanceHarness.seedCount)
        #expect(seconds >= target, "Sprout run \(run) seconds \(seconds), target \(target): \(line)")
        #expect(capped == 0, "\(line)")
    }

    /// R6 (#19, REVIEW-5 P2-5): an expert run lasts at most about 6 minutes (median). R7 (SCORE-R6 #14): with the
    /// night pool led by fireflies and crickets and the late decays 0.955 / 0.91, nine expert runs in ten do too
    /// (p90; the sim: 332 s on 16 seeds, 330 s on 8).
    @Test func expertRunLength() {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.expert)
        let line: String = SnapBalanceHarness.report(.expert, runs)
        let seconds: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in r.seconds }
        let secs: [Double] = runs.map { (r: SnapBalanceRun) -> Double in r.seconds }
        let p90: Double = SnapBalanceHarness.percentile(secs, 0.9)
        #expect(seconds <= 360, "expert seconds \(seconds): \(line)")
        #expect(p90 <= 360, "expert p90 seconds \(p90): \(line)")
    }

    /// R7 (#3): with the ×2 FEAST scores rise about 1.6× (the sim: casual ~7,800, expert ~40,000); "Well Fed"
    /// (Tuning.wellFedScore, R6's 10,000) still sits above the casual median and at or below the expert's, as
    /// docs/appstore/achievements.md asks.
    @Test func wellFedSitsBetweenCasualAndExpert() {
        let casual: Double = SnapBalanceHarness.medianScore(.casual)
        let expert: Double = SnapBalanceHarness.medianScore(.expert)
        let bar: Double = Double(Tuning.wellFedScore)
        #expect(casual < bar && bar <= expert, "casual \(casual) < \(bar) <= expert \(expert)")
    }

    /// R6 (#19): the last light ends even a hand that never gives up waiting (R5: 14 of 16 such runs hit the cap).
    @Test(arguments: SnapBalanceMemo.giveUpSkills)
    func patientRunsEnd(skill: PilotSkill) {
        if !SnapBalanceMemo.reportsNoGiveUp { return }
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.noGiveUpRuns(skill)
        let line: String = "nogiveup " + SnapBalanceHarness.report(skill, runs)
        let capped: Int = runs.filter { (r: SnapBalanceRun) -> Bool in r.capped }.count
        #expect(runs.count == SnapBalanceHarness.seedCount)
        #expect(capped == 0, "\(line)")
    }

    /// R6: the Zen Bog never ends, never wilts and never changes its snaps; its day loops, so after 10 minutes the
    /// pilot still catches (the sim: ≥ 50 in the last 2 minutes for casual, ≥ 89 for perfect; asserted ≥ 10).
    @Test(arguments: [PilotSkill.casual, PilotSkill.perfect])
    func zenBogNeverEnds(skill: PilotSkill) {
        var i: Int = 0
        while i < 2 {
            let z = SnapBalanceHarness.runZen(skill, seed: SnapBalanceHarness.seed(i), seconds: 600, lateSeconds: 120)
            let line: String = "SNAP-BAL zen \(skill.rawValue) seed=\(SnapBalanceHarness.seed(i)) caught=\(z.caught) late=\(z.caughtLate) stings=\(z.stings) chain=\(z.longestChain) loops=\(z.morningsAfterNight)"
            print(line)
            #expect(!z.finished && !z.tired, "\(line)")
            #expect(z.snapsChanged == 0 && z.wilts == 0, "\(line)")
            #expect(z.caughtLate >= 10, "\(line)")
            #expect(z.morningsAfterNight >= 1, "\(line)")
            i += 1
        }
    }

    @Test func perfectRunLength() {
        // R3/R4: a perfect player's run ends at 4–8 minutes (median), and hunger is not what ends it (≤ 5 wilts).
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.perfect)
        let line: String = SnapBalanceHarness.report(.perfect, runs)
        let seconds: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in r.seconds }
        let wilts: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.wilts) }
        #expect(seconds >= 240 && seconds <= 480, "perfect seconds \(seconds): \(line)")
        #expect(wilts <= 5, "perfect wilts \(wilts): \(line)")
    }

    @Test func perfectIsNeverStung() {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.perfect)
        let maxStings: Int = runs.map { (r: SnapBalanceRun) -> Int in r.stings }.max() ?? 0
        #expect(maxStings == 0, "\(SnapBalanceHarness.report(.perfect, runs))")
    }

    /// The novice is stung in at least half its runs (CI 40622079094: the 8-seed median was 0.5; the R3 night ends
    /// novice runs before many bees arrive).
    @Test func noviceGetsStung() {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.novice)
        let stings: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.stings) }
        #expect(stings >= 0.5, "novice stings median \(stings): \(SnapBalanceHarness.report(.novice, runs))")
    }

    @Test func skillOrdersTheScore() {
        let novice: Double = SnapBalanceHarness.medianScore(.novice)
        let casual: Double = SnapBalanceHarness.medianScore(.casual)
        let expert: Double = SnapBalanceHarness.medianScore(.expert)
        let perfect: Double = SnapBalanceHarness.medianScore(.perfect)
        let line: String = "novice \(novice) casual \(casual) expert \(expert) perfect \(perfect)"
        #expect(novice < casual, "\(line)")
        #expect(casual < expert, "\(line)")
        #expect(expert <= perfect, "\(line)")
    }
}
