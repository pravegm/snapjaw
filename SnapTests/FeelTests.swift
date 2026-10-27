import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Helpers

/// A fake Duo hinge: the hand's angle as a function of time, reported like the real hinge (at `rate` Hz, phase-locked
/// to the start of each `run`, and only when it moved at least `step` degrees: nothing while still), with display
/// frames at 120 Hz asking for the trap.
@MainActor
private final class FeelFakeHinge {
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
    /// Every report ever (for "the newest report before t").
    private(set) var allReports: [(time: Double, angle: Double)] = []

    init(source: HingeTrapSource) {
        self.source = source
        source.clock = { [weak self] in self?.time ?? 0 }
    }

    /// Runs for `duration` s; `angle` gives the hand's angle at local time 0…duration. `frames: false` asks no input
    /// (the game paused). Returns the last input.
    @discardableResult
    func run(_ duration: Double, rate: Double = 30, frames: Bool = true,
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
                    source.ingest(angleDegrees: a, at: time)
                    lastReported = a
                    reports.append((time: time, angle: a))
                    allReports.append((time: time, angle: a))
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

    /// The frames (indices into `inputs`) that carried a snap.
    var snapFrames: [Int] {
        var found: [Int] = []
        for (index, input) in inputs.enumerated() where input.snap != nil { found.append(index) }
        return found
    }

    /// The newest raw report at or before `t`.
    func rawAngle(atOrBefore t: Double) -> Double? {
        var result: Double?
        for report in allReports where report.time <= t + 1e-9 { result = report.angle }
        return result
    }
}

/// Renders `seconds` of `synth` in stereo and reports the RMS (both channels), each channel's RMS, the peak, the share
/// of samples over 0.6 and whether every sample was finite. `each` runs before every 512-frame block.
private func feelRender(_ synth: FeelSynth, seconds: Double,
                        each: (Int, Double) -> Void = { _, _ in })
    -> (rms: Double, left: Double, right: Double, peak: Float, hot: Double, finite: Bool) {
    let frames = 512
    let left = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    let right = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer {
        left.deallocate()
        right.deallocate()
    }
    let blocks = max(Int(seconds * Double(synth.sampleRate) / Double(frames)), 1)
    var sumL: Double = 0
    var sumR: Double = 0
    var peak: Float = 0
    var hot = 0
    var finite = true
    for block in 0..<blocks {
        each(block, Double(block * frames) / Double(synth.sampleRate))
        synth.render(frames: frames, left: left, right: right)
        for index in 0..<frames {
            let l = left[index]
            let r = right[index]
            if !l.isFinite || !r.isFinite { finite = false }
            peak = max(peak, max(abs(l), abs(r)))
            sumL += Double(l * l)
            sumR += Double(r * r)
            if abs(l) > 0.6 || abs(r) > 0.6 { hot += 1 }
        }
    }
    let count = Double(blocks * frames)
    let rmsL = (sumL / count).squareRoot()
    let rmsR = (sumR / count).squareRoot()
    return (((sumL + sumR) / (2 * count)).squareRoot(), rmsL, rmsR, peak, Double(hot) / count, finite)
}

private func feelBite(caught: [BugSpecies], stingers: [BugSpecies] = []) -> BiteReport {
    BiteReport(caught: caught, escaped: 1, stingers: stingers, points: 120, countMultiplier: max(caught.count, 1),
               chainMultiplier: 1.5, snapsBack: caught.count >= 3 ? 1 : 0, snapsLost: stingers.isEmpty ? 0 : 1,
               duration: 0.1, time: 12)
}

private func feelBuzzers(_ count: Int, flying: Bool = true) -> [Buzzer] {
    var buzzers: [Buzzer] = []
    for index in 0..<count {
        let species = BugSpecies.allCases[index % BugSpecies.allCases.count]
        let pan = -1 + 2 * Double(index) / Double(max(count - 1, 1))
        buzzers.append(Buzzer(id: index + 1, species: species, pan: pan, height: 0.3, flying: flying))
    }
    return buzzers
}

/// Every trap event, at least once.
private let feelEveryEvent: [TrapEvent] = [
    .waveStarted(index: 3, phase: .noon), .dayPhaseChanged(.morning), .dayPhaseChanged(.noon),
    .dayPhaseChanged(.dusk), .dayPhaseChanged(.night),
    .bugArrived(id: 1, species: .housefly),
    .bugLanded(id: 1, species: .housefly, position: CGPoint(x: 300, y: 300), inTrap: true),
    .bugLanded(id: 2, species: .dragonfly, position: CGPoint(x: 900, y: 100), inTrap: false),
    .bugSipping(id: 1, species: .housefly), .bugHopped(id: 3, species: .grasshopper),
    .bugLeft(id: 4, species: .moth), .bugSpooked(id: 5, species: .bluebottle),
    .snapStarted, .snapped(feelBite(caught: [.housefly, .gnat, .ladybird], stingers: [.bee])),
    .bugCaught(id: 1, species: .housefly, position: CGPoint(x: 400, y: 330)),
    .bugCaught(id: 6, species: .gnat, position: CGPoint(x: 520, y: 300)),
    .bugCaught(id: 7, species: .ladybird, position: CGPoint(x: 600, y: 360)),
    .bugEscaped(id: 8, species: .mosquito), .stung(id: 9, species: .bee, cost: 1),
    .stung(id: 10, species: .wasp, cost: 2), .stung(id: 11, species: .bumblebee, cost: 1), .drySnap,
    .feast(count: 3, snapsBack: 1), .luckySnap(species: .ladybird), .luckySnap(species: .goldenScarab),
    .chainUp(count: 3, multiplier: 2), .chainBroken(count: 4), .rearmed, .beeSpared(species: .bee),
    .beeSpared(species: .wasp), .lastSnap, .tired, .newBest, .finished,
]

private let feelPentatonic: Set<Int> = [0, 2, 4, 7, 9]

@MainActor
struct FeelTests {
    // MARK: - The snap path: filter + Core's SnapDetector, end to end

