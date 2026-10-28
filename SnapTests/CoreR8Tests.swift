import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Round 8 Core rules (design/notes/core-R8.md, ROUND-8 §1, §2, §4 and the founder's binding hinge rules)
//
// The lid is the jaw: SnapDetector (armed at 35°, the bite at the shut ≤ 18° or `.closed` ≤ 25°, partial closes never
// bite, re-armed at 35°, a round starts closed), the session (bug fear from the continuous closure, the bite rule's
// exposure, the frozen clock while shut and before the first close, the catch ratio, any miss breaks the chain, no
// refunds in levels) and the 30 levels (LevelBook: the table, the session's script and end, evaluate's edge cases).

struct CoreR8Tests {

    private let geo = TrapGeometry(sceneSize: CGSize(width: 952, height: 670))
    private let frame: Double = 1.0 / 60.0

    // MARK: Helpers

    /// A feed session without waves (bugs only by script), 10 snaps.
    private func quiet(seed: UInt64 = 7) -> TrapSession {
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.startSnaps = 10
        return TrapSession(mode: .feed, seed: seed, best: 0, geometry: geo, options: o)
    }

    @discardableResult
    private func run(_ s: TrapSession, _ seconds: Double, _ input: TrapInput = TrapInput()) -> [TrapEvent] {
        var out: [TrapEvent] = []
        var t: Double = 0
        while t < seconds - 1e-9 && !s.isFinished {
            out.append(contentsOf: s.step(dt: frame, input: input))
            t += frame
        }
        return out
    }

    /// One bug per nectar drop (in drop order), staying forever; then 6 s for them all to land and sip.
    private func sippers(_ s: TrapSession, _ species: [BugSpecies]) {
        let drops: [NectarDrop] = s.snapshot.nectar
        var k: Int = 0
        while k < species.count && k < drops.count {
            let p: CGPoint = drops[k].position
            _ = s.spawnScripted(species[k], entry: CGPoint(x: p.x < 476 ? -30 : 982, y: p.y), target: p,
                                linger: .infinity)
            k += 1
        }
        run(s, 6)
    }

    private func report(_ events: [TrapEvent]) -> BiteReport? {
        for e in events {
            if case .snapped(let r) = e { return r }
        }
        return nil
    }

    private func count(_ events: [TrapEvent], _ match: (TrapEvent) -> Bool) -> Int {
        var n: Int = 0
        for e in events where match(e) { n += 1 }
        return n
    }

    /// Feeds a straight move from `from` to `to` over `seconds` at 30 Hz from `t0`; returns (bites, durations, the
    /// last time, the max closure, any slow-close frame).
    private func move(_ d: inout SnapDetector, _ from: Double, _ to: Double, _ seconds: Double, _ t0: Double,
                      status: TrapHingeStatus = .unknown) -> (Int, [Double], Double, Double, Bool) {
        let n: Int = max(1, Int((seconds * 30).rounded()))
        var bites: Int = 0
        var durations: [Double] = []
        var maxClosure: Double = 0
        var slow: Bool = false
        var i: Int = 1
        while i <= n {
            let t: Double = t0 + Double(i) / 30.0
            let a: Double = from + (to - from) * Double(i) / Double(n)
            if let r = d.ingest(angle: a, at: t, status: status) {
                bites += 1
                durations.append(r.duration)
            }
            let inp: TrapInput = d.input(at: t + 0.001)
            maxClosure = max(maxClosure, inp.closure)
            if inp.creeping { slow = true }
            i += 1
        }
        return (bites, durations, t0 + Double(n) / 30.0, maxClosure, slow)
    }

    private func hold(_ d: inout SnapDetector, _ a: Double, _ seconds: Double, _ t0: Double) -> Double {
        let n: Int = Int((seconds * 30).rounded())
        var i: Int = 0
        while i <= n {
            _ = d.ingest(angle: a, at: t0 + Double(i) / 30.0)
            i += 1
        }
        return t0 + Double(n) / 30.0
    }

    // MARK: SnapDetector: the lid is the jaw

    @Test func aSlamBitesOnceAtTheShut() {
        var d = SnapDetector()
        let t: Double = hold(&d, 150, 1, 0)
        #expect(d.armed, "a book at 150° is open")
        let m = move(&d, 150, 5, 0.3, t)
        #expect(m.0 == 1)
        if let dur = m.1.first {
            // Close start (8°) to the shut (18°): (150 − 8 − 18) / 145 × 0.3 s ≈ 0.26 s.
            #expect(dur >= 0.2 && dur <= 0.3, "duration \(dur)")
        }
        #expect(!d.armed, "one bite per arm")
        let inp: TrapInput = d.input(at: m.2 + 0.1)
        #expect(inp.closure > 120, "shut: the closure from the bite's reference \(inp.closure)")
        #expect(!inp.tooFlat)
    }

    @Test func aSlowCloseBitesAtTheShutWithALongDuration() {
        var d = SnapDetector()
        let t: Double = hold(&d, 150, 1, 0)
        let m = move(&d, 150, 5, 2.5, t)
        #expect(m.0 == 1)
        if let dur = m.1.first { #expect(dur >= 1.5, "duration \(dur)") }
        #expect(m.4, "reported as a slow close on the way")
        // A creep too slow for the reference to see is still a slow bite.
        var c = SnapDetector()
        let t2: Double = hold(&c, 150, 1, 0)
        let slow = move(&c, 150, 5, 20, t2)
        #expect(slow.0 == 1)
        if let dur = slow.1.first { #expect(abs(dur - Tuning.untimedCloseDuration) < 1e-9 || dur >= 1.5) }
    }

    @Test func aPartialCloseNeverBitesHoweverDeep() {
        var d = SnapDetector()
        var t: Double = hold(&d, 150, 1, 0)
        let a = move(&d, 150, 60, 0.4, t)
        t = hold(&d, 60, 1, a.2)
        let b = move(&d, 60, 150, 0.6, t)
        t = hold(&d, 150, 1, b.2)
        let c = move(&d, 150, 25, 0.4, t)
        let e = move(&d, 25, 150, 0.6, c.2)
        #expect(a.0 + b.0 + c.0 + e.0 == 0)
        #expect(a.3 >= 60, "the closure still followed the phone: \(a.3)")
        #expect(d.armed)
        // A 90° phone is open, never closed.
        var n = SnapDetector()
        _ = hold(&n, 90, 1, 0)
        #expect(n.armed)
    }

    @Test func openingAgainEndsTheClose() {
        var d = SnapDetector()
        var t: Double = hold(&d, 150, 1, 0)
        let a = move(&d, 150, 60, 0.4, t)
        #expect(d.closing)
        let b = move(&d, 60, 120, 0.4, a.2)
        t = hold(&d, 120, 1, b.2)
        #expect(!d.closing, "opened 10° above the close's lowest: over")
        let c = move(&d, 120, 5, 0.25, t)
        #expect(c.0 == 1)
        if let dur = c.1.first { #expect(dur <= 0.3, "timed afresh: \(dur)") }
    }

    @Test func reopeningReArmsAtThirtyFive() {
        var d = SnapDetector()
        var t: Double = hold(&d, 150, 1, 0)
        let a = move(&d, 150, 5, 0.3, t)
        let b = move(&d, 5, 30, 0.2, a.2)
        #expect(!d.armed, "30° is still the shut side of the hysteresis")
        let c = move(&d, 30, 150, 0.4, b.2)
        t = hold(&d, 150, 0.7, c.2)
        #expect(d.armed)
        let e = move(&d, 150, 5, 0.3, t)
        #expect(a.0 + b.0 + c.0 == 1 && e.0 == 1)
    }

    @Test func theClosedStatusBitesOnlyLow() {
        // Hardware reads .closed from ~85°: the status alone never bites an open phone.
        var d = SnapDetector()
        let t: Double = hold(&d, 150, 1, 0)
        let a = move(&d, 150, 40, 0.3, t, status: .closed)
        #expect(a.0 == 0)
        let b = move(&d, 40, 24, 0.1, a.2, status: .closed)
        #expect(b.0 == 1, "`.closed` at ≤ 25° is the shut")
        #expect(SnapDetector.isShut(angle: 18, status: .unknown))
        #expect(!SnapDetector.isShut(angle: 19, status: .partiallyOpen))
        #expect(SnapDetector.isShut(angle: 25, status: .closed) && !SnapDetector.isShut(angle: 26, status: .closed))
    }

    @Test func aRoundStartsClosed() {
        // Founder rule 3: an open phone at Play is not armed; shut, then open: armed.
        var d = SnapDetector(requireShut: true)
        var t: Double = hold(&d, 150, 0.5, 0)
        #expect(!d.armed && d.waitingForShut)
        let a = move(&d, 150, 5, 0.3, t)
        #expect(a.0 == 0, "the shut that starts a round is not a bite")
        #expect(!d.waitingForShut)
        let b = move(&d, 5, 90, 0.4, a.2)
        t = hold(&d, 90, 0.5, b.2)
        #expect(d.armed, "opened: the trap opens")
        let c = move(&d, 90, 5, 0.2, t)
        #expect(c.0 == 1)
        // Without requireShut a fresh detector on an open phone is armed at once; no sample: open and armed.
        var plain = SnapDetector()
        let none: TrapInput = plain.input(at: 0)
        #expect(none.armed && none.angle == nil && none.closure == 0)
        _ = plain.ingest(angle: 140, at: 0)
        #expect(plain.armed)
    }

    @Test func jitterAndFlatNeverCloseOrBite() {
        var d = SnapDetector()
        var r = SeededRandom(seed: 5)
        var bad: Int = 0
        var i: Int = 0
        while i < 600 {
            let t: Double = Double(i) / 30.0
            if d.ingest(angle: 178 + r.between(-1.5, 1.5), at: t) != nil { bad += 1 }
            let inp: TrapInput = d.input(at: t)
            if inp.creeping || inp.snap != nil || inp.tooFlat || inp.closure >= Tuning.closeStart { bad += 1 }
            i += 1
        }
        #expect(bad == 0)
    }

    // MARK: The bite rule

    @Test func theModelledExposure() {
        #expect(abs(TrapRules.modelExposure(nerve: Tuning.closeStart, duration: 0.3) - 0.3) < 1e-12)
        let half: Double = Tuning.closeStart + Tuning.modelCloseSpan / 2
        #expect(abs(TrapRules.modelExposure(nerve: half, duration: 0.4) - 0.2) < 1e-12)
        #expect(abs(TrapRules.modelExposure(nerve: 500, duration: 1)) < 1e-12)
        #expect(abs(TrapRules.modelExposure(nerve: 12, duration: Double.nan)) < 1e-12)
        #expect(abs(TrapRules.modelExposure(nerve: 12, duration: -1)) < 1e-12)
    }

    @Test func aFastCloseCatchesTheSittersAndASlowOneOnlyTheSlow() {
        // ROUND-8 §1: a decisive slam (≤ 0.3 s) catches the sitters; a slow close (≥ 1 s) loses the flies and gets
        // only the slow ones (the ladybird, a beetle: startle 40°).
        let fast: TrapSession = quiet()
        sippers(fast, [.housefly, .fruitFly, .ladybird])
        let f: BiteReport? = report(fast.step(dt: frame, input: biteInput(0.3)))
        #expect(f?.caught.count == 3, "\(String(describing: f))")
        #expect(abs((f?.catchRatio ?? 0) - 1) < 1e-9)
        let slow: TrapSession = quiet()
        sippers(slow, [.housefly, .fruitFly, .ladybird])
        let s: BiteReport? = report(slow.step(dt: frame, input: biteInput(1.2)))
        #expect(s?.caught == [.ladybird], "\(String(describing: s))")
        #expect(s?.escaped == 2)
        #expect(abs((s?.catchRatio ?? 0) - 1.0 / 3.0) < 1e-9)
    }

    private func biteInput(_ duration: Double) -> TrapInput {
        return TrapInput(closure: 132, armed: false, creeping: false,
                         snap: SnapTrigger(duration: duration, time: 0), tooFlat: false, angle: 18)
    }

    @Test func bugsFeelTheClosureAndFleeAfterTheirReaction() {
        // A real close: the closure passes the fly's startle depth (12°) but not the ladybird's (40°); after its
        // reaction time the fly flees (bugSpooked) and the ladybird stays.
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .ladybird])
        var spooked: [BugSpecies] = []
        var f: Int = 0
        while f < 90 {
            for e in s.step(dt: frame, input: TrapInput(closure: 30, armed: true, angle: 120)) {
                if case .bugSpooked(_, let sp) = e { spooked.append(sp) }
            }
            f += 1
        }
        #expect(spooked == [.housefly], "\(spooked)")
        // Opened again (closure under closeCancel): the close is over, nobody else flees.
        run(s, 2)
        let beetles: Int = s.snapshot.bugs.filter { (b: BugState) -> Bool in b.species == .ladybird && b.inTrap }.count
        #expect(beetles == 1)
        // A bite after a close that the fly fled counts the fly as escaped.
        let t: TrapSession = quiet()
        sippers(t, [.housefly, .ladybird])
        var g: Int = 0
        while g < 90 {
            _ = t.step(dt: frame, input: TrapInput(closure: 30, armed: true, angle: 120))
            g += 1
        }
        let r: BiteReport? = report(t.step(dt: frame, input: biteInput(0.3)))
        #expect(r?.caught == [.ladybird] && r?.escaped == 1, "\(String(describing: r))")
        #expect(abs((r?.catchRatio ?? 0) - 0.5) < 1e-9)
    }

    @Test func anyMissBreaksTheChain() {
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .housefly])
        _ = s.step(dt: frame, input: biteInput(0.1))
        run(s, 1)
        sippers(s, [.housefly, .housefly])
        _ = s.step(dt: frame, input: biteInput(0.1))
        #expect(s.snapshot.chain == 2)
        run(s, 1)
        sippers(s, [.housefly, .housefly, .ladybird])
        // 0.95 s: the ladybird is caught, both flies get away: a miss.
        let ev: [TrapEvent] = s.step(dt: frame, input: biteInput(0.95))
        #expect(report(ev)?.caught == [.ladybird])
        #expect(s.snapshot.chain == 0)
        let broken: Int = count(ev) { (e: TrapEvent) -> Bool in if case .chainBroken = e { return true }; return false }
        #expect(broken == 1)
    }

    // MARK: Shut = digesting; a round starts closed

    @Test func theClockIsFrozenWhileShut() {
        let s: TrapSession = quiet()
        sippers(s, [.housefly])
        let d: NectarDrop = s.snapshot.nectar[2]
        _ = s.step(dt: frame, input: biteInput(0.1))
        #expect(s.snapshot.shut)
        let t0: Double = s.snapshot.time
        // A bug scripted while shut does not move: nothing arrives, nothing ages.
        let id: Int = s.spawnScripted(.housefly, entry: CGPoint(x: -30, y: d.position.y), target: d.position,
                                      linger: .infinity)
        let shut: [TrapEvent] = run(s, 3, TrapInput(closure: 132, armed: false, angle: 18))
        #expect(abs(s.snapshot.time - t0) < 1e-9, "frozen at \(t0): \(s.snapshot.time)")
        let landed: Int = count(shut) { (e: TrapEvent) -> Bool in if case .bugLanded = e { return true }; return false }
        #expect(landed == 0)
        #expect(s.snapshot.hint == .openUp, "\"Open it again\" on the cover")
        // The caught fly finished its moment while shut.
        let others: Bool = s.snapshot.bugs.contains { (b: BugState) -> Bool in b.id != id }
        #expect(!others)
        // Reopened: rearmed, the clock runs.
        let open: [TrapEvent] = s.step(dt: frame, input: TrapInput())
        let rearmed: Int = count(open) { (e: TrapEvent) -> Bool in if case .rearmed = e { return true }; return false }
        #expect(rearmed == 1)
        #expect(!s.snapshot.shut)
        run(s, 1)
        #expect(s.snapshot.time > t0 + 0.9)
    }

    @Test func aRoundWaitsForItsFirstClose() {
        let s = TrapSession(mode: .feed, seed: 4, best: 0, geometry: geo, options: SessionOptions())
        #expect(s.snapshot.waitingForClose)
        let closed: [TrapEvent] = run(s, 5, TrapInput(closure: 0, armed: false, angle: 150))
        #expect(s.snapshot.waitingForClose)
        #expect(abs(s.snapshot.time) < 1e-12, "the clock is frozen")
        let waves: Int = count(closed) { (e: TrapEvent) -> Bool in if case .waveStarted = e { return true }; return false }
        #expect(waves == 0)
        #expect(s.snapshot.hint == nil)
        run(s, 3)
        #expect(!s.snapshot.waitingForClose)
        #expect(s.snapshot.time > 2.9)
        #expect(s.snapshot.wave >= 1, "the bugs come once it opens")
        // A touch round (armed at once) never waits; a bite also starts it.
        let t: TrapSession = quiet()
        _ = t.step(dt: frame, input: biteInput(0.12))
        #expect(!t.snapshot.waitingForClose)
    }

    // MARK: Input: the touch fallback is first-class

    @MainActor @Test func aTapIsAnInstantBite() {
        let touch = TouchTrapSource()
        touch.tap(at: 10)
        let first: TrapInput = touch.input(at: 10)
        #expect(first.snap != nil)
        if let d = first.snap?.duration { #expect(abs(d - Tuning.touchSnapTime) < 1e-12) }
        #expect(!first.armed)
        #expect(touch.input(at: 10.01).snap == nil)
        #expect(touch.input(at: 10 + Tuning.touchRearmDelay + 0.01).armed)
        // Played into a session: a bite, shut until the re-arm, then the clock runs again.
        let s: TrapSession = quiet()
        sippers(s, [.housefly])
        let t = TouchTrapSource()
        t.tap(at: 0)
        var bites: Int = 0
        var shutFrames: Int = 0
        var time: Double = 0
        while time < 1 {
            let inp: TrapInput = t.input(at: time)
            for e in s.step(dt: frame, input: inp) {
                if case .snapped = e { bites += 1 }
            }
            if s.snapshot.shut { shutFrames += 1 }
            time += frame
        }
        #expect(bites == 1)
        #expect(shutFrames > 20 && !s.snapshot.shut, "shut \(shutFrames) frames, then open")
        #expect(s.snapshot.lastBite?.caught == [.housefly])
    }

    // MARK: Levels (ROUND-8 §4)

    @Test func theLevelTableIsWellFormed() {
        #expect(LevelBook.all.count == 30)
        var i: Int = 0
        for l in LevelBook.all {
            i += 1
            #expect(l.id == i)
            #expect(l.world == (i <= 10 ? 1 : (i <= 20 ? 2 : 3)), "level \(i) world \(l.world)")
            #expect(!l.title.isEmpty && !l.goalText.isEmpty)
            #expect(!l.bugs.isEmpty)
            #expect(l.biteLimit != nil || l.timeLimit != nil, "level \(i) has a limit")
            if let b = l.biteLimit { #expect(b >= 1 && b <= Tuning.maxSnaps) }
            #expect(l.threeStarBites >= 1 && l.threeStarBites <= l.twoStarBites)
            for b in l.bugs { #expect(abs(b.u) >= 0.3 && abs(b.u) <= 1 && abs(b.v) <= 1 && b.linger > 0) }
            #expect(LevelBook.level(i) == l)
        }
        #expect(LevelBook.level(0) == nil && LevelBook.level(31) == nil)
        #expect(LevelBook.levels(inWorld: 2).count == 10)
        #expect(LevelBook.worldName(1) == "Morning Bog" && LevelBook.worldName(3) == "Night")
        // Levels 1–5 teach in order: one fly; fast; wait for two; a bee; a crowd of three.
        let l1: LevelSpec = LevelBook.all[0]
        #expect(l1.goal.catchAny == 1 && l1.bugs.count == 1)
        #expect(LevelBook.all[2].goal.biteOf == 2)
        let bee: Bool = LevelBook.all[3].bugs.contains { (b: LevelBug) -> Bool in b.species == .bee }
        #expect(LevelBook.all[3].noSting && bee)
        #expect(LevelBook.all[4].goal.biteOf == 3)
        // Night is harder: its pace waves are past the late-night start.
        let fast: Bool = LevelBook.levels(inWorld: 3).allSatisfy { (l: LevelSpec) -> Bool in
            l.paceWave >= Tuning.lateWaveStart
        }
        #expect(fast)
    }

    @Test func aLevelSessionPlaysItsScriptAndEndsAtTheGoal() {
        guard let s = LevelBook.session(id: 1, geometry: geo) else {
            Issue.record("no level 1")
            return
        }
        #expect(s.levelSpec?.id == 1)
        #expect(SessionOptions.for(.level(1)) == LevelBook.options(LevelBook.all[0]))
        #expect(s.snapshot.snapsLeft == 3)
        let ev: [TrapEvent] = run(s, 5)
        let arrived: Int = count(ev) { (e: TrapEvent) -> Bool in if case .bugArrived = e { return true }; return false }
        #expect(arrived == 1)
        let waves: Int = count(ev) { (e: TrapEvent) -> Bool in if case .waveStarted = e { return true }; return false }
        #expect(waves == 0, "scripted, never random waves")
        _ = s.step(dt: frame, input: biteInput(0.2))
        #expect(s.levelEnd == .goal)
        run(s, 3)
        #expect(s.isFinished)
        guard let r = s.result, let l = LevelBook.level(1) else {
            Issue.record("no result")
            return
        }
        let o: LevelOutcome = LevelBook.evaluate(r, l)
        #expect(o.passed && o.stars == 3, "\(o)")
        #expect(r.escapes == 0)
    }

    @Test func aBeeBittenInANoStingLevelFailsAtOnce() {
        guard let s = LevelBook.session(id: 4, geometry: geo), let l = LevelBook.level(4) else {
            Issue.record("no level 4")
            return
        }
        var f: Int = 0
        var beeIn: Bool = false
        while f < 60 * 6 && !beeIn {
            _ = s.step(dt: frame, input: TrapInput())
            beeIn = s.snapshot.bugs.contains { (b: BugState) -> Bool in
                if case .sipping = b.activity { return b.species == .bee }
                return false
            }
            f += 1
        }
        #expect(beeIn)
        _ = s.step(dt: frame, input: biteInput(0.2))
        #expect(s.levelEnd == .stung)
        run(s, 3)
        if let r = s.result {
            let o: LevelOutcome = LevelBook.evaluate(r, l)
            #expect(!o.passed && o.stars == 0 && o.line.contains("bee"), "\(o)")
        }
    }

    @Test func aLevelRefundsNothing() {
        guard let s = LevelBook.session(id: 5, geometry: geo) else { return }
        run(s, 6)
        let ev: [TrapEvent] = s.step(dt: frame, input: biteInput(0.2))
        let r: BiteReport? = report(ev)
        #expect((r?.caught.count ?? 0) >= 3)
        #expect(r?.snapsBack == 0, "a level's bite limit is literal")
    }

    private func levelResult(_ id: Int, snaps: Int, caught: [String: Int] = [:], bugs: Int = 0, biggest: Int = 0,
                             spared: Int = 0, stings: Int = 0, seconds: Double = 20,
                             escapes: Int? = 0) -> RunResult {
        return RunResult(mode: .level(id), seed: 1, score: 0, seconds: seconds, snaps: snaps, bugsCaught: bugs,
                         caughtBySpecies: caught, sparedBySpecies: [:], bestBitePoints: 0, biggestBite: biggest,
                         longestChain: 0, beesSpared: spared, stings: stings, feasts: 0, waves: 1, drySnaps: 0,
                         fastestSnap: 0, escapes: escapes)
    }

    @Test func evaluateEdgeCases() {
        guard let l1 = LevelBook.level(1), let l4 = LevelBook.level(4), let l16 = LevelBook.level(16),
              let l15 = LevelBook.level(15), let l27 = LevelBook.level(27) else {
            Issue.record("levels missing")
            return
        }
        // Stars by bites used: 1 star for passing, 2 at twoStarBites, 3 at threeStarBites.
        #expect(LevelBook.evaluate(levelResult(1, snaps: 1, bugs: 1, biggest: 1), l1).stars == 3)
        #expect(LevelBook.evaluate(levelResult(1, snaps: 2, bugs: 1, biggest: 1), l1).stars == 2)
        #expect(LevelBook.evaluate(levelResult(1, snaps: 3, bugs: 1, biggest: 1), l1).stars == 1)
        // Over the bite limit, or the goal not met: failed, 0 stars.
        let over: LevelOutcome = LevelBook.evaluate(levelResult(1, snaps: 4, bugs: 1, biggest: 1), l1)
        #expect(!over.passed && over.stars == 0)
        let none: LevelOutcome = LevelBook.evaluate(levelResult(1, snaps: 3), l1)
        #expect(!none.passed && none.line.contains("bites"), "\(none.line)")
        // A sting fails a no-sting level even with the goal met.
        let stung: LevelOutcome = LevelBook.evaluate(levelResult(4, snaps: 1, bugs: 2, biggest: 2, stings: 1), l4)
        #expect(!stung.passed && stung.line.contains("bee"))
        // A time limit: met in time passes; late fails with "time".
        #expect(LevelBook.evaluate(levelResult(16, snaps: 6, bugs: 10, biggest: 3, seconds: 39), l16).passed)
        let late: LevelOutcome = LevelBook.evaluate(levelResult(16, snaps: 6, bugs: 10, biggest: 3, seconds: 41), l16)
        #expect(!late.passed && late.line.contains("time"), "\(late.line)")
        let slow: LevelOutcome = LevelBook.evaluate(levelResult(16, snaps: 6, bugs: 8, biggest: 3, seconds: 40), l16)
        #expect(!slow.passed && slow.line.contains("time"), "\(slow.line)")
        // A clean three: bites alone are not enough when a bug escaped (nil escapes reads as 0).
        let caught3: [String: Int] = ["grasshopper": 3]
        #expect(l15.cleanForThree)
        let dirty: LevelOutcome = LevelBook.evaluate(levelResult(15, snaps: l15.threeStarBites, caught: caught3,
                                                                 bugs: 3, biggest: 1, escapes: 2), l15)
        #expect(dirty.passed && dirty.stars == 2, "\(dirty)")
        let legacy: LevelOutcome = LevelBook.evaluate(levelResult(15, snaps: l15.threeStarBites, caught: caught3,
                                                                  bugs: 3, biggest: 1, escapes: nil), l15)
        #expect(legacy.stars == 3)
        // Species goals count only those species; spare goals need the spares.
        let wrong: LevelOutcome = LevelBook.evaluate(levelResult(15, snaps: 2, caught: ["housefly": 3], bugs: 3,
                                                                 biggest: 3), l15)
        #expect(!wrong.passed)
        let spares: LevelOutcome = LevelBook.evaluate(levelResult(27, snaps: 1, bugs: 5, biggest: 5, spared: 1), l27)
        #expect(!spares.passed)
        #expect(LevelBook.evaluate(levelResult(27, snaps: 1, bugs: 5, biggest: 5, spared: 2), l27).passed)
    }

    @Test func levelsUnlockInOrderAndWorldsAtTwentyStars() {
        #expect(LevelBook.levelUnlocked(1, best: [:]))
        #expect(!LevelBook.levelUnlocked(2, best: [:]))
        #expect(LevelBook.levelUnlocked(2, best: [1: 1]))
        #expect(!LevelBook.worldUnlocked(2, best: [1: 3]))
        var best: [Int: Int] = [:]
        for id in 1...10 { best[id] = 2 }
        #expect(LevelBook.totalStars(best) == 20)
        #expect(LevelBook.worldUnlocked(2, best: best) && LevelBook.levelUnlocked(11, best: best))
        #expect(!LevelBook.worldUnlocked(3, best: best) && !LevelBook.levelUnlocked(21, best: best))
        #expect(LevelBook.totalStars([1: 9, 2: -1]) == 3, "clamped to 0…3 a level")
    }

    @Test func levelModesAreHandled() {
        let m: RunMode = .level(3)
        #expect(!TrapRules.keepsBest(m) && !TrapRules.lastLightApplies(to: m))
        #expect(TrapRules.nightCue(wave: Tuning.lateWaveStart + 1, mode: m) == nil)
        #expect(TrapRules.paceWave(40, mode: m) == 40)
        #expect(SessionOptions().sproutPerks(for: m) == nil)
        #expect(GoalScope.anyMode.includes(m) && !GoalScope.standard.includes(m))
        #expect(PlantRanks.growth(from: levelResult(3, snaps: 1, bugs: 4)) == 4)
        let o: SessionOptions = SessionOptions.for(.level(99))
        #expect(!o.waves && !o.hunger && !o.refunds)
    }
}
