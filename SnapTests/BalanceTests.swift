import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Headless balance playtest (Round 3)
//
// Every PilotSkill plays real TrapSessions (mode .feed, SNAP_BAL_SEEDS seeds, default 16) at 60 Hz, the pilot fed the
// previous frame's snapshot the way GameController feeds it. Each run is capped at 10 min. Prints, per skill:
//   SNAP-BAL skill=casual score=4833 p10=… p90=… seconds=134.0 snaps=23.5 caught=62.0 stings=2.0 maxStings=6 …
// tools/balance-sim.js (a line-by-line port) predicts on these 16 seeds (design/notes/core-R3.md):
//   novice  166 protein    /  44 s / 10 snaps   / 1 sting (median) / 0 wilts
//   casual  4,833          / 134 s / 23.5 snaps / 2 stings / longest chain 5 / 1.5 wilts
//   expert  28,763         / 329 s / 34 snaps   / 0 stings / 11.5 wilts
//   perfect 43,378         / 353 s / 43 snaps   / never stung / 5 wilts
//   casual, Sprout run 1 (12 snaps, no wilting, the first sting free): 154 s
// R3 targets (asserted on medians): perfect runs 4–8 min (240–480 s) with ≤ 6 wilts; casual runs 100–240 s and 18–45
// snaps, with a longest chain of 3–6 and ≤ 2 wilts; the casual pilot's Sprout run 1 lasts ≥ 90 s; plus R1's: novice <
// casual < expert ≤ perfect, perfect never stung, novice stung ≥ 1. The late night (reactions × 0.96 per wave to 0.25,
// lingers × 0.92 to 0.2) ends every run, so no skill may hit the 10-minute cap.
// Each skill is simulated once (memoised), so the tests share the runs.

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

final class SnapBalanceMemo: @unchecked Sendable {
    static let shared = SnapBalanceMemo()

    private let locks: [PilotSkill: NSLock]
    private let dataLock = NSLock()
    private var results: [PilotSkill: [SnapBalanceRun]] = [:]
    private let sproutLock = NSLock()
    private var sprout: [SnapBalanceRun]? = nil

    init() {
        var l: [PilotSkill: NSLock] = [:]
        for s in PilotSkill.allCases { l[s] = NSLock() }
        locks = l
    }

    func runs(_ skill: PilotSkill) -> [SnapBalanceRun] {
        let lock: NSLock = locks[skill] ?? NSLock()
        lock.lock()
        defer { lock.unlock() }
        dataLock.lock()
        let cached: [SnapBalanceRun]? = results[skill]
        dataLock.unlock()
        if let c = cached { return c }
        let computed: [SnapBalanceRun] = SnapBalanceHarness.simulate(skill)
        dataLock.lock()
        results[skill] = computed
        dataLock.unlock()
        return computed
    }

    /// R3: the casual pilot's Sprout run 1 on every seed (SnapBalanceHarness.sproutRunOne).
    func sproutRuns() -> [SnapBalanceRun] {
        sproutLock.lock()
        defer { sproutLock.unlock() }
        if let c = sprout { return c }
        var out: [SnapBalanceRun] = []
        var i: Int = 0
        while i < SnapBalanceHarness.seedCount {
            out.append(SnapBalanceHarness.runOne(.casual, seed: SnapBalanceHarness.seed(i),
                                                 options: SnapBalanceHarness.sproutRunOne))
            i += 1
        }
        sprout = out
        return out
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

    /// R3: what the App passes for a Sprout's first run (12 snaps, no wilting, the first stinger bite free).
    static var sproutRunOne: SessionOptions {
        var o: SessionOptions = SessionOptions.for(.feed)
        o.startSnaps = 12
        o.hunger = false
        o.freeFirstSting = true
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

    static func simulate(_ skill: PilotSkill) -> [SnapBalanceRun] {
        var out: [SnapBalanceRun] = []
        var i: Int = 0
        while i < seedCount {
            out.append(runOne(skill, seed: seed(i)))
            i += 1
        }
        return out
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

    static func report(_ skill: PilotSkill, _ runs: [SnapBalanceRun]) -> String {
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
        let head: String = String(format: "SNAP-BAL skill=%@ score=%.0f p10=%.0f p90=%.0f seconds=%.1f snaps=%.1f",
                                  skill.rawValue, percentile(score, 0.5), percentile(score, 0.1),
                                  percentile(score, 0.9), percentile(secs, 0.5), percentile(snaps, 0.5))
        let tail: String = String(format: " caught=%.1f stings=%.1f maxStings=%d feasts=%.1f waves=%.1f chain=%.1f spared=%.1f wilts=%.1f capped=%d n=%d",
                                  percentile(caught, 0.5), percentile(stings, 0.5), maxStings,
                                  percentile(feasts, 0.5), percentile(waves, 0.5), percentile(chains, 0.5),
                                  percentile(spared, 0.5), percentile(wilts, 0.5), capped, runs.count)
        return head + tail
    }
}

struct BalanceTests {

    @Test(arguments: PilotSkill.allCases)
    func skillReport(skill: PilotSkill) {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(skill)
        let line: String = SnapBalanceHarness.report(skill, runs)
        // Unbuffered, so the line survives even if a later test crashes the runner.
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
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
        // R3 (REVIEW-2 #7): wilt 18/16/14/12 s from the first landing after a catch: a casual run wilts ≤ 2 times.
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.casual)
        let line: String = SnapBalanceHarness.report(.casual, runs)
        let wilts: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.wilts) }
        #expect(wilts <= 2, "casual wilts \(wilts): \(line)")
    }

    @Test func casualSproutRunOneLasts() {
        // R3 (REVIEW-2 #9): a first run (12 snaps, no wilting, the first sting free) lasts ≥ 90 s for the casual pilot.
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.sproutRuns()
        let line: String = "sprout1 " + SnapBalanceHarness.report(.casual, runs)
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
        let seconds: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in r.seconds }
        let wilts: Int = runs.map { (r: SnapBalanceRun) -> Int in r.wilts }.max() ?? 0
        let capped: Int = runs.filter { (r: SnapBalanceRun) -> Bool in r.capped }.count
        #expect(runs.count == SnapBalanceHarness.seedCount)
        #expect(seconds >= 90, "Sprout run 1 seconds \(seconds): \(line)")
        #expect(wilts == 0, "Sprout run 1 never wilts: \(line)")
        #expect(capped == 0, "\(line)")
    }

    @Test func perfectRunLength() {
        // R3: a perfect player's run ends at 4–8 minutes (median), and hunger is not what ends it (≤ 6 wilts).
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.perfect)
        let line: String = SnapBalanceHarness.report(.perfect, runs)
        let seconds: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in r.seconds }
        let wilts: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.wilts) }
        #expect(seconds >= 240 && seconds <= 480, "perfect seconds \(seconds): \(line)")
        #expect(wilts <= 6, "perfect wilts \(wilts): \(line)")
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
        FileHandle.standardOutput.write(Data(("SNAP-BAL order " + line + "\n").utf8))
        #expect(novice < casual, "\(line)")
        #expect(casual < expert, "\(line)")
        #expect(expert <= perfect, "\(line)")
    }
}
