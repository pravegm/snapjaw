import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Headless balance playtest (Round 2)
//
// Every PilotSkill plays real TrapSessions (mode .feed, SNAP_BAL_SEEDS seeds, default 16) at 60 Hz, the pilot fed the
// previous frame's snapshot the way GameController feeds it. Each run is capped at 10 min. Prints, per skill:
//   SNAP-BAL skill=casual score=5542 p10=… p90=… seconds=138.3 snaps=22.5 caught=66.5 stings=3.0 maxStings=6 …
// tools/balance-sim.js (a line-by-line port) predicts on these 16 seeds (design/notes/core-R2.md):
//   novice  255 protein    /  41 s / 10 snaps   / 1.5 stings (median)
//   casual  5,542          / 138 s / 22.5 snaps / 3 stings / longest chain 4.5
//   expert  24,340         / 255 s / 29 snaps   / 0 stings
//   perfect 35,608         / 292 s / 25 snaps   / never stung
// R2 targets (asserted on medians): perfect runs 4–7 min (240–420 s); casual runs 100–240 s and 18–45 snaps, with a
// longest chain of 3–6; plus R1's: novice < casual < expert ≤ perfect, perfect never stung, novice stung ≥ 1. With
// hunger (a snap wilts after 15/14/12/10 s without a catch) every run ends, so no skill may hit the 10-minute cap.
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
    var capped: Bool
}

final class SnapBalanceMemo: @unchecked Sendable {
    static let shared = SnapBalanceMemo()

    private let locks: [PilotSkill: NSLock]
    private let dataLock = NSLock()
    private var results: [PilotSkill: [SnapBalanceRun]] = [:]

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

    static func runOne(_ skill: PilotSkill, seed: UInt64) -> SnapBalanceRun {
        let geometry = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let session = TrapSession(mode: .feed, seed: seed, best: 0, geometry: geometry,
                                  options: SessionOptions.for(.feed))
        var pilot = TrapPilot(skill: skill, seed: seed &* 7 &+ 1)
        var t: Double = 0
        var frames: Int = 0
        let maxFrames: Int = Int(capSeconds / frameDt)
        while !session.isFinished && frames < maxFrames {
            let out: PilotOutput = pilot.step(dt: frameDt, time: t, snapshot: session.snapshot)
            _ = session.step(dt: frameDt, input: out.input)
            t += frameDt
            frames += 1
        }
        let capped: Bool = session.result == nil
        let r: RunResult = session.partialResult()
        return SnapBalanceRun(score: r.score, seconds: r.seconds, snaps: r.snaps, caught: r.bugsCaught,
                              stings: r.stings, feasts: r.feasts, waves: r.waves, longestChain: r.longestChain,
                              beesSpared: r.beesSpared, capped: capped)
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
        let maxStings: Int = runs.map { (r: SnapBalanceRun) -> Int in r.stings }.max() ?? 0
        let capped: Int = runs.filter { (r: SnapBalanceRun) -> Bool in r.capped }.count
        let head: String = String(format: "SNAP-BAL skill=%@ score=%.0f p10=%.0f p90=%.0f seconds=%.1f snaps=%.1f",
                                  skill.rawValue, percentile(score, 0.5), percentile(score, 0.1),
                                  percentile(score, 0.9), percentile(secs, 0.5), percentile(snaps, 0.5))
        let tail: String = String(format: " caught=%.1f stings=%.1f maxStings=%d feasts=%.1f waves=%.1f chain=%.1f spared=%.1f capped=%d n=%d",
                                  percentile(caught, 0.5), percentile(stings, 0.5), maxStings,
                                  percentile(feasts, 0.5), percentile(waves, 0.5), percentile(chains, 0.5),
                                  percentile(spared, 0.5), capped, runs.count)
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
        // R2: hunger ends every run, so no skill reaches the cap.
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

    @Test func perfectRunLength() {
        // R2 hunger: a perfect player's run ends at 4–7 minutes (median).
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.perfect)
        let line: String = SnapBalanceHarness.report(.perfect, runs)
        let seconds: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in r.seconds }
        #expect(seconds >= 240 && seconds <= 420, "perfect seconds \(seconds): \(line)")
    }

    @Test func perfectIsNeverStung() {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.perfect)
        let maxStings: Int = runs.map { (r: SnapBalanceRun) -> Int in r.stings }.max() ?? 0
        #expect(maxStings == 0, "\(SnapBalanceHarness.report(.perfect, runs))")
    }

    @Test func noviceGetsStung() {
        let runs: [SnapBalanceRun] = SnapBalanceMemo.shared.runs(.novice)
        let stings: Double = SnapBalanceHarness.median(runs) { (r: SnapBalanceRun) -> Double in Double(r.stings) }
        #expect(stings >= 1, "novice stings median \(stings): \(SnapBalanceHarness.report(.novice, runs))")
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
