import CoreGraphics
import Foundation

/// The App's pure rules (tested in SnapTests/AppTests.swift): poses, the fold, the frame step, the HUD's words,
/// telemetry, the Daily's dates, the Results sentence and the run tally.
enum AppRules {
    // MARK: Pose and fold

    /// The Duo cover display is 466 × 678 pt; its inner canvas 951 × 669. Anything whose long side is under this, on
    /// a device with a hinge, is the cover.
    static let coverMaxSide: CGFloat = 760

    /// Both Duo displays are ~0.7 short-to-long; other iPhones ~0.46. The inner display is ≥ 600 pt on its short side.
    static func looksLikeDuoInner(_ size: CGSize) -> Bool {
        let short = min(size.width, size.height)
        let long = max(size.width, size.height)
        guard long > 0 else { return false }
        return short / long > 0.62 && short >= 600
    }

    /// The pose for a canvas (Swoop's rule, landscape play).
    static func pose(canvas: CGSize, hingeSeen: Bool, isShut: Bool) -> AppPose {
        let valid = canvas.width > 10 && canvas.height > 10
        let long = max(canvas.width, canvas.height)
        let small = valid && long < coverMaxSide
        if hingeSeen && small { return .cover }
        // A lit inner display (long side ≥ 760) is never "shut", whatever a stale latch says.
        if hingeSeen && isShut && !(valid && long >= coverMaxSide) { return .cover }
        if valid && canvas.height > canvas.width { return .pose }
        return .play
    }

    /// A vertical fold runs down the middle of a landscape Duo inner display (book pose).
    static func hasFold(canvas: CGSize, hingeSeen: Bool, demoFold: Bool, divisionSeen: Bool) -> Bool {
        guard canvas.width >= canvas.height else { return false }
        if demoFold { return true }
        if hingeSeen || divisionSeen { return max(canvas.width, canvas.height) >= coverMaxSide }
        return looksLikeDuoInner(canvas)
    }

    // MARK: Frame step

    /// The driver clamps dt (ARCHITECTURE "The frame loop").
    static let maxStep: Double = 1.0 / 30.0

    static func clampStep(_ dt: Double) -> Double {
        guard dt.isFinite, dt > 0 else { return 0 }
        return min(dt, maxStep)
    }

    static func isLive(_ phase: RunPhase) -> Bool {
        if case .playing = phase { return true }
        return false
    }

    static func isTired(_ phase: RunPhase) -> Bool {
        if case .tired = phase { return true }
        return false
    }

    // MARK: Drawn closure (Scene R2 #20)

    /// Degrees closed from the rest reference for the drawn teeth: ≥ 0, finite, capped at 90. Pure; tested.
    static func drawnClosure(reference: Double, predicted: Double) -> Double? {
        guard reference.isFinite, predicted.isFinite else { return nil }
        return min(max(reference - predicted, 0), 90)
    }

    // MARK: Hinge pause

    /// The closing pause lifts once the hinge is back open past this (a natural snap often reaches 90–100°, so the
    /// pause never sits near 90°: it engages under `Tuning.closingAngle` and lifts well above it).
    static let resumeAngle: Double = 120

    /// Whether a paused (closing) hinge run may carry on. Pure; tested.
    static func mayResume(angle: Double?, isClosing: Bool, isShut: Bool) -> Bool {
        guard let angle, angle.isFinite, !isShut, !isClosing else { return false }
        return angle >= resumeAngle
    }

    // MARK: Words

    /// One line, ≤ 6 words (UI owns the words; Core picks the hint). `touch`: no hinge, so the bend/creep/open hints
    /// don't apply. Pure; tested.
    static func hintText(_ hint: TrapHint, touch: Bool) -> String? {
        switch hint {
        case .bendALittle: return touch ? nil : "Bend it, like a book"
        case .quick: return touch ? nil : "Snap it — quick!"
        case .openUp: return touch ? nil : "Open up to reset"
        case .beeInside: return "Bee! Wait…"
        case .crowd: return "Now!"
        case .lastSnap: return "Last snap — make it count"
        case .hungry: return "Hungry… bite!"
        }
    }

