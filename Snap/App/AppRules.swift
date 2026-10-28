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

    // MARK: R8: closed is not a pause
    //
    // ROUND-8 §1: the closing pause is gone. Shutting the Duo IS the bite, and the clock stands still while it is shut
    // (Core's `TrapSnapshot.shut`). The pause menu comes only from the pause button.

    /// Demo `closure=` holds the drawn closure; it reads as armed (open) below this many degrees (Core's close start).
    static let heldClosureArmedBelow: Double = 8
    /// Home's title trap: the closure (degrees) that reads as fully shut for its little creak meter.
    static let homeClosureSpan: Double = 90

    /// R8: a step made from a hinge report while no scene frame has come for this long (s): the Duo was shut (the app
    /// moved to the outer display), so the bite at the shut is stepped from the hinge itself. Pure; tested.
    static let sceneFrameGap: Double = 0.12

    static func stepsFromHinge(sinceSceneFrame: Double, liveHingeRun: Bool, menuOpen: Bool) -> Bool {
        // No frame ever (+∞) counts as "no scene drawing"; NaN never steps.
        guard liveHingeRun, !menuOpen, !sinceSceneFrame.isNaN else { return false }
        return sinceSceneFrame >= sceneFrameGap
    }

    // MARK: Words

    /// One short line, ≤ 4 words (UI owns the words; Core picks the hint). `touch`: no hinge, so the bend/creep/open
    /// hints don't apply. R8 (ROUND-8 §3: "Unclear what to do"): each says what to do now. Pure; tested.
    static func hintText(_ hint: TrapHint, touch: Bool) -> String? {
        switch hint {
        // R8 (founder rule 2: no pose demands, ever): flat, laptop, any angle plays; Core's too-flat hint says nothing.
        case .bendALittle: return nil
        case .quick: return touch ? nil : "Close it fast!"
        case .openUp: return touch ? nil : "Open it again"
        case .beeInside: return "Bee! Wait…"
        case .crowd: return touch ? "Now! Tap!" : "Now! Close it!"
        case .lastSnap: return "Last snap!"
        case .hungry: return "Hungry! Bite soon"
        }
    }

    // MARK: R8: what each bite did, in plain words

    /// A close from the book to shut this quick (s) is "fast" (ROUND-8 §1: a decisive slam ≤ 0.3 s).
    static let fastClose: Double = 0.3
    /// Under this share caught (of the bugs in the trap at the close's start) the bite was too slow.
    static let slowRatio: Double = 0.6

    /// R8 (ROUND-8 §3: "every bite's result says plainly what was good or bad"): "3 bugs! Fast close", "Too slow, they
    /// flew", "Bee! −1 snap". `good`: the cream plate. `touch`: a tap has no speed, so it never says "Fast close".
    /// Pure; tested.
    static func biteVerdict(_ r: BiteReport, touch: Bool = false) -> (text: String, good: Bool) {
        let n = r.caught.count
        if !r.stingers.isEmpty {
            let who = r.stingers.contains(.wasp) ? "Wasp!" : "Bee!"
            if r.snapsLost > 0 { return (who + " " + snapLossText(r.snapsLost), false) }
            return (who + " Let it leave", false)
        }
        if n == 0 {
            return r.escaped > 0 ? ("Too slow, they flew", false) : ("Empty bite", false)
        }
        let ratio = r.catchRatio.isFinite ? r.catchRatio : 1
        if r.escaped > 0 && ratio < slowRatio && !touch {
            return ("Too slow, \(r.escaped) flew", false)
        }
        let head = n == 1 ? "Got it!" : "\(n) bugs!"
        if !touch && r.duration.isFinite && r.duration > 0 && r.duration <= fastClose { return (head + " Fast close", true) }
        if r.escaped > 0 { return (head + " \(r.escaped) got away", true) }
        if n >= 3 { return (head + " Feast!", true) }
        return (head + " Clean bite", true)
    }

    /// Sample verdicts for the plate's fit tests (every shape the words take).
    static var verdictSamples: [String] {
        ["Got it! Fast close", "3 bugs! Fast close", "12 bugs! 3 got away", "Too slow, they flew",
         "Too slow, 11 flew", "Empty bite", "Bee! \u{2212}2 snaps", "Wasp! Let it leave", "5 bugs! Feast!",
         "2 bugs! Clean bite"]
    }

    // MARK: R8: the teaching levels' coach (Levels 1–5 replace the First Bite)

    /// How many sipping bugs each teaching level waits for before it says "Now" (ROUND-8 §4's teaching order: one fly,
    /// one fly fast, two, a bee then a fly, a crowd of three). Pure; tested.
    static func teachNeed(level: Int) -> Int? {
        switch level {
        case 1, 2, 4: return 1
        case 3: return 2
        case 5: return 3
        default: return nil
        }
    }

    /// The teaching level's one line for this moment, or nil (Core's hints, a bee in the trap among them, speak then).
    /// Pure; tested.
    static func coachLine(level: Int, sipping: Int, beeInTrap: Bool, armed: Bool, touch: Bool) -> String? {
        guard let need = teachNeed(level: level) else { return nil }
        if !armed { return touch ? nil : "Open it again" }
        if beeInTrap { return nil }
        if sipping >= need {
            if touch { return "Now! Tap!" }
            return level == 2 ? "Now! Close it fast!" : "Now close it, fast!"
        }
        if sipping > 0 { return "Wait for \(need)…" }
        if level == 1 { return touch ? "Wait for a fly" : "Bugs are landing…" }
        return level == 2 && !touch ? "Slow closes lose flies" : "Wait for a fly…"
    }

    /// Every coach line, for the fit tests.
    static var coachSamples: [String] {
        var out: [String] = []
        for level in 1...5 {
            for touch in [false, true] {
                for sipping in 0...3 {
                    for armed in [true, false] {
                        if let line = coachLine(level: level, sipping: sipping, beeInTrap: false, armed: armed,
                                                touch: touch), !out.contains(line) {
                            out.append(line)
                        }
                    }
                }
            }
        }
        return out
    }

    // MARK: R8 demo: the CHOMP card's bite

    /// Whether a bite is the kind demo `screen=chomp` waits for (a catch of 3+ bugs, a sting, a dry bite). Pure;
    /// tested.
    static func demoChompMatches(_ r: BiteReport, want: ChompInfo.Kind) -> Bool {
        switch want {
        case .catchBite: return r.stingers.isEmpty && r.caught.count >= 3
        case .sting: return !r.stingers.isEmpty
        case .dry: return r.stingers.isEmpty && r.caught.isEmpty
        }
    }

    /// The bite demo `screen=chomp` shows when the pilot never made one of that kind (logged `made up`).
    static func demoChomp(_ want: ChompInfo.Kind, score: Int) -> ChompInfo {
        switch want {
        case .catchBite:
            return ChompInfo(caught: [.housefly, .gnat, .housefly, .fruitFly], points: 360, score: score + 360,
                             verdict: "4 bugs! Fast close")
        case .sting:
            return ChompInfo(caught: [], stingers: [.bee], points: 0, snapsLost: 1, score: score,
                             verdict: "Bee! " + snapLossText(1))
        case .dry:
            return ChompInfo(caught: [], escaped: 2, points: 0, score: score, verdict: "Too slow, they flew")
        }
    }

    /// R4 (REVIEW-3 #3, the founder's copy): Sprout's free first sting, in the hint slot.
    static let freeStingCopy = "Bees and wasps cost snaps. This one's free!"
    /// R4 (REVIEW-3 #10): the card's chain line.
    static let chainLesson = "Big bites in a row build a chain."

    /// R4 (REVIEW-3 #10): the one-time tag on a player's first chain step. R6 (#14, SCORE-R5 D2 #2): it explains the
    /// chip: "Chain ×1.5! Big bites in a row multiply."
    static func chainTagText(_ multiplier: Double) -> String {
        "Chain " + multiplierText(multiplier) + "! Big bites in a row multiply."
    }

    /// R6: a goal's live toast ("Goal done! A 5-bug bite").
    static func goalDoneText(_ title: String) -> String { goalDoneHeading + " " + title }
    /// R6 (Core #19): the late night's telegraph.
    static func nightCueText(_ c: NightCue) -> String {
        switch c {
        case .nightGetsFast: return "The night gets fast…"
        case .lastLight: return "Last light…"
        }
    }

    /// R6: how long a goal toast stays (session s; its clock stands still under a warning).
    static let goalToastSeconds: Double = 2.6

    /// The plate's words for an App hint (Core's, the first wave's fold line, the free sting's toast, the first chain
    /// tag). Pure; tested.
    static func hudHintText(_ hint: HUDHint, touch: Bool) -> String? {
        switch hint {
        case let .trap(h): return hintText(h, touch: touch)
        // ROUND-3 founder call: the Duo's fold is the input, so the first wave says so (phones keep the tap).
        // R8 (founder rules 4, 6): "phone", and phones say "Tap to snap".
        case .foldInput: return touch ? "Tap to snap" : "Close the phone to bite"
        case .beesCost: return freeStingCopy
        case let .chainTag(m): return chainTagText(m)
        case let .goalDone(t): return goalDoneText(t)
        case let .nightCue(c): return nightCueText(c)
        case let .verdict(t, _): return t
        case let .coach(t): return t
        }
    }

    /// The free sting is good news (cream plate, R4); the crimson plate is for real warnings (R8: and a bad bite).
    static func hudHintIsWarning(_ hint: HUDHint) -> Bool {
        switch hint {
        case let .trap(h): return hintIsWarning(h)
        case let .verdict(_, good): return !good
        case .foldInput, .beesCost, .chainTag, .goalDone, .nightCue, .coach: return false
        }
    }

    /// The App's two-sentence toasts set a size smaller (`HintFit.font(compact:long:)`), so they fit three lines.
    static func hudHintIsLong(_ hint: HUDHint) -> Bool {
        switch hint {
        case .trap, .foldInput, .nightCue, .verdict, .coach: return false
        case .beesCost, .chainTag, .goalDone: return true
        }
    }

    /// R7 (#5): a plate that is a moment from the message queue (a toast), not a state: it waits (its clock still)
    /// rather than cover the bugs on the trap. Core's hints, the fold line and the coach are states and always show.
    /// Pure; tested.
    static func hudHintIsToast(_ hint: HUDHint) -> Bool {
        switch hint {
        case .trap, .foldInput, .coach: return false
        case .beesCost, .chainTag, .goalDone, .nightCue, .verdict: return true
        }
    }

    /// The chain tags the HUD can show (the first chain step's multipliers), for the fit tests.
    static let chainTagSamples: [Double] = [1.5, 2, 2.5]

    /// Every line the hint plate can show, on both inputs, with whether it is set in the toast size (REVIEW-2 #3: the
    /// no-truncation test renders each one). R8: with the bite verdicts and the teaching levels' coach lines.
    static var allHintLines: [(text: String, long: Bool)] {
        let core: [TrapHint] = [.bendALittle, .quick, .openUp, .beeInside, .crowd, .lastSnap, .hungry]
        var out: [(text: String, long: Bool)] = []
        var hints: [HUDHint] = core.map { HUDHint.trap($0) } + [.foldInput, .beesCost]
        hints += chainTagSamples.map { HUDHint.chainTag($0) }
        // R6: the late night's two cues (the goal toasts have their own plate: `goalToastTitles`).
        hints += [HUDHint.nightCue(.nightGetsFast), HUDHint.nightCue(.lastLight)]
        hints += verdictSamples.map { HUDHint.verdict($0, good: true) }
        hints += coachSamples.map { HUDHint.coach($0) }
        for touch in [false, true] {
            for h in hints {
                guard let t = hudHintText(h, touch: touch), !out.contains(where: { $0.text == t }) else { continue }
                out.append((text: t, long: hudHintIsLong(h)))
            }
        }
        return out
    }

    /// Every line the hint plate can show, on both inputs.
    static var allHintCopy: [String] { allHintLines.map(\.text) }

    /// R6: every goal title a toast can show (Core's whole pool). The plate sets "Goal done!" on its own line and the
    /// title under it in the toast size (`HintPlate`).
    static var goalToastTitles: [String] { GoalBridge.allIDs.map { GoalBridge.title($0) } }
    static let goalDoneHeading = "Goal done!"

    /// R4 (REVIEW-3 #9): how long the first-wave line may wait for its chance (session s after the run-start line).
    static let foldHintWindow: Double = 40

    /// The opening's "Snap the halves together" (phones: "Tap to snap"): Feed and the Daily only, before the run's
    /// first snap, once the run-start line has gone, and never over one of Core's hints. R4 (REVIEW-3 #9: frame 10 was
    /// wave 2 with no plate): the first two waves, within `foldHintWindow` s. Pure; tested.
    static func showsFoldHint(mode: RunMode, wave: Int, snapsMade: Int, time: Double, after banner: Double,
                              coreHint: TrapHint?) -> Bool {
        switch mode {
        case .feed, .daily, .zen: break
        // R8: a level's intro card and coach say it.
        case .attract, .lesson, .level: return false
        }
        return wave <= 2 && snapsMade == 0 && time >= banner && time < banner + foldHintWindow && coreHint == nil
    }

    /// Warnings get the crimson plate; the rest the cream one.
    static func hintIsWarning(_ hint: TrapHint) -> Bool {
        switch hint {
        case .beeInside, .quick, .lastSnap, .hungry: return true
        case .bendALittle, .openUp, .crowd: return false
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

    /// R4 (founder call, REVIEW-3 #11): Sprout's first Feed run starts full, at the most snaps the trap can hold. The
    /// lesson shows this same row (REVIEW-3 #19), so the count the player learns is the count they get.
    static var firstRunSnaps: Int { min(max(Tuning.firstRunSnaps, 1), Tuning.maxSnaps) }

    static func startSnaps(mode: RunMode, lifetimeBugs: Int) -> Int? {
        guard case .feed = mode else { return nil }
        return PlantRanks.rank(forLifetimeBugs: max(lifetimeBugs, 0)) == 0 ? sproutStartSnaps : nil
    }

    /// The player's very first Feed run (ROUND-3 founder call, REVIEW-2 #9): 14 snaps, it never wilts and its first bee
    /// is free. R4 (QA-2 #11): counted on Feed runs only, so a player whose first run was the Daily (which stays
    /// standard for fairness) still gets the perks on their first Feed run. Pure; tested.
    static func isSproutFirstRun(mode: RunMode, feedRuns: Int) -> Bool {
        guard case .feed = mode else { return false }
        return feedRuns <= 0
    }

    /// R5 (REVIEW-4 #8, founder call): the Sprout taper's run number for the next Feed run (1, 2 or 3: Core's
    /// `SessionOptions.sproutRun`), counted on Feed runs only; nil for the Daily (everyone's bog stays standard) and
    /// from the fourth Feed run. Pure; tested.
    static func sproutFeedRun(mode: RunMode, feedRuns: Int) -> Int? {
        guard case .feed = mode else { return nil }
        let run = max(feedRuns, 0) + 1
        return run <= Tuning.sproutTaperRuns ? run : nil
    }

    /// Demo play rules (REVIEW-3 #2): standard unless `firstRun=1`, or `progress=fresh` (a true first launch). `nil`:
    /// not a demo, use the store. Pure; tested.
    static func demoFirstRun(firstRun: Bool?, progress: DemoMode.Preset?) -> Bool {
        if let firstRun { return firstRun }
        return progress == .fresh
    }

    /// A sting that cost nothing in a scored run (Sprout's free first bee): the free-sting toast. The lesson's
    /// stings are free too, but it says "Bzzt! Never eat a bee." itself. Pure; tested.
    static func isFreeSting(_ event: TrapEvent, mode: RunMode) -> Bool {
        guard case let .stung(_, _, cost) = event, cost <= 0 else { return false }
        switch mode {
        case .feed, .daily: return true
        // R6: in the Zen Bog every sting is free (it only breaks the chain), so there's no "this one's free". R8: a
        // level's verdict says the sting.
        case .attract, .lesson, .zen, .level: return false
        }
    }

    /// The snaps the HUD shows: Core's count plus the Scene's in-flight offset (Scene R3 #14), within 0…max.
    /// Pure; tested.
    static func shownSnaps(_ left: Int, offset: Int, max m: Int) -> Int {
        min(max(left + offset, 0), max(m, 1))
    }

    /// R4 (QA-2 #2, #3, #4): the numeral and the glyphs only ever move from what they showed toward Core's real
    /// count. `candidate` (Core's count plus the Scene's in-flight offset) is kept between `previous` and `target`, so a
    /// costly sting only goes down, a Feast at the cap never dips, and a run that doesn't spend snaps (the lesson)
    /// never shows 10 → 9 → 10. `hold`: this frame's economy events haven't reached the Scene yet (its offset is a
    /// frame stale), so the row keeps what it showed. Pure; tested.
    static func truthfulSnaps(previous: Int?, target: Int, candidate: Int, max m: Int, hold: Bool) -> Int {
        let top = max(m, 1)
        let goal = min(max(target, 0), top)
        guard let prev = previous.map({ min(max($0, 0), top) }) else { return goal }
        if hold { return prev }
        let lo = min(prev, goal)
        let hi = max(prev, goal)
        return min(max(candidate, lo), hi)
    }

    /// Whether this frame's events change the snaps the Scene animates (its offset lags them by one frame).
    static func movesSnaps(_ events: [TrapEvent]) -> Bool {
        events.contains { e in
            switch e {
            case .snapped, .stung, .feast, .luckySnap, .wilted: return true
            default: return false
            }
        }
    }

    /// The one-time label on the first Feast's flying glyph ("+1 snap", "+2 snaps"). R4 (ROUND-4 "+1 (full)"): a
    /// refund that the full row can't hold says so. R7 (#5, SCORE-R6 D2 #2: "+2 (full)" was never explained): in plain
    /// words, "+2 snaps (row full)". Pure; tested.
    static func snapGainText(_ n: Int, full: Bool = false) -> String {
        let k = max(n, 1)
        let snaps = "+\(k) \(k == 1 ? "snap" : "snaps")"
        return full ? snaps + " (row full)" : snaps
    }

    /// R7 (#5: "Lucky!" and "Golden!" were never explained): the lucky bug's plain name.
    static func luckyName(_ s: BugSpecies) -> String {
        s == .goldenScarab ? "Golden scarab" : BugCatalog.info(s).name
    }

    /// R7 (#5): the lucky bug's line in plain words: "Golden scarab! +2 snaps", "Ladybird! +1 snap" (the Zen Bog has
    /// no snaps to win: "Golden scarab!"). For the Scene's line under the bite (design/notes/app-R7.md). Pure; tested.
    static func luckyText(_ s: BugSpecies, snaps: Bool = true) -> String {
        let name = luckyName(s) + "!"
        guard snaps else { return name }
        let k = max(s == .goldenScarab ? Tuning.scarabRefund : Tuning.ladybirdRefund, 1)
        return name + " +\(k) \(k == 1 ? "snap" : "snaps")"
    }

    /// R7 (#3, #5): the one tag a bite's refund gets at the snaps row, or nil (most bites say nothing there):
    /// - a lucky bug names itself ("Golden scarab! +2 snaps");
    /// - a FEAST event shows its refill ("FEAST! +2 snaps");
    /// - a refund the full row can't hold says so ("+2 snaps (row full)");
    /// - the player's first Feast ever is labelled once ("+1 snap").
    /// `back`: the bite's whole refund (`BiteReport.snapsBack`). Pure; tested.
    static func biteGainText(back: Int, full: Bool, lucky: [BugSpecies], bigFeast: Bool, firstFeast: Bool) -> String? {
        guard back > 0 else { return nil }
        let k = max(back, 1)
        let snaps = "+\(k) \(k == 1 ? "snap" : "snaps")" + (full ? " (row full)" : "")
        if let s = lucky.first { return luckyName(s) + "! " + snaps }
        if bigFeast { return "FEAST! " + snaps }
        if full || firstFeast { return snaps }
        return nil
    }

    /// R7 (#3, SCORE-R6 D2 #2: "×" meant the bug count and the chain at once): the bite's callout counts bugs in
    /// words, "5 bugs · +540" ("+12" for one bug); "×" is only ever the chain. For the Scene's pop
    /// (design/notes/app-R7.md). Pure; tested.
    static func biteCallout(count n: Int, points: Int) -> String {
        let p = "+" + formatted(max(points, 0))
        guard n >= 2 else { return p }
        return "\(n) bugs · " + p
    }

    /// R5 (REVIEW-4 #7, founder call): a costly sting's tag at the row, the mirror of "+1 snap": "−1 snap",
    /// "−2 snaps" (a true minus sign). Pure; tested.
    static func snapLossText(_ n: Int) -> String {
        let k = max(n, 1)
        return "\u{2212}\(k) \(k == 1 ? "snap" : "snaps")"
    }

    // MARK: R5: the score word, the tired banner, the bee guard, the Daily share

    /// R5 (REVIEW-4 #13, founder call): the score's word in the UI. R7 (#8): the leaderboard's display name is "Best
    /// Score" too ("Feast" is a 3+ bite).
    static let scoreWord = "score"
    static let leaderboardName = "Best Score"

    /// R5 (REVIEW-4 #4, with Feel's `afterLoss`): the tired banner waits this long after the bite (session s into the
    /// tired moment), so the numeral has dropped first.
    static let tiredBannerDelay: Double = 0.45
    /// If the numeral still hasn't reached 0 this far in (the Scene's crack held up, the scene paused), it is set to 0,
    /// so the banner can follow.
    static let tiredNumeralLimit: Double = 0.8
    /// R7 (#5, frame 19: "+12", "×1.5 held" and the banner at once): while the last bite's pops are still up the
    /// banner waits for them, until this far into the tired moment at the latest.
    static let tiredBannerLatest: Double = 1.5
    /// Demo `freezeOn=tired` holds here: the numeral at 0, the bite's pops gone and the banner up.
    static let tiredFreezeAt: Double = 1.6

    /// Seconds into the tired moment (nil while the trap is in play or the run is over). Pure; tested.
    static func tiredElapsed(_ phase: RunPhase) -> Double? {
        if case let .tired(elapsed) = phase { return elapsed.isFinite ? max(elapsed, 0) : 0 }
        return nil
    }

    /// "Your trap is tired." shows only once the numeral shows 0, and at least `tiredBannerDelay` after the bite
    /// (REVIEW-4 #4: 19 and 40 showed it over a 1 and a 2). Pure; tested.
    /// R7 (#5): `popsLive`: the Scene's pops are still on screen, so the banner waits (to `tiredBannerLatest`).
    static func showsTiredBanner(phase: RunPhase, shownSnaps: Int, popsLive: Bool = false) -> Bool {
        guard let t = tiredElapsed(phase) else { return false }
        guard shownSnaps <= 0 && t >= tiredBannerDelay else { return false }
        return !popsLive || t >= tiredBannerLatest
    }

    /// The numeral in the tired moment: what it would show, or 0 once `tiredNumeralLimit` has passed. Pure; tested.
    static func tiredNumeral(_ shown: Int, phase: RunPhase) -> Int {
        guard let t = tiredElapsed(phase), t >= tiredNumeralLimit else { return shown }
        return 0
    }

    /// R5 (REVIEW-4 #5, founder call, belt and braces): a protected bug's halo is inside the trap zone (the Scene draws
    /// the halo on every protected bug that isn't being caught). Pure; tested.
    /// R7 (#17, frame 33: "Hungry… bite!" beside a halo on the trap's edge): the halo counts, not just the bee's
    /// centre: a bee outside the zone whose halo (and a little margin) reaches the trap's edge is beside the trap too.
    static func protectedHaloInTrap(_ s: TrapSnapshot, geometry g: TrapGeometry) -> Bool {
        s.bugs.contains { b in
            guard b.species.isProtected else { return false }
            if case .caught = b.activity { return false }
            if b.inTrap || g.contains(b.position) { return true }
            return haloReaches(b.position, species: b.species, geometry: g)
        }
    }

    /// R7 (#17): the margin past the halo's drawn edge that still counts as touching the trap (scene points).
    static let haloMargin: CGFloat = 8

    /// R7 (#17): a protected bug at `p` has its halo (the Scene's ring, `TrapArt.protectedRingScale` × its radius,
    /// plus `haloMargin`) over the trap zone's edge: `p` is inside the zone grown by that halo. Pure; tested.
    static func haloReaches(_ p: CGPoint, species: BugSpecies, geometry g: TrapGeometry) -> Bool {
        guard p.x.isFinite, p.y.isFinite, g.a > 0, g.b > 0 else { return false }
        let halo = BugCatalog.info(species).radius * TrapArt.protectedRingScale + 4 + haloMargin
        let dx = (p.x - g.center.x) / (g.a + halo)
        let dy = (p.y - g.center.y) / (g.b + halo)
        return dx * dx + dy * dy <= 1
    }

    /// The App never shows "Hungry… bite!" while a halo is inside the zone: it says "Bee! Wait…" instead. Pure; tested.
    static func guardedHint(_ hint: TrapHint?, haloInTrap: Bool) -> TrapHint? {
        guard haloInTrap, hint == .hungry else { return hint }
        return .beeInside
    }

    /// R5 (ROUND-5, player 7's ask): the Daily's one-line share, e.g. "Snapjaw Daily Bog #301 · 4,210 · biggest bite
    /// 6 🪤" (day 0 is 1 Jan, bog #1; no link until launch). Pure; tested.
    /// R6: with the streak ("… · biggest bite 6 · 🔥 4 days 🪤") once there is one.
    static func dailyShareText(day: Int, score: Int, biggestBite: Int, streak: Int = 0,
                               brand: String = AppBrand.name) -> String {
        var line = brand + " Daily Bog #\(max(day, 0) + 1) · " + formatted(max(score, 0))
            + " · biggest bite \(max(biggestBite, 0))"
        if let s = ProgressRules.streakText(streak) { line += " · " + s }
        return line + " 🪤"
    }

    /// R6: a FEAST event (ROUND-6 decision 5): a clean bite of 5 or more bugs, or one at ×4 chain or more; a bite with
    /// a stinger never is (founder rule). The Scene's own rule (`FeastEvent.isBig`), so the freeze lands on the bite
    /// that shows the banner. Pure; tested.
    static func isBigFeast(_ events: [TrapEvent]) -> Bool {
        events.contains { e in
            if case let .snapped(r) = e { return FeastEvent.isBig(r) }
            return false
        }
    }

    /// R7 (demo `freezeOn=feastGulp`): a FEAST event of 5+ bugs (a ×4-chain FEAST of fewer bugs has no crowd to
    /// gulp). Pure; tested.
    static func isCrowdFeast(_ events: [TrapEvent]) -> Bool {
        events.contains { e in
            if case let .snapped(r) = e { return FeastEvent.isBig(r) && r.caught.count >= FeastEvent.count }
            return false
        }
    }

    /// A Feast's refund ran into the cap: the row was (or became) full. `before`: the snaps before the bite. Pure;
    /// tested.
    static func refundHitTheCap(before: Int, after: Int, back: Int, max m: Int) -> Bool {
        back > 0 && after >= m && before - 1 + back >= m
    }

    /// R4 (REVIEW-3 #10, "×1.5 held"): a clean one-bug bite keeps the chain going (no step, no break). Pure; tested.
    static func chainHeld(_ events: [TrapEvent], chain: Int) -> Bool {
        guard chain >= 1 else { return false }
        var held = false
        for e in events {
            switch e {
            case let .snapped(r):
                if r.caught.count == 1 && r.stingers.isEmpty { held = true }
            case .chainUp, .chainBroken:
                return false
            default:
                break
            }
        }
        return held
    }

    /// The chain chip's words: "×1.5", "Chain ×1.5", and "×1.5 held" for a beat after a held bite. Pure; tested.
    static func chainChipText(_ multiplier: Double, short: Bool, held: Bool) -> String {
        let m = multiplierText(multiplier)
        if held { return m + " held" }
        return short ? m : "Chain " + m
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

    /// Results' best chain as the multiplier it built (REVIEW-2 #24), under the label "Best chain": "×1.5 · 1 big
    /// bite", "×2 · 2 big bites"; "–" for none. Pure; tested.
    static func chainText(longest n: Int) -> String {
        guard n > 0 else { return "–" }
        let m = multiplierText(TrapRules.chainMultiplier(n))
        return m + " · \(n) big \(n == 1 ? "bite" : "bites")"
    }

    /// "A" or "An" before a number said aloud ("An 8-bug FEAST", "An 11-bug…", "A 5-bug…"). Pure; tested.
    static func article(_ n: Int) -> String {
        let vowelSound = n == 8 || n == 11 || n == 18 || (80...89).contains(n) || (800...899).contains(n)
        return vowelSound ? "An" : "A"
    }

    /// "was 3,200" beside Results' "New best!" (REVIEW-2 #24). Pure; tested.
    static func previousBestText(_ previous: Int) -> String? {
        previous > 0 ? "was " + formatted(previous) : nil
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
        case .zen: return zenBanner
        // R8: a level opens on its intro card (its goal in one line).
        case .attract, .lesson, .level: return nil
        }
    }

    /// R6: the Zen Bog's opening line.
    static let zenBanner = "Zen Bog. No rush at all."

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

    /// "Double", "Triple", "Quad", "FEAST" (GAME-DESIGN §5), nil for one bug. R7 (#3): no "×" (that is the chain's).
    static func biteName(_ count: Int) -> String? {
        switch count {
        case ..<2: return nil
        case 2: return "Double"
        case 3: return "Triple"
        case 4: return "Quad"
        default: return "FEAST"
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

    // MARK: The teaching levels' pointer (R8: the First Bite's rings, kept for Levels 1–5)

    /// Whether a bug is still part of the scene's play (not leaving, caught, escaped or let go).
    static func inPlay(_ a: BugActivity) -> Bool {
        switch a {
        case .arriving, .walking, .sipping, .hopping: return true
        case .leaving, .caught, .escaped, .released: return false
        }
    }

    /// Sipping bugs in the trap (bees apart) and whether a bee is in it: the coach's counts. Pure; tested.
    static func trapCounts(_ s: TrapSnapshot) -> (sipping: Int, beeInTrap: Bool) {
        var sipping = 0
        var bee = false
        for b in s.bugs where b.inTrap && inPlay(b.activity) {
            if b.species.isProtected {
                bee = true
            } else if b.activity == .sipping {
                sipping += 1
            }
        }
        return (sipping, bee)
    }

    /// The pointer's targets: every bug in play (scene space, rounded so the HUD publishes only on movement),
    /// bees marked (they get the "wait" ring). Pure; tested.
    /// R3: while a bee is in play only the bee is pointed at (its flies are the temptation, not the target).
    static func lessonTargets(_ s: TrapSnapshot) -> [LessonTarget] {
        var out: [LessonTarget] = []
        let beeInPlay = s.bugs.contains { inPlay($0.activity) && $0.species.isProtected }
        for b in s.bugs where inPlay(b.activity) && (!beeInPlay || b.species.isProtected) {
            let p = CGPoint(x: (b.position.x / 2).rounded() * 2, y: (b.position.y / 2).rounded() * 2)
            out.append(LessonTarget(id: b.id, point: p, bee: b.species.isProtected,
                                    sipping: b.activity == .sipping))
        }
        return out
    }

    /// R4 (REVIEW-3 #19: the bee pointer's arrowhead landed on the fly): while the lesson points at a bee, the other
    /// bugs in play, so its arrow comes in from a side that misses them. Pure; tested.
    static func lessonAvoidPoints(_ s: TrapSnapshot) -> [CGPoint] {
        let targets = Set(lessonTargets(s).map(\.id))
        guard s.bugs.contains(where: { targets.contains($0.id) && $0.species.isProtected }) else { return [] }
        var out: [CGPoint] = []
        for b in s.bugs where inPlay(b.activity) && !targets.contains(b.id) {
            out.append(CGPoint(x: (b.position.x / 4).rounded() * 4, y: (b.position.y / 4).rounded() * 4))
        }
        return out
    }

    /// R6 (#6): the queue's message is hidden while paused or frozen; once the trap is tired only a tag at the row
    /// (the last bite's cost) still shows. Pure; tested.
    static func hidesMessage(_ m: HUDMessage, paused: Bool, frozen: Bool, live: Bool) -> Bool {
        if paused || frozen { return true }
        if live { return false }
        if case .tag = m { return false }
        return true
    }

    /// R6 (#6, frame 43: the plate sat on the trap's flies): the boxes (scene space) round every bug in play on the
    /// trap, a little grown and snapped out to 16 pt so the HUD republishes only when one really moves. Pure; tested.
    static func subjectRects(_ s: TrapSnapshot, pad: CGFloat = 8) -> [CGRect] {
        var out: [CGRect] = []
        for b in s.bugs where b.inTrap && inPlay(b.activity) && b.activity != .arriving {
            let r = BugCatalog.info(b.species).radius + pad
            guard b.position.x.isFinite, b.position.y.isFinite, r.isFinite else { continue }
            let x0 = ((b.position.x - r) / 16).rounded(.down) * 16
            let y0 = ((b.position.y - r) / 16).rounded(.down) * 16
            let x1 = ((b.position.x + r) / 16).rounded(.up) * 16
            let y1 = ((b.position.y + r) / 16).rounded(.up) * 16
            out.append(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
        }
        return out
    }

    /// The Scene's live pops, rounded out to 8 pt so the HUD republishes only when one really moves. Pure; tested.
    static func roundedRects(_ rects: [CGRect]) -> [CGRect] {
        rects.compactMap { r -> CGRect? in
            guard r.minX.isFinite, r.minY.isFinite, r.width.isFinite, r.height.isFinite, r.width > 0,
                  r.height > 0 else { return nil }
            let x0 = (r.minX / 8).rounded(.down) * 8
            let y0 = (r.minY / 8).rounded(.down) * 8
            let x1 = (r.maxX / 8).rounded(.up) * 8
            let y1 = (r.maxY / 8).rounded(.up) * 8
            return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        }
    }

    // MARK: Results

    /// One sentence naming the best moment of the run. Pure; tested.
    static func story(_ r: RunResult) -> String {
        let scarabs = r.caughtBySpecies[BugSpecies.goldenScarab.rawValue] ?? 0
        let dragonflies = r.caughtBySpecies[BugSpecies.dragonfly.rawValue] ?? 0
        // R5 (REVIEW-4 #13): no "protein"; the bite's points are just its number.
        if r.biggestBite >= 5 {
            return "\(article(r.biggestBite)) \(r.biggestBite)-bug FEAST in one bite, worth "
                + "\(formatted(r.bestBitePoints))."
        }
        if scarabs > 0 { return "You caught a Golden Scarab. Lucky trap!" }
        if dragonflies > 0 { return "A dragonfly! Only the sharpest snaps catch those." }
        if r.longestChain >= 4 { return "\(r.longestChain) clean snaps in a row. What a chain." }
        if r.beesSpared >= 5 { return "You spared \(r.beesSpared) bees. The meadow thanks you." }
        if r.biggestBite >= 2 {
            return "Best bite: \(r.biggestBite) bugs, worth \(formatted(r.bestBitePoints))."
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

    // MARK: R6 (#16): the next Bug Book page

    /// The page to aim for next: the unfound species that comes earliest in the day (Bug Book order breaks ties);
    /// nil when the Book is full. Pure; tested.
    static func nextBookTarget(_ data: ProgressData) -> BugSpecies? {
        let open = BugSpecies.allCases.filter { !data.isFound($0) }
        return open.min { a, b in
            let pa = BugCatalog.info(a).firstPhase.rawValue + (a.isProtected ? 1 : 0)
            let pb = BugCatalog.info(b).firstPhase.rawValue + (b.isProtected ? 1 : 0)
            if pa != pb { return pa < pb }
            return (BugSpecies.allCases.firstIndex(of: a) ?? 0) < (BugSpecies.allCases.firstIndex(of: b) ?? 0)
        }
    }

    /// Results' line for it, from the Book's own clue ("Something new comes out at dusk."). Pure; tested.
    static func nextBookLine(_ s: BugSpecies) -> String {
        if s.isProtected { return "Spare a striped one to fill its page." }
        switch BugCatalog.info(s).firstPhase {
        case .morning: return "Something new buzzes by in the morning."
        case .noon: return "Something new turns up at noon."
        case .dusk: return "Something new comes out at dusk."
        case .night: return "Something new comes out at night."
        }
    }

    /// Results' Again: a Daily is always practised (one scored try a day).
    static func againMode(_ mode: RunMode) -> RunMode {
        switch mode {
        case let .daily(day, _): return .daily(day: day, scored: false)
        case .feed, .attract, .zen, .level: return mode
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
    /// R8: bugs that escaped a bite.
    var escapes = 0
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
        case .bugEscaped:
            // R8: a level's three stars want none (Core's `RunResult.escapes`).
            escapes += 1
        case .waveStarted, .dayPhaseChanged, .bugArrived, .bugLanded, .bugSipping, .bugHopped, .bugLeft, .bugSpooked,
             .snapStarted, .luckySnap, .chainBroken, .rearmed, .lastSnap, .hungry, .wilted, .tired,
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
                  stings: stings, feasts: feasts, waves: max(s.wave, 0), drySnaps: drySnaps, fastestSnap: fastestSnap,
                  escapes: escapes)
    }
}
