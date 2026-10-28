import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Input (R8, design/notes/core-R8.md): the hinge path end to end (HingeTrapSource → Core's SnapDetector), the
// filters and the touch fallback. Moved here from FeelTests.swift in R8; the R1–R7 partial-snap, creep-guard and
// closing-gate tests are gone with that behaviour.

/// A fake Duo hinge: the hand's angle as a function of time, reported like the real hinge (at `rate` Hz, phase-locked
/// to the start of each `run`, and only when it moved at least `step` degrees: nothing while still), with display
/// frames at 120 Hz asking for the trap.
@MainActor
private final class InputFakeHinge {
    let source: HingeTrapSource
    private(set) var time: Double = 100
    private var lastReported: Double?
    static let frame = 1.0 / 120
    static let step = 0.25
    /// Every frame's input and time from the last `run`.
    private(set) var inputs: [TrapInput] = []
    private(set) var times: [Double] = []
    /// Every report (time, raw angle) from the last `run`.
    private(set) var reports: [(time: Double, angle: Double)] = []

    init(source: HingeTrapSource) {
        self.source = source
        source.clock = { [weak self] in self?.time ?? 0 }
    }

    /// Runs for `duration` s; `angle` gives the hand's angle at local time 0…duration. `frames: false` asks no input
    /// (the game paused). Returns the last input.
    @discardableResult
    func run(_ duration: Double, rate: Double = 30, frames: Bool = true, status: TrapHingeStatus = .unknown,
             angle: (Double) -> Double) -> TrapInput {
        let start = time
        let steps = max(Int((duration / Self.frame).rounded()), 1)
        var nextReport = start + 1 / rate
        var last = TrapInput()
        inputs.removeAll()
        times.removeAll()
        reports.removeAll()
        for index in 1...steps {
            time = start + Double(index) * Self.frame
            if time >= nextReport - 1e-9 {
                let a = angle(time - start)
                var moved = true
                if let previous = lastReported { moved = abs(a - previous) >= Self.step }
                if moved {
                    source.ingest(angleDegrees: a, at: time, status: status)
                    lastReported = a
                    reports.append((time: time, angle: a))
                }
                nextReport += 1 / rate
            }
            if frames {
                last = source.input(at: time)
                inputs.append(last)
                times.append(time)
            }
        }
        return last
    }

    /// The frames (indices into `inputs`) that carried a bite.
    var snapFrames: [Int] {
        var found: [Int] = []
        for (index, input) in inputs.enumerated() where input.snap != nil { found.append(index) }
        return found
    }
}

@MainActor
struct InputTests {
    // MARK: - The hinge path

    @Test func aSlamBitesOnceOnTheShutReport() {
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 150 }
        #expect(hinge.source.hasHinge && hinge.source.armed)
        let quiet = hinge.inputs.allSatisfy { $0.snap == nil }
        #expect(quiet)
        // 150 → 5 in 0.3 s.
        hinge.run(1.0) { t in 150 - 145 * min(t / 0.3, 1) }
        let frames = hinge.snapFrames
        #expect(frames.count == 1)
        #expect(hinge.source.snapsFired == 1)
        guard let index = frames.first, let bite = hinge.inputs[index].snap else { return }
        #expect(bite.duration >= 0.2 && bite.duration <= 0.32, "duration \(bite.duration)")
        // It fires on the frame of the first report in the shut zone: no added lag.
        let shut = hinge.reports.first { $0.angle <= Tuning.shutAngle }
        let found = shut != nil
        #expect(found)
        if let shut { #expect(abs(hinge.times[index] - shut.time) < 1e-6) }
        #expect(hinge.inputs.last?.armed == false, "held shut: not armed")
        #expect(hinge.source.isShut)
        let deep = hinge.inputs.last?.closure ?? 0
        #expect(deep > 100, "the shut closure \(deep)")
    }

    @Test func aPartialCloseNeverBites() {
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 150 }
        hinge.run(0.5) { t in 150 - 90 * min(t / 0.4, 1) }
        hinge.run(1.0) { _ in 60 }
        let deepest = hinge.inputs.map { $0.closure }.max() ?? 0
        #expect(deepest >= 60, "the closure follows the phone: \(deepest)")
        hinge.run(0.8) { t in 60 + 90 * min(t / 0.6, 1) }
        #expect(hinge.source.snapsFired == 0)
        #expect(hinge.inputs.last?.armed == true)
        // The closed status at 40° is not a shut (hardware reads .closed from ~85°).
        hinge.run(0.5, status: .closed) { t in 150 - 110 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 0)
    }

    @Test func aSlowCloseIsASlowBiteAndSaysSo() {
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 150 }
        hinge.run(3.0) { t in 150 - 145 * min(t / 2.5, 1) }
        let slow = hinge.inputs.contains { $0.creeping }
        #expect(slow)
        #expect(hinge.snapFrames.count == 1)
        if let i = hinge.snapFrames.first, let d = hinge.inputs[i].snap?.duration { #expect(d >= 1.5, "\(d)") }
    }

    @Test func reopeningReArmsForTheNextBite() {
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 150 }
        hinge.run(0.6) { t in 150 - 145 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 1)
        #expect(hinge.source.armed == false)
        hinge.run(0.3) { t in 5 + 25 * min(t / 0.2, 1) }
        #expect(hinge.source.armed == false, "30° is not open yet")
        hinge.run(0.8) { t in 30 + 120 * min(t / 0.4, 1) }
        #expect(hinge.inputs.last?.armed == true)
        hinge.run(0.6) { t in 150 - 145 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 2)
        #expect(hinge.snapFrames.count == 1)
    }

    @Test func aRoundStartsClosed() {
        // Founder rule 3: startRound with the phone open: not armed until shut, then open.
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(0.5) { _ in 150 }
        hinge.source.startRound(at: hinge.time)
        hinge.run(0.5) { _ in 150 }
        #expect(hinge.inputs.last?.armed == false)
        #expect(hinge.source.waitingForShut)
        hinge.run(0.6) { t in 150 - 145 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 0, "the shut that starts a round is not a bite")
        hinge.run(0.6) { t in 5 + 85 * min(t / 0.4, 1) }
        #expect(hinge.inputs.last?.armed == true, "90° is open")
        // No hinge: a round never waits (the touch fallback is first-class).
        let none = HingeTrapSource()
        none.startRound(at: 1)
        #expect(none.input(at: 2).armed && !none.waitingForShut)
    }

    @Test func aBiteIsNeverLostOrDeliveredTwice() {
        let source = HingeTrapSource()
        source.clock = { 0 }
        source.ingest(angleDegrees: 150, at: 0)
        var frame = 0.0
        while frame < 0.5 {
            frame += 1.0 / 120
            _ = source.input(at: frame)
        }
        // Two reports land inside one frame: the bite must still reach that frame.
        source.ingest(angleDegrees: 100, at: frame + 0.01)
        _ = source.input(at: frame + 0.01)
        source.ingest(angleDegrees: 50, at: frame + 0.043)
        source.ingest(angleDegrees: 10, at: frame + 0.07)
        let bite = source.input(at: frame + 0.077)
        #expect(bite.snap != nil)
        let again = source.input(at: frame + 0.077)
        #expect(again.snap == nil)
        #expect(source.input(at: frame + 0.09).snap == nil)
        #expect(source.snapsFired == 1)
    }

    @Test func aBiteSurvivesAResetButNotANewRound() {
        // R8: the shut moves the app to the cover display, which can re-activate the scene (reset) before a frame.
        let a = InputFakeHinge(source: HingeTrapSource())
        a.run(1.0) { _ in 150 }
        a.run(0.4, frames: false) { t in 150 - 145 * min(t / 0.3, 1) }
        #expect(a.source.snapsFired == 1)
        a.source.reset(at: a.time)
        a.run(0.1) { _ in 5 }
        #expect(a.snapFrames.count == 1)
        let b = InputFakeHinge(source: HingeTrapSource())
        b.run(1.0) { _ in 150 }
        b.run(0.4, frames: false) { t in 150 - 145 * min(t / 0.3, 1) }
        b.source.startRound(at: b.time)
        b.run(0.1) { _ in 5 }
        #expect(b.snapFrames.isEmpty)
    }

    @Test func aBiteNobodyConsumedIsDroppedNotFiredOnTheNextRun() {
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 150 }
        // On Results nothing asks for the trap for 2 s; the player claps the Duo.
        hinge.run(2.0, frames: false) { t in 150 - 145 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 1)
        hinge.run(0.5) { _ in 5 }
        #expect(hinge.snapFrames.isEmpty)
        #expect(hinge.source.staleSnapsDropped == 1)
    }

    @Test func aWholeCloseInOneReportGetsASaneDuration() {
        let source = HingeTrapSource()
        source.clock = { 0 }
        source.ingest(angleDegrees: 150, at: 0)
        var frame = 0.0
        while frame < 1.0 {
            frame += 1.0 / 120
            _ = source.input(at: frame)
        }
        // The simulator's hinge CLI jumps 145° between two reports.
        source.ingest(angleDegrees: 5, at: frame + 0.004)
        let bite = source.input(at: frame + 0.005)
        #expect(bite.snap != nil)
        let duration = bite.snap?.duration ?? 0
        #expect(duration >= HingeTrapSource.minSnapDuration - 1e-12)
        #expect(duration.isFinite)
        let tiny = HingeTrapSource.sane(SnapTrigger(duration: 0.004, time: 1))
        #expect(abs(tiny.duration - HingeTrapSource.minSnapDuration) < 1e-12)
        let broken = HingeTrapSource.sane(SnapTrigger(duration: Double.nan, time: 1))
        #expect(broken.duration.isFinite)
        let real = HingeTrapSource.sane(SnapTrigger(duration: 0.25, time: 1))
        #expect(abs(real.duration - 0.25) < 1e-12)
    }

    @Test func flatAndJitterNeverBiteAndNothingIsTooFlat() {
        // Founder rule 2: no pose demands.
        let hinge = InputFakeHinge(source: HingeTrapSource())
        var dice = FeelDice(seed: 7)
        hinge.run(0.5) { _ in 178 }
        hinge.run(5.0) { _ in 178 + dice.range(-1.5, 1.5) }
        let calm = hinge.inputs.allSatisfy { $0.snap == nil && !$0.tooFlat && !$0.creeping }
        #expect(calm)
        let deepest = hinge.inputs.map { $0.closure }.max() ?? 99
        #expect(deepest < Tuning.closeStart)
        #expect(hinge.source.snapsFired == 0)
    }

    @Test func noHingeMeansAnOpenArmedTrap() {
        let source = HingeTrapSource()
        let input = source.input(at: 5)
        #expect(source.hasHinge == false)
        #expect(input.armed && input.snap == nil && input.angle == nil)
        #expect(abs(input.closure) < 1e-12)
        #expect(source.reference == nil && !source.isShut)
        source.ingest(angleDegrees: Double.nan, at: 6)
        source.ingest(angleDegrees: 150, at: Double.infinity)
        #expect(source.hasHinge == false)
        source.ingest(angleDegrees: 400, at: 7, status: .fullyOpen)
        #expect(source.hasHinge)
        #expect(source.lastRawAngle == 180)
        #expect(source.lastStatus == .fullyOpen)
        let flat = source.input(at: 7.1)
        #expect(flat.closure.isFinite && flat.angle != nil && flat.armed)
    }

    @Test func resetKeepsTheHingeAndNeverBitesOnItsOwn() {
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 150 }
        hinge.run(0.5) { t in 150 - 145 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 1)
        hinge.source.reset(at: hinge.time)
        #expect(hinge.source.hasHinge)
        hinge.run(1.0) { _ in 5 }
        #expect(hinge.snapFrames.isEmpty)
        #expect(hinge.source.snapsFired == 1)
        #expect(hinge.source.predictedAngle(at: hinge.time) != nil)
    }

    // MARK: - Filters

    @Test func theFilterPassesBigStepsAndSmoothsSmallOnes() {
        var filter = OneEuroSmoother(minCutoff: 1.2, beta: 0.5, dCutoff: 4, escape: 2)
        let first = filter.filter(160, at: 0)
        #expect(abs(first - 160) < 1e-12)
        let big = filter.filter(153, at: 1.0 / 30)
        #expect(abs(big - 153) < 1e-12)
        var slow = OneEuroSmoother(minCutoff: 1.2, beta: 0.5, dCutoff: 4, escape: 2)
        _ = slow.filter(160, at: 0)
        let small = slow.filter(159, at: 1.0 / 30)
        #expect(small < 160 && small > 159)
        slow.settle(158.5, at: 0.1)
        #expect(abs((slow.value ?? 0) - 158.5) < 1e-12)
        #expect(abs(slow.derivative) < 1e-12)
        var classic = OneEuroSmoother()
        _ = classic.filter(160, at: 0)
        let lagged = classic.filter(153, at: 1.0 / 30)
        #expect(lagged > 153.5)
        let nan = classic.filter(Double.nan, at: 0.1)
        #expect(nan.isFinite)
    }

    // MARK: - Touch: a tap is an instant bite

    @Test func aTapBitesAtOnceAndReArms() {
        let touch = TouchTrapSource()
        let t0 = 50.0
        let before = touch.input(at: t0 - 0.01)
        #expect(before.armed && before.snap == nil)
        #expect(abs(before.closure) < 1e-12)
        touch.tap(at: t0)
        let contact = touch.input(at: t0)
        #expect(contact.snap != nil)
        let duration = contact.snap?.duration ?? 0
        #expect(abs(duration - Tuning.touchSnapTime) < 1e-9)
        #expect(contact.armed == false && contact.creeping == false && contact.tooFlat == false)
        #expect(touch.input(at: t0 + 0.001).snap == nil)
        // The Scene's own shut animation: the drawn closure sweeps in and reopens.
        let mid = touch.input(at: t0 + Tuning.touchSnapTime * 0.5)
        #expect(mid.closure > 0 && mid.closure < Tuning.snapDepth)
        // A tap before the re-arm is ignored.
        touch.tap(at: t0 + 0.2)
        #expect(touch.bites == 1)
        let rearmed = touch.input(at: t0 + Tuning.touchRearmDelay + 0.001)
        #expect(rearmed.armed)
        touch.tap(at: t0 + 1)
        #expect(touch.bites == 2)
        #expect(touch.input(at: t0 + 1.004).snap != nil)
        touch.reset()
        let fresh = touch.input(at: t0 + 1.05)
        #expect(fresh.armed)
        #expect(abs(fresh.closure) < 1e-12)
    }

    @Test func aTapJustBeforeAPauseNeverBitesAfterIt() {
        let touch = TouchTrapSource()
        touch.tap(at: 10)
        let resumed = touch.input(at: 12)
        #expect(resumed.snap == nil && resumed.armed)
        #expect(touch.staleBites == 1)
        touch.tap(at: 12.1)
        #expect(touch.bites == 2)
        #expect(touch.input(at: 12.1 + 0.01).snap != nil)
    }

    @Test func theTouchJawCurveIsContinuous() {
        let close = Tuning.touchSnapTime
        let depth = Tuning.snapDepth
        #expect(abs(FeelTouchJaw.closure(elapsed: 0, close: close, reopen: FeelTouchJaw.reopen, depth: depth)) < 1e-12)
        let shut = FeelTouchJaw.closure(elapsed: close, close: close, reopen: FeelTouchJaw.reopen, depth: depth)
        #expect(abs(shut - depth) < 1e-9)
        let done = FeelTouchJaw.closure(elapsed: close + FeelTouchJaw.reopen, close: close,
                                        reopen: FeelTouchJaw.reopen, depth: depth)
        #expect(abs(done) < 1e-6)
        #expect(abs(FeelTouchJaw.closure(elapsed: Double.nan, close: close, reopen: 0.3, depth: depth)) < 1e-12)
        // The whole cycle fits inside the re-arm delay.
        #expect(close + FeelTouchJaw.reopen <= Tuning.touchRearmDelay + 1e-9)
    }
}