    @Test func aFastSnapFiresOnceOnTheReportThatCrossesTheDepth() {
        let hinge = FeelFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 160 }
        #expect(hinge.source.hasHinge)
        let rest = hinge.inputs.last
        #expect(rest?.snap == nil)
        // 25° in 0.12 s at 30 Hz: four reports, the last one past 22°.
        hinge.run(0.6) { t in 160 - 25 * min(t / 0.12, 1) }
        let frames = hinge.snapFrames
        #expect(frames.count == 1)
        #expect(hinge.source.snapsFired == 1)
        guard let index = frames.first, let trigger = hinge.inputs[index].snap else { return }
        #expect(trigger.duration >= 0.08)
        #expect(trigger.duration <= 0.16)
        // It fires on the frame of the first report at or past the snap depth: no added lag.
        let crossing = hinge.reports.first { 160 - $0.angle >= Tuning.snapDepth }
        let found = crossing != nil
        #expect(found)
        if let crossing {
            #expect(abs(hinge.times[index] - crossing.time) < 1e-6)
        }
        // One snap per arm: held shut, the trap is not armed.
        #expect(hinge.inputs.last?.armed == false)
    }

    @Test func aFastSnapAtTwentyFiveHertzAlsoFiresOnTheCrossingReport() {
        let hinge = FeelFakeHinge(source: HingeTrapSource())
        hinge.run(1.0, rate: 25) { _ in 160 }
        hinge.run(0.6, rate: 25) { t in 160 - 32 * min(t / 0.15, 1) }
        let frames = hinge.snapFrames
        #expect(frames.count == 1)
        guard let index = frames.first else { return }
        let crossing = hinge.reports.first { 160 - $0.angle >= Tuning.snapDepth }
        if let crossing {
            #expect(abs(hinge.times[index] - crossing.time) < 1e-6)
        }
    }

