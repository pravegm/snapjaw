import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Core rules (Round 1): detector, bite rule, economy, chain, waves, day, determinism, DailySeed, ranks,
// achievements, hints, the pilot.
// Round 2: bugs ×1.8 and the body rim test, hunger (hungry / wilted), the ≥ 2 chain rule, nectar clusters, crowd
// landings, SessionOptions.startSnaps, QA-1 #5 / #6 (detector), #12 (spared on escape) and #21 (caught height).

struct CoreTests {

    // MARK: Helpers

    private let geo = TrapGeometry(sceneSize: CGSize(width: 952, height: 670))
    private let frame: Double = 1.0 / 60.0

    /// A feed session without waves (bugs only by script).
    private func quiet(seed: UInt64 = 7, snapsRunOut: Bool = true, stingCosts: Bool = true,
                       best: Int = 0) -> TrapSession {
        let o = SessionOptions(snapsRunOut: snapsRunOut, waves: false, stingCosts: stingCosts)
        return TrapSession(mode: .feed, seed: seed, best: best, geometry: geo, options: o)
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

    private func entry(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: p.x < 476 ? -30 : 982, y: p.y)
    }

    /// One bug per nectar drop (in drop order), staying forever; then 6 s for them all to land and sip.
    @discardableResult
    private func sippers(_ s: TrapSession, _ species: [BugSpecies]) -> [Int] {
        let drops: [NectarDrop] = s.snapshot.nectar
        var ids: [Int] = []
        var k: Int = 0
        while k < species.count && k < drops.count {
            ids.append(s.spawnScripted(species[k], entry: entry(drops[k].position), target: drops[k].position,
                                       linger: .infinity))
            k += 1
        }
        run(s, 6)
        return ids
    }

    private func snap(_ s: TrapSession, _ duration: Double, angle: Double? = nil) -> [TrapEvent] {
        let input = TrapInput(closure: 22, armed: false, creeping: false,
                              snap: SnapTrigger(duration: duration, time: 0), tooFlat: false, angle: angle)
        return s.step(dt: frame, input: input)
    }

    private func count(_ events: [TrapEvent], _ match: (TrapEvent) -> Bool) -> Int {
        var n: Int = 0
        for e in events where match(e) { n += 1 }
        return n
    }

    private func report(_ events: [TrapEvent]) -> BiteReport? {
        for e in events {
            if case .snapped(let r) = e { return r }
        }
        return nil
    }

    private func activities(_ s: TrapSession) -> [BugActivity] {
        return s.snapshot.bugs.map { (b: BugState) -> BugActivity in b.activity }
    }

    private func allSipping(_ s: TrapSession) -> Bool {
        for b in s.snapshot.bugs {
            if case .sipping = b.activity { continue }
            return false
        }
        return true
    }

    /// Feeds a detector `angles` at 30 Hz from `start`; returns the triggers with their sample index.
    private func feed(_ d: inout SnapDetector, _ angles: [Double], start: Double) -> [(Int, SnapTrigger)] {
        var out: [(Int, SnapTrigger)] = []
        var i: Int = 0
        while i < angles.count {
            if let t = d.ingest(angle: angles[i], at: start + Double(i) / 30.0) { out.append((i, t)) }
            i += 1
        }
        return out
    }

    private func rest(_ d: inout SnapDetector, at angle: Double = 160, seconds: Double = 1) {
        let n: Int = Int(seconds * 30)
        var i: Int = 0
        while i <= n {
            _ = d.ingest(angle: angle, at: Double(i) / 30.0)
            i += 1
        }
    }

    private func result(mode: RunMode = .feed, score: Int = 0, caught: [String: Int] = [:], biggest: Int = 0,
                        chain: Int = 0, stings: Int = 0, feasts: Int = 0, waves: Int = 1,
                        bugs: Int = 0) -> RunResult {
        return RunResult(mode: mode, seed: 1, score: score, seconds: 100, snaps: 20, bugsCaught: bugs,
                         caughtBySpecies: caught, sparedBySpecies: [:], bestBitePoints: 0, biggestBite: biggest,
                         longestChain: chain, beesSpared: 0, stings: stings, feasts: feasts, waves: waves,
                         drySnaps: 0, fastestSnap: 0)
    }

    private func ids(_ defs: [AchievementDef]) -> Set<String> {
        return Set(defs.map { (a: AchievementDef) -> String in a.id })
    }

    // MARK: SeededRandom