// MARK: - R9 (design/notes/core-R9.md): the hinge source on real hardware

@MainActor
struct InputR9Tests {

    @Test func aResetDuringTheStartingCloseNeverBites() {
        // Closing the phone to start moves the app to the outer display, which re-activates the scene: the App resets
        // the hinge mid-close. Before R9 the fresh detector was armed at once and the starting close bit.
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(0.5) { _ in 150 }
        hinge.source.startRound(at: hinge.time)
        hinge.run(0.2) { t in 150 - 90 * min(t / 0.2, 1) }
        hinge.source.reset(at: hinge.time)
        #expect(hinge.source.waitingForShut, "a reset keeps the round's closed start")
        hinge.run(0.4) { t in 60 - 55 * min(t / 0.15, 1) }
        #expect(hinge.source.snapsFired == 0, "the starting close is not a bite")
        hinge.run(0.6) { t in 5 + 145 * min(t / 0.4, 1) }
        #expect(hinge.inputs.last?.armed == true)
        hinge.run(0.6) { t in 150 - 145 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 1)
        // Going Home: no round, so the trap never waits.
        let home = InputFakeHinge(source: HingeTrapSource())
        home.run(0.5) { _ in 150 }
        home.source.startRound(at: home.time)
        home.source.reset(at: home.time, keepsRoundStart: false)
        home.run(0.3) { _ in 150 }
        #expect(!home.source.waitingForShut && home.inputs.last?.armed == true)
    }