    @Test func aSlowCloseCreepsAndNeverBitesBeforeTheDepth() {
        let hinge = FeelFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 160 }
        // 40° over 2 s.
        hinge.run(2.0) { t in 160 - 20 * t }
        var crept = false
        for (index, input) in hinge.inputs.enumerated() {
            if input.creeping { crept = true }
            if input.snap != nil {
                let raw = hinge.rawAngle(atOrBefore: hinge.times[index]) ?? 160
                #expect(160 - raw >= Tuning.snapDepth - 1e-9)
            }
        }
        #expect(crept)
    }

    @Test func jitterAtRestNeverArmsASnap() {
        let hinge = FeelFakeHinge(source: HingeTrapSource())
        var dice = FeelDice(seed: 7)
        hinge.run(0.5) { _ in 158 }
        hinge.run(5.0) { _ in 158 + dice.range(-1.5, 1.5) }
        let clean = hinge.inputs.allSatisfy { $0.snap == nil }
        #expect(clean)
        let deepest = hinge.inputs.map { $0.closure }.max() ?? 99
        #expect(deepest < Tuning.snapStartDepth)
        #expect(hinge.source.snapsFired == 0)
        let calm = hinge.inputs.allSatisfy { !$0.creeping }
        #expect(calm)
    }

    @Test func reopeningReArmsForTheNextSnap() {
        let hinge = FeelFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 160 }
        hinge.run(0.5) { t in 160 - 25 * min(t / 0.12, 1) }
        #expect(hinge.source.snapsFired == 1)
        #expect(hinge.source.armed == false)
        hinge.run(0.8) { t in 135 + 25 * min(t / 0.3, 1) }
        #expect(hinge.inputs.last?.armed == true)
        hinge.run(0.5) { t in 160 - 25 * min(t / 0.12, 1) }
        #expect(hinge.source.snapsFired == 2)
        #expect(hinge.snapFrames.count == 1)
    }

    @Test func aSnapIsNeverLostOrDeliveredTwice() {
        let source = HingeTrapSource()
        source.clock = { 0 }
        source.ingest(angleDegrees: 160, at: 0)
        var frame = 0.0
        while frame < 0.5 {
            frame += 1.0 / 120
            _ = source.input(at: frame)
        }
        // Two reports land inside one frame: the snap must still reach that frame.
        source.ingest(angleDegrees: 152, at: frame + 0.01)
        _ = source.input(at: frame + 0.01)
        source.ingest(angleDegrees: 144, at: frame + 0.043)
        _ = source.input(at: frame + 0.043)
        source.ingest(angleDegrees: 137, at: frame + 0.07)
        source.ingest(angleDegrees: 132, at: frame + 0.076)
        let bite = source.input(at: frame + 0.077)
        #expect(bite.snap != nil)
        // Asked again for the same frame: no second snap.
        let again = source.input(at: frame + 0.077)
        #expect(again.snap == nil)
        let later = source.input(at: frame + 0.09)
        #expect(later.snap == nil)
        #expect(source.snapsFired == 1)
    }

    @Test func aHandThatStopsJustPastTheDepthStillBites() {
        let hinge = FeelFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 160 }
        // A moderate close (≈ 50°/s, small steps the filter smooths) that stops 0.3° past 22°; the Duo then sends
        // nothing at all.
        let target = 160 - Tuning.snapDepth - 0.3
        hinge.run(1.0) { t in max(160 - 50 * t, target) }
        #expect(hinge.source.snapsFired == 1)
    }

    @Test func noHingeMeansAnOpenArmedTrap() {
        let source = HingeTrapSource()
        let input = source.input(at: 5)
        #expect(source.hasHinge == false)
        #expect(input.armed)
        #expect(input.snap == nil)
        #expect(input.closure == 0)
        #expect(input.angle == nil)
        #expect(source.isClosing == false)
        #expect(source.reference == nil)
        source.ingest(angleDegrees: Double.nan, at: 6)
        source.ingest(angleDegrees: 150, at: Double.infinity)
        #expect(source.hasHinge == false)
        source.ingest(angleDegrees: 400, at: 7)
        #expect(source.hasHinge)
        #expect(source.lastRawAngle == 180)
        let flat = source.input(at: 7.1)
        #expect(flat.closure.isFinite)
        #expect(flat.angle != nil)
    }

    @Test func closingPausesOnlyWellPastHalfwayAndClearsOnReopening() {
        let hinge = FeelFakeHinge(source: HingeTrapSource())
        hinge.run(0.5) { _ in 160 }
        // A natural hard fold to 90° and a hold there: never a pause (Swoop's real-Duo lesson).
        hinge.run(0.4) { t in 160 - 70 * min(t / 0.3, 1) }
        hinge.run(2.0) { _ in 90 }
        #expect(hinge.source.isClosing == false)
        // Under 50°: a pause, but only after the full dwell.
        hinge.run(0.3) { t in 90 - 50 * min(t / 0.25, 1) }
        hinge.run(0.3) { _ in 40 }
        #expect(hinge.source.isClosing == false)
        hinge.run(0.5) { _ in 40 }
        #expect(hinge.source.isClosing)
        // Paused (no frames): reopening is judged from the reports.
        hinge.run(0.8, frames: false) { t in 40 + 110 * min(t / 0.4, 1) }
        #expect(hinge.source.isClosing == false)
    }

    @Test func resetKeepsTheHingeAndNeverSnapsOnItsOwn() {
        let hinge = FeelFakeHinge(source: HingeTrapSource())
        hinge.run(1.0) { _ in 158 }
        hinge.run(0.5) { t in 158 - 30 * min(t / 0.12, 1) }
        #expect(hinge.source.snapsFired == 1)
        hinge.source.reset(at: hinge.time)
        #expect(hinge.source.hasHinge)
        hinge.run(1.0) { _ in 128 }
        #expect(hinge.snapFrames.isEmpty)
        #expect(hinge.source.snapsFired == 1)
        #expect(hinge.source.angle != nil)
        #expect(hinge.source.predictedAngle(at: hinge.time) != nil)
    }

    // MARK: - Filters

    @Test func theSnapFilterPassesBigStepsAndSmoothsSmallOnes() {
        var filter = OneEuroSmoother(minCutoff: 1.2, beta: 0.5, dCutoff: 4, escape: 2)
        let first = filter.filter(160, at: 0)
        #expect(first == 160)
        // A 7° report (a real snap) passes straight through.
        let big = filter.filter(153, at: 1.0 / 30)
        #expect(abs(big - 153) < 1e-12)
        // A 1° report is smoothed (some lag), never overshoots.
        var slow = OneEuroSmoother(minCutoff: 1.2, beta: 0.5, dCutoff: 4, escape: 2)
        _ = slow.filter(160, at: 0)
        let small = slow.filter(159, at: 1.0 / 30)
        #expect(small < 160)
        #expect(small > 159)
        slow.settle(158.5, at: 0.1)
        #expect(slow.value == 158.5)
        #expect(slow.derivative == 0)
        // The classic filter (no escape) is unchanged: it lags a big step.
        var classic = OneEuroSmoother()
        _ = classic.filter(160, at: 0)
        let lagged = classic.filter(153, at: 1.0 / 30)
        #expect(lagged > 153.5)
        let nan = classic.filter(Double.nan, at: 0.1)
        #expect(nan.isFinite)
    }

    @Test func theClosingGateHasADwellAndHysteresis() {
        var gate = FeelClosingGate()
        gate.update(angle: Tuning.closingAngle - 1, at: 0)
        #expect(gate.isClosing(at: Tuning.closingDwell - 0.01) == false)
        #expect(gate.isClosing(at: Tuning.closingDwell + 0.01))
        gate.update(angle: Tuning.closingAngle + 3, at: 1)
        #expect(gate.isClosing(at: 1))
        gate.update(angle: Tuning.closingAngle + FeelClosingGate.reopenMargin + 1, at: 1.1)
        #expect(gate.isClosing(at: 1.1) == false)
        // A dip that comes back before the dwell never pauses.
        gate.update(angle: Tuning.closingAngle - 2, at: 2)
        gate.update(angle: Tuning.closingAngle + 2, at: 2.3)
        #expect(gate.isClosing(at: 5) == false)
    }

    // MARK: - Touch

    @Test func aTapSnapsWhenTheJawsMeetAndReArms() {
        let touch = TouchTrapSource()
        let t0 = 50.0
        let before = touch.input(at: t0 - 0.01)
        #expect(before.armed)
        #expect(before.closure == 0)
        #expect(before.snap == nil)
        touch.tap(at: t0)
        let mid = touch.input(at: t0 + 0.045)
        #expect(mid.snap == nil)
        #expect(mid.armed == false)
        #expect(mid.closure > 0)
        #expect(mid.closure < Tuning.snapDepth)
        #expect(mid.creeping == false)
        #expect(mid.tooFlat == false)
        let contact = touch.input(at: t0 + Tuning.touchSnapTime)
        #expect(contact.snap != nil)
        let duration = contact.snap?.duration ?? 0
        #expect(abs(duration - Tuning.touchSnapTime) < 1e-9)
        #expect(abs(contact.closure - Tuning.snapDepth) < 1e-9)
        let again = touch.input(at: t0 + Tuning.touchSnapTime + 0.001)
        #expect(again.snap == nil)
        // A tap before the re-arm is ignored.
        touch.tap(at: t0 + 0.2)
        #expect(touch.bites == 1)
        // The lobes reopen smoothly.
        var previous = Tuning.snapDepth
        var t = t0 + Tuning.touchSnapTime
        while t < t0 + 0.6 {
            let c = touch.input(at: t).closure
            #expect(c.isFinite)
            #expect(c <= previous + 1e-9)
            previous = c
            t += 1.0 / 120
        }
        let open = touch.input(at: t0 + 0.6)
        #expect(abs(open.closure) < 1e-9)
        #expect(open.snap == nil)
        let rearmed = touch.input(at: t0 + Tuning.touchRearmDelay + 0.001)
        #expect(rearmed.armed)
        touch.tap(at: t0 + 1)
        #expect(touch.bites == 2)
        let second = touch.input(at: t0 + 1 + Tuning.touchSnapTime + 0.004)
        #expect(second.snap != nil)
        touch.reset()
        let fresh = touch.input(at: t0 + 1.05)
        #expect(fresh.armed)
        #expect(fresh.closure == 0)
    }

    @Test func theTouchJawCurveIsContinuous() {
        let close = Tuning.touchSnapTime
        let depth = Tuning.snapDepth
        #expect(FeelTouchJaw.closure(elapsed: 0, close: close, reopen: FeelTouchJaw.reopen, depth: depth) == 0)
        let shut = FeelTouchJaw.closure(elapsed: close, close: close, reopen: FeelTouchJaw.reopen, depth: depth)
        #expect(abs(shut - depth) < 1e-9)
        let justBefore = FeelTouchJaw.closure(elapsed: close - 1e-6, close: close, reopen: FeelTouchJaw.reopen,
                                              depth: depth)
        #expect(abs(justBefore - depth) < 0.01)
        let done = FeelTouchJaw.closure(elapsed: close + FeelTouchJaw.reopen, close: close,
                                        reopen: FeelTouchJaw.reopen, depth: depth)
        #expect(abs(done) < 1e-6)
        #expect(FeelTouchJaw.closure(elapsed: Double.nan, close: close, reopen: 0.35, depth: depth) == 0)
        #expect(FeelTouchJaw.closure(elapsed: -1, close: close, reopen: 0.35, depth: depth) == 0)
        // The whole cycle fits inside the re-arm delay.
        #expect(close + FeelTouchJaw.reopen <= Tuning.touchRearmDelay + 1e-9)
    }

    // MARK: - Recipes

    @Test func everyRecipeIsSane() {
        var dice = FeelDice(seed: 11)
        var recipes: [[FeelSynthCommand]] = [
            FeelSoundBook.lastSnap(), FeelSoundBook.lastSnap(delay: 0.75), FeelSoundBook.tired(),
            FeelSoundBook.tired(delay: 0.9), FeelSoundBook.newBest(), FeelSoundBook.newBest(delay: 0.6),
            FeelSoundBook.uiTap(), FeelSoundBook.uiConfirm(),
        ]
        for caught in 0...9 {
            recipes.append(FeelSoundBook.chomp(caught: caught, dice: &dice))
        }
        recipes.append(FeelSoundBook.chomp(caught: 1, dice: &dice, scale: FeelSoundBook.homeChompScale))
        recipes.append(FeelSoundBook.drySnap(dice: &dice))
        for index in 0..<12 {
            recipes.append(FeelSoundBook.crunch(index: index, pan: -0.5, dice: &dice))
        }
        for count in [3, 4, 5, 9] {
            for back in 0...2 {
                recipes.append(FeelSoundBook.feast(count: count, snapsBack: back, dice: &dice))
            }
        }
        for count in [0, 1, 2, 5, 8, 40] {
            recipes.append(FeelSoundBook.chainUp(count: count, dice: &dice))
            recipes.append(FeelSoundBook.chainUp(count: count, delay: FeelSoundBook.chainAt, dice: &dice))
        }
        recipes.append(FeelSoundBook.chainBroken(dice: &dice))
        recipes.append(FeelSoundBook.chainBroken(delay: 0.75, dice: &dice))
        recipes.append(FeelSoundBook.snapWhoosh(dice: &dice))
        recipes.append(FeelSoundBook.rearmPluck(dice: &dice))
        recipes.append(FeelSoundBook.celebrate(dice: &dice))
        recipes.append(FeelSoundBook.sip(pan: 0.4, dice: &dice))
        recipes.append(FeelSoundBook.hop(pan: -0.4, dice: &dice))
        recipes.append(FeelSoundBook.whiff(pan: 0.8, delay: 0.05, dice: &dice))
        recipes.append(FeelSoundBook.spooked(pan: -0.8, dice: &dice))
        for phase in DayPhase.allCases {
            recipes.append(FeelSoundBook.dayChime(phase, dice: &dice))
        }
        for species in BugSpecies.allCases {
            recipes.append(FeelSoundBook.landingTik(species, inTrap: true, pan: 0.2, dice: &dice))
            recipes.append(FeelSoundBook.landingTik(species, inTrap: false, pan: -0.2, dice: &dice))
            recipes.append(FeelSoundBook.lucky(species, dice: &dice))
            recipes.append(FeelSoundBook.sting(species, pan: 0.3, delay: FeelSoundBook.stingAt, dice: &dice))
            recipes.append(FeelSoundBook.spared(species, pan: -0.3, dice: &dice))
        }
        for recipe in recipes {
            #expect(!recipe.isEmpty)
            for command in recipe {
                #expect(command.gain.isFinite)
                #expect(command.gain > 0)
                #expect(command.gain <= 0.4)
                #expect(command.delay >= 0)
                #expect(command.delay < 3)
                #expect(command.pan >= -1)
                #expect(command.pan <= 1)
            }
        }
    }

    @Test func theChompIsTheHeroAndGrowsWithTheBite() {
        var dice = FeelDice(seed: 3)
        let chompPeak = FeelSoundBook.chomp(caught: 1, dice: &dice).map { $0.gain }.max() ?? 0
        let tikPeak = FeelSoundBook.landingTik(.dragonfly, inTrap: true, pan: 0, dice: &dice).map { $0.gain }.max() ?? 1
        let sipPeak = FeelSoundBook.sip(pan: 0, dice: &dice).map { $0.gain }.max() ?? 1
        #expect(chompPeak > tikPeak * 3)
        #expect(chompPeak > sipPeak * 3)
        // The squelch tail: 120 ms + 60 ms per bug.
        #expect(abs(FeelSoundBook.squelchLength(caught: 1) - 0.18) < 1e-6)
        #expect(abs(FeelSoundBook.squelchLength(caught: 5) - 0.42) < 1e-6)
        func squelch(_ commands: [FeelSynthCommand]) -> FeelSquelchSpec? {
            for command in commands {
                if case .squelch(let spec) = command { return spec }
            }
            return nil
        }
        let one = squelch(FeelSoundBook.chomp(caught: 1, dice: &dice))
        let five = squelch(FeelSoundBook.chomp(caught: 5, dice: &dice))
        #expect(one != nil)
        #expect(five != nil)
        if let one, let five {
            #expect(five.duration > one.duration)
            #expect(five.gain >= one.gain)
        }
        // An empty clap has no squelch and no gulp, and is smaller.
        let dry = FeelSoundBook.drySnap(dice: &dice)
        #expect(squelch(dry) == nil)
        let dryPeak = dry.map { $0.gain }.max() ?? 1
        #expect(dryPeak < chompPeak)
    }

    @Test func everyChompIsALittleDifferent() {
        var dice = FeelDice(seed: 5)
        var thumps: [Float] = []
        var gaps: [Float] = []
        var all: [[FeelSynthCommand]] = []
        for _ in 0..<40 {
            let chomp = FeelSoundBook.chomp(caught: 2, dice: &dice)
            all.append(chomp)
            var woodDelays: [Float] = []
            for command in chomp {
                switch command {
                case .tone(let spec) where spec.delay == 0:
                    thumps.append(spec.start)
                case .ring(let spec) where spec.kind == .wood:
                    woodDelays.append(spec.delay)
                default:
                    break
                }
            }
            if woodDelays.count >= 2 {
                gaps.append(woodDelays[1] - woodDelays[0])
            }
        }
        #expect(thumps.count == 40)
        #expect(gaps.count == 40)
        // Pitch within ±4 % of 90 Hz, click spacing within 18 ± 3 ms, and they really vary.
        for f in thumps {
            #expect(f >= 90 * 0.96 - 0.001)
            #expect(f <= 90 * 1.04 + 0.001)
        }
        for gap in gaps {
            #expect(gap >= 0.015 - 1e-4)
            #expect(gap <= 0.021 + 1e-4)
        }
        let spread = (thumps.max() ?? 0) - (thumps.min() ?? 0)
        #expect(spread > 3)
        #expect(all[0] != all[1])
    }

    @Test func buzzTimbresFollowTheSpecies() {
        #expect(FeelSoundBook.timbre(.bee, flying: true) == .bee)
        #expect(FeelSoundBook.timbre(.bee, flying: false) == .bee)
        #expect(FeelSoundBook.timbre(.mosquito, flying: true) == .mosquito)
        #expect(FeelSoundBook.timbre(.ant, flying: false) == .silent)
        #expect(FeelSoundBook.timbre(.cricket, flying: false) == .cricket)
        #expect(FeelSoundBook.timbre(.cricket, flying: true) == .hopper)
        #expect(FeelSoundBook.timbre(.ladybird, flying: false) == .silent)
        // Flying and low is loudest; landed bugs are quieter.
        let high = FeelSoundBook.buzzLevel(.housefly, flying: true, height: 1)
        let low = FeelSoundBook.buzzLevel(.housefly, flying: true, height: 0)
        let landed = FeelSoundBook.buzzLevel(.housefly, flying: false, height: 0)
        #expect(low > high)
        #expect(high > landed)
        #expect(abs(low - 1) < 1e-9)
        for id in -5...200 {
            let pitch = FeelSoundBook.bugPitch(id: id)
            #expect(pitch >= 0.94)
            #expect(pitch <= 1.06)
        }
        #expect(FeelSoundBook.bugPitch(id: 3) == FeelSoundBook.bugPitch(id: 3))
        #expect(FeelSoundBook.pan(x: 0, width: 952) < -0.7)
        #expect(FeelSoundBook.pan(x: 952, width: 952) > 0.7)
        #expect(abs(FeelSoundBook.pan(x: 476, width: 952)) < 1e-6)
        #expect(FeelSoundBook.pan(x: Double.nan, width: 952) == 0)
        let gains = FeelSynth.panGains(0)
        #expect(abs(gains.left - 1) < 1e-6)
        #expect(abs(gains.right - 1) < 1e-6)
        let hard = FeelSynth.panGains(1)
        #expect(hard.left < 1e-6)
        #expect(FeelSynth.panGains(Float.nan).left == 1)
    }

    @Test func theBuzzMixerKeepsSlotsStableAndFadesBeforeReuse() {
        var mixer = FeelBuzzMixer()
        // Twelve flying bugs: only the eight loudest get a voice.
        var crowd: [Buzzer] = []
        for index in 0..<12 {
            let height = Double(index) / 12
            crowd.append(Buzzer(id: 100 + index, species: .housefly, pan: 0, height: height, flying: true))
        }
        let first = mixer.update(buzzers: crowd, share: 1, now: 0)
        #expect(first.count == FeelSynth.buzzSlots)
        let ids = mixer.ids.compactMap { $0 }
        #expect(ids.count == 8)
        #expect(ids.allSatisfy { $0 < 108 })
        // The same bugs next frame keep their slots.
        let before = mixer.ids
        _ = mixer.update(buzzers: crowd, share: 1, now: 0.016)
        #expect(mixer.ids == before)
        // One bug leaves: its slot fades and is not reused at once.
        let gone = crowd.filter { $0.id != 100 }
        let newcomer = Buzzer(id: 500, species: .bee, pan: 0.5, height: 0, flying: true)
        let slotOfGone = before.firstIndex(where: { $0 == 100 })
        _ = mixer.update(buzzers: gone + [newcomer], share: 1, now: 0.03)
        if let slot = slotOfGone {
            #expect(mixer.ids[slot] == nil)
            #expect(mixer.targets[slot].level == 0)
        }
        // After the fade the newcomer gets the slot.
        _ = mixer.update(buzzers: gone + [newcomer], share: 1, now: 0.2)
        #expect(mixer.ids.contains(where: { $0 == 500 }))
        // Silent species never take a slot; everyone gone → all fading.
        _ = mixer.update(buzzers: [Buzzer(id: 900, species: .ant, pan: 0, height: 0, flying: false)], share: 1,
                         now: 0.4)
        #expect(mixer.ids.allSatisfy { $0 == nil })
        #expect(mixer.targets.allSatisfy { $0.level == 0 })
    }

    // MARK: - The bed

    @Test func theBedFollowsTheTrapAndTheDay() {
        let creep = TrapTelemetry(closure: 14, creeping: true, buzzers: [], chain: 5, dayClock: 0.5, playing: true)
        let bed = FeelSoundBook.playBed(telemetry: creep, master: 1, ambience: 1)
        #expect(bed.groan > 0.55)
        #expect(bed.groanHz > 70)
        #expect(bed.groanHz < 140)
        #expect(bed.music == 1)
        #expect(bed.musicVoices == 3)
        #expect(bed.wind > 0)
        #expect(bed.crickets == 0)
        let calm = TrapTelemetry(closure: 14, creeping: false, buzzers: [], chain: 0, dayClock: 3.6, playing: true)
        let night = FeelSoundBook.playBed(telemetry: calm, master: 1, ambience: 1)
        #expect(night.groan == 0)
        #expect(night.musicVoices == 1)
        #expect(night.crickets > 0.9)
        #expect(night.wind < bed.wind)
        let menu = FeelSoundBook.playBed(telemetry: TrapTelemetry(), master: 1, ambience: 0)
        #expect(menu.hasLayers == false)
        #expect(FeelSoundBook.musicVoices(chain: 2) == 2)
        #expect(FeelSoundBook.musicVoices(chain: 6) == 4)
        #expect(FeelSoundBook.musicVoices(chain: 60) == 4)
        #expect(FeelSoundBook.groanLevel(closure: 30, creeping: false) == 0)
        #expect(abs(FeelSoundBook.groanLevel(closure: 40, creeping: true) - 1) < 1e-9)
        #expect(FeelSoundBook.groanLevel(closure: Double.nan, creeping: true) == 0)
        let weird = TrapTelemetry(closure: Double.nan, creeping: true, buzzers: [], chain: -3,
                                  dayClock: Double.infinity, playing: true)
        let safe = FeelSoundBook.playBed(telemetry: weird, master: 1, ambience: 1)
        #expect(safe.groan.isFinite)
        #expect(safe.groanHz.isFinite)
        #expect(safe.crickets.isFinite)
        #expect(safe.wind.isFinite)
    }

    @Test func theMarimbaLoopIsPentatonicAndGrowsAVoiceAtATime() {
        for voice in 0..<4 {
            var notes = 0
            for step in 0..<FeelSynth.musicSteps {
                if let note = FeelSynth.musicNote(voice: voice, step: step) {
                    notes += 1
                    let pitchClass = ((note % 12) + 12) % 12
                    #expect(feelPentatonic.contains(pitchClass))
                }
            }
            #expect(notes >= 8)
        }
        #expect(FeelSynth.musicNote(voice: 4, step: 0) == nil)
        #expect(FeelSynth.musicNote(voice: 0, step: FeelSynth.musicSteps) == nil)
        for chain in 0...7 {
            let voices = FeelSoundBook.musicVoices(chain: chain)
            #expect(voices >= 1)
            #expect(voices <= 4)
        }
    }

    // MARK: - The synth

    @Test func tenSecondsOfMixedEventsNeverClipOrNaN() {
        let synth = FeelSynth(sampleRate: 48_000)
        var dice = FeelDice(seed: 9)
        var mixer = FeelBuzzMixer()
        let blocksPerSecond = 48_000.0 / 512
        var nextCue = 0.0
        var cueIndex = 0
        let result = feelRender(synth, seconds: 10) { block, t in
            // A whole day in 10 s: the bog, a crowd buzzing, a creep, the chain climbing, bites of every size.
            let creeping = t > 2 && t < 3.5
            let telemetry = TrapTelemetry(closure: creeping ? 6 + 10 * (t - 2) : 2, creeping: creeping,
                                          buzzers: feelBuzzers(1 + Int(t) % 9), chain: Int(t) % 8,
                                          dayClock: t * 0.4, playing: true)
            if block % max(Int(blocksPerSecond / 60), 1) == 0 {
                synth.send(.bed(FeelSoundBook.playBed(telemetry: telemetry, master: FeelAudioEngine.masterGain,
                                                      ambience: 1)))
                let targets = mixer.update(buzzers: telemetry.buzzers, share: 1, now: t)
                for (slot, target) in targets.enumerated() {
                    synth.send(.buzz(slot: slot, buzz: target))
                }
            }
            if t >= nextCue {
                nextCue += 0.3
                cueIndex += 1
                var cue: [FeelSynthCommand]
                switch cueIndex % 8 {
                case 0: cue = FeelSoundBook.chomp(caught: 1 + cueIndex % 7, dice: &dice)
                case 1: cue = FeelSoundBook.drySnap(dice: &dice)
                case 2: cue = FeelSoundBook.feast(count: 5, snapsBack: 2, dice: &dice)
                case 3: cue = FeelSoundBook.sting(.wasp, pan: 0.5, delay: FeelSoundBook.stingAt, dice: &dice)
                case 4: cue = FeelSoundBook.lucky(.goldenScarab, dice: &dice)
                case 5: cue = FeelSoundBook.landingTik(.bumblebee, inTrap: true, pan: -0.6, dice: &dice)
                case 6: cue = FeelSoundBook.chainUp(count: cueIndex, delay: FeelSoundBook.chainAt, dice: &dice)
                default: cue = FeelSoundBook.celebrate(dice: &dice)
                }
                for index in 0..<3 {
                    cue.append(contentsOf: FeelSoundBook.crunch(index: index, pan: 0.2, dice: &dice))
                }
                for command in cue { synth.send(command) }
            }
        }
        #expect(result.finite)
        #expect(result.peak < 1.0)
        #expect(synth.peak < 1.0)
        #expect(result.rms > 0.01)
        // The limiter is a safety net, not the mix: almost nothing sits above 0.6.
        #expect(result.hot < 0.02)
    }

    @Test func aHotPileUpStillNeverClips() {
        let synth = FeelSynth(sampleRate: 44_100)
        let telemetry = TrapTelemetry(closure: 21, creeping: true, buzzers: feelBuzzers(8), chain: 9, dayClock: 3.5,
                                      playing: true)
        var bed = FeelSoundBook.playBed(telemetry: telemetry, master: FeelAudioEngine.masterGain, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        for slot in 0..<FeelSynth.buzzSlots {
            synth.send(.buzz(slot: slot, buzz: FeelBuzz(timbre: .bluebottle, level: 1, pan: 0, pitch: 1)))
        }
        var dice = FeelDice(seed: 5)
        for _ in 0..<4 {
            for command in FeelSoundBook.chomp(caught: 8, dice: &dice) { synth.send(command) }
        }
        for index in 0..<20 {
            synth.send(.ring(FeelRingSpec(.bell, fundamental: 300 + Float(index) * 37, partials: 6, decay: 0.5,
                                          gain: 2)))
            synth.send(.squelch(FeelSquelchSpec(duration: 0.5, gain: 2)))
        }
        let result = feelRender(synth, seconds: 2)
        #expect(result.finite)
        #expect(result.peak < 1)
        #expect(synth.peak < 1)
        #expect(synth.renderCallbacks > 0)
    }

    @Test func synthIsSilentWithMasterAtZero() {
        let synth = FeelSynth(sampleRate: 48_000)
        let telemetry = TrapTelemetry(closure: 12, creeping: true, buzzers: feelBuzzers(4), chain: 4, dayClock: 3.5,
                                      playing: true)
        var bed = FeelSoundBook.playBed(telemetry: telemetry, master: 0, ambience: 1)
        bed.glide = 0.01
        synth.send(.bed(bed))
        synth.send(.buzz(slot: 0, buzz: FeelBuzz(timbre: .bee, level: 1, pan: 0, pitch: 1)))
        var dice = FeelDice(seed: 1)
        for command in FeelSoundBook.chomp(caught: 3, dice: &dice) { synth.send(command) }
        let result = feelRender(synth, seconds: 0.5)
        #expect(result.peak < 0.0001)
    }

    @Test func eachContinuousLayerIsAudibleButGentle() {
        var beds: [FeelBed] = []
        var groan = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        groan.groan = 1
        groan.groanHz = 110
        beds.append(groan)
        var wind = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        wind.wind = 1
        beds.append(wind)
        var frogs = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        frogs.frogs = 1
        frogs.dripRate = 2
        beds.append(frogs)
        var crickets = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        crickets.crickets = 1
        beds.append(crickets)
        var music = FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)
        music.music = 1
        music.musicVoices = 4
        beds.append(music)
        for bed in beds {
            let synth = FeelSynth(sampleRate: 48_000)
            synth.send(.bed(bed))
            let result = feelRender(synth, seconds: 4.5)
            #expect(result.finite)
            #expect(result.rms > 0.0005)
            // A bed, not a moment: under −20 dBFS RMS.
            #expect(result.rms < 0.1)
            #expect(result.peak < 0.9)
        }
    }

    @Test func everyBuzzTimbreSoundsAndThePanIsHeard() {
        for timbre in FeelBuzzTimbre.allCases where timbre != .silent {
            let synth = FeelSynth(sampleRate: 48_000)
            synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
            synth.send(.buzz(slot: 3, buzz: FeelBuzz(timbre: timbre, level: 1, pan: 0, pitch: 1)))
            let result = feelRender(synth, seconds: 1.5)
            #expect(result.finite)
            #expect(result.rms > 0.0005)
            #expect(result.rms < 0.1)
            #expect(result.peak < 0.9)
        }
        // A bee at the right is louder on the right.
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
        synth.send(.buzz(slot: 0, buzz: FeelBuzz(timbre: .bee, level: 1, pan: 0.8, pitch: 1)))
        let panned = feelRender(synth, seconds: 1)
        #expect(panned.right > panned.left * 2)
        // Switching a slot's timbre goes through silence and never blows up.
        synth.send(.buzz(slot: 0, buzz: FeelBuzz(timbre: .mosquito, level: 1, pan: -0.8, pitch: 1.05)))
        let switched = feelRender(synth, seconds: 1)
        #expect(switched.finite)
        #expect(switched.left > switched.right)
        synth.send(.stopAll)
        let stopped = feelRender(synth, seconds: 0.3)
        #expect(stopped.peak < 0.01)
    }

    @Test func monoRenderMatchesTheStereoSum() {
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.idleBed(master: FeelAudioEngine.masterGain, glide: 0.01)))
        var dice = FeelDice(seed: 2)
        for command in FeelSoundBook.chomp(caught: 2, dice: &dice) { synth.send(command) }
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        defer { buffer.deallocate() }
        var finite = true
        var peak: Float = 0
        for _ in 0..<60 {
            synth.render(frames: 512, into: buffer)
            for index in 0..<512 {
                if !buffer[index].isFinite { finite = false }
                peak = max(peak, abs(buffer[index]))
            }
        }
        #expect(finite)
        #expect(peak > 0.01)
        #expect(peak < 1)
    }

    @Test func commandQueueDropsInsteadOfBlockingWhenFull() {
        let synth = FeelSynth(sampleRate: 48_000)
        var accepted = 0
        for _ in 0..<(FeelSynth.queueCapacity * 2) {
            if synth.send(.stopAll) { accepted += 1 }
        }
        #expect(accepted == FeelSynth.queueCapacity - 1)
    }

    @Test func theCricketChirpGateHasThreePulses() {
        var edges = 0
        var last: Float = 0
        var t: Float = 0
        while t < 0.6 {
            let gate = FeelSynth.chirpGate(t)
            if gate > 0.5 && last < 0.5 { edges += 1 }
            last = gate
            t += 0.0005
        }
        #expect(edges == 3)
        #expect(FeelSynth.chirpGate(-1) == 0)
    }

    // MARK: - Haptics

    @Test func theChompIsTheHeaviestHapticAndGrowsWithTheBite() {
        let one = FeelHapticBook.chomp(caught: 1)
        let five = FeelHapticBook.chomp(caught: 5)
        let peak = one.notes.map { $0.intensity }.max() ?? 0
        #expect(peak == 1)
        #expect(five.length > one.length - 1e-9)
        #expect(FeelHapticBook.rumbleLength(caught: 5) > FeelHapticBook.rumbleLength(caught: 1))
        #expect(abs(FeelHapticBook.rumbleLength(caught: 0) - 0.09) < 1e-9)
        let fiveRumble = five.notes.filter { $0.kind == .continuous }.map { $0.intensity }.max() ?? 0
        let oneRumble = one.notes.filter { $0.kind == .continuous }.map { $0.intensity }.max() ?? 0
        #expect(fiveRumble > oneRumble)
        let cues: [FeelHapticCue] = [
            FeelHapticBook.drySnap, FeelHapticBook.feast, FeelHapticBook.sting(), FeelHapticBook.sting(at: 0.06),
            FeelHapticBook.lucky(), FeelHapticBook.rearm, FeelHapticBook.spared, FeelHapticBook.lastSnap(),
            FeelHapticBook.tired(), FeelHapticBook.newBest(), FeelHapticBook.uiTap, FeelHapticBook.uiConfirm,
            FeelHapticBook.celebrate, FeelHapticBook.landing(.gnat), FeelHapticBook.landing(.dragonfly),
            FeelHapticBook.chomp(caught: 0), one, five, FeelHapticBook.chomp(caught: 99),
        ]
        for cue in cues {
            #expect(!cue.notes.isEmpty)
            #expect(cue.curve.count <= 16)
            for note in cue.notes {
                #expect(note.intensity >= 0 && note.intensity <= 1)
                #expect(note.sharpness >= 0 && note.sharpness <= 1)
                #expect(note.time >= 0)
            }
            // Nothing else hits harder on its first tap than the CHOMP.
            let first = cue.notes.first { $0.kind == .transient }?.intensity ?? 0
            #expect(first <= peak)
        }
        // A dry snap is lighter than a CHOMP's slam.
        let dryFirst = FeelHapticBook.drySnap.notes.first { $0.kind == .transient }?.intensity ?? 1
        #expect(dryFirst < peak)
        // Landing ticks scale with the bug.
        let gnat = FeelHapticBook.landing(.gnat).notes.first?.intensity ?? 1
        let dragonfly = FeelHapticBook.landing(.dragonfly).notes.first?.intensity ?? 0
        #expect(dragonfly > gnat)
        // Strong turns taps into bursts the Duo's weak actuator can push.
        let strong = FeelHapticBook.adapt(one, to: .strong)
        #expect(strong.notes.allSatisfy { $0.kind == .continuous })
        #expect(FeelHapticBook.adapt(FeelHapticBook.rearm, to: .normal) == FeelHapticBook.rearm)
        #expect(FeelHapticProfile.defaultFor(hasFold: true) == .strong)
        // Delaying a cue shifts every note.
        let later = FeelHapticBook.rearm.delayed(by: 0.25)
        #expect(abs((later.notes.first?.time ?? 0) - 0.25) < 1e-9)
    }

    @Test func theCreepTextureFollowsTheClosure() {
        #expect(FeelHapticBook.creepLevel(closure: 20, creeping: false) == 0)
        #expect(FeelHapticBook.creepLevel(closure: Double.nan, creeping: true) == 0)
        var previous: Float = 0
        var closure = Tuning.creepDepth
        while closure <= 40 {
            let level = FeelHapticBook.creepLevel(closure: closure, creeping: true)
            #expect(level >= previous)
            #expect(level > 0)
            #expect(level <= 1)
            previous = level
            closure += 0.5
        }
        #expect(FeelHapticBook.creepLevel(closure: 15, creeping: true, profile: .off) == 0)
        let normal = FeelHapticBook.creepLevel(closure: 15, creeping: true, profile: .normal)
        let strong = FeelHapticBook.creepLevel(closure: 15, creeping: true, profile: .strong)
        #expect(strong > normal)
        #expect(FeelHapticBook.stretchLevel(2, profile: .strong) <= 1)
    }

    // MARK: - Home's title trap

    @Test func theHomeStretchFollowsAClosingHingeOnly() {
        var meter = FeelStretchMeter()
        var t = 0.0
        _ = meter.update(closure: 0, at: t)
        // Held open: silent.
        for _ in 0..<60 {
            t += 1.0 / 60
            let level = meter.update(closure: 0, at: t)
            #expect(level == 0)
        }
        // Closing at 60°/s: it stretches.
        var closure = 0.0
        var loudest = 0.0
        for _ in 0..<20 {
            t += 1.0 / 60
            closure += 1
            loudest = max(loudest, meter.update(closure: closure, at: t))
        }
        #expect(loudest > 0.2)
        #expect(loudest <= 1)
        // Opening again: it fades to nothing.
        var level = 1.0
        for _ in 0..<60 {
            t += 1.0 / 60
            closure = max(closure - 1, 0)
            level = meter.update(closure: closure, at: t)
        }
        #expect(level < 0.01)
        let nan = meter.update(closure: Double.nan, at: t)
        #expect(nan == 0)
    }

    // MARK: - The director

    /// Sound and haptics off: the director takes a whole run's worth of events and frames, Home's trap, the menu
    /// sounds, idling and silences without starting any engine or crashing.
    @Test func directorHandlesEverythingWithFeedbackOff() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        director.respectSilentSwitch = true
        director.sceneWidth = 1120
        director.start()
        director.start()
        director.handle([], telemetry: TrapTelemetry())
        for frame in 0..<360 {
            let t = Double(frame) / 120
            let creeping = frame > 100 && frame < 200
            let telemetry = TrapTelemetry(closure: creeping ? 10 : 1, creeping: creeping,
                                          buzzers: feelBuzzers(frame % 11), chain: frame / 60, dayClock: t,
                                          playing: true)
            director.handle(frame == 30 ? feelEveryEvent : [], telemetry: telemetry)
        }
        director.handle([.snapped(feelBite(caught: [])), .drySnap], telemetry: TrapTelemetry(playing: true))
        director.handle([.tired], telemetry: TrapTelemetry(playing: false))
        director.handle([.finished], telemetry: TrapTelemetry())
        director.idle = true
        for frame in 0..<60 {
            director.homeTrap(closure: Double(frame % 30), snapped: frame == 25 || frame == 26)
        }
        director.uiTap()
        director.uiConfirm()
        director.celebrate()
        director.silence()
        director.silence()
        director.idle = false
        #expect(director.soundOn == false)
        #expect(director.hapticsOn == false)
        #expect(director.respectSilentSwitch)
        #expect(director.idle == false)
        // The bite with three caught, and Home's one chomp (the refractory swallowed the second frame).
        #expect(director.chomps == 2)
    }

    @Test func directorEdgeCasesDoNotCrash() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        director.sceneWidth = Double.nan
        let weird = TrapTelemetry(closure: Double.nan, creeping: true,
                                  buzzers: [Buzzer(id: -1, species: .bee, pan: Double.nan, height: Double.infinity,
                                                   flying: true)],
                                  chain: Int.max, dayClock: -Double.infinity, playing: true)
        var burst: [TrapEvent] = []
        for id in 0..<40 {
            burst.append(.bugLanded(id: id, species: .gnat, position: CGPoint(x: CGFloat(id * 30), y: 10),
                                    inTrap: id % 2 == 0))
            burst.append(.bugSpooked(id: id, species: .gnat))
            burst.append(.bugEscaped(id: id, species: .gnat))
        }
        burst.append(.snapped(feelBite(caught: Array(repeating: .housefly, count: 30))))
        director.handle(burst, telemetry: weird)
        director.homeTrap(closure: Double.nan, snapped: true)
        director.homeTrap(closure: -40, snapped: false)
        director.silence()
        director.handle([], telemetry: weird)
        let bed = FeelSoundBook.playBed(telemetry: weird, master: 1, ambience: 1)
        #expect(bed.groan.isFinite)
        #expect(bed.musicVoices == 4)
        let buzz = FeelSoundBook.buzz(for: weird.buzzers[0], share: 1)
        #expect(buzz.level.isFinite)
        #expect(buzz.pan == 0)
    }

    @Test func hapticsToggleRestoresTheProfile() {
        let director = FeedbackDirector()
        director.soundOn = false
        director.hapticsOn = false
        #expect(director.hapticsOn == false)
        director.deviceHasFold = true
        director.hapticsOn = true
        #expect(director.hapticProfile == .strong)
        director.hapticProfile = .normal
        director.hapticsOn = false
        director.hapticsOn = true
        #expect(director.hapticProfile == .normal)
        director.hapticsOn = false
    }

    #if DEBUG
    @Test func demoLogIsDebugAndSnapDemoOnly() {
        let wanted = ProcessInfo.processInfo.arguments.contains("-snapDemo")
        #expect(FeelDemoLog.isEnabled == wanted)
        #expect(FeelHingeLog.isEnabled == wanted)
    }
    #endif
}