    @Test func seededRandomIsDeterministicAndInRange() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        var i: Int = 0
        while i < 200 {
            let x: UInt64 = a.next()
            let y: UInt64 = b.next()
            #expect(x == y)
            let u: Double = a.unit()
            _ = b.unit()
            #expect(u >= 0 && u < 1)
            let k: Int = a.int(3...5)
            _ = b.int(3...5)
            #expect(k >= 3 && k <= 5)
            let r: Double = a.range(2.0...4.0)
            _ = b.range(2.0...4.0)
            #expect(r >= 2 && r < 4)
            i += 1
        }
        var c = SeededRandom(seed: 1)
        let single: Int = c.int(7...7)
        #expect(single == 7)
        var d = SeededRandom(seed: 9)
        var e = SeededRandom(seed: 9)
        let viaRange: Double = d.range(1.0...3.0)
        let viaBetween: Double = e.between(1, 3)
        #expect(abs(viaRange - viaBetween) < 1e-12)
    }

    // MARK: Tuning

    @Test func tuningMatchesTheDesign() {
        #expect(Tuning.snapDepth == 22)
        #expect(Tuning.snapStartDepth == 4)
        #expect(Tuning.creepDepth == 6)
        #expect(abs(Tuning.creepDwell - 0.45) < 1e-12)
        #expect(Tuning.rearmRise == 16)
        #expect(Tuning.rearmAngle == 150)
        #expect(abs(Tuning.refWindow - 0.6) < 1e-12)
        #expect(Tuning.refFallRate == 25)
        #expect(Tuning.creepWindow == 3)
        #expect(Tuning.creepRefFallRate == 6)
        #expect(Tuning.tooFlatAngle == 174)
        #expect(Tuning.closingAngle == 50)
        #expect(abs(Tuning.closingDwell - 0.6) < 1e-12)
        #expect(abs(Tuning.touchSnapTime - 0.09) < 1e-12)
        #expect(abs(Tuning.touchRearmDelay - 0.45) < 1e-12)
        #expect(Tuning.startSnaps == 10)
        #expect(Tuning.maxSnaps == 12)
        #expect(Tuning.noonWave == 7 && Tuning.duskWave == 15 && Tuning.nightWave == 23)
        // R2
        #expect(Tuning.wiltMorning == 15 && Tuning.wiltNoon == 14 && Tuning.wiltDusk == 12 && Tuning.wiltNight == 10)
        #expect(Tuning.hungryWarning == 3)
        #expect(Tuning.chainMinBite == 2)
        #expect(abs(Tuning.bugRadiusScale - 1.8) < 1e-12)
        #expect(Tuning.nectarMin == 6 && Tuning.nectarMax == 8)
        #expect(Tuning.nectarClusterMin == 2 && Tuning.nectarClusterMax == 3)
        #expect(TrapSession.wiltSeconds(.morning) == 15)
        #expect(TrapSession.wiltSeconds(.noon) == 14)
        #expect(TrapSession.wiltSeconds(.dusk) == 12)
        #expect(TrapSession.wiltSeconds(.night) == 10)
    }

    // MARK: SnapDetector

    @Test func fastSnapFiresOnceOnTheCrossingSample() {
        var d = SnapDetector()
        rest(&d)
        // 25° in 0.12 s at 30 Hz: 6.9°, 13.9°, 20.8°, 25° …
        var angles: [Double] = []
        var i: Int = 1
        while i <= 8 {
            angles.append(160 - min(25, 25 * (Double(i) / 30.0) / 0.12))
            i += 1
        }
        let fires: [(Int, SnapTrigger)] = feed(&d, angles, start: 1 + 1.0 / 30.0)
        #expect(fires.count == 1)
        if let f = fires.first {
            #expect(f.0 == 3, "fired on sample \(f.0)")
            #expect(f.1.duration >= 0.08 && f.1.duration <= 0.16, "duration \(f.1.duration)")
        }
        #expect(!d.armed)
        let inp: TrapInput = d.input(at: 1.3)
        #expect(inp.snap != nil)
        let again: TrapInput = d.input(at: 1.31)
        #expect(again.snap == nil, "the trigger is consumed once")
        #expect(inp.closure >= 22)
    }

    @Test func slowCloseCreepsAndNeverSnaps() {
        // Founder R1: 160 → 128 over 3 s creeps within ~1 s, reports the creep depth, and never snaps.
        var d = SnapDetector()
        rest(&d)
        var creepAt: Double = -1
        var fires: Int = 0
        var endClosure: Double = 0
        var i: Int = 1
        while i <= 90 {
            let t: Double = 1 + Double(i) / 30.0
            if d.ingest(angle: 160 - 32 * Double(i) / 90.0, at: t) != nil { fires += 1 }
            let inp: TrapInput = d.input(at: t + 0.001)
            if inp.snap != nil { fires += 1 }
            if inp.creeping && creepAt < 0 { creepAt = t - 1 }
            endClosure = inp.closure
            i += 1
        }
        #expect(fires == 0)
        #expect(creepAt > 0 && creepAt <= 1.2, "creeping at \(creepAt)")
        #expect(endClosure >= 15, "closure \(endClosure)")
        #expect(d.armed)
    }

    @Test func restingJitterNeverSnapsOrCreeps() {
        var d = SnapDetector()
        var r = SeededRandom(seed: 5)
        var bad: Int = 0
        var i: Int = 0
        while i < 600 {
            let t: Double = Double(i) / 30.0
            if d.ingest(angle: 160 + r.between(-1.5, 1.5), at: t) != nil { bad += 1 }
            let inp: TrapInput = d.input(at: t)
            if inp.creeping || inp.snap != nil { bad += 1 }
            i += 1
        }
        #expect(bad == 0)
    }

    @Test func restReferenceFollowsASlowDrift() {
        // 1.5 °/s drift for 10 s: the reference follows, no snap, no creep past the dwell.
        var d = SnapDetector()
        var fires: Int = 0
        var i: Int = 0
        while i <= 300 {
            let t: Double = Double(i) / 30.0
            if d.ingest(angle: 165 - 1.5 * t, at: t) != nil { fires += 1 }
            i += 1
        }
        #expect(fires == 0)
        let inp: TrapInput = d.input(at: 10.0)
        #expect(inp.closure < Tuning.snapStartDepth, "closure \(inp.closure)")
        #expect(abs(d.reference - 151) < 2, "reference \(d.reference)")
        #expect(!inp.creeping, "creep depth ~4.5° stays under 6°")
    }

    @Test func rearmsSixteenAboveTheLowestPoint() {
        var d = SnapDetector()
        rest(&d)
        let fires: [(Int, SnapTrigger)] = feed(&d, [154, 146, 138, 130, 126, 126, 130, 134, 138], start: 1 + 1.0 / 30.0)
        #expect(fires.count == 1)
        #expect(!d.armed, "138 is only 12° above 126")
        _ = d.ingest(angle: 142, at: 1.4)
        #expect(d.armed, "142 is 16° above 126")
        // A new snap is measured from the re-arm point.
        let second: [(Int, SnapTrigger)] = feed(&d, [136, 128, 119, 115], start: 1.4 + 1.0 / 30.0)
        #expect(second.count == 1)
    }

    @Test func rearmsAtOneFiftyAfterAShallowSnap() {
        var d = SnapDetector()
        rest(&d, at: 168)
        let fires: [(Int, SnapTrigger)] = feed(&d, [160, 152, 145, 144], start: 1 + 1.0 / 30.0)
        #expect(fires.count == 1)
        _ = d.ingest(angle: 148, at: 1.3)
        #expect(!d.armed)
        _ = d.ingest(angle: 150.5, at: 1.35)
        #expect(d.armed, "θ ≥ 150 and risen ≥ 4°")
    }

    @Test func overshootThenSettleNeverCreeps() {
        // QA-1 #5: snap, reopen past the rest (172°) and settle back (165°): never a creep.
        var d = SnapDetector()
        rest(&d, at: 165)
        var t: Double = 1
        var fires: Int = 0
        let path: [Double] = [155, 145, 138, 135, 140, 148, 156, 164, 170, 172, 171, 169, 167, 166, 165]
        for a in path {
            t += 1.0 / 30.0
            if d.ingest(angle: a, at: t) != nil { fires += 1 }
        }
        var creeping: Int = 0
        var i: Int = 0
        while i < 150 {
            t += 1.0 / 30.0
            _ = d.ingest(angle: 165 + (i % 2 == 0 ? -0.4 : 0.4), at: t)
            let inp: TrapInput = d.input(at: t)
            if inp.creeping { creeping += 1 }
            i += 1
        }
        #expect(fires == 1)
        #expect(creeping == 0, "creeping on \(creeping) frames")
        #expect(d.armed)
        #expect(d.creepDepth < Tuning.creepDepth, "creep depth \(d.creepDepth)")
    }

    @Test func snapAfterADriftIsTimedFromTheSnap() {
        // QA-1 #6: an 8 °/s drift keeps an attempt open (c ≈ 4.8°); a quick snap after it is timed from the snap.
        var d = SnapDetector()
        rest(&d, at: 165)
        var t: Double = 1
        var a: Double = 165
        var i: Int = 0
        while i < 60 {
            t += 1.0 / 30.0
            a -= 8.0 / 30.0
            _ = d.ingest(angle: a, at: t)
            i += 1
        }
        var duration: Double = -1
        i = 0
        while i < 4 {
            t += 1.0 / 30.0
            a -= 25.0 / 3.0
            if let r = d.ingest(angle: a, at: t), duration < 0 { duration = r.duration }
            i += 1
        }
        #expect(duration >= 0 && duration <= 0.15, "duration \(duration)")
    }

    @Test func tooFlatAndNoHinge() {
        var d = SnapDetector()
        let none: TrapInput = d.input(at: 0)
        #expect(none.angle == nil && none.closure == 0 && !none.tooFlat && none.armed)
        _ = d.ingest(angle: 176, at: 0)
        let flat: TrapInput = d.input(at: 0.01)
        #expect(flat.tooFlat)
        _ = d.ingest(angle: 170, at: 0.5)
        let ok: TrapInput = d.input(at: 0.51)
        #expect(!ok.tooFlat)
    }

    // MARK: Catalog and bite rule

    @Test func catalogHasSixteenInOrder() {
        #expect(BugCatalog.all.count == 16)
        var i: Int = 0
        for s in BugSpecies.allCases {
            #expect(BugCatalog.all[i].species == s)
            #expect(BugCatalog.info(s).species == s)
            #expect(!BugCatalog.info(s).joke.isEmpty && !BugCatalog.info(s).name.isEmpty)
            if s.isProtected { #expect(BugCatalog.info(s).points == 0) } else { #expect(BugCatalog.info(s).points > 0) }
            i += 1
        }
        let radii: [BugSpecies: CGFloat] = [.gnat: 7, .fruitFly: 9, .mosquito: 9, .ant: 10, .housefly: 14,
                                            .ladybird: 14, .firefly: 13, .moth: 18, .bluebottle: 16,
                                            .grasshopper: 18, .cricket: 17, .bee: 16, .bumblebee: 22, .wasp: 16,
                                            .dragonfly: 24, .goldenScarab: 20]
        // R2 (REVIEW-1 #4): the R1 art radii × 1.8, for the art and the rules alike.
        let scale: CGFloat = CGFloat(Tuning.bugRadiusScale)
        let tolerance: CGFloat = 0.001
        for (s, r) in radii {
            let want: CGFloat = r * scale
            #expect(abs(BugCatalog.info(s).radius - want) < tolerance, "\(s)")
        }
        let fly: CGFloat = BugCatalog.info(.housefly).radius
        #expect(abs(fly - CGFloat(25.2)) < tolerance, "housefly \(fly)")
        #expect(BugCatalog.info(.goldenScarab).points == 150)
        #expect(abs(BugCatalog.info(.dragonfly).reaction - 0.12) < 1e-12)
    }

    @Test func reactionFactors() {
        let fly: BugInfo = BugCatalog.info(.housefly)
        let base: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: false, wave: 1)
        #expect(abs(base - 0.24) < 1e-12)
        let sip: Double = TrapRules.reaction(fly, sipping: true, flying: false, onRim: false, wave: 1)
        #expect(abs(sip - 0.24 * 1.35) < 1e-12)
        let air: Double = TrapRules.reaction(fly, sipping: false, flying: true, onRim: false, wave: 1)
        #expect(abs(air - 0.24 * 0.55) < 1e-12)
        let rim: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: true, wave: 1)
        #expect(abs(rim - 0.24 * 0.6) < 1e-12)
        let all: Double = TrapRules.reaction(fly, sipping: true, flying: true, onRim: true, wave: 1)
        #expect(abs(all - 0.24 * 1.35 * 0.55 * 0.6) < 1e-12)
        let late: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: false, wave: 32)
        #expect(abs(late - 0.24 * 0.97 * 0.97) < 1e-9)
        let floor: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: false, wave: 400)
        #expect(abs(floor - 0.24 * 0.6) < 1e-9)
        #expect(TrapRules.isCandidate(.arriving, height: 0.5))
        #expect(!TrapRules.isCandidate(.arriving, height: 0.6))
        #expect(TrapRules.isCandidate(.hopping, height: 0.8))
        #expect(!TrapRules.isCandidate(.leaving, height: 0))
    }

    @Test func theRimTestUsesTheBugsBody() {
        // R2: a dragonfly (radius 43.2) centred at 0.78 reaches the rim band (its edge is at 0.88); a gnat does not.
        let p: CGPoint = geo.point(angle: 0, radius: 0.78)
        #expect(!geo.onRim(p))
        #expect(TrapRules.onRim(geo, p, radius: BugCatalog.info(.dragonfly).radius))
        #expect(!TrapRules.onRim(geo, p, radius: BugCatalog.info(.gnat).radius))
        #expect(!TrapRules.onRim(geo, geo.center, radius: 40), "the centre is never the rim")
        #expect(!TrapRules.onRim(geo, geo.point(angle: 1, radius: 1.05), radius: 10), "outside the trap")
        #expect(TrapRules.onRim(geo, geo.point(angle: 2, radius: 0.9), radius: 0), "radius 0 is the point test")
    }

    @Test func sippingBugIsCaughtByAFastEnoughSnap() {
        let s: TrapSession = quiet()
        sippers(s, [.housefly])
        #expect(allSipping(s))
        let ev: [TrapEvent] = snap(s, 0.30)
        let r: BiteReport? = report(ev)
        #expect(r?.caught == [.housefly])
        #expect(r?.points == 10)
        let n1: Int = count(ev) { (e: TrapEvent) -> Bool in if case .bugCaught = e { return true }; return false }
        #expect(n1 == 1)
        // The snapped event comes first.
        if let first = ev.first(where: { (e: TrapEvent) -> Bool in
            if case .snapped = e { return true }
            if case .bugCaught = e { return true }
            return false
        }) {
            if case .snapped = first {} else { Issue.record("snapped must precede bugCaught") }
        }
    }

    @Test func sippingBugEscapesASlowSnap() {
        let s: TrapSession = quiet()
        sippers(s, [.housefly])
        let ev: [TrapEvent] = snap(s, 0.33)
        let r: BiteReport? = report(ev)
        #expect(r?.caught.isEmpty == true)
        #expect(r?.escaped == 1)
        let n2: Int = count(ev) { (e: TrapEvent) -> Bool in if case .bugEscaped = e { return true }; return false }
        #expect(n2 == 1)
        let left: [BugActivity] = activities(s)
        #expect(left.count == 1)
        if let a = left.first {
            if case .escaped = a {} else { Issue.record("expected escaped, got \(a)") }
        }
    }

    @Test func walkingBugUsesTheBaseReaction() {
        let s: TrapSession = quiet()
        _ = s.spawnScripted(.housefly, entry: CGPoint(x: -30, y: 300), target: CGPoint(x: 300, y: 300),
                            linger: .infinity)
        run(s, 5)
        let b: BugState? = s.snapshot.bugs.first
        if let a = b?.activity {
            if case .walking = a {} else { Issue.record("expected walking, got \(a)") }
        }
        #expect(b?.onRim == false)
        let ev: [TrapEvent] = snap(s, 0.25)
        #expect(report(ev)?.escaped == 1, "0.25 > 0.24")
        let s2: TrapSession = quiet()
        _ = s2.spawnScripted(.housefly, entry: CGPoint(x: -30, y: 300), target: CGPoint(x: 300, y: 300),
                             linger: .infinity)
        run(s2, 5)
        let ev2: [TrapEvent] = snap(s2, 0.23)
        #expect(report(ev2)?.caught.count == 1)
    }

    // MARK: Economy

    @Test func drySnapCostsOneAndResetsTheChain() {
        let s: TrapSession = quiet()
        let ev: [TrapEvent] = snap(s, 0.1)
        let n3: Int = count(ev) { (e: TrapEvent) -> Bool in if case .drySnap = e { return true }; return false }
        #expect(n3 == 1)
        #expect(s.snapshot.snapsLeft == 9)
        #expect(s.snapshot.chain == 0)
    }

    @Test func tripleFeastRefundsOne() {
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .housefly, .housefly])
        let ev: [TrapEvent] = snap(s, 0.1)
        let r: BiteReport? = report(ev)
        #expect(r?.caught.count == 3)
        #expect(r?.points == 90, "30 points × 3 bugs × chain 1")
        #expect(r?.snapsBack == 1)
        #expect(s.snapshot.snapsLeft == 10)
        let n4: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .feast(let n, let back) = e { return n == 3 && back == 1 }
            return false
        }
        #expect(n4 == 1)
    }

    @Test func fiveFeastRefundsTwoAndSnapsCapAtTwelve() {
        let s: TrapSession = quiet()
        #expect(s.snapshot.nectar.count >= 6)
        sippers(s, [.housefly, .housefly, .housefly, .housefly, .housefly, .goldenScarab])
        let ev: [TrapEvent] = snap(s, 0.1)
        let r: BiteReport? = report(ev)
        #expect(r?.caught.count == 6)
        #expect(r?.snapsBack == 4, "big feast 2 + scarab 2")
        #expect(s.snapshot.snapsLeft == 12, "10 − 1 + 4 = 13, capped at 12")
        let n5: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .luckySnap(let sp) = e { return sp == .goldenScarab }
            return false
        }
        #expect(n5 == 1)
    }

    @Test func ladybirdRefundsOne() {
        let s: TrapSession = quiet()
        sippers(s, [.ladybird])
        _ = snap(s, 0.1)
        #expect(s.snapshot.snapsLeft == 10)
    }

    @Test func beeInTheBiteCostsOneMoreAndBreaksTheChain() {
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .housefly])
        _ = snap(s, 0.1)
        run(s, 1)
        sippers(s, [.housefly, .housefly])
        _ = snap(s, 0.1)
        #expect(s.snapshot.chain == 2)
        run(s, 1)
        sippers(s, [.housefly, .bee])
        let ev: [TrapEvent] = snap(s, 0.1)
        let r: BiteReport? = report(ev)
        #expect(r?.stingers == [.bee])
        #expect(r?.snapsLost == 1)
        let n6: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .stung(_, let sp, let cost) = e { return sp == .bee && cost == 1 }
            return false
        }
        #expect(n6 == 1)
        let n7: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .chainBroken(let n) = e { return n == 2 }
            return false
        }
        #expect(n7 == 1)
        #expect(s.snapshot.chain == 0)
        // 10 − 1 − 1 (two clean pair bites) − 1 − 1 (the bee bite)
        #expect(s.snapshot.snapsLeft == 6)
        let released: Bool = s.snapshot.bugs.contains { (b: BugState) -> Bool in
            if case .released = b.activity { return b.species == .bee }
            return false
        }
        #expect(released, "the bee is let go")
    }

    @Test func waspStingsForTwo() {
        let s: TrapSession = quiet()
        sippers(s, [.wasp])
        let ev: [TrapEvent] = snap(s, 0.1)
        #expect(report(ev)?.snapsLost == 2)
        #expect(s.snapshot.snapsLeft == 7)
    }

    @Test func lessonStingsCostNothing() {
        let s: TrapSession = quiet(snapsRunOut: false, stingCosts: false)
        sippers(s, [.bee])
        let ev: [TrapEvent] = snap(s, 0.1)
        #expect(report(ev)?.snapsLost == 0)
        #expect(s.snapshot.snapsLeft == Tuning.startSnaps)
    }

    @Test func chainGrowsOnBitesOfTwoHoldsOnOneAndBreaksOnADrySnap() {
        // R2 chain rule (GAME-DESIGN §5).
        let s: TrapSession = quiet()
        var points: [Int] = []
        var ups: Int = 0
        var k: Int = 0
        while k < 3 {
            sippers(s, [.housefly, .housefly])
            let ev: [TrapEvent] = snap(s, 0.1)
            points.append(report(ev)?.points ?? -1)
            ups += count(ev) { (e: TrapEvent) -> Bool in if case .chainUp = e { return true }; return false }
            run(s, 1)
            k += 1
        }
        #expect(points == [40, 60, 80], "20 points × 2 bugs × ×1, ×1.5, ×2")
        #expect(ups == 3)
        #expect(s.snapshot.chain == 3)
        #expect(abs(s.snapshot.chainMultiplier - 2.5) < 1e-12)
        // A clean 1-bug bite is scored at the chain's multiplier and holds it.
        sippers(s, [.housefly])
        let one: [TrapEvent] = snap(s, 0.1)
        #expect(report(one)?.points == 25, "10 × 1 × 2.5")
        let oneUps: Int = count(one) { (e: TrapEvent) -> Bool in if case .chainUp = e { return true }; return false }
        let oneBreaks: Int = count(one) { (e: TrapEvent) -> Bool in
            if case .chainBroken = e { return true }
            return false
        }
        #expect(oneUps == 0 && oneBreaks == 0)
        #expect(s.snapshot.chain == 3)
        run(s, 1)
        // A dry snap breaks it.
        let dry: [TrapEvent] = snap(s, 0.1)
        let broken: Int = count(dry) { (e: TrapEvent) -> Bool in
            if case .chainBroken(let n) = e { return n == 3 }
            return false
        }
        #expect(broken == 1)
        #expect(s.snapshot.chain == 0)
        #expect(s.partialResult().longestChain == 3)
        #expect(abs(TrapRules.chainMultiplier(6) - 4) < 1e-12)
        #expect(abs(TrapRules.chainMultiplier(20) - 4) < 1e-12)
    }

    @Test func tiredThenFinished() {
        let s: TrapSession = quiet(best: 0)
        var all: [TrapEvent] = []
        var k: Int = 0
        while k < 10 {
            all.append(contentsOf: snap(s, 0.1))
            k += 1
        }
        let n8: Int = count(all) { (e: TrapEvent) -> Bool in if case .lastSnap = e { return true }; return false }
        #expect(n8 == 1)
        let n9: Int = count(all) { (e: TrapEvent) -> Bool in if case .tired = e { return true }; return false }
        #expect(n9 == 1)
        if case .tired = s.snapshot.phase {} else { Issue.record("expected tired, got \(s.snapshot.phase)") }
        #expect(s.result == nil)
        let ev: [TrapEvent] = run(s, 3)
        #expect(s.isFinished)
        let n10: Int = count(ev) { (e: TrapEvent) -> Bool in if case .finished = e { return true }; return false }
        #expect(n10 == 1)
        #expect(s.result?.snaps == 10)
        #expect(s.result?.drySnaps == 10)
    }

    @Test func newBestFiresOnce() {
        let s: TrapSession = quiet(best: 15)
        sippers(s, [.housefly, .housefly])
        let ev: [TrapEvent] = snap(s, 0.1)
        let n11: Int = count(ev) { (e: TrapEvent) -> Bool in if case .newBest = e { return true }; return false }
        #expect(n11 == 1)
        run(s, 1)
        sippers(s, [.housefly])
        let ev2: [TrapEvent] = snap(s, 0.1)
        let n12: Int = count(ev2) { (e: TrapEvent) -> Bool in if case .newBest = e { return true }; return false }
        #expect(n12 == 0)
    }

    // MARK: Creep, spared, spacing

    @Test func creepSpooksTheTwitchyOnly() {
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .bumblebee])
        let ev: [TrapEvent] = s.step(dt: frame, input: TrapInput(closure: 8, armed: true, creeping: true))
        let n13: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .bugSpooked(_, let sp) = e { return sp == .housefly }
            return false
        }
        #expect(n13 == 1)
        let n14: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .bugSpooked(_, let sp) = e { return sp == .bumblebee }
            return false
        }
        #expect(n14 == 0)
        #expect(s.snapshot.hint == .quick)
    }

    @Test func aBeeThatLeavesIsSpared() {
        let s: TrapSession = quiet()
        let d: NectarDrop = s.snapshot.nectar[0]
        _ = s.spawnScripted(.bee, entry: entry(d.position), target: d.position, linger: 1)
        let ev: [TrapEvent] = run(s, 8)
        let n15: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .beeSpared(let sp) = e { return sp == .bee }
            return false
        }
        #expect(n15 == 1)
        #expect(s.snapshot.beesSpared == 1)
        #expect(s.snapshot.bugs.isEmpty)
    }

    @Test func aBeeThatEscapesASlowBiteIsSpared() {
        // QA-1 #12: a protected bug that escapes a slow bite left the trap uneaten, so it counts as spared.
        let s: TrapSession = quiet()
        sippers(s, [.bee])
        let ev: [TrapEvent] = snap(s, 2.0)
        let r: BiteReport? = report(ev)
        #expect(r?.stingers.isEmpty == true)
        #expect(r?.escaped == 1)
        let spared: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .beeSpared(let sp) = e { return sp == .bee }
            return false
        }
        #expect(spared == 1)
        #expect(s.snapshot.beesSpared == 1)
        #expect(s.partialResult().sparedBySpecies["bee"] == 1)
        run(s, 4)
        #expect(s.snapshot.beesSpared == 1, "counted once")
    }

    @Test func aBugCaughtInTheAirEasesDown() {
        // QA-1 #21: a bug caught while arriving keeps its height and eases down over the caught moment.
        let s: TrapSession = quiet()
        _ = s.spawnScripted(.housefly, entry: CGPoint(x: -30, y: 300), target: CGPoint(x: 300, y: 300),
                            linger: .infinity)
        var low: Bool = false
        var f: Int = 0
        while f < 600 && !low {
            _ = s.step(dt: frame, input: TrapInput())
            if let b = s.snapshot.bugs.first, case .arriving = b.activity, b.inTrap, b.height < 0.5, b.height > 0.2 {
                low = true
            }
            f += 1
        }
        #expect(low)
        let h0: Double = s.snapshot.bugs.first?.height ?? 0
        let ev: [TrapEvent] = snap(s, 0.05)
        #expect(report(ev)?.caught == [.housefly])
        let h1: Double = s.snapshot.bugs.first?.height ?? 0
        #expect(h1 > 0.1 && h1 <= h0 + 1e-9, "height \(h0) → \(h1)")
        run(s, 0.6)
        #expect(s.snapshot.bugs.isEmpty)
    }

    // MARK: Hunger (R2)

    @Test func aSnapWiltsAfterFifteenHungrySecondsInTheMorning() {
        let s: TrapSession = quiet()
        var t: Double = 0
        var hungryAt: [Double] = []
        var wiltAt: [Double] = []
        var hungryLeft: Double = -1
        var hintSeen: Bool = false
        var midHunger: Double = -1
        while t < 31 {
            let ev: [TrapEvent] = s.step(dt: frame, input: TrapInput())
            t += frame
            for e in ev {
                if case .hungry(let left) = e {
                    hungryAt.append(t)
                    hungryLeft = left
                }
                if case .wilted = e { wiltAt.append(t) }
            }
            if s.snapshot.hint == .hungry { hintSeen = true }
            if midHunger < 0 && t >= 7.5 - 1e-9 { midHunger = s.snapshot.hunger }
        }
        #expect(hungryAt.count == 2, "hungry at \(hungryAt)")
        #expect(wiltAt.count == 2, "wilted at \(wiltAt)")
        if let h = hungryAt.first { #expect(abs(h - 12) < 0.05, "hungry at \(h)") }
        if wiltAt.count == 2 {
            #expect(abs(wiltAt[0] - 15) < 0.05, "first wilt at \(wiltAt[0])")
            #expect(abs(wiltAt[1] - 30) < 0.05, "second wilt at \(wiltAt[1])")
        }
        #expect(abs(hungryLeft - 3) < 0.05, "secondsLeft \(hungryLeft)")
        #expect(abs(midHunger - 0.5) < 0.01, "hunger at 7.5 s \(midHunger)")
        #expect(hintSeen)
        #expect(s.snapshot.snapsLeft == 8)
    }

    @Test func onlyACatchFeedsTheTrap() {
        let s: TrapSession = quiet()
        run(s, 7.5)
        #expect(abs(s.snapshot.hunger - 0.5) < 0.01)
        let dry: [TrapEvent] = snap(s, 0.1)
        let dryCount: Int = count(dry) { (e: TrapEvent) -> Bool in if case .drySnap = e { return true }; return false }
        #expect(dryCount == 1)
        #expect(s.snapshot.hunger > 0.49, "a dry snap does not feed it")
        let a: [TrapEvent] = run(s, 7.6)
        let wiltA: Int = count(a) { (e: TrapEvent) -> Bool in if case .wilted = e { return true }; return false }
        #expect(wiltA == 1)
        #expect(s.snapshot.snapsLeft == 8, "10 − 1 (the dry snap) − 1 (the wilt)")
        sippers(s, [.housefly])
        let fed: [TrapEvent] = snap(s, 0.1)
        #expect(report(fed)?.caught.count == 1)
        #expect(s.snapshot.hunger < 0.01, "a catch feeds it")
        let b: [TrapEvent] = run(s, 14.5)
        let wiltB: Int = count(b) { (e: TrapEvent) -> Bool in if case .wilted = e { return true }; return false }
        #expect(wiltB == 0)
        let c: [TrapEvent] = run(s, 1)
        let wiltC: Int = count(c) { (e: TrapEvent) -> Bool in if case .wilted = e { return true }; return false }
        #expect(wiltC == 1)
    }

    @Test func aWiltCanEndTheRunAndWarnsOfTheLastSnap() {
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.startSnaps = 1
        let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
        #expect(s.snapshot.snapsLeft == 1)
        let ev: [TrapEvent] = run(s, 15.2)
        let wiltedToZero: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .wilted(let n) = e { return n == 0 }
            return false
        }
        #expect(wiltedToZero == 1)
        let tired: Int = count(ev) { (e: TrapEvent) -> Bool in if case .tired = e { return true }; return false }
        #expect(tired == 1)
        if case .tired = s.snapshot.phase {} else { Issue.record("expected tired, got \(s.snapshot.phase)") }
        run(s, 3)
        #expect(s.isFinished)
        if let secs = s.result?.seconds { #expect(abs(secs - 15) < 0.05, "seconds \(secs)") }

        var o2 = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o2.startSnaps = 2
        let s2 = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o2)
        let ev2: [TrapEvent] = run(s2, 15.2)
        let last: Int = count(ev2) { (e: TrapEvent) -> Bool in if case .lastSnap = e { return true }; return false }
        #expect(last == 1)
        #expect(s2.snapshot.snapsLeft == 1)
        #expect(s2.snapshot.hint == .lastSnap)
    }

    @Test func theLessonAttractAndHungerOffNeverWilt() {
        func wilts(_ ev: [TrapEvent]) -> Int {
            return count(ev) { (e: TrapEvent) -> Bool in
                if case .wilted = e { return true }
                if case .hungry = e { return true }
                return false
            }
        }
        let lesson = TrapSession(mode: .lesson, seed: 1, best: 0, geometry: geo, options: SessionOptions.for(.lesson))
        let l: [TrapEvent] = run(lesson, 40)
        #expect(wilts(l) == 0)
        #expect(lesson.snapshot.hunger == 0)
        let attract = TrapSession(mode: .attract, seed: 1, best: 0, geometry: geo,
                                  options: SessionOptions.for(.attract))
        let a: [TrapEvent] = run(attract, 40)
        #expect(wilts(a) == 0)
        #expect(attract.snapshot.snapsLeft == Tuning.startSnaps)
        var off = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        off.hunger = false
        let quietOff = TrapSession(mode: .feed, seed: 1, best: 0, geometry: geo, options: off)
        let q: [TrapEvent] = run(quietOff, 40)
        #expect(wilts(q) == 0)
        #expect(quietOff.snapshot.snapsLeft == Tuning.startSnaps)
        #expect(quietOff.snapshot.hint != .hungry)
    }

    @Test func startSnapsOption() {
        #expect(SessionOptions().startSnaps == nil)
        #expect(quiet().snapshot.snapsLeft == Tuning.startSnaps)
        let cases: [(Int, Int)] = [(12, 12), (20, 12), (0, 1), (5, 5)]
        for c in cases {
            var o = SessionOptions()
            o.startSnaps = c.0
            let s = TrapSession(mode: .feed, seed: 2, best: 0, geometry: geo, options: o)
            #expect(s.snapshot.snapsLeft == c.1, "startSnaps \(c.0)")
        }
    }

    @Test func landedBugsKeepTheirDistance() {
        let s: TrapSession = quiet()
        _ = s.spawnScripted(.housefly, entry: CGPoint(x: -30, y: 300), target: CGPoint(x: 300, y: 300),
                            linger: .infinity)
        _ = s.spawnScripted(.housefly, entry: CGPoint(x: -30, y: 320), target: CGPoint(x: 300, y: 300),
                            linger: .infinity)
        run(s, 5)
        let bs: [BugState] = s.snapshot.bugs
        #expect(bs.count == 2)
        if bs.count == 2 {
            let dist: Double = hypot(Double(bs[0].position.x - bs[1].position.x),
                                     Double(bs[0].position.y - bs[1].position.y))
            // R2: radius + radius + 4 with the ×1.8 radii (25.2 each) is 54.4.
            let need: Double = Double(BugCatalog.info(.housefly).radius) * 2 + Tuning.landSpacing
            #expect(dist >= need - 0.5, "landed \(dist) apart, need \(need)")
        }
    }

    @Test func scriptedBugArrivesLandsAndSips() {
        let s: TrapSession = quiet()
        let d: NectarDrop = s.snapshot.nectar[0]
        let id: Int = s.spawnScripted(.housefly, entry: entry(d.position), target: d.position, linger: .infinity)
        let ev: [TrapEvent] = run(s, 6)
        let n16: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .bugArrived(let i, _) = e { return i == id }
            return false
        }
        #expect(n16 == 1)
        let n17: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .bugLanded(let i, _, _, let inTrap) = e { return i == id && inTrap }
            return false
        }
        #expect(n17 == 1)
        let n18: Int = count(ev) { (e: TrapEvent) -> Bool in if case .bugSipping = e { return true }; return false }
        #expect(n18 == 1)
        #expect(s.snapshot.nectar[0].occupant == id)
        run(s, 20)
        #expect(s.snapshot.bugs.count == 1, "linger .infinity stays")
    }

    // MARK: Hints

    @Test func hintPriority() {
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .housefly, .housefly])
        _ = s.step(dt: frame, input: TrapInput())
        #expect(s.snapshot.hint == .crowd)
        _ = s.step(dt: frame, input: TrapInput(closure: 0, armed: true, creeping: true, tooFlat: true))
        #expect(s.snapshot.hint == .bendALittle)
        _ = s.step(dt: frame, input: TrapInput(closure: 0, armed: true, creeping: true))
        #expect(s.snapshot.hint == .quick)

        let b: TrapSession = quiet()
        sippers(b, [.housefly, .housefly, .housefly, .bee])
        _ = b.step(dt: frame, input: TrapInput())
        #expect(b.snapshot.hint == .beeInside, "a bee beats the crowd")

        let o: TrapSession = quiet()
        _ = snap(o, 0.1)
        run(o, 1.2, TrapInput(closure: 20, armed: false))
        #expect(o.snapshot.hint == .openUp)
        _ = o.step(dt: frame, input: TrapInput())
        #expect(o.snapshot.hint == nil)

        let l: TrapSession = quiet()
        var k: Int = 0
        while k < 9 {
            _ = snap(l, 0.1)
            k += 1
        }
        _ = l.step(dt: frame, input: TrapInput())
        #expect(l.snapshot.snapsLeft == 1)
        #expect(l.snapshot.hint == .lastSnap)

        // R2: hungry comes just after quick: it beats the crowd (and every hint below it), a creep beats it.
        let h: TrapSession = quiet()
        sippers(h, [.housefly, .housefly, .housefly])
        run(h, 6.2)
        #expect(h.snapshot.hint == .hungry, "12.2 s without a bite")
        _ = h.step(dt: frame, input: TrapInput(closure: 0, armed: true, creeping: true))
        #expect(h.snapshot.hint == .quick, "a creep beats hunger")
        _ = h.step(dt: frame, input: TrapInput())
        #expect(h.snapshot.hint == .hungry)
    }

    // MARK: Waves and the day

    @Test func dayPhasesByWave() {
        #expect(WaveFactory.phase(forWave: 0) == .morning)
        #expect(WaveFactory.phase(forWave: 1) == .morning)
        #expect(WaveFactory.phase(forWave: 6) == .morning)
        #expect(WaveFactory.phase(forWave: 7) == .noon)
        #expect(WaveFactory.phase(forWave: 14) == .noon)
        #expect(WaveFactory.phase(forWave: 15) == .dusk)
        #expect(WaveFactory.phase(forWave: 22) == .dusk)
        #expect(WaveFactory.phase(forWave: 23) == .night)
        #expect(WaveFactory.phase(forWave: 90) == .night)
    }

    @Test func wavesAreDeterministicAndFollowTheTable() {
        let nectar: [NectarDrop] = WaveFactory.nectar(seed: WaveFactory.nectarSeed(seed: 11, block: 0), geometry: geo)
        var seed: UInt64 = 1
        while seed <= 40 {
            var index: Int = 1
            while index <= 40 {
                let a: WaveSpec = WaveFactory.wave(seed: seed, index: index, geometry: geo, nectar: nectar)
                let b: WaveSpec = WaveFactory.wave(seed: seed, index: index, geometry: geo, nectar: nectar)
                #expect(a == b)
                #expect(a.index == index && a.phase == WaveFactory.phase(forWave: index))
                #expect(!a.bugs.isEmpty)
                #expect(a.bugs.count <= Tuning.maxWaveBugs + 1 + Tuning.maxProtectedPerWave)
                let protected: Int = a.bugs.filter { (x: SpawnSpec) -> Bool in x.species.isProtected }.count
                if index < Tuning.beeFromWave { #expect(protected == 0) }
                #expect(protected <= Tuning.maxProtectedPerWave)
                if index == 1 {
                    #expect(abs(a.delay - Tuning.firstWaveTime) < 1e-12)
                } else {
                    #expect(a.delay >= Tuning.waveDelayMin && a.delay <= Tuning.waveDelayMax)
                }
                for x in a.bugs {
                    #expect(BugCatalog.info(x.species).firstPhase <= a.phase || x.species == .goldenScarab)
                    if x.species == .ant || x.species == .ladybird { #expect(a.phase == .noon) }
                    let offEdge: Bool = x.entry.x <= 0 || x.entry.x >= 952 || x.entry.y <= 0 || x.entry.y >= 670
                    #expect(offEdge, "entry \(x.entry)")
                    if x.landsInTrap { #expect(geo.contains(x.target)) }
                    #expect(x.groupOffset >= 0 && x.groupOffset < 15)
                }
                index += 1
            }
            seed += 1
        }
    }

    @Test func nectarDropsSitInClustersOnTheLobes() {
        // R2 (REVIEW-1 #19): 6–8 drops in clusters of 2–3 on both lobes, off the crease.
        let cx: Double = Double(geo.center.x)
        var seed: UInt64 = 1
        while seed <= 50 {
            let drops: [NectarDrop] = WaveFactory.nectar(seed: seed, geometry: geo)
            #expect(drops.count >= 6 && drops.count <= 8)
            var left: Int = 0
            var k: Int = 0
            for d in drops {
                #expect(d.id == k)
                #expect(geo.normalizedRadius(d.position) <= 0.73)
                #expect(geo.lobe(of: d.position) != 0, "off the crease")
                #expect(abs(Double(d.position.x) - cx) >= Tuning.nectarCreaseClearance - 0.01)
                if geo.lobe(of: d.position) < 0 { left += 1 }
                #expect(d.radius >= 12 && d.radius <= 16)
                // Its cluster mates are 69–96 pt away; every other drop is further than 100 pt.
                var nearest: Double = Double.infinity
                var mates: Int = 0
                for o in drops where o.id != d.id {
                    let dist: Double = hypot(Double(o.position.x - d.position.x), Double(o.position.y - d.position.y))
                    nearest = min(nearest, dist)
                    if dist <= 100 { mates += 1 }
                }
                #expect(nearest >= 60 && nearest <= 97, "seed \(seed) drop \(d.id): nearest \(nearest)")
                #expect(mates >= 1 && mates <= 2, "seed \(seed) drop \(d.id): \(mates) mates")
                k += 1
            }
            #expect(left >= 2 && drops.count - left >= 2)
            seed += 1
        }
    }

    @Test func crowdWavesAreTimedToLandTogether() {
        // R2: in a crowd wave every flyer's start + flight time lies within crowdSpread + a gnat swarm's steps.
        let nectar: [NectarDrop] = WaveFactory.nectar(seed: WaveFactory.nectarSeed(seed: 11, block: 0), geometry: geo)
        let bound: Double = Tuning.crowdSpread + 4 * 0.08 + 1e-9
        var crowds: Int = 0
        var worst: Double = 0
        var seed: UInt64 = 1
        while seed <= 40 {
            var index: Int = Tuning.crowdFromWave
            while index <= 40 {
                let w: WaveSpec = WaveFactory.wave(seed: seed, index: index, geometry: geo, nectar: nectar)
                if w.crowd {
                    crowds += 1
                    var etas: [Double] = []
                    for x in w.bugs where !x.species.isProtected {
                        if let f = WaveFactory.flightTime(x) { etas.append(x.groupOffset + f) }
                    }
                    if let lo = etas.min(), let hi = etas.max() { worst = max(worst, hi - lo) }
                }
                index += 1
            }
            seed += 1
        }
        #expect(crowds > 100, "crowds \(crowds)")
        #expect(worst <= bound, "worst arrival spread \(worst)")
    }

    @Test func aCrowdWaveLandsWithinOnePointTwoSeconds() {
        // R2: fly real crowd waves in (scripted at their offsets) and time the landings.
        var checked: Int = 0
        var worst: Double = 0
        var seed: UInt64 = 1
        while seed <= 40 && checked < 12 {
            let drops: [NectarDrop] = quiet(seed: seed).snapshot.nectar
            var index: Int = Tuning.crowdFromWave
            while index <= 30 && checked < 12 {
                let w: WaveSpec = WaveFactory.wave(seed: seed, index: index, geometry: geo, nectar: drops)
                index += 1
                if !w.crowd { continue }
                let flyers: [SpawnSpec] = w.bugs.filter { (x: SpawnSpec) -> Bool in
                    !x.species.isProtected && WaveFactory.flightTime(x) != nil
                }
                // Stable by start time (ties keep the wave's order), as tools/balance-sim.js does.
                let order: [Int] = Array(0..<flyers.count).sorted { (i: Int, j: Int) -> Bool in
                    if flyers[i].groupOffset != flyers[j].groupOffset {
                        return flyers[i].groupOffset < flyers[j].groupOffset
                    }
                    return i < j
                }
                let specs: [SpawnSpec] = order.map { (i: Int) -> SpawnSpec in flyers[i] }
                if specs.count < 2 { continue }
                let s: TrapSession = quiet(seed: seed)
                var lands: [Double] = []
                var t: Double = 0
                var k: Int = 0
                var f: Int = 0
                while f < 60 * 15 {
                    while k < specs.count && specs[k].groupOffset <= t + 1e-9 {
                        _ = s.spawnScripted(specs[k].species, entry: specs[k].entry, target: specs[k].target,
                                            linger: .infinity)
                        k += 1
                    }
                    for e in s.step(dt: frame, input: TrapInput()) {
                        if case .bugLanded = e { lands.append(t) }
                    }
                    t += frame
                    f += 1
                }
                #expect(lands.count == specs.count, "seed \(seed) wave \(index - 1)")
                if let lo = lands.min(), let hi = lands.max() { worst = max(worst, hi - lo) }
                checked += 1
            }
            seed += 1
        }
        #expect(checked == 12)
        #expect(worst <= 1.2, "worst landing spread \(worst)")
    }

    /// Feed options with hunger off (nobody snaps in these tests, so the trap would otherwise wilt and tire).
    private func noHunger() -> SessionOptions {
        var o: SessionOptions = SessionOptions.for(.feed)
        o.hunger = false
        return o
    }

    @Test func theDayMovesThroughThePhases() {
        let s = TrapSession(mode: .feed, seed: 3, best: 0, geometry: geo, options: noHunger())
        let ev: [TrapEvent] = run(s, 120)
        var changes: [DayPhase] = []
        var waves: Int = 0
        for e in ev {
            if case .dayPhaseChanged(let p) = e { changes.append(p) }
            if case .waveStarted = e { waves += 1 }
        }
        #expect(changes == [.noon, .dusk, .night])
        #expect(waves == s.snapshot.wave && waves >= 23)
        #expect(s.snapshot.dayPhase == .night)
        #expect(s.snapshot.dayClock >= 3 && s.snapshot.dayClock <= 4)
        #expect(!s.isFinished, "nobody snapped and hunger is off: the run never tires")
    }

    @Test func dayClockIsMonotonic() {
        let s = TrapSession(mode: .feed, seed: 4, best: 0, geometry: geo, options: noHunger())
        var last: Double = 0
        var ok: Bool = true
        var f: Int = 0
        while f < 60 * 150 {
            _ = s.step(dt: frame, input: TrapInput())
            let c: Double = s.snapshot.dayClock
            if c < last - 1e-9 || c < 0 || c > 4 { ok = false }
            last = c
            f += 1
        }
        #expect(ok)
        #expect(last >= 3)
    }

    @Test func sameSeedSameRun() {
        let a = TrapSession(mode: .feed, seed: 99, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        let b = TrapSession(mode: .feed, seed: 99, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        var pa = TrapPilot(skill: .casual, seed: 5)
        var pb = TrapPilot(skill: .casual, seed: 5)
        var same: Bool = true
        var t: Double = 0
        var f: Int = 0
        while f < 60 * 60 {
            let oa: PilotOutput = pa.step(dt: frame, time: t, snapshot: a.snapshot)
            let ob: PilotOutput = pb.step(dt: frame, time: t, snapshot: b.snapshot)
            let ea: [TrapEvent] = a.step(dt: frame, input: oa.input)
            let eb: [TrapEvent] = b.step(dt: frame, input: ob.input)
            if ea != eb || a.snapshot != b.snapshot || oa != ob { same = false }
            t += frame
            f += 1
        }
        #expect(same)
        let c = TrapSession(mode: .feed, seed: 100, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        run(c, 20)
        let d = TrapSession(mode: .feed, seed: 99, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        run(d, 20)
        #expect(c.snapshot != d.snapshot, "different seeds differ")
    }

    @Test func optionsPerMode() {
        #expect(SessionOptions.for(.feed) == SessionOptions())
        #expect(SessionOptions.for(.daily(day: 3, scored: true)) == SessionOptions())
        #expect(SessionOptions.for(.attract).snapsRunOut == false)
        #expect(SessionOptions().hunger && SessionOptions().startSnaps == nil)
        #expect(SessionOptions.for(.feed).hunger)
        let lesson: SessionOptions = SessionOptions.for(.lesson)
        #expect(!lesson.snapsRunOut && !lesson.waves && !lesson.stingCosts)
        let l = TrapSession(mode: .lesson, seed: 1, best: 0, geometry: geo, options: lesson)
        let ev: [TrapEvent] = run(l, 10)
        let n19: Int = count(ev) { (e: TrapEvent) -> Bool in if case .waveStarted = e { return true }; return false }
        #expect(n19 == 0)
    }

    @Test func firstWaveOptionStartsLater() {
        var o = SessionOptions()
        o.firstWave = 23
        let s = TrapSession(mode: .feed, seed: 5, best: 0, geometry: geo, options: o)
        #expect(s.snapshot.dayPhase == .night)
        let ev: [TrapEvent] = run(s, 2)
        var first: Int = -1
        for e in ev {
            if case .waveStarted(let i, _) = e, first < 0 { first = i }
        }
        #expect(first == 23)
    }

    // MARK: Pilot

    @Test func pilotPlaysAttractForever() {
        let s = TrapSession(mode: .attract, seed: 7, best: 0, geometry: geo, options: SessionOptions.for(.attract))
        var p = TrapPilot(skill: .casual, seed: 7)
        var t: Double = 0
        var bites: Int = 0
        var durations: [Double] = []
        var f: Int = 0
        while f < 60 * 120 {
            let o: PilotOutput = p.step(dt: frame, time: t, snapshot: s.snapshot)
            if let sn = o.input.snap { durations.append(sn.duration) }
            for e in s.step(dt: frame, input: o.input) {
                if case .snapped = e { bites += 1 }
            }
            t += frame
            f += 1
        }
        #expect(!s.isFinished)
        #expect(bites >= 5, "bites \(bites)")
        #expect(s.snapshot.snapsLeft == Tuning.startSnaps)
        // Casual snaps take 0.14–0.24 s, or 0.3–0.45 s when it fumbles (R2).
        var fumbles: Int = 0
        for d in durations {
            let normal: Bool = d >= 0.13 && d <= 0.25
            let fumble: Bool = d >= 0.29 && d <= 0.46
            if fumble { fumbles += 1 }
            #expect(normal || fumble, "casual duration \(d)")
        }
        #expect(fumbles < durations.count, "most casual snaps are not fumbles")
    }

    @Test func perfectPilotSnapsAtEightyMilliseconds() {
        var p = TrapPilot(skill: .perfect, seed: 1)
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .housefly, .housefly])
        var t: Double = 0
        var fired: SnapTrigger? = nil
        var f: Int = 0
        while f < 120 && fired == nil {
            let o: PilotOutput = p.step(dt: frame, time: t, snapshot: s.snapshot)
            fired = o.input.snap
            _ = s.step(dt: frame, input: o.input)
            t += frame
            f += 1
        }
        #expect(fired != nil)
        if let d = fired?.duration { #expect(abs(d - 0.08) < 1e-6, "duration \(d)") }
    }

    // MARK: DailySeed

    @Test func dailyDayNumberIsUTC() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? utc.timeZone
        let start = Date(timeIntervalSince1970: 1_767_225_600)        // 2026-01-01 00:00:00 UTC
        let lastSecond = Date(timeIntervalSince1970: 1_767_311_999)   // 2026-01-01 23:59:59 UTC
        let next = Date(timeIntervalSince1970: 1_767_312_000)         // 2026-01-02 00:00:00 UTC
        let today = Date(timeIntervalSince1970: 1_793_102_400)        // 2026-10-27 12:00:00 UTC
        let before = Date(timeIntervalSince1970: 1_767_222_000)       // 2025-12-31 23:00:00 UTC
        #expect(DailySeed.dayNumber(for: start, calendar: utc) == 0)
        #expect(DailySeed.dayNumber(for: lastSecond, calendar: utc) == 0)
        #expect(DailySeed.dayNumber(for: next, calendar: utc) == 1)
        #expect(DailySeed.dayNumber(for: today, calendar: utc) == 299)
        #expect(DailySeed.dayNumber(for: before, calendar: utc) == -1)
        // The default calendar is UTC (everyone shares one Daily Bog).
        #expect(DailySeed.dayNumber(for: lastSecond) == 0)
        #expect(DailySeed.dayNumber(for: next) == 1)
        #expect(DailySeed.utcCalendar.timeZone.secondsFromGMT(for: today) == 0)
    }

    @Test func dailySeedsAreStableAndDistinct() {
        #expect(DailySeed.seed(day: 299) == DailySeed.seed(day: 299))
        var seen: Set<UInt64> = []
        var d: Int = -5
        while d < 400 {
            seen.insert(DailySeed.seed(day: d))
            d += 1
        }
        #expect(seen.count == 405)
    }

    // MARK: Ranks

    @Test func plantRanks() {
        #expect(PlantRanks.count == 12)
        #expect(PlantRanks.title(0) == "Sprout")
        #expect(PlantRanks.title(11) == "Bog Monarch")
        #expect(PlantRanks.title(99) == "Bog Monarch")
        #expect(PlantRanks.title(-3) == "Sprout")
        #expect(PlantRanks.rank(forLifetimeBugs: 0) == 0)
        #expect(PlantRanks.rank(forLifetimeBugs: 29) == 0)
        #expect(PlantRanks.rank(forLifetimeBugs: 30) == 1)
        #expect(PlantRanks.rank(forLifetimeBugs: 4_999) == 10)
        #expect(PlantRanks.rank(forLifetimeBugs: 5_000) == 11)
        #expect(PlantRanks.rank(forLifetimeBugs: 1_000_000) == 11)
        var i: Int = 1
        while i < PlantRanks.count {
            #expect(PlantRanks.threshold(i) > PlantRanks.threshold(i - 1))
            #expect(PlantRanks.rank(forLifetimeBugs: PlantRanks.threshold(i)) == i)
            i += 1
        }
        #expect(Set(PlantRanks.titles).count == 12)
    }

    // MARK: Achievements

    @Test func achievementsMatchTheStoreKit() {
        let expected: [String] = ["feast", "bite5", "chain4", "scarab", "dragonfly", "spare50", "bugbook", "monarch",
                                  "night", "daily", "score10k", "nobees"]
        #expect(Achievements.all.count == 12)
        let gotIDs: [String] = Achievements.all.map { (a: AchievementDef) -> String in a.id }
        let wantIDs: [String] = expected.map { (k: String) -> String in "snap.ach." + k }
        #expect(gotIDs == wantIDs)
        for a in Achievements.all {
            #expect(!a.title.isEmpty && a.title.count <= 30)
            #expect(!a.detail.isEmpty)
        }
        #expect(Achievements.all[2].title == "Four Times Hungry")
        #expect(Achievements.chainForMaxMultiplier == 7)
    }

    @Test func achievementThresholds() {
        func got(_ r: RunResult, bugs: Int = 0, spared: Int = 0, species: Int = 0) -> Set<String> {
            return ids(Achievements.earned(after: r, lifetimeBugs: bugs, lifetimeSpared: spared, speciesFound: species,
                                           alreadyEarned: []))
        }
        #expect(got(result()).isEmpty)
        #expect(got(result(feasts: 1)).contains("snap.ach.feast"))
        #expect(!got(result(biggest: 4)).contains("snap.ach.bite5"))
        #expect(got(result(biggest: 5)).contains("snap.ach.bite5"))
        #expect(!got(result(chain: 6)).contains("snap.ach.chain4"))
        #expect(got(result(chain: 7)).contains("snap.ach.chain4"))
        #expect(got(result(caught: ["goldenScarab": 1])).contains("snap.ach.scarab"))
        #expect(!got(result(caught: ["housefly": 9])).contains("snap.ach.scarab"))
        #expect(got(result(caught: ["dragonfly": 1])).contains("snap.ach.dragonfly"))
        #expect(!got(result(), spared: 49).contains("snap.ach.spare50"))
        #expect(got(result(), spared: 50).contains("snap.ach.spare50"))
        #expect(!got(result(), species: 15).contains("snap.ach.bugbook"))
        #expect(got(result(), species: 16).contains("snap.ach.bugbook"))
        #expect(!got(result(), bugs: 4_999).contains("snap.ach.monarch"))
        #expect(got(result(), bugs: 5_000).contains("snap.ach.monarch"))
        #expect(!got(result(waves: 22)).contains("snap.ach.night"))
        #expect(got(result(waves: 23)).contains("snap.ach.night"))
        #expect(!got(result(mode: .daily(day: 4, scored: false))).contains("snap.ach.daily"))
        #expect(got(result(mode: .daily(day: 4, scored: true))).contains("snap.ach.daily"))
        #expect(!got(result(score: 9_999)).contains("snap.ach.score10k"))
        #expect(got(result(score: 10_000)).contains("snap.ach.score10k"))
        #expect(!got(result(stings: 0, bugs: 29)).contains("snap.ach.nobees"))
        #expect(!got(result(stings: 1, bugs: 30)).contains("snap.ach.nobees"))
        #expect(got(result(stings: 0, bugs: 30)).contains("snap.ach.nobees"))
    }

    @Test func achievementsSkipAttractLessonAndEarned() {
        let big: RunResult = result(score: 50_000, biggest: 7, chain: 9, feasts: 5, waves: 40, bugs: 99)
        let attract: RunResult = result(mode: .attract, score: 50_000, biggest: 7, chain: 9, feasts: 5, waves: 40,
                                        bugs: 99)
        let lesson: RunResult = result(mode: .lesson, feasts: 1)
        #expect(Achievements.earned(after: attract, lifetimeBugs: 9_999, lifetimeSpared: 99, speciesFound: 16,
                                    alreadyEarned: []).isEmpty)
        #expect(Achievements.earned(after: lesson, lifetimeBugs: 0, lifetimeSpared: 0, speciesFound: 0,
                                    alreadyEarned: []).isEmpty)
        let first: [AchievementDef] = Achievements.earned(after: big, lifetimeBugs: 99, lifetimeSpared: 0,
                                                          speciesFound: 3, alreadyEarned: [])
        #expect(ids(first).contains("snap.ach.feast"))
        let again: [AchievementDef] = Achievements.earned(after: big, lifetimeBugs: 99, lifetimeSpared: 0,
                                                          speciesFound: 3, alreadyEarned: ids(first))
        #expect(again.isEmpty)
    }
}
