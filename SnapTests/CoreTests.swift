import CoreGraphics
import Foundation
import Testing
@testable import Snap

// MARK: - Core rules (Round 1): detector, bite rule, economy, chain, waves, day, determinism, DailySeed, ranks,
// achievements, hints, the pilot.
// Round 2: bugs ×1.8 and the body rim test, hunger (hungry / wilted), the ≥ 2 chain rule, nectar clusters, crowd
// landings, SessionOptions.startSnaps, QA-1 #5 / #6 (detector), #12 (spared on escape) and #21 (caught height).
// Round 3: nothing rests on the crease, hunger 18/16/14/12 s from the first landing, stinger bites ×1 with no refund,
// SessionOptions.freeFirstSting and Sprout run 1, tight nectar clusters, the ×5 chain cap at step 8, maxSnaps 14, and
// the deterministic pilot (its own clock, PilotRun's fixed steps).
// Round 4: the hunger clock ticks only with food in the trap and no bee (night 14 s), SessionOptions.firstRun (Feed
// only), the calm first morning, nothing low over the crease, and the 0.2 late reaction floor.
// Round 5: a protected bug pauses the clock from its final approach, the Sprout taper (SessionOptions.sprout(feedRun:),
// SproutPerks), and no bee entry under a Duo thumb.
// Round 6: the Zen Bog (options, free stings, the looping day, no score feats), the late night's cues and the last
// light, the halo rule for "Hungry… bite!", goals (pool, scopes, tracker, book, draws, rewards) and the Garden's varieties.
// Round 7: the ×2 FEAST multiplier, one scoring function in every mode, the night pool (fireflies and crickets), the
// late decays 0.955 / 0.91, goal tiers, and sessions' keep-out rects (Scene's HUD zones).
// Round 8: the R1–R7 detector (22° partial snaps, the creep), the creep spook and the closing pause are gone, with
// their tests. The bite rule is the R8 exposure rule (TrapRules.modelExposure); the new hinge, fear, shut, level and
// economy rules are tested in CoreR8Tests.swift. The quiet sessions here start with 10 snaps (R1–R7's start), so the
// economy arithmetic below reads as before.

struct CoreTests {

    // MARK: Helpers

    private let geo = TrapGeometry(sceneSize: CGSize(width: 952, height: 670))
    private let frame: Double = 1.0 / 60.0

    /// A feed session without waves (bugs only by script).
    private func quiet(seed: UInt64 = 7, snapsRunOut: Bool = true, stingCosts: Bool = true,
                       best: Int = 0) -> TrapSession {
        var o = SessionOptions(snapsRunOut: snapsRunOut, waves: false, stingCosts: stingCosts)
        o.startSnaps = 10
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

    /// R8: the slowest close (s) that still catches a resting `species` in a quiet session (the morning, wave 0).
    private func slowest(_ species: BugSpecies, sipping: Bool) -> Double {
        let info: BugInfo = BugCatalog.info(species)
        let r: Double = TrapRules.reaction(info, sipping: sipping, flying: false, onRim: false, wave: 0)
        let frac: Double = min(max((info.nerve - Tuning.closeStart) / Tuning.modelCloseSpan, 0), 1)
        return r / (1 - frac)
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
        // R8 (the founder's hinge rules): armed at 35°, the shut zone ≤ 18° (.closed ≤ 25°), a close from 8°.
        #expect(Tuning.armAngle == 35 && Tuning.shutAngle == 18 && Tuning.statusShutAngle == 25)
        #expect(Tuning.shutAngle < Tuning.statusShutAngle && Tuning.statusShutAngle < Tuning.armAngle)
        #expect(Tuning.closeStart == 8 && Tuning.closeCancel == 4 && Tuning.reopenCancel == 10)
        #expect(abs(Tuning.modelCloseSpan - (Tuning.pilotIdleAngle - Tuning.shutAngle - Tuning.closeStart)) < 1e-12)
        #expect(abs(Tuning.refWindow - 0.6) < 1e-12)
        #expect(Tuning.refFallRate == 25)
        #expect(abs(Tuning.touchSnapTime - 0.12) < 1e-12)
        #expect(abs(Tuning.touchRearmDelay - 0.45) < 1e-12)
        #expect(Tuning.startSnaps == 12)
        #expect(Tuning.missBreaksChain && Tuning.dryBiteCost == 0)
        #expect(Tuning.noonWave == 7 && Tuning.duskWave == 15 && Tuning.nightWave == 23)
        // R2
        #expect(Tuning.hungryWarning == 3)
        #expect(Tuning.chainMinBite == 2)
        #expect(abs(Tuning.bugRadiusScale - 1.8) < 1e-12)
        #expect(Tuning.nectarMin == 6 && Tuning.nectarMax == 8)
        #expect(Tuning.nectarClusterMin == 2 && Tuning.nectarClusterMax == 3)
        // R3 (the founder's economy numbers, ROUND-3)
        #expect(Tuning.maxSnaps == 14)
        #expect(abs(Tuning.chainMaxMultiplier - 5) < 1e-12)
        #expect(TrapRules.chainSteps(toReach: 5) == 8, "×5 at step 8")
        #expect(TrapRules.chainSteps(toReach: 4) == 6)
        // R8 (ROUND-8 §2): faster hunger from noon on: 18/14/12/12.
        #expect(Tuning.wiltMorning == 18 && Tuning.wiltNoon == 14 && Tuning.wiltDusk == 12 && Tuning.wiltNight == 12)
        #expect(TrapSession.wiltSeconds(.morning) == 18)
        #expect(TrapSession.wiltSeconds(.noon) == 14)
        #expect(TrapSession.wiltSeconds(.dusk) == 12)
        #expect(TrapSession.wiltSeconds(.night) == 12)
        #expect(Tuning.creaseClearance == 16)
        #expect(Tuning.nectarRingMin == 24 && Tuning.nectarRingMax == 30)
        #expect(abs(Tuning.pilotStep - 1.0 / 60.0) < 1e-12)
        // R4
        #expect(Tuning.firstRunSnaps == 14 && Tuning.firstRunSnaps <= Tuning.maxSnaps)
        #expect(Tuning.firstRunCalmWaves == 14)
        #expect(abs(Tuning.firstRunWaveGap - 1.6) < 1e-12)
        // R7 (#14): 0.955 and 0.91 (R3–R6: 0.96 and 0.92).
        #expect(abs(Tuning.lateReactionDecay - 0.955) < 1e-12 && abs(Tuning.lateReactionFloor - 0.2) < 1e-12)
        #expect(abs(Tuning.lateLingerDecay - 0.91) < 1e-12 && abs(Tuning.lateLingerFloor - 0.2) < 1e-12)
        #expect(Tuning.extraBeeEvery == 40)
        #expect(abs(Tuning.creaseAirHeight - 0.5) < 1e-12)
        #expect(Tuning.creaseAirHeight <= 1 - Tuning.approachHeightDrop, "an approach never flies lower than this")
        #expect(Tuning.creaseAirHeight <= Tuning.crossHeight)
        // R5 (REVIEW-4 #8 and #15, founder calls)
        #expect(Tuning.sproutRun2Snaps == 13 && Tuning.sproutRun3Snaps == 12 && Tuning.sproutTaperRuns == 3)
        #expect(Tuning.sproutRun2Snaps <= Tuning.firstRunSnaps && Tuning.sproutRun3Snaps <= Tuning.sproutRun2Snaps)
        #expect(abs(Tuning.thumbBandWidth - 90) < 1e-12)
        #expect(abs(Tuning.thumbBandLow - 0.25) < 1e-12 && abs(Tuning.thumbBandHigh - 0.75) < 1e-12)
        // R6
        #expect(Tuning.lastLightWave == 85 && Tuning.zenDayWaves == 28)
        #expect(abs(Tuning.haloScale - 1.6) < 1e-12 && abs(Tuning.haloPad - 4) < 1e-12)
        #expect(Tuning.goalsActive == 3 && Tuning.goalRecentMemory == 6 && Tuning.goalMinSnaps == 5)
    }

    // MARK: SnapDetector: R8's rules are tested in CoreR8Tests.swift (the R1–R7 partial-snap tests are gone).

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
        #expect(abs(BugCatalog.info(.dragonfly).reaction - 0.22) < 1e-12)
        // R8: nerve is the startle depth: nervy flies ~12°, ants and beetles ~45°.
        #expect(BugCatalog.info(.housefly).nerve == 12 && BugCatalog.info(.ant).nerve == 45)
    }