    /// Warnings get the crimson plate; the rest the cream one.
    static func hintIsWarning(_ hint: TrapHint) -> Bool {
        switch hint {
        case .beeInside, .quick, .lastSnap, .hungry: return true
        case .bendALittle, .openUp, .crowd: return false
        }
    }

    /// The lesson shows only the hints it teaches with ("Bee! Wait…" in the bee step, "Now!" when the crowd sips).
    static func lessonShowsHint(_ hint: TrapHint) -> Bool {
        switch hint {
        case .beeInside, .crowd: return true
        case .bendALittle, .quick, .openUp, .lastSnap, .hungry: return false
        }
    }

    /// The HUD's hunger (the next snap glyph's drain): 0 outside play, clamped, in steps of 1/40 so the HUD
    /// republishes only when the glyph visibly changes. Pure; tested.
    static func hudHunger(_ hunger: Double, live: Bool) -> Double {
        guard live, hunger.isFinite else { return 0 }
        return (min(max(hunger, 0), 1) * 40).rounded() / 40
    }

    // MARK: First runs

    /// The snaps a run starts with: 12 while the plant rank is Sprout (GAME-DESIGN §5 "First runs"), else Core's
    /// default (nil). Only Feed: the Daily is everyone's bog, so it stays the same for every player. Pure; tested.
    static let sproutStartSnaps = 12

    static func startSnaps(mode: RunMode, lifetimeBugs: Int) -> Int? {
        guard case .feed = mode else { return nil }
        return PlantRanks.rank(forLifetimeBugs: max(lifetimeBugs, 0)) == 0 ? sproutStartSnaps : nil
    }

    // MARK: Short labels (tiles and stats)

    /// A species' name for small tiles ("Scarab", not "Golden Scarab"). Pure; tested.
    static func shortName(_ s: BugSpecies) -> String {
        switch s {
        case .goldenScarab: return "Scarab"
        default: return BugCatalog.info(s).name
        }
    }

    /// Results' best bite: "4 bugs · 48" ("1 bug · 10"; "–" for none). Pure; tested.
    static func bestBiteText(bugs: Int, points: Int) -> String {
        guard bugs > 0 else { return "–" }
        return "\(bugs) \(bugs == 1 ? "bug" : "bugs") · \(formatted(max(points, 0)))"
    }

    /// Results' longest chain as the multiplier it built: "×1.5 (1 bite)", "×2 (2 bites)"; "–" for none.
    /// Pure; tested.
    static func chainText(longest n: Int) -> String {
        guard n > 0 else { return "–" }
        return multiplierText(TrapRules.chainMultiplier(n)) + " (\(n) \(n == 1 ? "bite" : "bites"))"
    }

    /// Under the rank title: what grows it next ("Catch 30 bugs to grow", "12 more bugs to Nibbler"). Pure; tested.
    static func rankHint(lifetimeBugs: Int) -> String {
        let bugs = max(lifetimeBugs, 0)
        let rank = PlantRanks.rank(forLifetimeBugs: bugs)
        guard rank + 1 < PlantRanks.count else { return "Top rank. The bog bows." }
        let left = max(PlantRanks.threshold(rank + 1) - bugs, 1)
        if bugs == 0 { return "Catch \(left) bugs to grow" }
        return "\(left) more \(left == 1 ? "bug" : "bugs") to \(PlantRanks.title(rank + 1))"
    }

    /// The run-start line (≤ 6 words), shown while no hint is up.
    static func startBanner(_ mode: RunMode, touch: Bool) -> String? {
        switch mode {
        case .feed: return touch ? "Tap to snap. Spare bees." : "Wait for a crowd. Spare bees."
        case let .daily(day, scored): return scored ? dailyTitle(day: day) : "Practice: no score today"
        case .attract, .lesson: return nil
        }
    }