    @Test func aResetWhileShutNeverReArmsEarly() {
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 150 }
        // A `.closed` bite at 24°, the phone hovering there; a reset (the outer display) at 36° on report noise.
        hinge.run(0.5, status: .closed) { t in 150 - 126 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 1)
        hinge.run(0.2, status: .closed) { _ in 36 }
        hinge.source.reset(at: hinge.time)
        hinge.run(0.3, status: .closed) { _ in 36 }
        #expect(hinge.inputs.last?.armed == false, "36° is not past the re-arm after a 24° shut")
        hinge.run(0.5, status: .closed) { t in 36 - 12 * min(t / 0.2, 1) }
        #expect(hinge.source.snapsFired == 1, "no second bite from the hover")
        hinge.run(0.6) { t in 24 + 126 * min(t / 0.4, 1) }
        #expect(hinge.inputs.last?.armed == true)
    }

    @Test func theOuterDisplayCountsAsFolded() {
        // The round's start: the outer display took over with no shut report (reports stopped at 60°).
        let start = InputFakeHinge(source: HingeTrapSource())
        start.run(0.5) { _ in 150 }
        start.source.startRound(at: start.time)
        start.run(0.3) { t in 150 - 90 * min(t / 0.2, 1) }
        start.source.noteFolded(at: start.time)
        #expect(!start.source.waitingForShut)
        #expect(start.source.snapsFired == 0)
        start.run(0.6) { t in 60 + 90 * min(t / 0.4, 1) }
        #expect(start.inputs.last?.armed == true, "opened: the round opens")
        // In play, folded at 22° (no `.closed` report): the bite, as the status would give it; at 50°: nothing.
        let low = InputFakeHinge(source: HingeTrapSource())
        low.run(1.0) { _ in 150 }
        low.run(0.4) { t in 150 - 128 * min(t / 0.3, 1) }
        #expect(low.source.snapsFired == 0)
        low.source.noteFolded(at: low.time)
        low.run(0.1) { _ in 22 }
        #expect(low.source.snapsFired == 1 && low.snapFrames.count == 1)
        let high = InputFakeHinge(source: HingeTrapSource())
        high.run(1.0) { _ in 150 }
        high.run(0.4) { t in 150 - 100 * min(t / 0.3, 1) }
        high.source.noteFolded(at: high.time)
        #expect(high.source.snapsFired == 0)
        // No hinge: nothing.
        let none = HingeTrapSource()
        none.noteFolded(at: 1)
        #expect(none.snapsFired == 0 && !none.hasHinge)
    }

    @Test func launchedShutOnTheOuterDisplayTheRoundStartsWhenItOpens() {
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(0.5, status: .closed) { _ in 0 }
        hinge.source.startRound(at: hinge.time)
        #expect(!hinge.source.waitingForShut, "already closed: the round only waits for the opening")
        hinge.run(0.6) { t in 145 * min(t / 0.4, 1) }
        #expect(hinge.inputs.last?.armed == true)
        #expect(hinge.source.snapsFired == 0)
        hinge.run(0.6) { t in 145 - 140 * min(t / 0.3, 1) }
        #expect(hinge.source.snapsFired == 1)
    }

    @Test func noisyReportsThroughTheFilterBiteOncePerClose() {
        // ±3° of report noise passes the 2° escape unfiltered: still one bite a slam, none for a deep partial close.
        var dice = FeelDice(seed: 9)
        let hinge = InputFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 150 + dice.range(-3, 3) }
        hinge.run(1.0) { t in 150 - 145 * min(t / 0.3, 1) + dice.range(-3, 3) }
        #expect(hinge.source.snapsFired == 1)
        hinge.run(1.0) { t in max(0, 5 + 145 * min(t / 0.4, 1) + dice.range(-3, 3)) }
        hinge.run(1.5) { t in 150 - 100 * min(t / 0.4, 1) + dice.range(-3, 3) }
        hinge.run(1.0) { t in 50 + 100 * min(t / 0.4, 1) + dice.range(-3, 3) }
        #expect(hinge.source.snapsFired == 1, "a partial close to 50° never bites")
        hinge.run(1.0) { t in 150 - 145 * min(t / 0.3, 1) + dice.range(-3, 3) }
        #expect(hinge.source.snapsFired == 2)
    }
}