    @Test func reactionFactors() {
        // R8: housefly 0.5 s; noon (wave 7) has no morning factor.
        let fly: BugInfo = BugCatalog.info(.housefly)
        let base: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: false, wave: 7)
        #expect(abs(base - 0.5) < 1e-12)
        let sip: Double = TrapRules.reaction(fly, sipping: true, flying: false, onRim: false, wave: 7)
        #expect(abs(sip - 0.5 * 1.35) < 1e-12)
        let air: Double = TrapRules.reaction(fly, sipping: false, flying: true, onRim: false, wave: 7)
        #expect(abs(air - 0.5 * 0.55) < 1e-12)
        let rim: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: true, wave: 7)
        #expect(abs(rim - 0.5 * 0.6) < 1e-12)
        let all: Double = TrapRules.reaction(fly, sipping: true, flying: true, onRim: true, wave: 7)
        #expect(abs(all - 0.5 * 1.35 * 0.55 * 0.6) < 1e-12)
        // R8: the sleepy morning (waves before noon) × Tuning.morningReactionFactor.
        let morning: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: false, wave: 1)
        #expect(abs(morning - 0.5 * Tuning.morningReactionFactor) < 1e-12)
        let late: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: false, wave: 32)
        // R3/R4: × lateReactionDecay (R7: 0.955) per wave after 30, to the Tuning floor (0.2 since R4).
        #expect(abs(late - 0.5 * 0.955 * 0.955) < 1e-9)
        let floor: Double = TrapRules.reaction(fly, sipping: false, flying: false, onRim: false, wave: 400)
        #expect(abs(floor - 0.5 * Tuning.lateReactionFloor) < 1e-9)
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
        // R8: caught when the modelled exposure is within the sipping reaction (quiet sessions: the morning).
        let ev: [TrapEvent] = snap(s, slowest(.housefly, sipping: true) * 0.97)
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
        let ev: [TrapEvent] = snap(s, slowest(.housefly, sipping: true) * 1.03)
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
        let limit: Double = slowest(.housefly, sipping: false)
        let ev: [TrapEvent] = snap(s, limit * 1.03)
        #expect(report(ev)?.escaped == 1, "past \(limit)")
        let s2: TrapSession = quiet()
        _ = s2.spawnScripted(.housefly, entry: CGPoint(x: -30, y: 300), target: CGPoint(x: 300, y: 300),
                             linger: .infinity)
        run(s2, 5)
        let ev2: [TrapEvent] = snap(s2, limit * 0.97)
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

    @Test func fiveFeastRefundsTwoAndSnapsCapAtFourteen() {
        // R3 (REVIEW-2 #23): the cap is 14 (two rows of 7), so a Sprout's 12-snap start keeps its first refunds.
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.startSnaps = 12
        let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
        #expect(s.snapshot.snapsMax == 14)
        #expect(s.snapshot.nectar.count >= 6)
        sippers(s, [.housefly, .housefly, .housefly, .housefly, .housefly, .goldenScarab])
        let ev: [TrapEvent] = snap(s, 0.1)
        let r: BiteReport? = report(ev)
        #expect(r?.caught.count == 6)
        #expect(r?.snapsBack == 4, "big feast 2 + scarab 2")
        #expect(s.snapshot.snapsLeft == 14, "12 − 1 + 4 = 15, capped at 14")
        let t: TrapSession = quiet()
        sippers(t, [.housefly, .housefly, .housefly])
        _ = snap(t, 0.1)
        #expect(t.snapshot.snapsLeft == 10, "10 − 1 + 1")
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
        // R3 (REVIEW-2 #8): a stung bite scores ×1, not at the chain's ×2.
        #expect(r?.points == 10, "10 × 1 bug × 1")
        #expect(r?.chainMultiplier == 1)
        #expect(r?.snapsBack == 0)
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
        #expect(s.snapshot.snapsLeft == 10, "the quiet session's 10")
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
        // R3 (REVIEW-2 #22): the cap is ×5, at step 8.
        #expect(abs(TrapRules.chainMultiplier(7) - 4.5) < 1e-12)
        #expect(abs(TrapRules.chainMultiplier(8) - 5) < 1e-12)
        #expect(abs(TrapRules.chainMultiplier(20) - 5) < 1e-12)
    }

    @Test func theChainCapsAtFiveTimesAtTheEighthStep() {
        // R3 (REVIEW-2 #22): nine clean pair bites score ×1, ×1.5 … ×4.5, ×5; the 8th step reports ×5.
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.startSnaps = 12
        let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
        var points: [Int] = []
        var lastUp: Double = 0
        var k: Int = 0
        while k < 9 {
            sippers(s, [.housefly, .housefly])
            let ev: [TrapEvent] = snap(s, 0.1)
            points.append(report(ev)?.points ?? -1)
            for e in ev {
                if case .chainUp(let n, let m) = e, n == 8 { lastUp = m }
            }
            run(s, 1)
            k += 1
        }
        #expect(points == [40, 60, 80, 100, 120, 140, 160, 180, 200], "20 points × 2 bugs × ×1 … ×5")
        #expect(abs(lastUp - 5) < 1e-12, "the 8th step is ×5")
        #expect(s.snapshot.chain == 9)
        #expect(abs(s.snapshot.chainMultiplier - 5) < 1e-12, "capped")
    }

    @Test func aStingerBiteScoresTimesOneAndRefundsNothing() {
        // R3 (REVIEW-2 #8): no Feast, scarab or ladybird refund in a bite with a stinger; it scores ×1; the sting
        // cost stays. Before R3 this bite was net +1 snap.
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .housefly])
        _ = snap(s, 0.1)
        run(s, 1)
        #expect(s.snapshot.chain == 1)
        #expect(s.snapshot.snapsLeft == 9)
        sippers(s, [.housefly, .housefly, .ladybird, .goldenScarab, .bumblebee])
        let ev: [TrapEvent] = snap(s, 0.1)
        let r: BiteReport? = report(ev)
        #expect(r?.caught.count == 4)
        #expect(r?.stingers == [.bumblebee])
        #expect(r?.points == 740, "(10 + 10 + 15 + 150) × 4 bugs × 1, not × 1.5")
        #expect(r?.chainMultiplier == 1)
        #expect(r?.snapsBack == 0, "no Feast, ladybird or scarab snaps")
        #expect(r?.snapsLost == 1)
        #expect(s.snapshot.snapsLeft == 7, "9 − 1 − 1")
        let feasts: Int = count(ev) { (e: TrapEvent) -> Bool in if case .feast = e { return true }; return false }
        let lucky: Int = count(ev) { (e: TrapEvent) -> Bool in if case .luckySnap = e { return true }; return false }
        #expect(feasts == 0 && lucky == 0)
        #expect(s.partialResult().feasts == 0)
        #expect(s.partialResult().biggestBite == 4)
        #expect(s.snapshot.chain == 0, "a stinger breaks the chain")
        // A wasp in the bite still stings for 2.
        let w: TrapSession = quiet()
        sippers(w, [.housefly, .housefly, .housefly, .wasp])
        let we: [TrapEvent] = snap(w, 0.1)
        #expect(report(we)?.snapsBack == 0)
        #expect(report(we)?.snapsLost == 2)
        #expect(w.snapshot.snapsLeft == 7, "10 − 1 − 2, no Feast")
    }

    @Test func freeFirstStingWaivesOnlyTheFirstStingerBite() {
        // R3 (REVIEW-2 #9): Sprout run 1's first bee costs 0 (the App's "Bees cost a snap!" keys on stung cost 0).
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.freeFirstSting = true
        let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
        sippers(s, [.housefly, .bee])
        let first: [TrapEvent] = snap(s, 0.1)
        #expect(report(first)?.stingers == [.bee])
        #expect(report(first)?.snapsLost == 0)
        #expect(report(first)?.points == 10, "still × 1")
        let waived: Int = count(first) { (e: TrapEvent) -> Bool in
            if case .stung(_, let sp, let cost) = e { return sp == .bee && cost == 0 }
            return false
        }
        #expect(waived == 1)
        #expect(s.snapshot.snapsLeft == 9, "10 − 1 only")
        run(s, 1)
        sippers(s, [.housefly, .bee])
        let second: [TrapEvent] = snap(s, 0.1)
        #expect(report(second)?.snapsLost == 1)
        #expect(s.snapshot.snapsLeft == 7, "9 − 1 − 1")
        #expect(SessionOptions().freeFirstSting == false)
        // Without the option the first bee costs 1.
        let n: TrapSession = quiet()
        sippers(n, [.housefly, .bee])
        _ = snap(n, 0.1)
        #expect(n.snapshot.snapsLeft == 8)
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

    /// R3: spawns one `species` at nectar drop `drop` (staying for `linger`) and steps until it lands in the trap.
    /// Returns the session time it landed at (−1 if it never did within 10 s).
    @discardableResult
    private func landOne(_ s: TrapSession, _ species: BugSpecies = .housefly, drop: Int = 0,
                         linger: Double = .infinity) -> Double {
        let d: NectarDrop = s.snapshot.nectar[drop]
        let id: Int = s.spawnScripted(species, entry: entry(d.position), target: d.position, linger: linger)
        var f: Int = 0
        while f < 600 {
            let ev: [TrapEvent] = s.step(dt: frame, input: TrapInput())
            for e in ev {
                if case .bugLanded(let i, _, _, let inTrap) = e, i == id, inTrap { return s.snapshot.time }
            }
            f += 1
        }
        return -1
    }

    private func wiltCount(_ ev: [TrapEvent]) -> Int {
        return count(ev) { (e: TrapEvent) -> Bool in if case .wilted = e { return true }; return false }
    }

    @Test func anEmptyTrapNeverGetsHungry() {
        // R3 (REVIEW-2 #7): the clock waits for the first catchable bug to land in the trap; a bee doesn't count.
        let s: TrapSession = quiet()
        let a: [TrapEvent] = run(s, 40)
        let hungry: Int = count(a) { (e: TrapEvent) -> Bool in if case .hungry = e { return true }; return false }
        #expect(hungry == 0 && wiltCount(a) == 0)
        #expect(s.snapshot.hunger == 0)
        let landedAt: Double = landOne(s, .bee)
        #expect(landedAt > 0)
        let b: [TrapEvent] = run(s, 30)
        #expect(wiltCount(b) == 0, "a bee alone is not food")
        #expect(s.snapshot.hunger == 0)
        #expect(s.snapshot.snapsLeft == 10)
    }

    @Test func aSnapWiltsEighteenSecondsAfterTheFirstLandingInTheMorning() {
        // R3: wilt 18 s in the morning, counted from the first in-trap landing; hungry 3 s before; it repeats.
        let s: TrapSession = quiet()
        run(s, 5)
        let t0: Double = landOne(s)
        #expect(t0 > 5)
        #expect(s.snapshot.hunger < 0.01)
        var hungryAt: [Double] = []
        var wiltAt: [Double] = []
        var hungryLeft: Double = -1
        var hintSeen: Bool = false
        var midHunger: Double = -1
        var f: Int = 0
        while f < 60 * 37 {
            let ev: [TrapEvent] = s.step(dt: frame, input: TrapInput())
            let t: Double = s.snapshot.time - t0
            for e in ev {
                if case .hungry(let left) = e {
                    hungryAt.append(t)
                    hungryLeft = left
                }
                if case .wilted = e { wiltAt.append(t) }
            }
            if s.snapshot.hint == .hungry { hintSeen = true }
            if midHunger < 0 && t >= 9 - 1e-9 { midHunger = s.snapshot.hunger }
            f += 1
        }
        #expect(hungryAt.count == 2, "hungry at \(hungryAt)")
        #expect(wiltAt.count == 2, "wilted at \(wiltAt)")
        if let h = hungryAt.first { #expect(abs(h - 15) < 0.05, "hungry at \(h)") }
        if wiltAt.count == 2 {
            #expect(abs(wiltAt[0] - 18) < 0.05, "first wilt at \(wiltAt[0])")
            #expect(abs(wiltAt[1] - 36) < 0.05, "second wilt at \(wiltAt[1]): the clock keeps running")
        }
        #expect(abs(hungryLeft - 3) < 0.05, "secondsLeft \(hungryLeft)")
        #expect(abs(midHunger - 0.5) < 0.01, "hunger 9 s after landing \(midHunger)")
        #expect(hintSeen)
        #expect(s.snapshot.snapsLeft == 8)
    }

    @Test func onlyACatchFeedsTheTrapAndAnEmptyTrapPausesTheClock() {
        // R4 (QA-2 #1): a miss doesn't feed the trap, but the empty trap after it never gets hungrier.
        let s: TrapSession = quiet()
        landOne(s)
        run(s, 9)
        #expect(abs(s.snapshot.hunger - 0.5) < 0.02)
        // A slow snap misses (the fly escapes): no catch, so the level stays, and the empty trap pauses the clock.
        let miss: [TrapEvent] = snap(s, 1.0)
        #expect(report(miss)?.caught.isEmpty == true)
        let afterMiss: Double = s.snapshot.hunger
        #expect(afterMiss > 0.49, "a miss does not feed it")
        let dry: [TrapEvent] = snap(s, 0.1)
        let dryCount: Int = count(dry) { (e: TrapEvent) -> Bool in if case .drySnap = e { return true }; return false }
        #expect(dryCount == 1)
        let a: [TrapEvent] = run(s, 30)
        #expect(wiltCount(a) == 0, "an empty trap never wilts")
        let paused: Double = s.snapshot.hunger
        #expect(abs(paused - afterMiss) < 1e-9, "the level holds while the trap is empty")
        #expect(s.snapshot.hint != .hungry)
        #expect(s.snapshot.snapsLeft == 8, "10 − 1 (the miss) − 1 (the dry snap)")
        // The next landing carries on from the held level: about 9 s later a snap wilts.
        landOne(s)
        let b: [TrapEvent] = run(s, 8.6)
        #expect(wiltCount(b) == 0)
        let c: [TrapEvent] = run(s, 0.8)
        #expect(wiltCount(c) == 1)
        #expect(s.snapshot.snapsLeft == 7)
        // A catch feeds it: hunger 0, and 30 s of empty trap after it never wilts.
        let fed: [TrapEvent] = snap(s, 0.1)
        #expect(report(fed)?.caught.count == 1)
        #expect(s.snapshot.hunger < 0.01, "a catch feeds it")
        let d: [TrapEvent] = run(s, 30)
        #expect(wiltCount(d) == 0, "the clock waits for food")
        #expect(s.snapshot.hunger == 0)
        // The next landing starts it again from 0: 18 s later a snap wilts.
        landOne(s)
        let e: [TrapEvent] = run(s, 17.8)
        #expect(wiltCount(e) == 0)
        let g: [TrapEvent] = run(s, 0.4)
        #expect(wiltCount(g) == 1)
    }

    @Test func aBeeInTheTrapPausesTheClock() {
        // R4 (REVIEW-3 #12, founder call): a bee-plus-flies trap never gets hungrier; waiting the bee out is right.
        let s: TrapSession = quiet()
        landOne(s, .housefly, drop: 0)
        run(s, 6)
        let before: Double = s.snapshot.hunger
        #expect(before > 0.3, "6 s of an 18 s morning \(before)")
        let beeAt: Double = landOne(s, .bee, drop: 3, linger: 6)
        #expect(beeAt > 0)
        let landed: Double = s.snapshot.hunger
        let a: [TrapEvent] = run(s, 5)
        #expect(wiltCount(a) == 0)
        let held: Double = s.snapshot.hunger
        #expect(abs(held - landed) < 1e-9, "paused while the bee sits: \(landed) → \(held)")
        #expect(s.snapshot.hint == .beeInside)
        // The bee leaves (6 s linger): the fly is still there, so the clock goes on.
        run(s, 3)
        let gone: Bool = !s.snapshot.bugs.contains { (b: BugState) -> Bool in b.species == .bee && b.inTrap }
        #expect(gone, "the bee left")
        let later: Double = s.snapshot.hunger
        #expect(later > landed + 0.01, "ticking again once the bee is gone")
        // The QA-2 #1 case: a fly and a bee, the fly leaves, the bee stays: the bee alone never wilts a snap.
        let q: TrapSession = quiet()
        landOne(q, .housefly, drop: 0, linger: 4)
        landOne(q, .bee, drop: 3)
        let ev: [TrapEvent] = run(q, 40)
        #expect(wiltCount(ev) == 0, "only the bee is left: never hungrier")
        let hungry: Int = count(ev) { (e: TrapEvent) -> Bool in if case .hungry = e { return true }; return false }
        #expect(hungry == 0)
        #expect(q.snapshot.snapsLeft == 10)
    }

    @Test func aBeeOnItsFinalApproachPausesTheClock() {
        // R5 (REVIEW-4 #5, founder call): a protected bug counts as in the trap from its final approach: inside the
        // zone and below Tuning.creaseAirHeight (its hover down, with the halo drawn). Higher up it doesn't (the deep
        // night's always-arriving bees), and the hungry hint follows the clock.
        #expect(TrapSession.protectedCountsAsIn(landed: true, height: 0))
        #expect(TrapSession.protectedCountsAsIn(landed: false, height: 0.2))
        #expect(!TrapSession.protectedCountsAsIn(landed: false, height: Tuning.creaseAirHeight))
        #expect(!TrapSession.protectedCountsAsIn(landed: false, height: 0.9))
        let s: TrapSession = quiet()
        landOne(s, .housefly, drop: 0)
        run(s, 15.1)
        #expect(s.snapshot.hint == .hungry, "15.1 s of an 18 s morning")
        let d: NectarDrop = s.snapshot.nectar[3]
        let beeID: Int = s.spawnScripted(.bee, entry: entry(d.position), target: d.position, linger: .infinity)
        var highFrames: Int = 0
        var highTicks: Int = 0
        var highHungry: Int = 0
        var lowFrames: Int = 0
        var lowMoves: Int = 0
        var lowHungry: Int = 0
        var prevLow: Bool = false
        var prevHigh: Bool = false
        var prevHunger: Double = s.snapshot.hunger
        var down: Bool = false
        var f: Int = 0
        while f < 600 && !down {
            let ev: [TrapEvent] = s.step(dt: frame, input: TrapInput())
            #expect(wiltCount(ev) == 0)
            let shot: TrapSnapshot = s.snapshot
            guard let bee = shot.bugs.first(where: { (b: BugState) -> Bool in b.id == beeID }) else { break }
            var arriving: Bool = false
            if case .arriving = bee.activity { arriving = true }
            let low: Bool = bee.inTrap && arriving && bee.height < Tuning.creaseAirHeight
            let high: Bool = bee.inTrap && arriving && bee.height >= Tuning.creaseAirHeight
            let level: Double = shot.hunger
            if low && prevLow {
                lowFrames += 1
                if abs(level - prevHunger) > 1e-12 { lowMoves += 1 }
                if shot.hint == .hungry { lowHungry += 1 }
            }
            if high && prevHigh {
                highFrames += 1
                if level > prevHunger + 1e-9 { highTicks += 1 }
                if shot.hint == .hungry { highHungry += 1 }
            }
            if !arriving && lowFrames > 0 { down = true }
            prevLow = low
            prevHigh = high
            prevHunger = level
            f += 1
        }
        #expect(down, "the bee landed")
        #expect(highFrames >= 10 && highTicks == highFrames,
                "high in the zone: the clock ticks (\(highTicks) of \(highFrames) frames)")
        #expect(highHungry == highFrames, "and the hungry hint stays")
        #expect(lowFrames >= 10 && lowMoves == 0, "below creaseAirHeight: paused (\(lowMoves) of \(lowFrames) moved)")
        #expect(lowHungry == 0, "no hungry hint beside a bee on its final approach")
        #expect(s.snapshot.hint == .beeInside)
    }

    @Test func theHungryHintShowsOnlyWhileTheClockTicks() {
        // R4: "Hungry… bite!" once the clock passes 15 s, gone while the trap is empty, back when food lands again.
        let s: TrapSession = quiet()
        landOne(s, .housefly, drop: 0, linger: 16)
        var seen: Bool = false
        var f: Int = 0
        while f < 60 * 16 && !seen {
            _ = s.step(dt: frame, input: TrapInput())
            if s.snapshot.hint == .hungry { seen = true }
            f += 1
        }
        #expect(seen, "hungry 15 s after landing")
        run(s, 3)
        let inTrap: Int = s.snapshot.bugs.filter { (b: BugState) -> Bool in b.inTrap }.count
        #expect(inTrap == 0, "the fly left")
        #expect(s.snapshot.hint != .hungry, "the fly left: the clock is paused")
        landOne(s, .housefly, drop: 1)
        _ = s.step(dt: frame, input: TrapInput())
        #expect(s.snapshot.hint == .hungry, "food again, and the warning with it")
    }

    @Test func aWiltCanEndTheRunAndWarnsOfTheLastSnap() {
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.startSnaps = 1
        let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
        #expect(s.snapshot.snapsLeft == 1)
        let t0: Double = landOne(s)
        let ev: [TrapEvent] = run(s, 18.2)
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
        if let secs = s.result?.seconds { #expect(abs(secs - (t0 + 18)) < 0.05, "seconds \(secs)") }

        var o2 = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o2.startSnaps = 2
        let s2 = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o2)
        landOne(s2)
        let ev2: [TrapEvent] = run(s2, 18.2)
        let last: Int = count(ev2) { (e: TrapEvent) -> Bool in if case .lastSnap = e { return true }; return false }
        #expect(last == 1)
        #expect(s2.snapshot.snapsLeft == 1)
        #expect(s2.snapshot.hint == .lastSnap)
    }

    @Test func sproutRunOneNeverWilts() {
        // R3 (REVIEW-2 #9): the R3 Sprout run 1 switches (12 snaps, hunger off, the first sting free) still work.
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.startSnaps = 12
        o.hunger = false
        o.freeFirstSting = true
        let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
        landOne(s)
        let ev: [TrapEvent] = run(s, 60)
        #expect(wiltCount(ev) == 0)
        #expect(s.snapshot.hunger == 0)
        #expect(s.snapshot.snapsLeft == 12)
    }

    @Test func firstRunGivesTheSproutPerksInFeedOnly() {
        // R4 (REVIEW-3 #11, QA-2 #11, founder call): SessionOptions.firstRun: 14 snaps (over startSnaps), never wilts,
        // the first stinger bite is free. The Daily ignores it (everyone's bog stays standard).
        #expect(SessionOptions().firstRun == false)
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.startSnaps = 12
        o.firstRun = true
        #expect(o.firstRunApplies(to: .feed))
        #expect(!o.firstRunApplies(to: .daily(day: 3, scored: true)))
        #expect(!o.firstRunApplies(to: .attract) && !o.firstRunApplies(to: .lesson))
        #expect(!SessionOptions().firstRunApplies(to: .feed))
        let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
        #expect(s.firstRunPerks)
        #expect(s.snapshot.snapsLeft == 14, "the max, whatever startSnaps says")
        sippers(s, [.housefly, .bee])
        let first: [TrapEvent] = snap(s, 0.1)
        #expect(report(first)?.snapsLost == 0, "the first sting is free")
        #expect(s.snapshot.snapsLeft == 13)
        landOne(s, .housefly, drop: 2)
        let ev: [TrapEvent] = run(s, 60)
        #expect(wiltCount(ev) == 0, "a first run never wilts")
        #expect(s.snapshot.hunger == 0)
        // The same options on the Daily: standard rules (the first bee costs 1, hunger on).
        let d = TrapSession(mode: .daily(day: 3, scored: true), seed: 7, best: 0, geometry: geo, options: o)
        #expect(!d.firstRunPerks)
        #expect(d.snapshot.snapsLeft == 12, "the Daily keeps the options' own startSnaps (the App passes nil)")
        sippers(d, [.housefly, .bee])
        let ds: [TrapEvent] = snap(d, 0.1)
        #expect(report(ds)?.snapsLost == 1, "no free sting on the Daily")
        landOne(d, .housefly, drop: 2)
        let dv: [TrapEvent] = run(d, 18.5)
        #expect(wiltCount(dv) == 1, "the Daily wilts")
    }

    @Test func aFirstRunHasACalmMorning() {
        // R4 (REVIEW-3 #11): a first run's waves 1…14 are crowds and come firstRunWaveGap × further apart; past the
        // calm stretch the wave recipes are the standard ones.
        let seed: UInt64 = 1000
        var calm = SessionOptions()
        calm.firstRun = true
        calm.hunger = false
        let s = TrapSession(mode: .feed, seed: seed, best: 0, geometry: geo, options: calm)
        var startedAt: [Int: Double] = [:]
        var f: Int = 0
        while f < 60 * 140 && startedAt[17] == nil && !s.isFinished {
            let ev: [TrapEvent] = s.step(dt: frame, input: TrapInput())
            for e in ev {
                if case .waveStarted(let i, _) = e { startedAt[i] = s.snapshot.time }
            }
            f += 1
        }
        var k: Int = 1
        while k <= 16 {
            if let a = startedAt[k], let b = startedAt[k + 1] {
                let base: Double = WaveFactory.delay(seed: seed, index: k + 1)
                let want: Double = k <= Tuning.firstRunCalmWaves ? base * Tuning.firstRunWaveGap : base
                #expect(abs((b - a) - want) < 0.03, "gap after wave \(k): \(b - a), want \(want)")
            } else {
                Issue.record("wave \(k) or \(k + 1) never started")
            }
            k += 1
        }
        // The recipes: crowds through wave 14, then identical to a standard run's.
        let drops: [NectarDrop] = WaveFactory.nectar(seed: WaveFactory.nectarSeed(seed: seed, block: 0), geometry: geo)
        var i: Int = 1
        while i <= 20 {
            let plain: WaveSpec = WaveFactory.wave(seed: seed, index: i, geometry: geo, nectar: drops)
            let gentle: WaveSpec = WaveFactory.wave(seed: seed, index: i, geometry: geo, nectar: drops, calm: true)
            if i <= Tuning.firstRunCalmWaves {
                #expect(gentle.crowd, "calm wave \(i) is a crowd")
            } else {
                #expect(gentle == plain, "wave \(i) is standard")
            }
            #expect(gentle.phase == plain.phase)
            i += 1
        }
    }

    @Test func theSproutPerksTaperOverThreeFeedRuns() {
        // R5 (REVIEW-4 #8, founder call): run 1 has 14 snaps, no wilt, a free sting and the calm morning; run 2 has 13
        // snaps, a free sting and the calm morning; run 3 has 12 snaps and the calm morning; from run 4, standard.
        #expect(SproutPerks.forFeedRun(1) == SproutPerks(run: 1, startSnaps: 14, noWilt: true, freeSting: true,
                                                         calmMorning: true))
        #expect(SproutPerks.forFeedRun(2) == SproutPerks(run: 2, startSnaps: 13, noWilt: false, freeSting: true,
                                                         calmMorning: true))
        #expect(SproutPerks.forFeedRun(3) == SproutPerks(run: 3, startSnaps: 12, noWilt: false, freeSting: false,
                                                         calmMorning: true))
        #expect(SproutPerks.forFeedRun(4) == nil)
        #expect(SproutPerks.forFeedRun(0) == nil && SproutPerks.forFeedRun(-2) == nil)
        // The options: sprout(feedRun:) is the Feed options plus sproutRun; R4's firstRun is sproutRun 1.
        let one: SessionOptions = SessionOptions.sprout(feedRun: 1)
        let two: SessionOptions = SessionOptions.sprout(feedRun: 2)
        #expect(one.firstRun && one.sproutRun == 1)
        #expect(!two.firstRun && two.sproutRun == 2)
        #expect(SessionOptions.sprout(feedRun: 4) == SessionOptions.for(.feed))
        #expect(SessionOptions.sprout(feedRun: 0) == SessionOptions())
        var legacy = SessionOptions()
        legacy.firstRun = true
        #expect(legacy == one, "R4's firstRun = true is Sprout run 1")
        legacy.firstRun = false
        #expect(legacy == SessionOptions())
        var keep: SessionOptions = two
        keep.firstRun = false
        #expect(keep.sproutRun == 2, "clearing firstRun leaves a run-2 taper alone")
        #expect(two.sproutPerks(for: .feed)?.run == 2)
        #expect(two.sproutPerks(for: .daily(day: 3, scored: true)) == nil)
        #expect(two.sproutPerks(for: .attract) == nil && two.sproutPerks(for: .lesson) == nil)
        // Sessions, as the App builds them (startSnaps 12 while the rank is Sprout): snaps, the first bee, the wilt.
        let wantSnaps: [Int] = [14, 13, 12, 12]
        var feedRun: Int = 1
        while feedRun <= 4 {
            var o: SessionOptions = SessionOptions.sprout(feedRun: feedRun)
            o.waves = false
            o.startSnaps = 12
            let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
            let start: Int = wantSnaps[feedRun - 1]
            #expect(s.snapshot.snapsLeft == start, "run \(feedRun) starts with \(start)")
            #expect(s.sproutPerks == SproutPerks.forFeedRun(feedRun))
            #expect(s.firstRunPerks == (feedRun == 1))
            sippers(s, [.housefly, .bee])
            let first: [TrapEvent] = snap(s, 0.1)
            let lost: Int = feedRun <= 2 ? 0 : Tuning.beeCost
            #expect(report(first)?.snapsLost == lost, "run \(feedRun): the first bee costs \(lost)")
            #expect(s.snapshot.snapsLeft == start - 1 - lost)
            landOne(s, .housefly, drop: 2)
            let ev: [TrapEvent] = run(s, 18.5)
            #expect(wiltCount(ev) == (feedRun == 1 ? 0 : 1), "run \(feedRun) wilts: \(feedRun != 1)")
            feedRun += 1
        }
        // The Daily ignores the taper (everyone's bog stays standard).
        let daily = TrapSession(mode: .daily(day: 3, scored: true), seed: 7, best: 0, geometry: geo, options: two)
        #expect(daily.sproutPerks == nil && !daily.firstRunPerks)
        #expect(daily.snapshot.snapsLeft == Tuning.startSnaps)
    }

    @Test func sproutRunsOneToThreeHaveTheCalmMorning() {
        // R5 (REVIEW-4 #8): the calm morning (gaps × firstRunWaveGap after waves 1…14) is on for runs 1–3, off from 4.
        let seed: UInt64 = 1000
        var feedRun: Int = 1
        while feedRun <= 4 {
            var o: SessionOptions = SessionOptions.sprout(feedRun: feedRun)
            o.hunger = false
            let s = TrapSession(mode: .feed, seed: seed, best: 0, geometry: geo, options: o)
            var startedAt: [Int: Double] = [:]
            var f: Int = 0
            while f < 60 * 30 && startedAt[3] == nil && !s.isFinished {
                let ev: [TrapEvent] = s.step(dt: frame, input: TrapInput())
                for e in ev {
                    if case .waveStarted(let i, _) = e { startedAt[i] = s.snapshot.time }
                }
                f += 1
            }
            var k: Int = 1
            while k <= 2 {
                if let a = startedAt[k], let b = startedAt[k + 1] {
                    let base: Double = WaveFactory.delay(seed: seed, index: k + 1)
                    let want: Double = feedRun <= 3 ? base * Tuning.firstRunWaveGap : base
                    #expect(abs((b - a) - want) < 0.03, "run \(feedRun), gap after wave \(k): \(b - a), want \(want)")
                } else {
                    Issue.record("run \(feedRun): wave \(k) or \(k + 1) never started")
                }
                k += 1
            }
            feedRun += 1
        }
    }

    @Test func theLessonAttractAndHungerOffNeverWilt() {
        func alarms(_ ev: [TrapEvent]) -> Int {
            return count(ev) { (e: TrapEvent) -> Bool in
                if case .wilted = e { return true }
                if case .hungry = e { return true }
                return false
            }
        }
        let lesson = TrapSession(mode: .lesson, seed: 1, best: 0, geometry: geo, options: SessionOptions.for(.lesson))
        landOne(lesson)
        let l: [TrapEvent] = run(lesson, 40)
        #expect(alarms(l) == 0)
        #expect(lesson.snapshot.hunger == 0)
        let attract = TrapSession(mode: .attract, seed: 1, best: 0, geometry: geo,
                                  options: SessionOptions.for(.attract))
        let a: [TrapEvent] = run(attract, 40)
        #expect(alarms(a) == 0)
        #expect(attract.snapshot.snapsLeft == Tuning.startSnaps)
        var off = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        off.hunger = false
        let quietOff = TrapSession(mode: .feed, seed: 1, best: 0, geometry: geo, options: off)
        landOne(quietOff)
        let q: [TrapEvent] = run(quietOff, 40)
        #expect(alarms(q) == 0)
        #expect(quietOff.snapshot.snapsLeft == Tuning.startSnaps)
        #expect(quietOff.snapshot.hint != .hungry)
    }

    @Test func startSnapsOption() {
        #expect(SessionOptions().startSnaps == nil)
        #expect(quiet().snapshot.snapsLeft == 10, "the tests' quiet session")
        let standard = TrapSession(mode: .feed, seed: 2, best: 0, geometry: geo, options: SessionOptions())
        #expect(standard.snapshot.snapsLeft == Tuning.startSnaps)
        // R3: clamped to 1…14 (Tuning.maxSnaps).
        let cases: [(Int, Int)] = [(12, 12), (14, 14), (20, 14), (0, 1), (5, 5)]
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

    // MARK: The crease (R3, REVIEW-2 #5)

    /// R3: resting bugs (sipping, or walking but still since the last frame) closer to the midrib line than
    /// TrapRules.creaseGap(radius:). A walker may end a dash up to its wobble amplitude off its spot.
    private func creaseOffenders(_ s: TrapSession, _ last: inout [Int: CGPoint], _ rests: inout Int) -> [String] {
        let cx: Double = Double(geo.center.x)
        var bad: [String] = []
        var now: [Int: CGPoint] = [:]
        for b in s.snapshot.bugs where b.inTrap {
            now[b.id] = b.position
            var resting: Bool = false
            switch b.activity {
            case .sipping:
                resting = true
            case .walking:
                if let p = last[b.id] {
                    resting = abs(Double(p.x - b.position.x)) < 0.001 && abs(Double(p.y - b.position.y)) < 0.001
                }
            case .arriving, .hopping, .leaving, .caught, .escaped, .released:
                resting = false
            }
            if !resting { continue }
            rests += 1
            let m: BugMotion = BugCatalog.motion(b.species)
            let tol: Double = m.style == .walker ? m.wobbleAmp + 0.5 : 0.5
            let gap: Double = TrapRules.creaseGap(radius: BugCatalog.info(b.species).radius)
            let slack: Double = abs(Double(b.position.x) - cx) - gap
            if slack < -tol { bad.append("\(b.species) at x \(b.position.x) (slack \(slack))") }
        }
        last = now
        return bad
    }

    @Test func offCreasePushesSpotsSideways() {
        let cx: Double = Double(geo.center.x)
        let cy: Double = Double(geo.center.y)
        let r: CGFloat = BugCatalog.info(.housefly).radius
        let gap: Double = TrapRules.creaseGap(radius: r)
        #expect(abs(gap - (20 + Double(r) + 16)) < 1e-9, "the band, the body and 16 pt")
        let a: (Double, Double) = TrapRules.offCrease(geo, cx, cy, maxR: 0.8, radius: r)
        #expect(abs(a.0 - (cx + gap)) < 1e-9 && abs(a.1 - cy) < 1e-9, "a point on the line goes right")
        let b: (Double, Double) = TrapRules.offCrease(geo, cx - 10, cy + 50, maxR: 0.8, radius: r)
        #expect(abs(b.0 - (cx - gap)) < 1e-9 && abs(b.1 - (cy + 50)) < 1e-9, "left of the line goes left")
        let c: (Double, Double) = TrapRules.offCrease(geo, cx + 200, cy - 30, maxR: 0.8, radius: r)
        #expect(abs(c.0 - (cx + 200)) < 1e-9 && abs(c.1 - (cy - 30)) < 1e-9, "far enough: unchanged")
        // Near the top of the midrib the push keeps the spot inside maxR by pulling y in.
        let d: (Double, Double) = TrapRules.offCrease(geo, cx + 5, cy + 0.8 * Double(geo.b), maxR: 0.8, radius: r)
        #expect(abs(d.0 - (cx + gap)) < 1e-9)
        #expect(geo.normalizedRadius(CGPoint(x: d.0, y: d.1)) <= 0.8 + 1e-9)
    }

    @Test func bugsAimedAtTheMidribRestOffIt() {
        // R3: a scripted bug told to land on the midrib (every kind of mover) lands, sips and wanders off it.
        let cx: Double = Double(geo.center.x)
        let species: [BugSpecies] = [.housefly, .moth, .grasshopper, .gnat, .dragonfly, .ant, .bumblebee]
        var bad: [String] = []
        var rests: Int = 0
        for sp in species {
            let s: TrapSession = quiet()
            let from: CGPoint = sp == .ant ? CGPoint(x: cx, y: -20) : CGPoint(x: -30, y: 330)
            _ = s.spawnScripted(sp, entry: from, target: CGPoint(x: cx, y: 340), linger: .infinity)
            var last: [Int: CGPoint] = [:]
            var f: Int = 0
            while f < 60 * 20 {
                _ = s.step(dt: frame, input: TrapInput())
                bad += creaseOffenders(s, &last, &rests)
                f += 1
            }
        }
        #expect(rests > 500, "rests \(rests)")
        #expect(bad.isEmpty, "\(bad.prefix(5))")
    }

    @Test func noBugRestsOnTheCreaseInRealWaves() {
        // R3: three runs of real waves with the casual pilot (spots, swarms, hops, moths, crowds, nectar).
        var bad: [String] = []
        var rests: Int = 0
        let seeds: [UInt64] = [3, 41, 977]
        for seed in seeds {
            let s = TrapSession(mode: .feed, seed: seed, best: 0, geometry: geo, options: noHunger())
            var p = TrapPilot(skill: .casual, seed: seed)
            var last: [Int: CGPoint] = [:]
            var f: Int = 0
            while f < 60 * 150 && !s.isFinished {
                let o: PilotOutput = p.step(dt: frame, time: 0, snapshot: s.snapshot)
                _ = s.step(dt: frame, input: o.input)
                bad += creaseOffenders(s, &last, &rests)
                f += 1
            }
        }
        #expect(rests > 2000, "rests \(rests)")
        #expect(bad.isEmpty, "\(bad.prefix(5))")
    }

    /// R4 (REVIEW-3 #14): bugs over the trap within creaseHalfWidth + radius of the midrib line that are lower than
    /// Tuning.creaseAirHeight (caught bugs slide into the seam on purpose and are skipped).
    private func lowOverTheCrease(_ s: TrapSession, _ banded: inout Int) -> [String] {
        let cx: Double = Double(geo.center.x)
        var bad: [String] = []
        for b in s.snapshot.bugs {
            if case .caught = b.activity { continue }
            if !geo.contains(b.position) { continue }
            let r: Double = Double(BugCatalog.info(b.species).radius)
            if abs(Double(b.position.x) - cx) >= Double(ScreenLayout.creaseHalfWidth) + r { continue }
            banded += 1
            if b.height < Tuning.creaseAirHeight - 1e-9 {
                bad.append("\(b.species) \(b.activity) at x \(b.position.x) height \(b.height)")
            }
        }
        return bad
    }

    @Test func nothingWalksOrHoversLowOverTheCrease() {
        // R4 (REVIEW-3 #14): feed runs (casual and perfect pilots) and the Home attract session, real waves: anything
        // over the crease is airborne. Before R4, ants, wanderers, nectar dashes, hops and hovers crossed it low
        // (tools/balance-sim.js crease=1: 6,089 low frames in 8 seeds; 0 now).
        var bad: [String] = []
        var banded: Int = 0
        let seeds: [UInt64] = [3, 41, 977]
        for seed in seeds {
            var k: Int = 0
            while k < 3 {
                let attract: Bool = k == 2
                let mode: RunMode = attract ? .attract : .feed
                let o: SessionOptions = attract ? SessionOptions.for(.attract) : SessionOptions.for(.feed)
                let s = TrapSession(mode: mode, seed: seed, best: 0, geometry: geo, options: o)
                var p = TrapPilot(skill: k == 1 ? .perfect : .casual, seed: seed)
                var f: Int = 0
                while f < 60 * 150 && !s.isFinished {
                    let out: PilotOutput = p.step(dt: frame, time: 0, snapshot: s.snapshot)
                    _ = s.step(dt: frame, input: out.input)
                    bad += lowOverTheCrease(s, &banded)
                    f += 1
                }
                k += 1
            }
        }
        #expect(banded > 500, "frames over the crease \(banded)")
        #expect(bad.isEmpty, "\(bad.count) low: \(bad.prefix(5))")
    }

    @Test func groundMovesKeepToTheirLobe() {
        // R4 (REVIEW-3 #14): an ant told to walk in from the far side enters on its spot's side; a grasshopper and a
        // wandering housefly never change lobes once landed.
        let cx: Double = Double(geo.center.x)
        let s: TrapSession = quiet()
        let ant: Int = s.spawnScripted(.ant, entry: CGPoint(x: cx - 250, y: -20), target: CGPoint(x: cx + 150, y: 260),
                                       linger: .infinity)
        let hopper: Int = s.spawnScripted(.grasshopper, entry: CGPoint(x: -30, y: 400),
                                          target: CGPoint(x: cx - 120, y: 400), linger: .infinity)
        let fly: Int = s.spawnScripted(.housefly, entry: CGPoint(x: 982, y: 300), target: CGPoint(x: cx + 70, y: 300),
                                       linger: .infinity)
        var banded: Int = 0
        var bad: [String] = []
        var crossed: [String] = []
        var landedIDs: Set<Int> = []
        var f: Int = 0
        while f < 60 * 40 {
            let ev: [TrapEvent] = s.step(dt: frame, input: TrapInput())
            for e in ev {
                if case .bugLanded(let id, _, _, _) = e { landedIDs.insert(id) }
            }
            bad += lowOverTheCrease(s, &banded)
            for b in s.snapshot.bugs where b.inTrap {
                let x: Double = Double(b.position.x)
                if b.id == ant && x < cx { crossed.append("ant at \(x)") }
                if b.id == hopper && landedIDs.contains(hopper) && x > cx { crossed.append("grasshopper at \(x)") }
                if b.id == fly && landedIDs.contains(fly) && x < cx { crossed.append("housefly at \(x)") }
            }
            f += 1
        }
        #expect(landedIDs.contains(ant) && landedIDs.contains(hopper) && landedIDs.contains(fly))
        #expect(bad.isEmpty, "\(bad.prefix(5))")
        #expect(crossed.isEmpty, "\(crossed.prefix(5))")
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
        // R8 (founder rule 2): never a pose hint; a slow close says "quick".
        _ = s.step(dt: frame, input: TrapInput(closure: 0, armed: true, creeping: true, tooFlat: true))
        #expect(s.snapshot.hint == .quick)
        _ = s.step(dt: frame, input: TrapInput(closure: 0, armed: true, creeping: true))
        #expect(s.snapshot.hint == .quick)

        let b: TrapSession = quiet()
        sippers(b, [.housefly, .housefly, .housefly, .bee])
        _ = b.step(dt: frame, input: TrapInput())
        #expect(b.snapshot.hint == .beeInside, "a bee beats the crowd")

        let o: TrapSession = quiet()
        _ = snap(o, 0.1)
        // R8: shut (after the bite, unarmed) for over Tuning.openUpDelay: "Open it again".
        run(o, 1.2, TrapInput(closure: 20, armed: false))
        #expect(o.snapshot.shut)
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
        // R3: hungry 15 s after the first landing (the sippers landed 1–3 s into their 6 s).
        var waited: Int = 0
        while waited < 60 * 20 && h.snapshot.hint != .hungry {
            _ = h.step(dt: frame, input: TrapInput())
            waited += 1
        }
        #expect(h.snapshot.hint == .hungry, "15 s after the first landing")
        #expect(waited > 60 * 8 && waited < 60 * 15, "waited \(waited) frames")
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

    @Test func beeEntriesNeverStartUnderAThumb() {
        // R5 (REVIEW-4 #15): on the Duo in book pose the thumbs rest on the outer edges at mid-height. No bee, bumblebee
        // or wasp enters within Tuning.thumbBandWidth (90 pt) of either outer edge in the middle half of the height.
        let size: CGSize = geo.sceneSize
        let lo: Double = Double(size.height) * Tuning.thumbBandLow
        let hi: Double = Double(size.height) * Tuning.thumbBandHigh
        // The rule, pure: a y in the band is mirrored across its nearer edge; x and everything outside stay put.
        let left = CGPoint(x: -30, y: 300)
        #expect(WaveFactory.inThumbBand(left, sceneSize: size))
        let movedLeft: CGPoint = WaveFactory.thumbSafeEntry(left, sceneSize: size)
        #expect(abs(Double(movedLeft.x) - Double(left.x)) < 1e-9)
        #expect(abs(Double(movedLeft.y) - (2 * lo - 300)) < 1e-9, "the band's lower half goes below it")
        #expect(!WaveFactory.inThumbBand(movedLeft, sceneSize: size))
        let right = CGPoint(x: 982, y: 400)
        let movedRight: CGPoint = WaveFactory.thumbSafeEntry(right, sceneSize: size)
        #expect(abs(Double(movedRight.y) - (2 * hi - 400)) < 1e-9, "the band's upper half goes above it")
        #expect(!WaveFactory.inThumbBand(movedRight, sceneSize: size))
        let inner = CGPoint(x: 120, y: 330)
        #expect(!WaveFactory.inThumbBand(inner, sceneSize: size))
        #expect(WaveFactory.thumbSafeEntry(inner, sceneSize: size) == inner, "90 pt in: no thumb")
        let top = CGPoint(x: 40, y: -30)
        #expect(WaveFactory.thumbSafeEntry(top, sceneSize: size) == top, "a top or bottom entry is off the band")
        let corner = CGPoint(x: -30, y: 100)
        #expect(WaveFactory.thumbSafeEntry(corner, sceneSize: size) == corner)
        // Real waves: 48 seeds × 60 waves, every protected entry (landing, sitting on the bog and crossing alike).
        var protectedEntries: Int = 0
        var sideEntries: Int = 0
        var bad: [String] = []
        var thumbFlies: Int = 0
        var seed: UInt64 = 1
        while seed <= 48 {
            var index: Int = 1
            while index <= 60 {
                let drops: [NectarDrop] = WaveFactory.nectar(
                    seed: WaveFactory.nectarSeed(seed: seed, block: (index - 1) / Tuning.nectarReseedWaves),
                    geometry: geo)
                let w: WaveSpec = WaveFactory.wave(seed: seed, index: index, geometry: geo, nectar: drops)
                for x in w.bugs {
                    if !x.species.isProtected {
                        if WaveFactory.inThumbBand(x.entry, sceneSize: size) { thumbFlies += 1 }
                        continue
                    }
                    protectedEntries += 1
                    if x.entry.x < 0 || Double(x.entry.x) > Double(size.width) { sideEntries += 1 }
                    if WaveFactory.inThumbBand(x.entry, sceneSize: size) {
                        bad.append("seed \(seed) wave \(index) \(x.species) at \(x.entry)")
                    }
                }
                index += 1
            }
            seed += 1
        }
        #expect(protectedEntries > 500, "protected entries \(protectedEntries)")
        #expect(sideEntries > 100, "they still come in from the sides: \(sideEntries)")
        #expect(bad.isEmpty, "\(bad.prefix(5))")
        #expect(thumbFlies > 0, "only protected bugs are kept out (flies still may enter there)")
    }

    @Test func nectarDropsSitInClustersOnTheLobes() {
        // R2 (REVIEW-1 #19): 6–8 drops in clusters of 2–3 on both lobes, off the crease. R3 (REVIEW-2 #16): tight
        // 24–30 pt rings (cluster mates 41–61 pt apart, other drops > 80 pt) and ≥ 80 pt off the midrib line, which
        // keeps every nectar sipper (the biggest is the bumblebee) clear of the crease.
        let cx: Double = Double(geo.center.x)
        for sp in BugSpecies.allCases where BugCatalog.motion(sp).nectarChance > 0 {
            #expect(Tuning.nectarCreaseClearance >= TrapRules.creaseGap(radius: BugCatalog.info(sp).radius),
                    "\(sp) sips off the crease")
        }
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
                // R3: its cluster mates are 41–61 pt away; every other drop is further than 80 pt.
                var nearest: Double = Double.infinity
                var mates: Int = 0
                for o in drops where o.id != d.id {
                    let dist: Double = hypot(Double(o.position.x - d.position.x), Double(o.position.y - d.position.y))
                    nearest = min(nearest, dist)
                    if dist <= 80 { mates += 1 }
                }
                #expect(nearest >= 41 && nearest <= 61, "seed \(seed) drop \(d.id): nearest \(nearest)")
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
        // R3: the App opts a Sprout's first run in; no mode does by default.
        #expect(!SessionOptions.for(.feed).freeFirstSting && !SessionOptions.for(.lesson).freeFirstSting)
        // R4: the App opts a Sprout's first Feed run in.
        #expect(!SessionOptions.for(.feed).firstRun && !SessionOptions.for(.daily(day: 1, scored: true)).firstRun)
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
        // R8 (ROUND-8 §2): a casual close takes 0.35–0.65 s from the close start to the shut.
        #expect(!durations.isEmpty)
        for d in durations {
            #expect(d >= 0.35 - 0.02 && d <= 0.65 + 0.02, "casual close \(d)")
        }
    }

    @Test func perfectPilotClosesInEighteenHundredths() {
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
        // R8: the perfect close is 0.18 s from the close start to the shut.
        if let d = fired?.duration { #expect(abs(d - 0.18) < 1e-6, "duration \(d)") }
    }

    @Test func thePilotIgnoresTheCallersClock() {
        // R3 (REVIEW-2 #21): only the seed and the dts matter, never the time the caller passes (a wall clock).
        let a = TrapSession(mode: .feed, seed: 21, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        let b = TrapSession(mode: .feed, seed: 21, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        var pa = TrapPilot(skill: .expert, seed: 9)
        var pb = TrapPilot(skill: .expert, seed: 9)
        var same: Bool = true
        var snaps: Int = 0
        var f: Int = 0
        while f < 60 * 90 {
            let oa: PilotOutput = pa.step(dt: frame, time: Double(f) * frame, snapshot: a.snapshot)
            let ob: PilotOutput = pb.step(dt: frame, time: 5_000 + Double(f) * frame * 3, snapshot: b.snapshot)
            var ia: TrapInput = oa.input
            var ib: TrapInput = ob.input
            ia.snap?.time = 0
            ib.snap?.time = 0
            if ia != ib { same = false }
            if ia.snap != nil { snaps += 1 }
            let ea: [TrapEvent] = a.step(dt: frame, input: ia)
            let eb: [TrapEvent] = b.step(dt: frame, input: ib)
            if ea != eb { same = false }
            f += 1
        }
        #expect(same)
        #expect(snaps >= 3, "snaps \(snaps)")
        #expect(a.snapshot == b.snapshot)
    }

    @Test func aPilotRunIsTheSameRunAtAnyFrameRate() {
        // R3 (REVIEW-2 #21): jittery frame times and a steady 60 Hz give the same fixed steps, so the same bites.
        let jitter: [Double] = [1.0 / 60.0, 1.0 / 30.0, 1.0 / 120.0, 0.05, 1.0 / 90.0, 0.004, 1.0 / 45.0]
        let a = TrapSession(mode: .feed, seed: 33, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        var ra = PilotRun(skill: .casual, seed: 12)
        var ea: [TrapEvent] = []
        var k: Int = 0
        while ra.stepsRun < 60 * 90 && !a.isFinished {
            ea.append(contentsOf: ra.advance(a, dt: jitter[k % jitter.count], stamp: Double(k)))
            k += 1
        }
        let b = TrapSession(mode: .feed, seed: 33, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        var rb = PilotRun(skill: .casual, seed: 12)
        var eb: [TrapEvent] = []
        while rb.stepsRun < ra.stepsRun && !b.isFinished {
            eb.append(contentsOf: rb.advance(b, dt: Tuning.pilotStep))
        }
        #expect(rb.stepsRun == ra.stepsRun)
        #expect(ea == eb)
        #expect(a.snapshot == b.snapshot)
        let bites: Int = count(ea) { (e: TrapEvent) -> Bool in if case .snapped = e { return true }; return false }
        #expect(bites >= 3, "bites \(bites)")
        // The plain 60 Hz loop (BalanceTests, DemoRunner) plays the same run too.
        let c = TrapSession(mode: .feed, seed: 33, best: 0, geometry: geo, options: SessionOptions.for(.feed))
        var pc = TrapPilot(skill: .casual, seed: 12)
        var ec: [TrapEvent] = []
        var n: Int = 0
        while n < ra.stepsRun && !c.isFinished {
            let o: PilotOutput = pc.step(dt: Tuning.pilotStep, time: 0, snapshot: c.snapshot)
            ec.append(contentsOf: c.step(dt: Tuning.pilotStep, input: o.input))
            n += 1
        }
        #expect(ec == eb)
        // The step budget: a long hitch runs at most pilotMaxStepsPerFrame steps; a half step waits for the next.
        var r = PilotRun(skill: .novice, seed: 1)
        let long: Int = r.steps(for: 1.0)
        #expect(long == Tuning.pilotMaxStepsPerFrame)
        #expect(r.carry == 0)
        let half: Int = r.steps(for: 0.5 / 60.0)
        let full: Int = r.steps(for: 0.5 / 60.0)
        let bad: Int = r.steps(for: Double.nan)
        #expect(half == 0 && full == 1 && bad == 0)
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
        // R3: the cap is ×5 (the 9th clean bite in a row), but "Four Times Hungry" stays at ×4 (the 7th).
        #expect(Achievements.chainForX4 == 7)
        #expect(Achievements.chainForMaxMultiplier == 9)
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
        // R7: R6's 10,000, now named Tuning.wellFedScore.
        #expect(Tuning.wellFedScore == 10_000)
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

    // MARK: R6: the Zen Bog

    @Test func zenOptionsNeverRunOutNeverWiltAndStingsAreFree() {
        let z: SessionOptions = SessionOptions.for(.zen)
        #expect(!z.snapsRunOut && z.waves && !z.stingCosts && !z.hunger)
        #expect(z.sproutPerks(for: .zen) == nil)
        var withPerks: SessionOptions = z
        withPerks.sproutRun = 1
        #expect(withPerks.sproutPerks(for: .zen) == nil && !withPerks.firstRunApplies(to: .zen))
        // The Daily's rules are untouched.
        #expect(SessionOptions.for(.daily(day: 3, scored: true)) == SessionOptions())
        var o: SessionOptions = z
        o.waves = false
        let s = TrapSession(mode: .zen, seed: 7, best: 5, geometry: geo, options: o)
        let start: Int = s.snapshot.snapsLeft
        sippers(s, [.housefly, .fruitFly])
        let clean: [TrapEvent] = snap(s, 0.05)
        #expect(report(clean)?.caught.count == 2)
        #expect(s.snapshot.chain == 1)
        #expect(s.snapshot.score > 5)
        let best: Int = count(clean) { (e: TrapEvent) -> Bool in if case .newBest = e { return true }; return false }
        #expect(best == 0, "no best in the Zen Bog")
        run(s, 1)
        sippers(s, [.housefly, .bee])
        let stung: [TrapEvent] = snap(s, 0.05)
        let costs: [Int] = stung.compactMap { (e: TrapEvent) -> Int? in
            if case .stung(_, _, let cost) = e { return cost }
            return nil
        }
        #expect(costs == [0], "a bee costs no snap in Zen")
        #expect(report(stung)?.snapsLost == 0)
        #expect(s.snapshot.chain == 0, "but it breaks the chain")
        #expect(s.snapshot.snapsLeft == start)
        #expect(s.snapshot.hunger == 0)
        #expect(s.snapshot.hint != .lastSnap && s.snapshot.hint != .hungry)
    }

    @Test func zenDayLoopsAndNeverSpeedsUp() {
        #expect(Tuning.zenDayWaves < Tuning.lateWaveStart)
        #expect(TrapRules.paceWave(1, mode: .zen) == 1)
        #expect(TrapRules.paceWave(Tuning.zenDayWaves, mode: .zen) == Tuning.zenDayWaves)
        #expect(TrapRules.paceWave(Tuning.zenDayWaves + 1, mode: .zen) == 1)
        #expect(TrapRules.paceWave(100, mode: .feed) == 100)
        #expect(TrapRules.paceWave(100, mode: .daily(day: 1, scored: true)) == 100)
        let fly: BugInfo = BugCatalog.info(.housefly)
        let late: Double = TrapRules.reaction(fly, sipping: true, flying: false, onRim: false,
                                              wave: TrapRules.paceWave(150, mode: .zen))
        // R8: the recipe wave (10 here, a noon) reacts like a first day's noon: never the late night's speed.
        let fresh: Double = TrapRules.reaction(fly, sipping: true, flying: false, onRim: false,
                                               wave: ((150 - 1) % Tuning.zenDayWaves) + 1)
        #expect(abs(late - fresh) < 1e-12, "Zen's night never outruns the hand")
        let noon: Double = TrapRules.reaction(fly, sipping: true, flying: false, onRim: false, wave: Tuning.noonWave)
        #expect(late >= noon - 1e-12)
        let s = TrapSession(mode: .zen, seed: 11, best: 0, geometry: geo, options: SessionOptions.for(.zen))
        let ev: [TrapEvent] = run(s, 130)
        var phases: [DayPhase] = []
        var tired: Int = 0
        var wilts: Int = 0
        for e in ev {
            if case .dayPhaseChanged(let p) = e { phases.append(p) }
            if case .tired = e { tired += 1 }
            if case .wilted = e { wilts += 1 }
        }
        #expect(phases.contains(.night))
        if let n = phases.firstIndex(of: .night) {
            #expect(phases[(n + 1)...].contains(.morning), "after the night comes a new morning: \(phases)")
        }
        #expect(tired == 0 && wilts == 0)
        #expect(!s.isFinished && s.snapshot.snapsLeft == Tuning.startSnaps)
        #expect(s.snapshot.wave > Tuning.zenDayWaves)
    }

    @Test func zenEarnsNoScoreFeats() {
        let zen: RunResult = result(mode: .zen, score: 50_000, caught: ["dragonfly": 2], biggest: 7, chain: 9,
                                    feasts: 5, waves: 160, bugs: 400)
        let got: Set<String> = ids(Achievements.earned(after: zen, lifetimeBugs: 400, lifetimeSpared: 60,
                                                       speciesFound: 10, alreadyEarned: []))
        #expect(got.contains("snap.ach.feast") && got.contains("snap.ach.bite5"))
        #expect(got.contains("snap.ach.dragonfly") && got.contains("snap.ach.spare50"))
        for skipped in ["snap.ach.chain4", "snap.ach.night", "snap.ach.score10k", "snap.ach.nobees", "snap.ach.daily"] {
            #expect(!got.contains(skipped), "\(skipped)")
        }
        #expect(Achievements.zenSkips.count == 4)
        #expect(!TrapRules.keepsBest(.zen) && TrapRules.keepsBest(.feed) && TrapRules.keepsBest(.daily(day: 1, scored: true)))
    }

    @Test func zenBugsGrowTheRankAtAQuarter() {
        #expect(abs(Tuning.zenRankShare - 0.25) < 1e-12)
        #expect(PlantRanks.growth(from: result(mode: .feed, bugs: 70)) == 70)
        #expect(PlantRanks.growth(from: result(mode: .daily(day: 2, scored: false), bugs: 33)) == 33)
        #expect(PlantRanks.growth(from: result(mode: .zen, bugs: 325)) == 81, "25 %, rounded down per run")
        #expect(PlantRanks.growth(from: result(mode: .zen, bugs: 3)) == 0)
        #expect(PlantRanks.growth(from: result(mode: .zen, bugs: 4)) == 1)
        #expect(PlantRanks.growth(from: result(mode: .attract, bugs: 99)) == 0)
        #expect(PlantRanks.growth(from: result(mode: .lesson, bugs: 5)) == 0)
    }

    // MARK: R6: the late night (#19) and the halo rule (#15)

    @Test func theLateNightIsTelegraphed() {
        let feed: RunMode = .feed
        let daily: RunMode = .daily(day: 9, scored: true)
        #expect(TrapRules.nightCue(wave: Tuning.lateWaveStart, mode: feed) == nil)
        #expect(TrapRules.nightCue(wave: Tuning.lateWaveStart + 1, mode: feed) == .nightGetsFast)
        #expect(TrapRules.nightCue(wave: Tuning.lateWaveStart + 1, mode: daily) == .nightGetsFast)
        #expect(TrapRules.nightCue(wave: Tuning.lastLightWave, mode: feed) == .lastLight)
        #expect(TrapRules.nightCue(wave: Tuning.lastLightWave, mode: daily) == .lastLight, "the Daily plays Feed rules")
        #expect(TrapRules.nightCue(wave: Tuning.lastLightWave + 1, mode: feed) == nil)
        for m in [RunMode.zen, RunMode.attract, RunMode.lesson] {
            #expect(TrapRules.nightCue(wave: Tuning.lateWaveStart + 1, mode: m) == nil)
            #expect(TrapRules.nightCue(wave: Tuning.lastLightWave, mode: m) == nil)
        }
        #expect(Tuning.lastLightWave > Tuning.lateWaveStart + 1)
        #expect(TrapRules.lastLightApplies(to: .feed) && TrapRules.lastLightApplies(to: daily))
        #expect(!TrapRules.lastLightApplies(to: .zen) && !TrapRules.lastLightApplies(to: .attract))
        // The cue fires on the wave that starts.
        var o = SessionOptions()
        o.firstWave = Tuning.lateWaveStart
        let s = TrapSession(mode: .feed, seed: 3, best: 0, geometry: geo, options: o)
        var cues: [NightCue] = []
        for e in run(s, 12) {
            if case .waveStarted(let i, _) = e, let c = TrapRules.nightCue(wave: i, mode: .feed) { cues.append(c) }
        }
        #expect(cues == [.nightGetsFast])
    }

    @Test func theLastLightMakesAnyFeedTrapHungry() {
        // From Tuning.lastLightWave the clock ticks with an empty trap: night wilt 14 s, "hungry" 3 s before.
        var o = SessionOptions(snapsRunOut: true, waves: false, stingCosts: true)
        o.firstWave = Tuning.lastLightWave + 1
        let s = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: o)
        #expect(s.inLastLight)
        // R8: night wilt 12 s, hungry 3 s before.
        let a: [TrapEvent] = run(s, 10)
        #expect(wiltCount(a) == 0)
        #expect(s.snapshot.hint == .hungry, "the empty trap is hungry in the last light")
        let b: [TrapEvent] = run(s, 2.5)
        #expect(wiltCount(b) == 1)
        #expect(s.snapshot.snapsLeft == Tuning.startSnaps - 1)
        // The Daily too (Feed rules); not before the last light, not without hunger.
        var early = o
        early.firstWave = Tuning.lastLightWave - 1
        let e = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: early)
        #expect(!e.inLastLight)
        #expect(wiltCount(run(e, 20)) == 0)
        let d = TrapSession(mode: .daily(day: 2, scored: true), seed: 7, best: 0, geometry: geo, options: o)
        #expect(d.inLastLight)
        #expect(wiltCount(run(d, 12.5)) == 1)
        var fed = o
        fed.hunger = false
        let h = TrapSession(mode: .feed, seed: 7, best: 0, geometry: geo, options: fed)
        #expect(!h.inLastLight)
        #expect(wiltCount(run(h, 20)) == 0)
    }

    @Test func aHaloOnTheTrapEdgeHidesTheHungryHint() {
        let c: CGPoint = geo.center
        let bee: CGFloat = BugCatalog.info(.bee).radius
        #expect(TrapRules.haloTouchesTrap(geo, c, radius: bee))
        // Just outside the right edge: the halo (1.6 × r + 4 = 50 pt) reaches in.
        #expect(TrapRules.haloTouchesTrap(geo, CGPoint(x: c.x + geo.a + 30, y: c.y), radius: bee))
        #expect(!TrapRules.haloTouchesTrap(geo, CGPoint(x: c.x + geo.a + 60, y: c.y), radius: bee))
        #expect(!TrapRules.haloTouchesTrap(geo, CGPoint(x: c.x, y: c.y + geo.b + 60), radius: bee))
        #expect(TrapRules.haloTouchesTrap(geo, CGPoint(x: c.x, y: c.y - geo.b - 40), radius: bee))
        // In real waves with no snaps (hungry all along), "Hungry… bite!" never shows beside a low haloed bee
        // outside the trap.
        var hungryFrames: Int = 0
        var offenders: Int = 0
        var seed: UInt64 = 1
        while seed <= 12 {
            let s = TrapSession(mode: .feed, seed: seed, best: 0, geometry: geo, options: SessionOptions())
            var f: Int = 0
            while f < 60 * 60 && !s.isFinished {
                _ = s.step(dt: frame, input: TrapInput())
                let shot: TrapSnapshot = s.snapshot
                if shot.hint == .hungry {
                    hungryFrames += 1
                    for b in shot.bugs where b.species.isProtected && !geo.contains(b.position) {
                        var staying: Bool = false
                        switch b.activity {
                        case .arriving, .walking, .sipping, .hopping: staying = true
                        case .leaving, .caught, .escaped, .released: staying = false
                        }
                        if staying && b.height < Tuning.creaseAirHeight
                            && TrapRules.haloTouchesTrap(geo, b.position, radius: BugCatalog.info(b.species).radius) {
                            offenders += 1
                        }
                    }
                }
                f += 1
            }
            seed += 1
        }
        #expect(hungryFrames > 0)
        #expect(offenders == 0)
    }

    // MARK: R6: goals

    /// A bite's events as TrapSession sends them (the report, each catch, a feast, a chain step, a dry snap).
    private func goalBite(_ caught: [BugSpecies], stingers: [BugSpecies] = [], points: Int = 10,
                          chain: Int = 0) -> [TrapEvent] {
        let r = BiteReport(caught: caught, escaped: 0, stingers: stingers, points: points,
                           countMultiplier: caught.count, chainMultiplier: 1, snapsBack: 0, snapsLost: 0,
                           duration: 0.1, time: 0)
        var ev: [TrapEvent] = [.snapped(r)]
        var k: Int = 0
        for sp in caught {
            ev.append(.bugCaught(id: 100 + k, species: sp, position: CGPoint(x: 300, y: 300)))
            k += 1
        }
        if stingers.isEmpty && caught.count >= Tuning.feastCount {
            ev.append(.feast(count: caught.count, snapsBack: 1))
        }
        if stingers.isEmpty && caught.count >= Tuning.chainMinBite && chain > 0 {
            ev.append(.chainUp(count: chain, multiplier: TrapRules.chainMultiplier(chain)))
        }
        if caught.isEmpty && stingers.isEmpty { ev.append(.drySnap) }
        return ev
    }

    private func goal(_ id: String) -> GoalSpec {
        if let d = GoalBook.def(id) { return d }
        Issue.record("no goal \(id)")
        return GoalBook.pool[0]
    }

    @Test func theGoalPoolIsWellFormed() {
        let pool: [GoalSpec] = GoalBook.pool
        #expect(pool.count >= 34 && pool.count <= 42, "about 36: \(pool.count)")
        let poolIDs: Set<String> = Set(pool.map { (d: GoalSpec) -> String in d.id })
        #expect(poolIDs.count == pool.count, "ids are unique")
        for d in pool {
            #expect(d.target >= 1, "\(d.id)")
            #expect(!d.title.isEmpty && !d.title.contains("{n}") && d.title.count <= 60, "\(d.id): \(d.title)")
            #expect(d.ranks.lowerBound >= 0 && d.ranks.upperBound <= PlantRanks.count - 1, "\(d.id)")
            if d.unlocks != nil { #expect(d.span == .run && d.scope != .zen && d.scope != .daily, "\(d.id)") }
        }
        #expect(goal("daily2k").title == "Score 2,000 in the Daily")
        #expect(goal("dragonfly3").title == "Catch 3 dragonflies in one run")
        #expect(goal("chain3").title == "Reach a ×3 chain")
        #expect(goal("daily6k").progressLabel(1_250) == "1,250/6,000")
        #expect(goal("bite4").progressLabel(9) == "4/4")
        #expect(GoalBook.grouped(0) == "0" && GoalBook.grouped(1_000_005) == "1,000,005" && GoalBook.grouped(-2_500) == "-2,500")
        // Every rank has plenty to draw from, in every kind of run.
        var r: Int = 0
        while r < PlantRanks.count {
            let open: [GoalSpec] = GoalBook.eligible(rank: r)
            let anyRun: Int = open.filter { (d: GoalSpec) -> Bool in d.scope == .anyMode || d.scope == .standard }.count
            let families: Set<String> = Set(open.map { (d: GoalSpec) -> String in d.kind.family })
            #expect(anyRun >= 8, "rank \(r): \(anyRun)")
            #expect(families.count >= 5, "rank \(r): \(families)")
            let hasDaily: Bool = open.contains { (d: GoalSpec) -> Bool in d.scope == .daily }
            let hasZen: Bool = open.contains { (d: GoalSpec) -> Bool in d.scope == .zen }
            #expect(hasDaily, "rank \(r) has a Daily goal")
            #expect(hasZen, "rank \(r) has a Zen goal")
            r += 1
        }
        // The variety goals match the Garden.
        for v in TrapVariety.allCases {
            if case .goal(let id) = Varieties.info(v).unlock {
                #expect(GoalBook.def(id)?.unlocks == v, "\(v)")
            }
        }
        let unlockers: [GoalSpec] = pool.filter { (d: GoalSpec) -> Bool in d.unlocks != nil }
        #expect(unlockers.count == 3)
    }

    @Test func goalScopesCountTheRightModes() {
        let daily: RunMode = .daily(day: 4, scored: false)
        #expect(GoalScope.anyMode.includes(.feed) && GoalScope.anyMode.includes(daily) && GoalScope.anyMode.includes(.zen))
        #expect(GoalScope.standard.includes(.feed) && GoalScope.standard.includes(daily))
        #expect(!GoalScope.standard.includes(.zen))
        #expect(GoalScope.daily.includes(daily) && !GoalScope.daily.includes(.feed) && !GoalScope.daily.includes(.zen))
        #expect(GoalScope.zen.includes(.zen) && !GoalScope.zen.includes(.feed))
        for sc in GoalScope.allCases {
            #expect(!sc.includes(.attract) && !sc.includes(.lesson))
            #expect(!sc.label.isEmpty)
        }
        // A run that doesn't count leaves a goal where it was.
        let ev: [TrapEvent] = goalBite([.housefly, .housefly, .housefly])
        #expect(GoalBook.progress(for: goal("bite3"), mode: .attract, events: ev) == 0)
        #expect(GoalBook.progress(for: goal("bite3"), mode: .zen, events: ev) == 3)
        #expect(GoalBook.progress(for: goal("feast2"), mode: .zen, events: ev) == 0)
        #expect(GoalBook.progress(for: goal("feast2"), mode: .feed, events: ev) == 1)
        #expect(GoalBook.progress(for: goal("daily2k"), mode: .feed, events: goalBite([.dragonfly], points: 5_000)) == 0)
        #expect(GoalBook.progress(for: goal("daily2k"), mode: daily, events: goalBite([.dragonfly], points: 5_000)) == 5_000)
    }

    @Test func goalTrackerReadsTheEvents() {
        var ev: [TrapEvent] = [.waveStarted(index: 1, phase: .morning)]
        ev += goalBite([.housefly, .fruitFly, .bluebottle], points: 120, chain: 1)
        ev += goalBite([.housefly, .housefly], points: 40, chain: 2)
        ev += [.beeSpared(species: .bee), .beeSpared(species: .wasp), .beeSpared(species: .wasp)]
        let picks: [String] = ["flyTrio", "bite3", "mixed3", "feastMorning", "feast2", "chain2", "spare3", "wasp2",
                               "catch20", "clean25", "cleanToDusk", "night", "fireflyNight"]
        let defs: [GoalSpec] = picks.map { (id: String) -> GoalSpec in goal(id) }
        var t = GoalTracker(goals: defs, carried: [:], mode: .feed)
        let met: [GoalSpec] = t.ingest(ev)
        let metIDs: Set<String> = Set(met.map { (d: GoalSpec) -> String in d.id })
        #expect(metIDs == ["flyTrio", "bite3", "mixed3", "feastMorning", "chain2", "spare3", "wasp2"], "\(metIDs)")
        #expect(t.progress(goal("feast2")) == 1)
        #expect(t.progress(goal("spare3")) == 3)
        #expect(t.progress(goal("catch20")) == 5)
        #expect(t.progress(goal("clean25")) == 5)
        #expect(t.progress(goal("chain2")) == 2)
        // Clean to dusk needs Tuning.goalMinSnaps snaps first: two are not enough.
        var early = t
        early.ingest([.dayPhaseChanged(.dusk)])
        #expect(early.progress(goal("cleanToDusk")) == 0 && early.isSpoiled(goal("cleanToDusk")))
        var k: Int = 0
        while k < Tuning.goalMinSnaps {
            t.ingest(goalBite([.housefly]))
            k += 1
        }
        #expect(!t.isSpoiled(goal("cleanToDusk")))
        let dusk: [GoalSpec] = t.ingest([.waveStarted(index: 15, phase: .dusk), .dayPhaseChanged(.dusk)])
        let duskIDs: [String] = dusk.map { (d: GoalSpec) -> String in d.id }
        #expect(duskIDs == ["cleanToDusk"])
        // A dry snap at dusk, then a bee bitten: the counts stop where they were.
        t.ingest(goalBite([]))
        t.ingest(goalBite([.housefly], stingers: [.bee]))
        t.ingest(goalBite([.housefly, .housefly]))
        #expect(t.progress(goal("clean25")) == 5 + Tuning.goalMinSnaps)
        #expect(t.isSpoiled(goal("clean25")))
        #expect(t.progress(goal("catch20")) == 5 + Tuning.goalMinSnaps + 3)
        // Night: a firefly caught at night counts, and the trap reached night.
        t.ingest([.waveStarted(index: 23, phase: .night), .dayPhaseChanged(.night)])
        #expect(t.progress(goal("night")) == 1)
        let ff: [GoalSpec] = t.ingest(goalBite([.firefly]))
        let ffIDs: [String] = ff.map { (d: GoalSpec) -> String in d.id }
        #expect(ffIDs == ["fireflyNight"])
        let again: [GoalSpec] = t.ingest(goalBite([.firefly]))
        #expect(again.isEmpty, "each goal toasts once")
        // A dry snap before dusk spoils the clean-to-dusk goal for the run.
        var dry = GoalTracker(goals: [goal("cleanToDusk")], carried: [:], mode: .feed)
        dry.ingest(goalBite([]))
        #expect(dry.isSpoiled(goal("cleanToDusk")))
    }

    @Test func goalProgressCarriesBetweenRuns() {
        // Run goals keep the best run; total goals add up.
        let spare3: GoalSpec = goal("spare3")
        let spare100: GoalSpec = goal("spare100")
        var t = GoalTracker(goals: [spare3, spare100], carried: ["spare3": 2, "spare100": 98], mode: .zen)
        #expect(t.progress(spare3) == 2 && t.progress(spare100) == 98)
        let first: [GoalSpec] = t.ingest([.beeSpared(species: .bee)])
        #expect(first.isEmpty)
        #expect(t.progress(spare3) == 2, "Zen doesn't count for a Feed-or-Daily goal")
        let met: [GoalSpec] = t.ingest([.beeSpared(species: .bumblebee)])
        #expect(met == [spare100])
        let later: [GoalSpec] = t.ingest([.beeSpared(species: .bee)])
        #expect(later.isEmpty)
        #expect(t.progress(spare100) == 101)
        var f = GoalTracker(goals: [spare3], carried: ["spare3": 2], mode: .feed)
        f.ingest([.beeSpared(species: .bee)])
        #expect(f.progress(spare3) == 2, "one run's 1 doesn't beat the best run's 2")
        f.ingest([.beeSpared(species: .bee), .beeSpared(species: .bee)])
        #expect(f.isMet(spare3))
    }

    @Test func goalBookDrawsDeterministically() {
        var rank: Int = 0
        var differs: Bool = false
        while rank < PlantRanks.count {
            var seed: UInt64 = 1
            while seed <= 24 {
                let a: GoalBookState = GoalBook.start(seed: seed, rank: rank)
                let b: GoalBookState = GoalBook.start(seed: seed, rank: rank)
                #expect(a == b)
                if seed > 1 && a.active != GoalBook.start(seed: 1, rank: rank).active { differs = true }
                let defs: [GoalSpec] = GoalBook.activeGoals(a)
                let slotIDs: Set<String> = Set(a.active.map { (s: GoalBookSlot) -> String in s.id })
                #expect(defs.count == Tuning.goalsActive && slotIDs.count == Tuning.goalsActive)
                for d in defs { #expect(d.ranks.contains(rank), "rank \(rank) seed \(seed): \(d.id)") }
                let modeGoals: Int = defs.filter { (d: GoalSpec) -> Bool in d.scope == .daily || d.scope == .zen }.count
                let variety: Int = defs.filter { (d: GoalSpec) -> Bool in d.unlocks != nil }.count
                #expect(modeGoals <= 1 && variety <= 1, "rank \(rank) seed \(seed)")
                let fams: Set<String> = Set(defs.map { (d: GoalSpec) -> String in d.kind.family })
                #expect(fams.count == Tuning.goalsActive, "rank \(rank) seed \(seed)")
                seed += 1
            }
            rank += 1
        }
        #expect(differs, "the seed matters")
        // A stale book is repaired: unknown ids and repeats go, the slots refill.
        var stale = GoalBookState(seed: 3)
        stale.active = [GoalBookSlot(id: "gone"), GoalBookSlot(id: "bite3", progress: 2), GoalBookSlot(id: "bite3")]
        let fixed: GoalBookState = GoalBook.normalized(stale, rank: 0)
        #expect(fixed.active.count == 3 && fixed.active[0] == GoalBookSlot(id: "bite3", progress: 2))
        // Codable round trip.
        let data: Data? = try? JSONEncoder().encode(fixed)
        let back: GoalBookState? = data.flatMap { (d: Data) -> GoalBookState? in try? JSONDecoder().decode(GoalBookState.self, from: d) }
        #expect(back == fixed)
    }

    @Test func goalBookCompletesReplacesAndRewards() {
        #expect(GoalBook.reward(rank: 0) == 10 && GoalBook.reward(rank: 3) == 30 && GoalBook.reward(rank: 11) == 150)
        var r: Int = 1
        while r < PlantRanks.count {
            #expect(GoalBook.reward(rank: r) >= GoalBook.reward(rank: r - 1))
            r += 1
        }
        var st = GoalBookState(seed: 9)
        st.active = [GoalBookSlot(id: "bite3"), GoalBookSlot(id: "chain2"), GoalBookSlot(id: "spare3")]
        var ev: [TrapEvent] = [.waveStarted(index: 1, phase: .morning)]
        ev += goalBite([.housefly, .housefly, .housefly], chain: 1)
        ev += goalBite([.gnat, .gnat], chain: 2)
        ev += [.beeSpared(species: .bee), .beeSpared(species: .bee), .beeSpared(species: .bee)]
        let up: GoalBookUpdate = GoalBook.complete(st, mode: .feed, events: ev, rank: 0)
        let doneIDs: [String] = up.completed.map { (d: GoalSpec) -> String in d.id }
        #expect(doneIDs == ["bite3", "chain2", "spare3"])
        #expect(up.bonus == GoalBook.tripleBonus(rank: 0) && up.growth == 3 * 10 + up.bonus)
        #expect(up.state.growth == up.growth && up.state.completedCount == 3)
        #expect(up.state.everCompleted == ["bite3", "chain2", "spare3"] && up.state.recent == up.state.everCompleted)
        #expect(up.added.count == 3 && up.state.active.count == 3)
        for d in up.added {
            #expect(!["bite3", "chain2", "spare3"].contains(d.id) && d.ranks.contains(0), "\(d.id)")
        }
        let fresh: [Int] = up.state.active.map { (s: GoalBookSlot) -> Int in s.progress }
        #expect(fresh == [0, 0, 0])
        #expect(GoalBook.complete(st, mode: .feed, events: ev, rank: 0) == up, "deterministic")
        // One met: no bonus; the others bank their progress.
        var two = GoalBookState(seed: 9)
        two.active = [GoalBookSlot(id: "bite4"), GoalBookSlot(id: "chain2"), GoalBookSlot(id: "spare100", progress: 40)]
        let up2: GoalBookUpdate = GoalBook.complete(two, mode: .feed, events: ev, rank: 4)
        let done2: [String] = up2.completed.map { (d: GoalSpec) -> String in d.id }
        #expect(done2 == ["chain2"])
        #expect(up2.bonus == 0 && up2.growth == GoalBook.reward(rank: 4))
        #expect(up2.state.active[0] == GoalBookSlot(id: "bite4", progress: 3))
        #expect(up2.state.active[2] == GoalBookSlot(id: "spare100", progress: 43))
        #expect(up2.state.active[1].id != "chain2")
        // A run of a mode that doesn't count banks nothing.
        let up3: GoalBookUpdate = GoalBook.complete(st, mode: .attract, events: ev, rank: 0)
        #expect(up3.completed.isEmpty && up3.growth == 0 && up3.state.active == st.active)
    }

    @Test func varietyGoalsAreOfferedOnceTheirBandOpens() {
        let at3: GoalBookState = GoalBook.start(seed: 5, rank: 3)
        let at3IDs: [String] = at3.active.map { (s: GoalBookSlot) -> String in s.id }
        #expect(at3IDs.contains(GoalBook.sawtoothGoal), "\(at3IDs)")
        var st = GoalBookState(seed: 5)
        st.everCompleted = [GoalBook.sawtoothGoal]
        let at6: GoalBookState = GoalBook.normalized(st, rank: 6)
        let at6IDs: [String] = at6.active.map { (s: GoalBookSlot) -> String in s.id }
        #expect(at6IDs.contains(GoalBook.sharkToothGoal), "\(at6IDs)")
        #expect(!at6IDs.contains(GoalBook.sawtoothGoal))
        var doneAll = GoalBookState(seed: 5)
        doneAll.everCompleted = [GoalBook.sawtoothGoal, GoalBook.sharkToothGoal, GoalBook.fusedToothGoal]
        var seed: UInt64 = 1
        while seed <= 20 {
            doneAll.seed = seed
            let b: GoalBookState = GoalBook.normalized(doneAll, rank: 10)
            let plainOnly: Bool = GoalBook.activeGoals(b).allSatisfy { (d: GoalSpec) -> Bool in d.unlocks == nil }
            #expect(plainOnly, "seed \(seed)")
            seed += 1
        }
        // At rank 9 all three variety goals are open, but only one is offered at a time.
        let at9: GoalBookState = GoalBook.start(seed: 2, rank: 9)
        let at9Variety: Int = GoalBook.activeGoals(at9).filter { (d: GoalSpec) -> Bool in d.unlocks != nil }.count
        #expect(at9Variety == 1)
    }

    @Test func varietiesUnlockByRankAndGoals() {
        #expect(Varieties.all.count == TrapVariety.allCases.count)
        let order: [TrapVariety] = Varieties.all.map { (v: VarietyInfo) -> TrapVariety in v.variety }
        let names: Set<String> = Set(Varieties.all.map { (v: VarietyInfo) -> String in v.name })
        #expect(order == TrapVariety.allCases)
        #expect(names.count == 8)
        for v in TrapVariety.allCases {
            #expect(Varieties.info(v).variety == v)
            #expect(!Varieties.info(v).blurb.isEmpty && Varieties.info(v).blurb.count <= 60)
            #expect(!Varieties.ruleText(v).isEmpty)
        }
        #expect(Varieties.unlocked(rank: 0, completedGoals: []) == [.classic])
        #expect(Varieties.unlocked(rank: 2, completedGoals: []) == [.classic, .redDragon])
        #expect(Varieties.unlocked(rank: 11, completedGoals: []) == [.classic, .redDragon, .b52, .cupped, .goldenGlow])
        let goals: Set<String> = [GoalBook.sawtoothGoal, GoalBook.sharkToothGoal, GoalBook.fusedToothGoal]
        #expect(Varieties.unlocked(rank: 11, completedGoals: goals) == TrapVariety.allCases)
        #expect(Varieties.unlocked(rank: 0, completedGoals: [GoalBook.sawtoothGoal]) == [.classic, .sawtooth])
        #expect(Varieties.ruleText(.redDragon) == "Reach " + PlantRanks.title(2))
        #expect(Varieties.ruleText(.sawtooth) == "Goal: Spare 12 bees in one run")
        #expect(Varieties.newlyUnlocked(rankBefore: 1, goalsBefore: [], rankAfter: 2, goalsAfter: []) == [.redDragon])
        #expect(Varieties.newlyUnlocked(rankBefore: 4, goalsBefore: [], rankAfter: 5,
                                        goalsAfter: [GoalBook.sawtoothGoal]) == [.b52, .sawtooth])
        #expect(Varieties.effective(.goldenGlow, rank: 3, completedGoals: []) == .classic)
        #expect(Varieties.effective(.redDragon, rank: 3, completedGoals: []) == .redDragon)
        // About every 1.5 ranks: the unlock ranks (a goal's from its band) step 1–2 ranks apart up to the top.
        var steps: [Int] = []
        for v in TrapVariety.allCases {
            switch Varieties.info(v).unlock {
            case .start: steps.append(0)
            case .rank(let r): steps.append(r)
            case .goal(let id): steps.append(GoalBook.def(id)?.ranks.lowerBound ?? -1)
            }
        }
        let sortedSteps: [Int] = steps.sorted()
        #expect(sortedSteps.first == 0 && sortedSteps.last == PlantRanks.count - 1, "\(sortedSteps)")
        var i: Int = 1
        while i < sortedSteps.count {
            let gap: Int = sortedSteps[i] - sortedSteps[i - 1]
            #expect(gap >= 1 && gap <= 2, "\(sortedSteps)")
            i += 1
        }
    }

    @Test func goalsAgreeWithTheRunResultOnARealRun() {
        let s = TrapSession(mode: .feed, seed: 1000, best: 0, geometry: geo, options: SessionOptions())
        var pilot = TrapPilot(skill: .casual, seed: 7001)
        var ev: [TrapEvent] = []
        var t: Double = 0
        var f: Int = 0
        while f < 60 * 300 && !s.isFinished {
            let out: PilotOutput = pilot.step(dt: frame, time: t, snapshot: s.snapshot)
            ev.append(contentsOf: s.step(dt: frame, input: out.input))
            t += frame
            f += 1
        }
        let r: RunResult = s.partialResult()
        #expect(r.bugsCaught > 10)
        var compared: Int = 0
        for d in GoalBook.pool {
            guard let fromResult = GoalBook.progress(for: d, result: r) else { continue }
            let fromEvents: Int = GoalBook.progress(for: d, mode: .feed, events: ev)
            #expect(fromEvents == fromResult, "\(d.id): events \(fromEvents), result \(fromResult)")
            compared += 1
        }
        #expect(compared >= 20)
    }

    // MARK: R7: the ×2 FEAST (#3), one scoring function (#10), the night pool (#14), goal tiers (#15), keep-out (#4)

    /// Every bug that scores (not the bees, bumblebees and wasps).
    private var scoringSpecies: [BugSpecies] {
        return BugSpecies.allCases.filter { (s: BugSpecies) -> Bool in !s.isProtected }
    }

    @Test func aFeastOutScoresTheFourBugBitesPlayersCompare() {
        // R7 (SCORE-R6 #3, founder call): a clean bite of 5+ scores × Tuning.feastMultiplier (×2) inside its points.
        #expect(abs(Tuning.feastMultiplier - 2.0) < 1e-12)
        #expect(abs(TrapRules.feastBonus(count: 4, stung: false) - 1) < 1e-12)
        #expect(abs(TrapRules.feastBonus(count: Tuning.bigFeastCount, stung: false) - Tuning.feastMultiplier) < 1e-12)
        #expect(abs(TrapRules.feastBonus(count: 7, stung: false) - Tuning.feastMultiplier) < 1e-12)
        #expect(abs(TrapRules.feastBonus(count: 6, stung: true) - 1) < 1e-12, "a stung bite is never a FEAST")
        let values: [Int] = scoringSpecies.map { (s: BugSpecies) -> Int in BugCatalog.info(s).points }
        #expect(values.min() == 3 && values.max() == 150, "gnat 3 … Golden Scarab 150")
        var chain: Int = 0
        while chain <= 10 {
            for small in scoringSpecies {
                let smallPoints: Double = Double(BugCatalog.info(small).points)
                // 1. The same mean points per bug: 5–7 of a species beat 4 of it.
                let quadSame: Int = TrapRules.bitePoints([small, small, small, small], chain: chain, stung: false)
                var n: Int = Tuning.bigFeastCount
                while n <= 7 {
                    let many: [BugSpecies] = Array(repeating: small, count: n)
                    let bite: Int = TrapRules.bitePoints(many, chain: chain, stung: false)
                    if bite <= quadSame { Issue.record("\(n) × \(small) (\(bite)) ≤ 4 × \(small) (\(quadSame)), chain \(chain)") }
                    n += 1
                }
                // 2. A 4-bug bite whose mean points per bug are up to 2.5× higher still loses to 5.
                let five: [BugSpecies] = Array(repeating: small, count: 5)
                let feast: Int = TrapRules.bitePoints(five, chain: chain, stung: false)
                for big in scoringSpecies where Double(BugCatalog.info(big).points) <= 2.5 * smallPoints {
                    let quad: Int = TrapRules.bitePoints([big, big, big, big], chain: chain, stung: false)
                    if feast <= quad { Issue.record("5 × \(small) (\(feast)) ≤ 4 × \(big) (\(quad)), chain \(chain)") }
                }
            }
            chain += 1
        }
        // 3. R6's store frames (48 / P02 / D02 "FEAST! ×5 · +180", 14 "QUAD ×4 · +260", 49 "+520" = the QUAD at ×2):
        // 36 points over 5 bugs (3 houseflies, 2 gnats) against 65 over 4 (bluebottle, grasshopper, 2 houseflies).
        let feastBite: [BugSpecies] = [.housefly, .housefly, .housefly, .gnat, .gnat]
        let quadBite: [BugSpecies] = [.bluebottle, .grasshopper, .housefly, .housefly]
        #expect(TrapRules.bitePoints(quadBite, chain: 0, stung: false) == 260, "R6's QUAD +260")
        #expect(TrapRules.bitePoints(quadBite, chain: 2, stung: false) == 520, "R6's QUAD +520 (×2)")
        #expect(TrapRules.bitePoints(feastBite, chain: 0, stung: false) == 360, "R6's +180 FEAST is now +360")
        #expect(TrapRules.bitePoints(feastBite, chain: 2, stung: false) == 720, "… and +720 at ×2, against +520")
        // Below 5 nothing changes (R6's numbers), and a stung bite is × 1.
        #expect(TrapRules.bitePoints([.housefly, .housefly], chain: 2, stung: false) == 80, "20 × 2 × ×2")
        #expect(TrapRules.bitePoints([.housefly, .housefly, .ladybird, .goldenScarab], chain: 1, stung: true) == 740)
        // Not a guarantee over the whole range (founder call): four Golden Scarabs still out-score five gnats.
        let gnats: [BugSpecies] = Array(repeating: .gnat, count: 5)
        let scarabs: [BugSpecies] = Array(repeating: .goldenScarab, count: 4)
        #expect(TrapRules.bitePoints(gnats, chain: 0, stung: false) == 150, "3 × 5 × 5 × 2")
        #expect(TrapRules.bitePoints(scarabs, chain: 0, stung: false) == 2_400, "150 × 4 × 4")
    }

    @Test func aFeastBiteCarriesItsMultiplierInThePoints() {
        // R7 (#3, shared contract): the ×2 is inside BiteReport.points (App shows caught.count and the points).
        let s: TrapSession = quiet()
        sippers(s, [.housefly, .housefly, .housefly, .housefly, .housefly])
        let ev: [TrapEvent] = snap(s, 0.1)
        let r: BiteReport? = report(ev)
        #expect(r?.caught.count == 5)
        #expect(r?.points == 500, "10 × 5 × 5 × ×1 × 2")
        #expect(r?.countMultiplier == 5)
        #expect(r?.snapsBack == Tuning.bigFeastRefund)
        #expect(s.snapshot.score == 500)
        let feasts: Int = count(ev) { (e: TrapEvent) -> Bool in
            if case .feast(let n, let back) = e { return n == 5 && back == Tuning.bigFeastRefund }
            return false
        }
        #expect(feasts == 1)
        #expect(s.partialResult().bestBitePoints == 500)
        // A 5-bug bite with a bee in it: × 1, no FEAST and no ×2 (eating a bee is never the best move).
        let t: TrapSession = quiet()
        sippers(t, [.housefly, .housefly, .housefly, .housefly, .housefly, .bee])
        let te: [TrapEvent] = snap(t, 0.1)
        let tr: BiteReport? = report(te)
        #expect(tr?.caught.count == 5)
        #expect(tr?.stingers == [.bee])
        #expect(tr?.points == 250, "10 × 5 × 5 × 1, no ×2")
        let stungFeasts: Int = count(te) { (e: TrapEvent) -> Bool in if case .feast = e { return true }; return false }
        #expect(stungFeasts == 0)
    }

    @Test func everyModeScoresWithTheOneFunction() {
        // R7 (#10): Feed and the Zen Bog score every bite with TrapRules.bitePoints, and the score in play
        // (snapshot.score), the BiteReports and Results (RunResult.score) are one number.
        let modes: [RunMode] = [.feed, .zen]
        for m in modes {
            let s = TrapSession(mode: m, seed: 1000, best: 1, geometry: geo, options: SessionOptions.for(m))
            var pilot = TrapPilot(skill: .casual, seed: 7001)
            var t: Double = 0
            var f: Int = 0
            var sum: Int = 0
            var bites: Int = 0
            var mismatches: Int = 0
            while f < 60 * 150 && !s.isFinished {
                let out: PilotOutput = pilot.step(dt: frame, time: t, snapshot: s.snapshot)
                for e in s.step(dt: frame, input: out.input) {
                    guard case .snapped(let r) = e else { continue }
                    sum += r.points
                    bites += 1
                    var base: Int = 0
                    for sp in r.caught { base += BugCatalog.info(sp).points }
                    let stung: Bool = !r.stingers.isEmpty
                    base = base * r.caught.count
                    let x: Double = TrapRules.feastBonus(count: r.caught.count, stung: stung)
                    let want: Int = Int((Double(base) * r.chainMultiplier * x).rounded())
                    if want != r.points { mismatches += 1 }
                }
                if s.snapshot.score != sum { mismatches += 1 }
                t += frame
                f += 1
            }
            let res: RunResult = s.partialResult()
            #expect(bites >= 8, "\(m): \(bites) bites")
            #expect(mismatches == 0, "\(m)")
            #expect(res.score == sum, "\(m): Results \(res.score), bites \(sum)")
            #expect(s.snapshot.score == res.score, "\(m)")
        }
    }

    @Test func nightIsFirefliesAndCrickets() {
        // R7 (SCORE-R6 #14): over waves 23–90 of the balance seeds the firefly is the commonest bug landing in the
        // trap, and fireflies and crickets are ≥ 40% of them (tools/balance-sim.js night=1: 45.6%; R6: 13%, gnats first).
        var counts: [BugSpecies: Int] = [:]
        var total: Int = 0
        var i: Int = 0
        while i < 16 {
            let seed: UInt64 = UInt64(1000 + i * 7919)
            var w: Int = Tuning.nightWave
            while w <= 90 {
                let block: Int = (w - 1) / Tuning.nectarReseedWaves
                let nectar: [NectarDrop] = WaveFactory.nectar(seed: WaveFactory.nectarSeed(seed: seed, block: block),
                                                              geometry: geo)
                let spec: WaveSpec = WaveFactory.wave(seed: seed, index: w, geometry: geo, nectar: nectar)
                for b in spec.bugs where b.landsInTrap && !b.species.isProtected {
                    counts[b.species, default: 0] += 1
                    total += 1
                }
                w += 1
            }
            i += 1
        }
        let fireflies: Int = counts[.firefly] ?? 0
        let crickets: Int = counts[.cricket] ?? 0
        let share: Double = Double(fireflies + crickets) / Double(max(total, 1))
        var top: BugSpecies = .firefly
        for (sp, n) in counts where n > (counts[top] ?? 0) { top = sp }
        #expect(total > 1_000)
        #expect(share >= 0.4, "fireflies + crickets \(share): \(counts)")
        #expect(top == .firefly, "\(counts)")
        // The day pool is R6's: no firefly or cricket before night.
        let nectar0: [NectarDrop] = WaveFactory.nectar(seed: WaveFactory.nectarSeed(seed: 1000, block: 2), geometry: geo)
        var d: Int = 1
        while d < Tuning.nightWave {
            for b in WaveFactory.wave(seed: 1000, index: d, geometry: geo, nectar: nectar0).bugs {
                #expect(b.species != .firefly && b.species != .cricket, "wave \(d)")
            }
            d += 1
        }
    }

    @Test func goalsHaveSensibleTiers() {
        // R7 (SCORE-R6 #15): every goal is easy, medium or hard; all three are used; a Sprout (rank 0) is never
        // offered a hard goal and easy goals open by rank 2; within one kind, span and scope a bigger target is
        // never an easier tier; the variety goals are hard.
        let pool: [GoalSpec] = GoalBook.pool
        #expect(GoalTier.allCases.count == 3)
        #expect(GoalTier.easy.label == "Easy" && GoalTier.medium.label == "Medium" && GoalTier.hard.label == "Hard")
        #expect(GoalTier.easy < GoalTier.medium && GoalTier.medium < GoalTier.hard)
        for tier in GoalTier.allCases {
            let n: Int = pool.filter { (d: GoalSpec) -> Bool in d.tier == tier }.count
            #expect(n >= 8, "\(tier): \(n)")
        }
        for d in pool {
            if d.tier == .hard { #expect(d.ranks.lowerBound >= 3, "\(d.id) is hard from rank \(d.ranks.lowerBound)") }
            if d.tier == .easy { #expect(d.ranks.lowerBound <= 2, "\(d.id) is easy from rank \(d.ranks.lowerBound)") }
            for e in pool where e.kind == d.kind && e.span == d.span && e.scope == d.scope && e.target > d.target {
                #expect(e.tier >= d.tier, "\(e.id) (\(e.tier)) vs \(d.id) (\(d.tier))")
            }
            if d.unlocks != nil { #expect(d.tier == .hard, "\(d.id) unlocks a variety") }
        }
        #expect(goal("bite3").tier == .easy && goal("bite5").tier == .medium && goal("bite7").tier == .hard)
        #expect(goal("daily2k").tier == .easy && goal("daily6k").tier == .hard)
        // Every rank's draw has an easy or medium goal to offer.
        var r: Int = 0
        while r < PlantRanks.count {
            let open: [GoalSpec] = GoalBook.eligible(rank: r)
            let gentle: Bool = open.contains { (d: GoalSpec) -> Bool in d.tier != .hard }
            #expect(gentle, "rank \(r)")
            r += 1
        }
    }

    /// R7 (#4): a 60 s seeded run of waves (no snaps): how many still, resting bug-frames there were, and how many of
    /// them had a centre within keepOutClearance (less 3.5 pt: a walker ends its dash up to its 3 pt wobble off its
    /// spot) of `zone`. `guarded` sets the session's keepOut to [zone].
    private func keepOutRests(_ zone: CGRect, guarded: Bool) -> (rests: Int, inside: Int) {
        let o = SessionOptions(snapsRunOut: false, waves: true, stingCosts: true)
        let s = TrapSession(mode: .feed, seed: 1000, best: 0, geometry: geo, options: o)
        if guarded { s.keepOut = [zone] }
        var last: [Int: CGPoint] = [:]
        var rests: Int = 0
        var inside: Int = 0
        var f: Int = 0
        while f < 60 * 60 {
            _ = s.step(dt: frame, input: TrapInput())
            for bug in s.snapshot.bugs {
                let prev: CGPoint? = last[bug.id]
                last[bug.id] = bug.position
                guard let p = prev else { continue }
                let still: Bool = abs(p.x - bug.position.x) < CGFloat(1e-9) && abs(p.y - bug.position.y) < CGFloat(1e-9)
                var resting: Bool = false
                switch bug.activity {
                case .sipping, .walking, .arriving: resting = still
                case .hopping, .leaving, .caught, .escaped, .released: resting = false
                }
                if !resting { continue }
                rests += 1
                let c: Double = TrapRules.keepOutClearance(radius: BugCatalog.info(bug.species).radius,
                                                           protected: bug.species.isProtected)
                if TrapRules.touchesKeepOut([zone], Double(bug.position.x), Double(bug.position.y), clearance: c - 3.5) {
                    inside += 1
                }
            }
            f += 1
        }
        return (rests: rests, inside: inside)
    }

    @Test func noBugRestsInAKeepOutRect() {
        // R7 (SCORE-R6 #4): Core is the source of truth for the HUD's clear zones. With a corner keep-out (the top-right
        // corner of the 952 × 670 scene, over the right lobe's upper half), no resting bug (sipping, or still on the
        // ground, a perch or a dart hover) comes within its clearance over 60 s. The same seed without keepOut does
        // rest there, so it is the rule that moves them.
        let zone = CGRect(x: 560, y: 360, width: 392, height: 310)
        let free = keepOutRests(zone, guarded: false)
        let held = keepOutRests(zone, guarded: true)
        #expect(free.inside > 0, "without keepOut bugs rest in the corner: \(free)")
        #expect(held.rests > 100, "bugs still rest elsewhere: \(held)")
        #expect(held.inside == 0, "\(held)")
        // The clearance: radius + 8 pt; a protected bug's halo (radius × 1.6 + 4) + 8 pt.
        let fly: CGFloat = BugCatalog.info(.housefly).radius
        let bee: CGFloat = BugCatalog.info(.bee).radius
        #expect(abs(TrapRules.keepOutClearance(radius: fly, protected: false) - (Double(fly) + 8)) < 1e-9)
        #expect(abs(TrapRules.keepOutClearance(radius: bee, protected: true) - (Double(bee) * 1.6 + 12)) < 1e-9)
        #expect(TrapRules.touchesKeepOut([zone], 550, 400, clearance: 11))
        #expect(!TrapRules.touchesKeepOut([zone], 550, 400, clearance: 10))
        #expect(!TrapRules.touchesKeepOut([], 700, 500, clearance: 50))
        #expect(TrapRules.touchesKeepOut([zone], 700, 500, clearance: 0.5), "inside the rect")
    }
}