    /// "×1.5" (one decimal only when it has one).
    static func multiplierText(_ m: Double) -> String {
        guard m.isFinite else { return "×1" }
        let r = (m * 10).rounded() / 10
        if r == r.rounded() { return "×\(Int(r))" }
        return "×" + String(format: "%.1f", r)
    }

    /// 12,450 (grouped, en locale so CI frames are stable).
    static func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_GB")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// "Double ×2", "Triple ×3", "Quad ×4", "FEAST ×5" (GAME-DESIGN §5), nil for one bug.
    static func biteName(_ count: Int) -> String? {
        switch count {
        case ..<2: return nil
        case 2: return "Double ×2"
        case 3: return "Triple ×3"
        case 4: return "Quad ×4"
        default: return "FEAST ×\(count)"
        }
    }

    // MARK: Daily dates

    /// Daily days are UTC days (Core's `DailySeed.dayNumber` counts them in UTC), so their labels are too.
    static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return c
    }

    /// The calendar day of a Daily day number (days since 2026-01-01, `DailySeed.dayNumber`).
    static func date(day: Int, calendar: Calendar = AppRules.utcCalendar) -> Date {
        var c = DateComponents()
        c.year = 2026
        c.month = 1
        c.day = 1
        c.hour = 12
        let start = calendar.date(from: c) ?? Date(timeIntervalSince1970: 1_767_268_800)
        return calendar.date(byAdding: .day, value: day, to: start) ?? start
    }

    /// "27 Oct".
    static func dailyDate(day: Int, calendar: Calendar = AppRules.utcCalendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = calendar.timeZone
        f.dateFormat = "d MMM"
        return f.string(from: date(day: day, calendar: calendar))
    }

    /// "Daily Bog · 27 Oct".
    static func dailyTitle(day: Int) -> String { "Daily Bog · " + dailyDate(day: day) }

    // MARK: Telemetry

    /// Whether a bug is in the air (the buzz layer is louder when flying).
    static func isFlying(_ a: BugActivity) -> Bool {
        switch a {
        case .arriving, .hopping, .leaving, .escaped, .released: return true
        case .walking, .sipping, .caught: return false
        }
    }

    /// The bugs on screen for the panned buzz layer (caught bugs are silent). Pure; tested.
    static func buzzers(_ s: TrapSnapshot, sceneWidth: CGFloat) -> [Buzzer] {
        let half = max(sceneWidth / 2, 1)
        var out: [Buzzer] = []
        out.reserveCapacity(s.bugs.count)
        for b in s.bugs {
            if case .caught = b.activity { continue }
            let pan = Double(min(max((b.position.x - half) / half, -1), 1))
            out.append(Buzzer(id: b.id, species: b.species, pan: pan.isFinite ? pan : 0,
                              height: min(max(b.height.isFinite ? b.height : 0, 0), 1), flying: isFlying(b.activity)))
        }
        return out
    }

    static func telemetry(_ s: TrapSnapshot, sceneWidth: CGFloat, playing: Bool) -> TrapTelemetry {
        TrapTelemetry(closure: s.closure, creeping: s.creeping && playing,
                      buzzers: playing ? buzzers(s, sceneWidth: sceneWidth) : [], chain: s.chain,
                      dayClock: s.dayClock, playing: playing)
    }

    // MARK: The lesson's landing spots

    /// Scripted landing spots on the lobes (fractions of the trap's semi-axes) and where each bug flies in from (above
    /// the top edge, on its own side). Pure; tested (every target inside the trap, every entry off screen).
    static let lessonSpots: [(dx: Double, dy: Double)] = [
        (-0.42, 0.02), (-0.46, 0.22), (0.40, -0.26), (-0.48, 0.10), (0.42, -0.18), (-0.22, -0.34),
    ]

    static func lessonSpot(slot: Int, geometry g: TrapGeometry) -> (entry: CGPoint, target: CGPoint) {
        let spot = lessonSpots[((slot % lessonSpots.count) + lessonSpots.count) % lessonSpots.count]
        let target = CGPoint(x: g.center.x + g.a * CGFloat(spot.dx), y: g.center.y + g.b * CGFloat(spot.dy))
        return (lessonEntry(for: target, geometry: g), target)
    }

    /// Where a scripted bug flies in from: above the top edge, on its target's side.
    static func lessonEntry(for target: CGPoint, geometry g: TrapGeometry) -> CGPoint {
        let side: CGFloat = target.x < g.center.x ? -1 : 1
        let entryX = min(max(target.x + side * 220, -30), g.sceneSize.width + 30)
        return CGPoint(x: entryX, y: g.sceneSize.height + 60)
    }

    /// The lesson's target for `slot` ON a real nectar drop, so the bug sips (Core sips only when the target is within
    /// 1.5 pt of a free drop: QA-1 #3, REVIEW-1 #8). The drop nearest the slot's spot that is free (no occupant) and not
    /// in `taken` (drops already given to this step's other bugs). Falls back to the spot when there's no free drop.
    /// Returns the drop id used (nil: the fallback). Pure; tested.
    static func lessonSpot(slot: Int, geometry g: TrapGeometry, nectar: [NectarDrop],
                           taken: Set<Int>) -> (entry: CGPoint, target: CGPoint, drop: Int?) {
        let spot = lessonSpot(slot: slot, geometry: g).target
        var best: NectarDrop?
        var bestD = Double.infinity
        for d in nectar where d.occupant == nil && !taken.contains(d.id) && g.contains(d.position) {
            // Keep the lesson's bugs off the crease (the midrib band distorts small sprites on a Duo).
            guard abs(d.position.x - g.center.x) > ScreenLayout.creaseHalfWidth + 8 else { continue }
            let dist = Double(hypot(d.position.x - spot.x, d.position.y - spot.y))
            if dist < bestD {
                bestD = dist
                best = d
            }
        }
        guard let drop = best else { return (lessonEntry(for: spot, geometry: g), spot, nil) }
        return (lessonEntry(for: drop.position, geometry: g), drop.position, drop.id)
    }

    /// Whether a bug is still part of the scene's play (not leaving, caught, escaped or let go).
    static func inPlay(_ a: BugActivity) -> Bool {
        switch a {
        case .arriving, .walking, .sipping, .hopping: return true
        case .leaving, .caught, .escaped, .released: return false
        }
    }

    /// The lesson's drop claims kept only for bugs still in play. Pure; tested.
    static func liveClaims(_ claims: [Int: Int], snapshot s: TrapSnapshot) -> [Int: Int] {
        var live = Set<Int>()
        for b in s.bugs where inPlay(b.activity) { live.insert(b.id) }
        return claims.filter { live.contains($0.key) }
    }

    /// The lesson's pointer targets: every bug in play (scene space, rounded so the HUD publishes only on movement),
    /// bees marked (they get the "wait" ring). Pure; tested.
    static func lessonTargets(_ s: TrapSnapshot) -> [LessonTarget] {
        var out: [LessonTarget] = []
        for b in s.bugs where inPlay(b.activity) {
            let p = CGPoint(x: (b.position.x / 2).rounded() * 2, y: (b.position.y / 2).rounded() * 2)
            out.append(LessonTarget(id: b.id, point: p, bee: b.species.isProtected,
                                    sipping: b.activity == .sipping))
        }
        return out
    }

    // MARK: Results

    /// One sentence naming the best moment of the run. Pure; tested.
    static func story(_ r: RunResult) -> String {
        let scarabs = r.caughtBySpecies[BugSpecies.goldenScarab.rawValue] ?? 0
        let dragonflies = r.caughtBySpecies[BugSpecies.dragonfly.rawValue] ?? 0
        if r.biggestBite >= 5 {
            return "A \(r.biggestBite)-bug FEAST in one bite: \(formatted(r.bestBitePoints)) protein."
        }
        if scarabs > 0 { return "You caught a Golden Scarab. Lucky trap!" }
        if dragonflies > 0 { return "A dragonfly! Only the sharpest snaps catch those." }
        if r.longestChain >= 4 { return "\(r.longestChain) clean snaps in a row. What a chain." }
        if r.beesSpared >= 5 { return "You spared \(r.beesSpared) bees. The meadow thanks you." }
        if r.biggestBite >= 2 {
            return "Best bite: \(r.biggestBite) bugs for \(formatted(r.bestBitePoints)) protein."
        }
        if r.bugsCaught > 0 {
            return "\(r.bugsCaught) \(r.bugsCaught == 1 ? "bug" : "bugs") caught. Next time, wait for a crowd."
        }
        return "Not a nibble. Wait until they sip, then snap."
    }

    /// "312 short of your best" within 25 % of it. Pure; tested.
    static func nearMiss(score: Int, best: Int, newBest: Bool) -> String? {
        guard !newBest, best > 0, score > 0, score < best else { return nil }
        let gap = best - score
        guard Double(gap) <= Double(best) * 0.25 else { return nil }
        return "\(formatted(gap)) short of your best"
    }

    /// Results' Again: a Daily is always practised (one scored try a day).
    static func againMode(_ mode: RunMode) -> RunMode {
        switch mode {
        case let .daily(day, _): return .daily(day: day, scored: false)
        case .feed, .attract: return mode
        case .lesson: return .feed
        }
    }
}

