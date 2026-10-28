import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Headless balance playtest (Round 4)
//
// Every PilotSkill plays real TrapSessions (mode .feed, SNAP_BAL_SEEDS seeds, default 16; CI sets 8) at 60 Hz, the
// pilot fed the previous frame's snapshot the way GameController feeds it. Each run is capped at 10 min. R4: every
// run (the four skills plus the novice and casual pilots' Sprout run 1) is simulated once, in parallel, the first time
// any balance test asks, and the whole table is printed then as ONE block between "SNAP-BAL ==== table" and
// "SNAP-BAL ==== end", so it sits at the start of the balance section of the CI log:
//   SNAP-BAL skill=casual score=5206 p10=… p90=… seconds=147.4 snaps=24.5 caught=70.5 stings=2.5 maxStings=6 …
// tools/balance-sim.js (a line-by-line port) predicts on these 16 seeds (design/notes/core-R4.md):
//   novice  191 protein    /  45 s / 10 snaps   / 1 sting (median) / 0 wilts
//   casual  5,206          / 147 s / 24.5 snaps / 2.5 stings / longest chain 5 / 0 wilts
//   expert  28,763         / 326 s / 43 snaps   / 0 stings / 3 wilts
//   perfect 42,761         / 377 s / 43 snaps   / never stung / 3 wilts
//   Sprout run 1 (SessionOptions.firstRun: 14 snaps, no wilting, the first sting free, a calm first morning):
//   novice 105 s, casual 165 s
// (8 seeds: casual 128 s, chain 5, 0 wilts; expert 3 wilts; perfect 366 s, 2 wilts; novice Sprout run 1 101 s.)
// R4 targets (asserted on medians): perfect runs 4–8 min (240–480 s) with ≤ 5 wilts; expert ≤ 6 wilts; casual runs
// 100–240 s and 18–45 snaps, with a longest chain of 3–6 and ≤ 2 wilts; the novice and casual pilots' Sprout run 1
// lasts ≥ 90 s and never wilts; plus R1's: novice < casual < expert ≤ perfect, perfect never stung, novice stung (R3:
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

    /// The skills whose Sprout run 1 is simulated too.
    static let sproutSkills: [PilotSkill] = [.novice, .casual]

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

    private struct Job {
        var skill: PilotSkill
        var sprout: Bool
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
                jobs.append(Job(skill: s, sprout: false, index: i))
                i += 1
            }
        }
        for s in SnapBalanceMemo.sproutSkills {
            var i: Int = 0
            while i < n {
                jobs.append(Job(skill: s, sprout: true, index: i))
                i += 1
            }
        }
        let box = SnapBalanceBox()
        let list: [Job] = jobs
        DispatchQueue.concurrentPerform(iterations: list.count) { (k: Int) in
            let j: Job = list[k]
            let options: SessionOptions = j.sprout ? SnapBalanceHarness.sproutRunOne : SessionOptions.for(.feed)
            let r: SnapBalanceRun = SnapBalanceHarness.runOne(j.skill, seed: SnapBalanceHarness.seed(j.index),
                                                              options: options)
            box.put(k, r)
        }
        let done: [Int: SnapBalanceRun] = box.all()
        var plain: [PilotSkill: [SnapBalanceRun]] = [:]
        var first: [PilotSkill: [SnapBalanceRun]] = [:]
        var k: Int = 0
        while k < list.count {
            let j: Job = list[k]
            if let r = done[k] {
                if j.sprout {
                    first[j.skill, default: []].append(r)
                } else {
                    plain[j.skill, default: []].append(r)
                }
            }
            k += 1
        }
        results = plain
        sprout = first
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
        var o: SessionOptions = SessionOptions.for(.feed)
        o.startSnaps = 12
        o.firstRun = true
        return o
    }

    static func runOne(_ skill: PilotSkill, seed: UInt64,
                       options: SessionOptions = SessionOptions.for(.feed)) -> SnapBalanceRun {
        let geometry = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let session = TrapSession(mode: .feed, seed: seed, best: 0, geometry: geometry, options: options)
        var pilot = TrapPilot(skill: skill, seed: seed &* 7 &+ 1)
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