// MARK: - The run tally (the App's own count of a live run, for a run left early)

/// Core's `RunResult` exists only once a run finishes; a run left early (Home, Restart, a kill in the background) is
/// filed from this tally of its events plus the last snapshot, so its bugs still fill the Bug Book.
struct RunTally: Equatable {
    var snaps = 0
    var caught: [String: Int] = [:]
    var spared: [String: Int] = [:]
    var bestBitePoints = 0
    var biggestBite = 0
    var longestChain = 0
    var stings = 0
    var feasts = 0
    var drySnaps = 0
    /// Hinge snaps only (touch runs report 0, like Core).
    var fastestSnap = 0.0
    var hingeTiming = false

    init(hingeTiming: Bool = false) { self.hingeTiming = hingeTiming }

    mutating func note(_ event: TrapEvent) {
        switch event {
        case let .snapped(report):
            snaps += 1
            bestBitePoints = max(bestBitePoints, report.points)
            biggestBite = max(biggestBite, report.caught.count)
            if hingeTiming, report.duration.isFinite, report.duration > 0 {
                fastestSnap = fastestSnap > 0 ? min(fastestSnap, report.duration) : report.duration
            }
        case let .bugCaught(_, species, _):
            if !species.isProtected { caught[species.rawValue, default: 0] += 1 }
        case let .beeSpared(species):
            spared[species.rawValue, default: 0] += 1
        case .stung:
            stings += 1
        case .feast:
            feasts += 1
        case .drySnap:
            drySnaps += 1
        case let .chainUp(count, _):
            longestChain = max(longestChain, count)
        case .waveStarted, .dayPhaseChanged, .bugArrived, .bugLanded, .bugSipping, .bugHopped, .bugLeft, .bugSpooked,
             .snapStarted, .bugEscaped, .luckySnap, .chainBroken, .rearmed, .lastSnap, .hungry, .wilted, .tired,
             .newBest, .finished:
            break
        }
    }

    /// The run so far as a RunResult.
    func result(mode: RunMode, seed: UInt64, snapshot s: TrapSnapshot) -> RunResult {
        RunResult(mode: mode, seed: seed, score: max(s.score, 0), seconds: s.time.isFinite ? max(s.time, 0) : 0,
                  snaps: snaps, bugsCaught: max(s.bugsCaught, caught.values.reduce(0, +)), caughtBySpecies: caught,
                  sparedBySpecies: spared, bestBitePoints: bestBitePoints, biggestBite: biggestBite,
                  longestChain: max(longestChain, s.chain), beesSpared: max(s.beesSpared, spared.values.reduce(0, +)),
                  stings: stings, feasts: feasts, waves: max(s.wave, 0), drySnaps: drySnaps, fastestSnap: fastestSnap)
    }
}
