import Combine
import QuartzCore
import SpriteKit
import SwiftUI
import UIKit

/// The hub of the frame loop (ARCHITECTURE "The frame loop"): BogScene.update → advance(dt:now:) → trap source (hinge,
/// touch, pilot, fixed) → TrapSession.step → FeedbackDirector → HUD. Owns the session, the scene, the sources, the
/// app's route, the levels and the Duo states (the cover, shut; R8: portrait plays, the scene turned a quarter).
///
/// R8 (ROUND-8 §1: the phone IS the trap): closed is not a pause. Shutting the Duo is the bite (Core's `snapped`, at
/// the shut) and the clock stands still while it is shut (`TrapSnapshot.shut`). iOS moves the app to the outer display
/// then, so the scene stops drawing: the hinge's own reports step the session (`stepFromHinge`), so the bite, its CHOMP
/// and its haptic land at the shut, and the outer display shows the CHOMP card (`coverChomp`).
///
/// Pauses (no stepping): the app inactive or in the background, the pause menu (the pause button only), the cover
/// (`pose`: the cover display; R8: never portrait, which plays) and a touch level's intro card. The "tired" ending plays
/// out under a pose pause, so a finished run always reaches Results.
@MainActor
final class GameController: ObservableObject, SceneDriver {
    private enum PauseReason: String, Hashable { case menu, background, pose, intro }

    // MARK: Tuning (named so they're easy to find)

    /// HUD publishing cap.
    static let hudInterval: Double = 1.0 / 15.0
    /// `SNAP-T trap …` at 10 Hz.
    static let trapLogInterval: Double = 0.1
    /// The Duo counts as shut (cover display) at or below this hinge angle, and open again from the release angle.
    static let shutBelow: Double = 10
    static let shutReleaseAbove: Double = 15
    /// The Results card follows the end of Core's tired moment after this beat.
    static let resultsDelay: Double = 0.6
    /// The run-start line's life (session s).
    static let bannerSeconds: Double = 2.6
    static let toastSeconds: Double = 2.4
    /// The first Feast's "+1 snap" label (session s).
    static let snapGainSeconds: Double = 1.8
    /// R4: the free sting's green flash, and how long the chip says "held".
    static let freeFlashSeconds: Double = 1.4
    static let chainHeldSeconds: Double = 1.4
    /// If the tired moment hasn't finished this long after it began (the scene stopped drawing: the cover display),
    /// the run is finished headless and Results shown.
    static let endWatchSeconds: Double = 3.4
    /// An event freeze also pauses the scene this long after it lands (CI: the moment stays on screen).
    static let sceneHoldDelay: Double = 0.4
    /// Home's title trap: a touch chomp on phones.
    static let homeTouchClosure: Double = 22

    // MARK: Published state (the HUD lives in `hud`, Home's trap in `homeTrap`)

    @Published private(set) var route: AppRoute = .home
    @Published private(set) var scene: BogScene?
    @Published private(set) var sceneGeneration = 0
    /// A hinge has reported this launch (or on an earlier launch of this Duo).
    @Published private(set) var hingeSeen = false
    /// The Duo is shut (hinge ≤ 10°, released at ≥ 15°).
    @Published private(set) var isShut = false
    @Published private(set) var input: AppInputKind = .touch
    @Published private(set) var isMenuOpen = false
    @Published private(set) var summary: ResultSummary?
    /// R8: the last bite of this run, for the outer display's CHOMP card (nil before the first bite).
    @Published private(set) var coverChomp: ChompInfo?
    /// R8: a level's intro card (its goal in one line, a picture), up at the level's start.
    @Published private(set) var levelIntro: LevelIntro?
    @Published private(set) var pose: AppPose = .play
    /// Demo `screen=cover|shut|chomp` forces the cover. (R8: `screen=pose` is the portrait layout, `demoPortrait`.)
    @Published private(set) var forcedPose: AppPose?
    /// Demo `screen=icon`: the app icon full screen (and rendered to Documents).
    @Published private(set) var showsIcon = false
    @Published private(set) var mode: RunMode = .feed
    /// A short line over the screen ("Sign in to Game Center in Settings").
    @Published private(set) var toast: String?
    @Published private(set) var reduceMotion = false
    /// Demo event freezes: the scene is paused too, so the moment stays on screen.
    @Published private(set) var sceneHeld = false
    /// A still of the bog as the scene last drew it (REVIEW-1 #12, juror 7: the menus sit on the blurred bog, so the
    /// app is one place). Nil until the scene has been on a view.
    @Published private(set) var bogStill: UIImage?

    let hud = HUDState()
    let homeTrap = HomeTrapState()
    let store: ProgressStore
    let settings: SettingsStore
    let hinge = HingeTrapSource()
    /// The tap source: a fresh one each run.
    private(set) var touch = TouchTrapSource()
    /// Home's title trap on an iPhone without a hinge.
    private let homeTouch = TouchTrapSource()
    private let fixedSource = FixedTrapSource()
    private let feedback = FeedbackDirector.shared
    let demo: DemoMode?

    private var session: TrapSession?
    /// Home's live bog: an attract session drawn behind the menu (never recorded, never on a leaderboard).
    private var homeSession: TrapSession?
    /// Snaps wilted and stings taken this run (the HUD keys its moments on them).
    private var wilts = 0
    private var stings = 0
    /// Where the HUD's snaps row sits, in scene space (Scene's economy glyph flights fly there).
    private var snapsAnchor: CGPoint?
    private var snapsRow: CGRect?
    /// The demo pilot, in fixed steps (Core R3 `PilotRun`, REVIEW-2 #21).
    private var pilotRun: PilotRun?
    /// R8: when the scene last called `advance` and when the session last stepped (CACurrentMediaTime): a hinge
    /// report with no scene frame for `AppRules.sceneFrameGap` steps the session itself (the Duo is shut).
    private var lastSceneFrame: CFTimeInterval = -Double.infinity
    private var lastStepAt: CFTimeInterval = -Double.infinity
    /// R8: the level being played (nil outside a level), its goal met (the level ends a beat later), and that beat.
    private var levelSpec: LevelSpec?
    private var levelPassed = false
    private var levelEndTask: Task<Void, Never>?
    /// R8: the intro card shows at least until this (wall clock), and was dismissed.
    private var introUntil: CFTimeInterval = 0
    /// R8: bites made this run (the cover says "Open to start" before the first).
    private(set) var bitesThisRun = 0
    private var layout: ScreenLayout?
    private var lastCanvasSize: CGSize = .zero
    private var lastCanvasFold = false
    /// R8: the last canvas is portrait, its scene shown turned a quarter (`AppRules.turnsScene`).
    private(set) var canvasTurned = false
    /// The layout the session was built for (its trap geometry).
    private var sessionLayout = ScreenLayout(hasFold: false)
    private var pauseReasons: Set<PauseReason> = []
    private var tally = RunTally()
    private var frames = 0
    private var lastHUD: TimeInterval = -1
    private var lastTrapLog: TimeInterval = -1
    private var lastHint: HUDHint?
    private var recorded = false
    private var checkpointSaved = false
    private var resultsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var endWatchTask: Task<Void, Never>?
    /// Session seconds stepped this run (the demo freeze-after key).
    private var playTime: Double = 0
    /// Demo freeze: the session no longer steps (the scene keeps drawing the held frame).
    private(set) var frozen = false
    private var freezePendingAt: Double?
    private var freezePendingTag: DemoMode.Freeze?
    private var systemReduceMotion = false
    private var homeTicker: AppFrameTicker?
    private var lastCanvasLine = ""
    private var bannerText: String?
    private var passedBest = false
    private var appActive = true
    /// R3: Core's `hungry` fired and no bite or wilt has followed yet.
    private var hungryOn = false
    /// R3: the first Feast's one-time "+1 snap" label.
    private var feastsAtStart = 0
    private var snapGainShown = false
    /// R4 (QA-2 #2–#4): what the snaps row last showed (it only ever moves toward Core's count), and Core's count
    /// on the last frame (a Feast's refund against the cap).
    private var shownSnaps: Int?
    private var lastCoreSnaps = 0
    /// R4 (REVIEW-3 #3): the free sting's green row flash and its "free!" tag.
    private var freeFlashUntil: Double = -1
    /// R4 (REVIEW-3 #10): the one-time chain tag (R6 #14: the chain explainer, once ever) and the "held" chip glow.
    private var chainTagEligible = false
    private var chainHeldUntil: Double = -1
    /// R6 (#6): one message at a time (every toast and tag; Core's hints when it's empty).
    private var messages = MessageQueue()
    /// R7 (#5): PlayLayer found no spot for the current toast clear of the trap's bugs (its clock stands still).
    private var plateHeld = false
    /// R7 (#12): the too-flat prompt is up (logged on each change: `SNAP-T too-flat on|off angle=<deg>`).
    private var tooFlatShown = false
    /// R7 (#4): the scene's last `coreKeepOut` (scene space), given to every session.
    private var lastKeepOut: [CGRect] = []
    /// R6: this run's goals, ticked live.
    private var goalRun = GoalRun()
    /// R6 Garden: the variety the scene last drew.
    private var drawnVariety: TrapVariety?

    init(store: ProgressStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.demo = DemoMode.current
        // `snap.hasHinge` comes back with a backup restored onto another iPhone: believe it only on a Duo-shaped screen.
        let stored = UserDefaults.standard.bool(forKey: OrientationLock.hingeKey)
        let trusted = OrientationLock.trustsStoredHinge(stored, screen: UIScreen.main.bounds.size)
        if stored && !trusted { UserDefaults.standard.removeObject(forKey: OrientationLock.hingeKey) }
        self.hingeSeen = trusted
        self.reduceMotion = settings.reduceMotion
    }

    // MARK: - Derived state

    var isDemo: Bool { demo != nil }
    var hasHinge: Bool { hinge.hasHinge }
    var isPaused: Bool { !pauseReasons.isEmpty }
    var hudOnLeft: Bool { demo?.hudLeft ?? settings.hudOnLeft }
    /// R8: the HUD side the scene is laid out with (a turned, portrait scene keeps it on the right: `AppRules.hudOnLeft`).
    private var layoutHudOnLeft: Bool { hudOnLeft && !canvasTurned }
    var demoFold: Bool { demo?.fold ?? false }
    /// R8 demo `portrait=1` or `screen=pose`: the portrait layout on a landscape simulator (`RootView`).
    var demoPortrait: Bool { demo?.showsPortrait ?? false }
    /// No hinge drives the trap: the copy says "tap".
    var touchWording: Bool { input == .touch }
    /// R3: the hint plate's wording. The fold is the input on a hinge, and for a pilot or held demo on a Duo layout
    /// (CI's fold=1 frames); a pilot on a phone layout reads as a phone ("Tap to snap").
    var hintTouch: Bool { !(input == .hinge || (input != .touch && sessionLayout.hasFold)) }
    /// R3 (ROUND-3 founder call): show the Duo's fold as the input (Home's clap diagram, the hinge copy) on a device
    /// with a hinge, or on a Duo layout.
    func showsFoldInput(_ info: AppCanvas) -> Bool { hingeSeen || hinge.hasHinge || info.hasFold }
    /// A run is in play (not finished) on a play route.
    var isLiveRun: Bool {
        guard route.isPlay, let session else { return false }
        return !session.isFinished
    }
    var isScoredDaily: Bool {
        if case let .daily(_, scored) = mode { return scored }
        return false
    }
    var today: Int { DailySeed.dayNumber(for: Date()) }
    var dailyScoredAvailable: Bool { store.canPlayScoredDaily(today: today) }

    /// R8: the level being played (nil outside one).
    var levelID: Int? {
        if case let .level(id) = mode { return id }
        return nil
    }
    /// R8: the level's goal for the cover ("Level 3 · Catch 3 flies").
    var levelGoalLine: String? {
        guard isLiveRun, let spec = levelSpec else { return nil }
        return LevelWords.levelName(LevelBridge.id(spec)) + " · " + LevelWords.goal(spec, touch: hintTouch)
    }
    /// R8: Home's and the cover's next level ("Next: Level 4"), nil when every level is done.
    var nextLevelLine: String? {
        LevelRules.next(store.data).map { "Next: " + LevelWords.levelName($0) }
    }
    /// R8: a run started and no bite yet (the cover says "Open to start").
    var awaitingFirstBite: Bool { isLiveRun && bitesThisRun == 0 }
    /// "Daily Bog · 27 Oct" for the run's day (nil outside a Daily).
    var dailyMarker: String? {
        guard case let .daily(day, scored) = mode else { return nil }
        return scored ? AppRules.dailyTitle(day: day) : "Daily practice · " + AppRules.dailyDate(day: day)
    }
    var restartLabel: String { isScoredDaily ? "Restart as practice" : "Restart" }

    // MARK: - SceneDriver

    func advance(dt: TimeInterval, now: TimeInterval) -> (TrapSnapshot, [TrapEvent]) {
        frames += 1
        if frames == 120 { AppTrace.t("SNAP-T frame 120") }
        lastSceneFrame = CACurrentMediaTime()
        // R8: every menu sits on Home's live bog.
        if route.showsLiveBog { return advanceHome(dt: dt, now: now) }
        return runStep(dt: dt, now: now, headless: false)
    }

    /// R8: the Duo is shut (the scene isn't drawing): a hinge report steps the session, so the bite at the shut, its
    /// CHOMP and its haptic land now, and the cover shows the CHOMP card. Logs `SNAP-T hinge step` once per shut.
    private func stepFromHinge() {
        let now = CACurrentMediaTime()
        let live = route.isPlay && input == .hinge && isLiveRun && !frozen
        guard AppRules.stepsFromHinge(sinceSceneFrame: now - lastSceneFrame, liveHingeRun: live,
                                      menuOpen: isMenuOpen) else { return }
        let dt = lastStepAt.isFinite ? now - lastStepAt : AppRules.maxStep
        let before = session?.snapshot.shut ?? false
        _ = runStep(dt: dt, now: now, headless: true)
        if let s = session?.snapshot, s.shut != before {
            AppTrace.t("SNAP-T hinge step shut=\(s.shut ? 1 : 0) angle=" + AppTrace.fixed(hinge.angle ?? -1, 0))
        }
    }

    /// One step of the run: from the scene's frame, or (`headless`, R8) from a hinge report while the Duo is shut. A
    /// headless step ignores the pose and background pauses (the shut moves the app to the outer display), never the
    /// menu.
    private func runStep(dt: TimeInterval, now: TimeInterval, headless: Bool) -> (TrapSnapshot, [TrapEvent]) {
        guard let session else { return (homeSession?.snapshot ?? TrapSnapshot(), []) }
        guard route.isPlay, !session.isFinished else { return (session.snapshot, []) }
        if !headless { applyDrawnClosure(now: now) }
        let width = sessionLayout.size.width
        if frozen {
            feedback.handle([], telemetry: AppRules.telemetry(session.snapshot, sceneWidth: width, playing: false))
            return (session.snapshot, [])
        }
        refreshIntro(session.snapshot)
        let blocked = headless ? (isMenuOpen || pauseReasons.contains(.intro))
                               : (isPaused && !stepsThroughPause(session.snapshot.phase))
        if blocked {
            // No stepping. The hinge keeps its own state; a snap made while paused is dropped, never played later.
            if input == .hinge { _ = hinge.input(at: now) }
            let s = session.snapshot
            feedback.handle([], telemetry: AppRules.telemetry(s, sceneWidth: width, playing: false))
            publishHUD(s, now: now, force: false)
            return (s, [])
        }
        // A frame-sized step (clamped at 1/30 s), never the time the game was paused or not drawn.
        let step = AppRules.clampStep(dt)
        guard step > 0 else { return (session.snapshot, []) }
        lastStepAt = CACurrentMediaTime()

        let trap: TrapInput
        let events: [TrapEvent]
        if input == .pilot, var run = pilotRun {
            // REVIEW-2 #21 (Core R3): the pilot runs in fixed 1/60 s steps of session time, whatever the frame time,
            // so a CI frame is the same run every time.
            let before = session.snapshot.time
            events = run.advance(session, dt: dt.isFinite ? max(dt, 0) : 0, stamp: now)
            pilotRun = run
            trap = run.lastInput
            playTime += max(session.snapshot.time - before, 0)
        } else {
            trap = currentInput(now: now, step: step, session: session)
            events = session.step(dt: step, input: trap)
            playTime += step
        }

        let snapshot = session.snapshot
        let live = AppRules.isLive(snapshot.phase)
        feedback.handle(events, telemetry: AppRules.telemetry(snapshot, sceneWidth: width, playing: live))
        var snapped = false
        var stingCost = 0
        var bite: BiteReport?
        for event in events {
            tally.note(event)
            switch event {
            case let .snapped(report):
                snapped = true
                bite = report
                bitesThisRun += 1
                // QA-2 #10: only a bite that eats something feeds the trap (a dry snap or a bee bite doesn't).
                if !report.caught.isEmpty { hungryOn = false }
                // R8: the outer display's CHOMP card, and the bite's verdict in plain words for the reopen (session
                // time stands still while shut, so it shows in full once the phone opens).
                coverChomp = ChompInfo(report, score: snapshot.score)
                let verdict = AppRules.biteVerdict(report, touch: input == .touch)
                messages.post(.plate(.verdict(verdict.text, good: verdict.good)), seconds: Self.toastSeconds,
                              now: snapshot.time, interrupt: true)
                AppTrace.t("SNAP-T verdict '" + verdict.text + "' ratio=" + AppTrace.fixed(report.catchRatio, 2))
            case .tired: watchTheEnd()
            case .newBest: passedBest = true
            case .wilted:
                wilts += 1
                snapped = true
                hungryOn = false
            case let .stung(_, _, cost):
                // QA-2 #5: the crimson "lost" flash only for a sting that cost something.
                if cost > 0 {
                    stings += 1
                    stingCost += cost
                }
                // Sprout's free first sting (REVIEW-3 #3): the hint slot says what it would have cost, and the row
                // flashes green. R6 (#6, frame 43): the plate alone says it (no "free!" tag beside it).
                if AppRules.isFreeSting(event, mode: session.mode) {
                    messages.post(.plate(.beesCost), seconds: Self.toastSeconds, now: snapshot.time, interrupt: true)
                    freeFlashUntil = snapshot.time + Self.freeFlashSeconds
                    snapped = true
                    AppTrace.t("SNAP-T toast bees-cost")
                }
            case .hungry:
                hungryOn = true
                snapped = true
            case let .chainUp(_, multiplier):
                // REVIEW-3 #10, R6 (#14): the chain chip is explained once ever, at a player's first chain step.
                if chainTagEligible && levelSpec == nil {
                    chainTagEligible = false
                    store.markChainTipSeen()
                    messages.post(.plate(.chainTag(multiplier)), seconds: Self.toastSeconds, now: snapshot.time)
                    snapped = true
                    AppTrace.t("SNAP-T toast chain")
                }
            default: break
            }
            AppTrace.t("SNAP-T event " + AppTrace.describe(event))
        }
        // The bite's refund, one tag at the row (R7 #3, #5): a lucky bug names itself ("Golden scarab! +2 snaps"), a
        // FEAST event shows its refill ("FEAST! +2 snaps"), a refund the full row can't hold says so ("+1 snap (row
        // full)"; ROUND-4: the numeral never dips), and the first Feast ever is labelled once (REVIEW-2 #12).
        if let bite, bite.snapsBack > 0, session.mode != .zen {
            let full = AppRules.refundHitTheCap(before: lastCoreSnaps, after: snapshot.snapsLeft, back: bite.snapsBack,
                                                max: snapshot.snapsMax)
            let feasted = events.contains { e in
                if case .feast = e { return true }
                return false
            }
            let first = feasted && !snapGainShown && feastsAtStart == 0
            let lucky = bite.caught.filter { $0 == .goldenScarab || $0 == .ladybird }
            if let text = AppRules.biteGainText(back: bite.snapsBack, full: full, lucky: lucky,
                                                bigFeast: FeastEvent.isBig(bite), firstFeast: first) {
                if first { snapGainShown = true }
                messages.post(.tag(.gain(text)), seconds: Self.snapGainSeconds, now: snapshot.time, interrupt: true)
                snapped = true
            }
        }
        if AppRules.chainHeld(events, chain: snapshot.chain) {
            chainHeldUntil = snapshot.time + Self.chainHeldSeconds
            snapped = true
        }
        if stingCost > 0 && session.mode != .zen {
            // R5 (REVIEW-4 #7): "−1 snap" / "−2 snaps" at the row (one tag for the bite's whole cost).
            messages.post(.tag(.loss(AppRules.snapLossText(stingCost))), seconds: Self.snapGainSeconds,
                          now: snapshot.time, interrupt: true)
            snapped = true
        }
        // R6: the goals tick live: a toast each (through the queue) and Feel's chime, after `handle` (above), so a
        // goal a bite completed chimes once the bite's sounds are over.
        let done = goalRun.note(events)
        for g in done {
            messages.post(.plate(.goalDone(g.title)), seconds: AppRules.goalToastSeconds, now: snapshot.time)
            feedback.goalCompleted(bonus: goalRun.completed.count >= GoalBridge.slots && g.id == done.last?.id)
            snapped = true
            AppTrace.t("SNAP-T goal done " + g.id)
        }
        // R6 (Core #19): the night's telegraph ("The night gets fast…", "Last light…") as a toast, in its turn.
        for event in events {
            guard case let .waveStarted(index, _) = event, let cue = TrapRules.nightCue(wave: index, mode: session.mode)
            else { continue }
            messages.post(.plate(.nightCue(cue)), seconds: Self.toastSeconds, now: snapshot.time)
            snapped = true
            AppTrace.t("SNAP-T night cue " + cue.rawValue)
        }
        if AppTrace.enabled && now - lastTrapLog >= Self.trapLogInterval {
            lastTrapLog = now
            let ref = input == .hinge ? hinge.reference : AppTrace.reference(trap)
            AppTrace.t(AppTrace.trapLine(trap, reference: ref))
        }
        publishHUD(snapshot, now: now, force: snapped, hold: AppRules.movesSnaps(events))
        lastCoreSnaps = snapshot.snapsLeft
        demoAfterStep(snapshot, events: events)
        if session.isFinished {
            handleFinished(immediate: headless)
        } else if levelSpec != nil {
            checkLevel(session, snapshot: snapshot)
        }
        return (snapshot, events)
    }

    /// A tap anywhere on the scene: snaps when there is no hinge (ignored otherwise).
    func sceneTapped(at point: CGPoint, time: TimeInterval) {
        // R8 (founder rule 6: nothing is ever stuck on a phone): a tap anywhere starts a level from its intro card.
        if route.isPlay, input == .touch, levelIntro != nil, !isMenuOpen {
            beginLevel()
            return
        }
        guard route.isPlay, input == .touch, !isPaused, !frozen, let session, !session.isFinished else { return }
        guard AppRules.isLive(session.snapshot.phase) else { return }
        touch.tap(at: time)
    }

    /// The tired ending keeps stepping under a closing or pose pause (never under the menu or the background).
    private func stepsThroughPause(_ phase: RunPhase) -> Bool {
        guard AppRules.isTired(phase) else { return false }
        return !pauseReasons.contains(.menu) && !pauseReasons.contains(.background)
    }

    private func currentInput(now: TimeInterval, step: Double, session: TrapSession) -> TrapInput {
        switch input {
        case .hinge:
            return hinge.input(at: now)
        case .touch:
            return touch.input(at: now)
        case .fixed:
            return fixedSource.input(at: now)
        case .pilot:
            // The pilot is stepped by `pilotRun` in `advance`; this is only its last input (or the trap held open).
            return pilotRun?.lastInput ?? fixedSource.input(at: now)
        }
    }

    private func chooseInput() -> AppInputKind {
        if demo?.pilot != nil { return .pilot }
        if demo?.closure != nil { return .fixed }
        if hinge.hasHinge || hingeSeen { return .hinge }
        return .touch
    }

    private func setInput(_ kind: AppInputKind, force: Bool = false) {
        let changed = input != kind
        if changed { input = kind }
        if changed || force { AppTrace.t("SNAP-T input \(kind.rawValue)") }
        // R8 (design/notes/scene-R8.md): with the hinge the lobes never draw shut on the inner screen.
        SceneHooks.setUsesHinge(scene, kind == .hinge)
    }

    /// The first hinge sample of a launch re-chooses the input; a live touch run moves onto the hinge.
    func refreshInput() {
        let kind = chooseInput()
        guard kind != input else { return }
        setInput(kind)
        // QA-1 #8: a run that moved onto the hinge times its snaps from now on.
        if kind == .hinge { tally.hingeTiming = true }
        refreshIdleTimer()
    }

    // MARK: - Lifecycle hooks from RootView

    func launch() {
        if let demo {
            launchDemo(demo)
            return
        }
        // A run killed in the background is filed as left early (its bugs and achievements are kept).
        if let recovered = store.recoverPendingRun(today: today) {
            GameCenterManager.shared.report(result: recovered.0, outcome: recovered.1, progress: store.data)
        }
        // R8 (founder rule 5: no forced tutorial gate): every launch opens on Home. Its Play is Level 1 on a first
        // launch (Levels 1–5 teach), and Endless is one tap away.
        goHome()
    }

    /// The play canvas changed (fold, size, HUD side). The scene is built once and then re-laid out.
    func updateCanvas(_ size: CGSize, hasFold: Bool) {
        guard size.width > 10, size.height > 10 else { return }
        lastCanvasSize = size
        lastCanvasFold = hasFold
        // R8 portrait: the same landscape scene, shown turned a quarter (its layout is the landscape one; the HUD
        // stays on the scene's right lobe, the bottom page) and its word pops drawn upright.
        canvasTurned = AppRules.turnsScene(size)
        SceneHooks.setTextTurned(scene, canvasTurned)
        let left = layoutHudOnLeft
        let newLayout = ScreenLayout.make(viewSize: size, hasFold: hasFold, hudOnLeft: left)
        let line = "SNAP-T canvas \(Int(size.width.rounded()))x\(Int(size.height.rounded())) "
            + "fold=\(hasFold ? 1 : 0) hudLeft=\(left ? 1 : 0)" + (canvasTurned ? " turned=1" : "")
        if line != lastCanvasLine {
            lastCanvasLine = line
            AppTrace.t(line)
        }
        guard newLayout != layout || scene == nil else { return }
        layout = newLayout
        // Feel pans event sounds across the scene's width (wider phones have a wider scene).
        feedback.sceneWidth = Double(newLayout.size.width)
        if hingeSeen && !feedback.deviceHasFold { feedback.deviceHasFold = true }
        if session == nil { sessionLayout = newLayout }
        if let scene {
            // QA-1 (Scene P2): a canvas width change mid-run waits for the next session, so the drawn trap always
            // matches the session's geometry. Fold and HUD-side changes apply at once.
            if isLiveRun && newLayout.size != sessionLayout.size { return }
            scene.layout = newLayout
        } else {
            makeScene(newLayout)
        }
        // Home's bog follows the canvas (its trap geometry must match the scene's).
        if session == nil, let home = homeSession, home.geometry != newLayout.geometry { makeHomeSession() }
    }

    /// Settings › HUD on the left changed.
    func refreshLayout() {
        guard lastCanvasSize.width > 10 else { return }
        updateCanvas(lastCanvasSize, hasFold: lastCanvasFold)
    }

    private func makeScene(_ layout: ScreenLayout) {
        let newScene = BogScene(layout: layout)
        newScene.scaleMode = .aspectFill
        newScene.reduceMotion = reduceMotion
        newScene.driver = self
        scene = newScene
        SceneHooks.setUsesHinge(newScene, input == .hinge)
        SceneHooks.setTextTurned(newScene, canvasTurned)
        sceneGeneration += 1
        drawnVariety = nil
        applyVariety()
        newScene.reset()
        if let p = snapsAnchor { SceneHooks.setSnapsAnchor(newScene, p) }
        SceneHooks.setSnapsRow(newScene, snapsRow)
        SceneHooks.setShowsEconomy(newScene, route.isPlay)
        homeTicker?.stop()
    }

    /// Only `.background` opens the pause menu (folding shut may pass through `.inactive` on hardware, and then every
    /// close would end on the menu). Inactive (Control Centre, a call banner) pauses quietly.
    func setScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            appActive = true
            // A fresh snap detector from the last reading: a stale reference can't make the first frames snap.
            // R9 (core-R9): in a round the reset keeps a waiting round start (the outer-display handover re-activates
            // the scene mid-close); off a round nothing waits.
            if hinge.hasHinge { hinge.reset(at: CACurrentMediaTime(), keepsRoundStart: route.isPlay) }
            if checkpointSaved {
                checkpointSaved = false
                store.clearCheckpoint()
            }
            setPause(.background, false)
            if route == .home { startHomeTicker() }
            return
        }
        appActive = false
        let background = phase == .background
        if background, isLiveRun, !isDemo, let session, !recorded {
            // A kill in the background must not lose the run: keep its result so far until we're back.
            let partial = tally.result(mode: session.mode, seed: session.seed, snapshot: session.snapshot)
            if ProgressRules.worthRecording(partial, goals: goalRun.report) {
                store.saveCheckpoint(partial, goals: goalRun.report)
                checkpointSaved = true
            }
            if !isShut { openMenu() }
        }
        setPause(.background, true)
        homeTicker?.stop()
        feedback.silence()
    }

    /// The display's pose changed (the cover display and back; R8: portrait is play). Logs `SNAP-T pose <pose>`.
    func setPose(_ newPose: AppPose) {
        guard newPose != pose else { return }
        // Keep the bog as it was last drawn for the menus.
        if pose == .play && (route.isPlay || route == .home) { captureStill() }
        pose = newPose
        AppTrace.t("SNAP-T pose \(newPose.rawValue)")
        setPause(.pose, newPose != .play)
        // R9 (core-R9): the outer display took over a hinge round, so the phone is folded even if the hinge's reports
        // stopped short of the shut zone. A waiting round start counts as closed; a shut bites at once (headless step).
        if newPose == .cover && route.isPlay && input == .hinge && hinge.hasHinge && isLiveRun {
            hinge.noteFolded(at: CACurrentMediaTime())
            stepFromHinge()
        }
    }

    func setSystemReduceMotion(_ on: Bool) {
        systemReduceMotion = on
        refreshMotion()
    }

    func refreshMotion() {
        let on = systemReduceMotion || settings.reduceMotion
        if reduceMotion != on { reduceMotion = on }
        scene?.reduceMotion = on
    }

    // MARK: - Hinge

    func hingeSample(angle: Double, time: TimeInterval, status: TrapHingeStatus = .unknown) {
        guard angle.isFinite else { return }
        hinge.ingest(angleDegrees: angle, at: time, status: status)
        if !hingeSeen {
            hingeSeen = true
            if !isDemo { UserDefaults.standard.set(true, forKey: OrientationLock.hingeKey) }
            OrientationLock.hingeArrived()
        }
        if !feedback.deviceHasFold { feedback.deviceHasFold = true }
        if isShut {
            if angle >= Self.shutReleaseAbove { isShut = false }
        } else if angle <= Self.shutBelow {
            isShut = true
        }
        refreshInput()
        // R8: the Duo shut moves the app to the outer display and the scene stops drawing; the hinge's reports step
        // the session from here (the bite at the shut, the reopen's re-arm).
        stepFromHinge()
    }

    /// After a hinge has been seen, a nil is a display handover, never "no hinge" (Brim research).
    func hingeUnavailable() {}

    // MARK: - Values the scene draws from (Scene R2: closure tracking, the economy glyph flights)

    /// The closure the scene draws the teeth from (REVIEW-1 #20): degrees closed from the detector's rest reference,
    /// at display rate from `HingeTrapSource.predictedAngle(at:)` (drawing only, never the snap rule). Nil without a
    /// hinge driving the trap (the scene then uses the snapshot's closure).
    func drawnClosureDegrees(now: TimeInterval) -> Double? {
        guard input == .hinge, hinge.hasHinge, let ref = hinge.reference,
              let predicted = hinge.predictedAngle(at: now) else { return nil }
        return AppRules.drawnClosure(reference: ref, predicted: predicted)
    }

    private func applyDrawnClosure(now: TimeInterval) {
        SceneHooks.setDrawnClosure(scene, drawnClosureDegrees(now: now))
    }

    /// The HUD's snaps anchor (the glyph that changes next, QA-2 #6) and the whole row, in scene space (PlayLayer
    /// reports them on layout and on every count change).
    func setSnapsAnchor(_ p: CGPoint, row: CGRect? = nil) {
        if let row, row != snapsRow {
            snapsRow = row
            SceneHooks.setSnapsRow(scene, row)
        }
        guard p.x.isFinite, p.y.isFinite, p != snapsAnchor else { return }
        snapsAnchor = p
        SceneHooks.setSnapsAnchor(scene, p)
    }

    /// R6 (Scene #7): the play HUD's corners in scene space (PlayLayer reports them with the snaps anchor).
    func setHUDKeepOut(_ rects: [CGRect]) {
        SceneHooks.setHUDKeepOut(scene, rects)
    }

    /// R7 (#5): PlayLayer reports whether the toast on the plate has a spot clear of the trap's bugs this frame.
    func setPlateHeld(_ held: Bool) {
        if plateHeld != held { plateHeld = held }
    }

    /// R7 (Scene/Core #4): Home's real button frames (scene space), so no bug rests behind them.
    func setHomeButtonFrames(_ rects: [CGRect]) {
        SceneHooks.setHomeButtonFrames(scene, rects.isEmpty ? nil : rects)
    }

    /// R7 (Scene/Core #4): Core's clear zones (`BogScene.coreKeepOut`: the HUD plates or Home's buttons, the midrib,
    /// the edges) on both sessions. The Scene sends them on every change; a new session also takes them before its
    /// first step (`prepareKeepOut`).
    fileprivate func applyKeepOut(_ rects: [CGRect]) {
        lastKeepOut = rects
        session?.keepOut = rects
        homeSession?.keepOut = rects
    }

    /// A new session takes the scene's keep-out now (or the last one sent, before a scene exists).
    private func prepareKeepOut(_ s: TrapSession) {
        if let scene {
            scene.applyKeepOut(to: s)
        } else {
            s.keepOut = lastKeepOut
        }
    }

    // MARK: - Home's live bog

    /// Home on an iPhone without a hinge: a tap on the bog chomps the trap.
    func homeTrapTapped() {
        guard route == .home, !hinge.hasHinge else { return }
        homeTouch.tap(at: CACurrentMediaTime())
    }

    /// Home's bog: an attract session (waves of bugs, snaps never run out) drawn by the real scene behind the menu
    /// (REVIEW-1 #12). The hinge (or a tap on phones) drives the trap, so a snap on Home chomps whatever has landed.
    /// Never recorded; its events reach the scene's FX, not the run's feedback (Home plays only the chomp).
    private func advanceHome(dt: TimeInterval, now: TimeInterval) -> (TrapSnapshot, [TrapEvent]) {
        guard let home = homeSession else { return (TrapSnapshot(), []) }
        guard appActive, pose == .play, !frozen else {
            if hinge.hasHinge { _ = hinge.input(at: now) }
            return (home.snapshot, [])
        }
        let step = AppRules.clampStep(dt)
        guard step > 0 else { return (home.snapshot, []) }
        let trap: TrapInput
        if let held = demo?.closure {
            trap = TrapInput(closure: held, armed: true)
        } else if hinge.hasHinge {
            trap = hinge.input(at: now)
        } else {
            trap = homeTouch.input(at: now)
        }
        let events = home.step(dt: step, input: trap)
        let chomped = trap.snap != nil
        feedback.homeTrap(closure: trap.closure, snapped: chomped)
        let c01 = trap.closure.isFinite ? trap.closure / AppRules.homeClosureSpan : 0
        homeTrap.update(closure01: min(max(c01, 0), 1), chomped: chomped)
        applyDrawnClosure(now: now)
        return (home.snapshot, events)
    }

    /// A fresh attract bog for Home (its own seed; demo runs keep theirs so frames are stable).
    private func makeHomeSession() {
        let l = layout ?? ScreenLayout(hasFold: false, hudOnLeft: layoutHudOnLeft)
        sessionLayout = l
        if let scene, scene.layout != l { scene.layout = l }
        let seed: UInt64 = isDemo ? (demo?.seed ?? DemoMode.defaultSeed) : UInt64.random(in: 1...UInt64.max)
        let home = TrapSession(mode: .attract, seed: seed, best: 0, geometry: l.geometry,
                               options: SessionOptions.`for`(.attract))
        // R7 (#4): Core's clear zones before the first step (Home's buttons follow from `goHome`).
        prepareKeepOut(home)
        homeSession = home
        homeTouch.reset()
        scene?.reset()
    }

    /// Captures the scene as last drawn (the menus' backdrop). Cheap enough to do on each screen change: one
    /// offscreen render. Never from inside the scene's own update.
    func captureStill() {
        guard let scene, let view = scene.view, scene.size.width > 1, scene.size.height > 1 else { return }
        guard let texture = view.texture(from: scene) else { return }
        let cg = texture.cgImage()
        guard cg.width > 1, cg.height > 1 else { return }
        bogStill = UIImage(cgImage: cg)
    }

    /// The menus ask for a still when they appear (the first launch straight onto a menu: the scene may not be on a
    /// view yet, so it tries again for a moment).
    func ensureStill() {
        guard bogStill == nil else { return }
        captureStill()
        guard bogStill == nil else { return }
        Task { [weak self] in
            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, self.bogStill == nil else { return }
                self.captureStill()
            }
        }
    }

    private func startHomeTicker() {
        // The live scene drives Home; the ticker is only a fallback before the scene exists.
        guard scene == nil else {
            homeTicker?.stop()
            return
        }
        if homeTicker == nil {
            homeTicker = AppFrameTicker { [weak self] now in self?.tickHome(now) }
        }
        homeTicker?.start()
    }

    private func tickHome(_ now: TimeInterval) {
        guard route == .home, appActive, scene == nil else {
            homeTicker?.stop()
            return
        }
        let trap: TrapInput
        if let held = demo?.closure {
            trap = TrapInput(closure: held, armed: true)
        } else if hinge.hasHinge {
            trap = hinge.input(at: now)
        } else {
            trap = homeTouch.input(at: now)
        }
        let chomped = trap.snap != nil
        feedback.homeTrap(closure: trap.closure, snapped: chomped)
        let c01 = trap.closure.isFinite ? trap.closure / AppRules.homeClosureSpan : 0
        homeTrap.update(closure01: min(max(c01, 0), 1), chomped: chomped)
    }

    // MARK: - Navigation

    func show(_ newRoute: AppRoute) {
        guard !newRoute.isPlay else { return }
        feedback.uiTap()
        if newRoute == .home {
            goHome()
            return
        }
        setRoute(newRoute)
    }

    /// R8: a small tap sound for in-page choices (the map's worlds).
    func feedbackTap() { feedback.uiTap() }

    /// R8: a level's star lands on its Results (`index` 0…2): a rising confirm, the third a celebration.
    func starLanded(_ index: Int) {
        if index >= 2 { feedback.celebrate() } else { feedback.uiConfirm() }
    }

    /// R8: Home's Play: the next level (Level 1 on a first launch), or Endless once every level is done.
    func play() {
        feedback.uiConfirm()
        if let next = LevelRules.next(store.data) {
            start(.level(next))
        } else {
            start(.feed)
        }
    }

    /// R8: Endless (the arcade run: Feed).
    func playEndless() {
        feedback.uiConfirm()
        start(.feed)
    }

    /// R8: a level from the map (a locked one is ignored).
    func playLevel(_ id: Int) {
        guard LevelRules.isOpen(store.data, id) else { return }
        feedback.uiConfirm()
        start(.level(id))
    }

    /// R8: the level results' Next.
    func playNextLevel() {
        guard let next = summary?.level?.next else {
            show(.levels)
            return
        }
        playLevel(next)
    }

    /// R8: the intro card's Go (touch: the clock waits for it).
    func beginLevel() {
        guard levelIntro != nil else { return }
        feedback.uiTap()
        dismissIntro()
    }

    func playDaily() {
        feedback.uiConfirm()
        start(.daily(day: today, scored: true))
    }

    func practiseDaily() {
        feedback.uiConfirm()
        start(.daily(day: today, scored: false))
    }

    /// R6: Home's Zen Bog.
    func playZen() {
        feedback.uiConfirm()
        start(.zen)
    }

    /// Results' Again (a Daily is always practised: `AppRules.againMode`).
    func again() {
        feedback.uiConfirm()
        start(summary.map { AppRules.againMode($0.result.mode) } ?? .feed)
    }

    /// R6 Zen: the pause menu's End. The visit is filed as a finished run (no best, no leaderboard; the Bug Book and
    /// the goals count) and Results shows it.
    func endZen() {
        guard mode == .zen, let session, !recorded else { return }
        feedback.uiConfirm()
        clearRunPauses()
        let result = tally.result(mode: .zen, seed: session.seed, snapshot: session.snapshot)
        AppTrace.t("SNAP-T zen end bugs=\(result.bugsCaught) seconds=\(Int(result.seconds.isFinite ? result.seconds : 0))")
        file(result)
        refreshIdleTimer()
        showResults()
    }

    /// R6: the goals as the pause menu shows them (this run's progress, ticked live).
    var pauseGoals: [GoalLine] {
        guard route == .playing else { return [] }
        return goalRun.lines
    }

    /// R6 Garden: the variety drawn (demo `variety=` wins).
    var trapVariety: TrapVariety { demo?.variety ?? store.data.chosenVariety }

    /// R6 Garden: picks a grown variety; the scene, Home and Results draw it from now on.
    func chooseVariety(_ v: TrapVariety) {
        guard store.chooseVariety(v) else { return }
        feedback.uiTap()
        AppTrace.t("SNAP-T variety \(v.rawValue)")
        applyVariety()
    }

    /// The scene draws the chosen variety (set only when it changes).
    private func applyVariety() {
        let v = trapVariety
        guard v != drawnVariety else { return }
        drawnVariety = v
        SceneHooks.setVariety(scene, v)
    }

    func openMenu() {
        guard route.isPlay, !isMenuOpen else { return }
        feedback.uiTap()
        isMenuOpen = true
        setPause(.menu, true)
    }

    func resume() {
        guard isMenuOpen else { return }
        feedback.uiTap()
        isMenuOpen = false
        setPause(.menu, false)
    }

    /// The pause menu's Restart: a scored Daily restarts as practice (one scored try a day).
    func restart() {
        feedback.uiTap()
        switch mode {
        case let .daily(day, _):
            start(.daily(day: day, scored: false))
        case .feed, .attract, .zen, .level:
            start(mode)
        case .lesson:
            start(.feed)
        }
    }

    func goHome() {
        abandonLiveRun()
        resultsTask?.cancel()
        endWatchTask?.cancel()
        // Back from a run (or the first time): a fresh bog behind Home. Back from the Bug Book or Settings: the same.
        let freshBog = homeSession == nil || session != nil
        session = nil
        pilotRun = nil
        levelSpec = nil
        levelIntro = nil
        levelPassed = false
        levelEndTask?.cancel()
        coverChomp = nil
        bitesThisRun = 0
        clearRunPauses()
        frozen = false
        sceneHeld = false
        scene?.isPaused = false
        feedback.silence()
        feedback.zen = false
        messages.clear()
        plateHeld = false
        tooFlatShown = false
        goalRun = GoalRun()
        hud.update(HUDValues())
        shownSnaps = nil
        applyVariety()
        if freshBog { makeHomeSession() }
        // QA-2 #7: Home has no snaps row. R6: Home's HUD corners are the Scene's defaults.
        SceneHooks.setShowsEconomy(scene, false)
        SceneHooks.setHUDKeepOut(scene, nil)
        // A snap made on a menu is never delivered on Home's first frame either. R9: Home's trap never waits for a close.
        if hinge.hasHinge { hinge.reset(at: CACurrentMediaTime(), keepsRoundStart: false) }
        setRoute(.home)
        refreshIdleTimer()
    }

    func showGameCenter() {
        switch GameCenterManager.shared.showDashboard() {
        case .shown, .signingIn: break
        case .signedOut: showToast("Sign in to Game Center in Settings")
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.toastSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func setRoute(_ newRoute: AppRoute) {
        if newRoute != route {
            // Leaving the bog for a menu: keep a still of it for the menu's backdrop.
            if (route == .home || route.isPlay) && !newRoute.isPlay && newRoute != .home { captureStill() }
            route = newRoute
            AppTrace.t("SNAP-T screen \(newRoute.rawValue)")
        }
        if newRoute == .home && appActive { startHomeTicker() } else { homeTicker?.stop() }
        feedback.idle = !newRoute.isPlay
    }

    // MARK: - R8: levels (Levels 1–5 teach; the First Bite lesson is retired)

    /// The intro card's least time on screen (wall s) on a hinge, where it waits for the phone to close.
    static let introSeconds: Double = 2.5
    /// Core ends a level itself (goal met, a bee bitten, time or bites out: the tired ending, then finished). If it
    /// hasn't this long (wall s) after the goal was met, the App ends it (a belt-and-braces fallback).
    static let levelEndBeat: Double = 4.0

    /// The level's intro card. Touch (and a held demo frame): the clock waits for Go. The hinge: it stays while Core
    /// waits for the phone to close (`waitingForClose`), at least `introSeconds`.
    private func showIntro(_ spec: LevelSpec) {
        let id = LevelBridge.id(spec)
        levelIntro = LevelIntro(id: id, world: LevelRules.world(of: id), title: LevelBridge.title(spec),
                                goal: LevelWords.goal(spec, touch: hintTouch), touch: input != .hinge)
        introUntil = CACurrentMediaTime() + Self.introSeconds
        if input == .touch || input == .fixed { setPause(.intro, true) }
        AppTrace.t("SNAP-T level intro \(id)")
    }

    private func dismissIntro() {
        guard levelIntro != nil else { return }
        levelIntro = nil
        setPause(.intro, false)
        AppTrace.t("SNAP-T level go")
    }

    /// The hinge's intro goes once the phone has closed (Core no longer waits) and its least time is up.
    private func refreshIntro(_ s: TrapSnapshot) {
        guard levelIntro != nil, input != .touch, input != .fixed else { return }
        if !s.waitingForClose && CACurrentMediaTime() >= introUntil { dismissIntro() }
    }

    /// Each step of a level: the goal met (Core's own judge on the run so far) ticks the goal line; Core ends the level
    /// (`levelEndBeat` is only the fallback).
    private func checkLevel(_ session: TrapSession, snapshot s: TrapSnapshot) {
        guard let spec = levelSpec, !recorded, !levelPassed else { return }
        let partial = tally.result(mode: session.mode, seed: session.seed, snapshot: s)
        if LevelBridge.evaluate(partial, spec).passed {
            levelPassed = true
            AppTrace.t("SNAP-T level passed \(LevelBridge.id(spec)) t=" + AppTrace.fixed(s.time, 1))
            levelEndTask?.cancel()
            levelEndTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(GameController.levelEndBeat * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.finishLevelNow()
            }
            return
        }
    }

    /// Ends the level here (its goal met, or its time up) and shows its Results.
    private func finishLevelNow() {
        guard levelSpec != nil, let session, !recorded, route.isPlay, !frozen else { return }
        clearRunPauses()
        let result = session.result ?? tally.result(mode: session.mode, seed: session.seed, snapshot: session.snapshot)
        file(result)
        refreshIdleTimer()
        showResults()
    }

    /// Core judges the level; the stars are kept (the best ever) and the next level and world open by them.
    private func fileLevel(_ id: Int, _ result: RunResult) -> LevelResult {
        let spec = LevelBridge.spec(id)
        let judged = spec.map { LevelBridge.evaluate(result, $0) } ?? LevelJudgement(stars: 0, passed: false, line: "")
        let stars = judged.passed ? min(max(judged.stars, 1), 3) : 0
        let kept = store.recordLevel(id, stars: stars)
        let next = LevelRules.nextAfter(id, in: store.data)
        AppTrace.t("SNAP-T level result \(id) stars=\(stars) passed=\(judged.passed ? 1 : 0) best=\(kept.after)"
                   + (kept.opened.map { " world=\($0)" } ?? ""))
        // R9: the goal and Core's line in the player's control (a phone never reads "Shut it faster").
        let phoneWords = hintTouch
        return LevelResult(id: id, world: LevelRules.world(of: id), title: spec.map { LevelBridge.title($0) } ?? "",
                           goal: spec.map { LevelWords.goal($0, touch: phoneWords) } ?? "", stars: stars,
                           bestStars: kept.after, passed: judged.passed,
                           line: LevelWords.outcomeLine(judged.line, touch: phoneWords), next: next,
                           worldOpened: kept.opened)
    }

    /// Files a run once (the store, Game Center, the level's stars) and builds its summary.
    @discardableResult
    private func file(_ result: RunResult) -> ResultSummary {
        recorded = true
        checkpointSaved = false
        endWatchTask?.cancel()
        levelEndTask?.cancel()
        let outcome = store.record(result, today: today, goals: goalRun.report)
        var level: LevelResult?
        if case let .level(id) = result.mode { level = fileLevel(id, result) }
        GameCenterManager.shared.report(result: result, outcome: outcome, progress: store.data)
        AppTrace.t("SNAP-T run score=\(result.score) bugs=\(result.bugsCaught) snaps=\(result.snaps) "
                   + "seconds=\(Int(result.seconds.isFinite ? result.seconds : 0))")
        var made = makeSummary(result, outcome: outcome)
        made.level = level
        summary = made
        return made
    }

    // MARK: - Runs

    private func start(_ newMode: RunMode) {
        abandonLiveRun()
        resultsTask?.cancel()
        endWatchTask?.cancel()
        summary = nil
        clearRunPauses()
        frozen = false
        sceneHeld = false
        scene?.isPaused = false
        freezePendingAt = nil
        freezePendingTag = nil
        var m = newMode
        if case let .daily(day, scored) = m, scored {
            if store.canPlayScoredDaily(today: day) {
                store.startDaily(day: day)
            } else {
                m = .daily(day: day, scored: false)
            }
        }
        mode = m
        if layout == nil {
            // Not laid out yet (a portrait launch): the trap is built for the screen as it will be held.
            var screen = OrientationLock.screenSize()
            if screen.width < 1 { screen = UIScreen.main.bounds.size }
            layout = ScreenLayout.make(viewSize: screen, hasFold: false, hudOnLeft: layoutHudOnLeft)
        }
        sessionLayout = layout ?? ScreenLayout(hasFold: false, hudOnLeft: layoutHudOnLeft)
        let runSeed = seed(for: m)
        // R8: a level's scripted bog, limits and judge are Core's (`SessionOptions.for(.level(id))`).
        var options: SessionOptions = SessionOptions.`for`(m)
        levelSpec = nil
        if case let .level(id) = m { levelSpec = LevelBridge.spec(id) }
        // Demo `wave=`: Core starts the run at that wave (its nectar block and day follow). Never in a level.
        if levelSpec == nil, let wave = demo?.wave, wave > 1 { options.firstWave = wave }
        let rules = runRules(for: m)
        // First runs (GAME-DESIGN §5): 12 snaps while the plant rank is Sprout.
        options.startSnaps = rules.startSnaps
        // R3/R4 (founder calls): the first Feed run starts with 14, never wilts and its first sting is free. R5
        // (REVIEW-4 #8, founder call): the perks taper over Feed runs 1–3 (Core's `SessionOptions.sproutRun`).
        Self.applySprout(feedRun: rules.sproutRun, to: &options)
        if let run = rules.sproutRun {
            AppTrace.t(run == 1 ? "SNAP-T first run options" : "SNAP-T sprout run \(run) options")
        }
        let newSession = TrapSession(mode: m, seed: runSeed, best: store.best(for: m), geometry: sessionLayout.geometry,
                                     options: options)
        session = newSession
        if let scene, scene.layout != sessionLayout { scene.layout = sessionLayout }
        // R7 (#4): Core's clear zones before the first step (the HUD's plates follow once PlayLayer reports them).
        prepareKeepOut(newSession)
        homeSession = nil
        wilts = 0
        stings = 0
        hungryOn = false
        feastsAtStart = store.data.feasts
        snapGainShown = false
        shownSnaps = nil
        lastCoreSnaps = newSession.snapshot.snapsLeft
        freeFlashUntil = -1
        // R6 (#14): the chain explainer shows once ever (a persisted flag, so a seeded demo profile can show it too).
        chainTagEligible = !store.data.chainTipSeen && levelSpec == nil && m != .attract
        chainHeldUntil = -1
        messages.clear()
        plateHeld = false
        tooFlatShown = false
        coverChomp = nil
        bitesThisRun = 0
        levelPassed = false
        levelEndTask?.cancel()
        levelIntro = nil
        pauseReasons.remove(.intro)
        // R6: the run plays the goals Home showed (written now); Feel's Zen bed for the Zen Bog only. R8: a level has
        // its own goal, so the three goals wait for Endless, the Daily and Zen.
        switch m {
        case .feed, .daily, .zen:
            goalRun = GoalRun(book: store.prepareGoals(), mode: m,
                              startPhase: WaveFactory.phase(forWave: max(options.firstWave, 1)))
        case .attract, .lesson, .level:
            goalRun = GoalRun()
        }
        feedback.zen = FeedbackDirector.wantsZen(m)
        applyVariety()
        touch = TouchTrapSource()
        fixedSource.closure = demo?.closure ?? 0
        // R9: a level's pilot reads the level's goal (`DemoRunner.pilot`); every other mode's is unchanged.
        pilotRun = demo?.pilot.map { PilotRun(pilot: DemoRunner.pilot(skill: $0, seed: runSeed &+ 101, mode: m)) }
        setInput(chooseInput(), force: true)
        // QA-1 #2: a snap made on Results, a menu or the pause menu must never fire at t = 0 of this run.
        // R8 (founder rule 3, Core): every hinge round starts closed (shut once, then open).
        if input == .hinge && hinge.hasHinge { hinge.startRound(at: CACurrentMediaTime()) }
        tally = RunTally(hingeTiming: input == .hinge || input == .pilot)
        recorded = false
        playTime = 0
        passedBest = false
        lastHUD = -1
        lastHint = nil
        bannerText = AppRules.startBanner(m, touch: touchWording)
        scene?.reset()
        // R6 Zen: no snaps row, so no economy glyphs either.
        SceneHooks.setShowsEconomy(scene, m != .zen)
        setRoute(.playing)
        // R8: a level opens on its intro card (a pilot demo plays straight through, unless it is the intro's frame).
        if let spec = levelSpec, demo?.pilot == nil || demo?.effectiveScreen == .levelIntro { showIntro(spec) }
        publishHUD(newSession.snapshot, now: CACurrentMediaTime(), force: true)
        refreshIdleTimer()
    }

    /// Core's first-run switches (design/notes/core-R3.md): no hunger, and the first stinger bite costs nothing (its
    /// `stung(cost: 0)` shows the toast). R4 (founder call, REVIEW-3 #11): it starts full, at 14. Pure; tested.
    nonisolated static func applyFirstRun(_ on: Bool, to options: inout SessionOptions) {
        applySprout(feedRun: on ? 1 : nil, to: &options)
    }

    /// R5 (REVIEW-4 #8, founder call; design/notes/core-R5.md): a Sprout's Feed runs 1–3 taper the perks. Run 1: 14
    /// snaps, no wilt, a free sting, the calm morning; run 2: 13, a free sting, the calm morning; run 3: 12, the calm
    /// morning. Core's `sproutRun` is the switch; run 1 also keeps its R3/R4 switches, so it reads the same either way.
    /// Runs 2 and 3 set nothing else (Core's `SproutPerks` decide their wilt and sting). Pure; tested.
    nonisolated static func applySprout(feedRun: Int?, to options: inout SessionOptions) {
        guard let run = feedRun, run >= 1, run <= Tuning.sproutTaperRuns else { return }
        options.sproutRun = run
        if run == 1 {
            options.hunger = false
            options.freeFirstSting = true
            options.startSnaps = AppRules.firstRunSnaps
        }
    }

    /// A run's opening rules: its start snaps and its Sprout taper run (nil: standard). Demo play runs are standard
    /// unless `firstRun=1` or `progress=fresh` (REVIEW-3 #2: every CI run was a Sprout run 1, so hunger and the costly
    /// sting were never seen); those play run 1.
    private func runRules(for m: RunMode) -> (startSnaps: Int?, sproutRun: Int?) {
        let sprout = AppRules.startSnaps(mode: m, lifetimeBugs: store.data.growth)
        guard let demo else {
            return (sprout, AppRules.sproutFeedRun(mode: m, feedRuns: store.data.feedRuns))
        }
        guard case .feed = m else { return (nil, nil) }
        if demo.playsFirstRun { return (sprout, 1) }
        // Unseeded demo progress plays like `progress=mid`: Core's standard start.
        return (demo.progress == nil ? nil : sprout, nil)
    }

    private func seed(for mode: RunMode) -> UInt64 {
        switch mode {
        case .feed, .zen:
            if let s = demo?.seed { return s }
            // R7 (#10, 47 repeated 26's best bite and chain): the Zen Results demo plays its own seed, a Zen run's
            // own numbers.
            if isDemo { return DemoMode.seed(for: mode, screen: demo?.effectiveScreen) }
            return UInt64.random(in: 1...UInt64.max)
        case let .daily(day, _):
            return DailySeed.seed(day: day)
        case .attract:
            return demo?.seed ?? DemoMode.defaultSeed
        case .lesson:
            return 1
        case let .level(id):
            // R8: a level is hand-made: the same bog every try (Core's seed, as the balance sim plays it).
            return LevelBridge.seed(id)
        }
    }

    /// Leaving a live run (Home, Restart, a new run) files its result so far: its bugs into the Bug Book, its catches
    /// into the rank, and a scored Daily's score as the day's score (plus the Game Center boards).
    private func abandonLiveRun() {
        guard let session, !recorded, !session.isFinished else { return }
        if AppRules.isTired(session.snapshot.phase) {
            // QA-1 #9: left during the tired moment, the run is over: file it as the finished run it is (no Results).
            finishHeadless(session)
            if session.isFinished && recordFinished() != nil { return }
        }
        recorded = true
        checkpointSaved = false
        let partial = tally.result(mode: session.mode, seed: session.seed, snapshot: session.snapshot)
        guard ProgressRules.worthRecording(partial, goals: goalRun.report) else {
            store.clearCheckpoint()
            return
        }
        let outcome = store.recordAbandoned(partial, today: today, goals: goalRun.report)
        GameCenterManager.shared.report(result: partial, outcome: outcome, progress: store.data)
        AppTrace.t("SNAP-T abandoned score=\(partial.score) bugs=\(partial.bugsCaught)")
    }

    /// The tired moment normally finishes in 2.2 s of drawn frames. If the scene stopped drawing (the Duo was folded
    /// onto the cover display), finish the run headless so Results never wait on the hinge.
    private func watchTheEnd() {
        endWatchTask?.cancel()
        endWatchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.endWatchSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finishIfStuck()
        }
    }

    private func finishIfStuck() {
        guard let session, !recorded, !session.isFinished, route.isPlay, !frozen, freezePendingAt == nil else { return }
        guard AppRules.isTired(session.snapshot.phase) else { return }
        finishHeadless(session)
        if session.isFinished { handleFinished(immediate: true) }
    }

    /// Steps the tired moment to its end with the trap open (no frames needed).
    private func finishHeadless(_ session: TrapSession) {
        var steps = 0
        let open = TrapInput()
        while !session.isFinished && steps < 600 {
            let events = session.step(dt: AppRules.maxStep, input: open)
            for e in events { tally.note(e) }
            _ = goalRun.note(events)
            steps += 1
        }
        AppTrace.t("SNAP-T ending finished headless steps=\(steps)")
    }

    /// Files the finished run once (the store, Game Center, the `SNAP-T run` line) and builds its summary.
    @discardableResult
    private func recordFinished() -> ResultSummary? {
        guard !recorded, let session, let result = session.result else { return nil }
        return file(result)
    }

    private func handleFinished(immediate: Bool) {
        guard recordFinished() != nil else { return }
        refreshIdleTimer()
        resultsTask?.cancel()
        if immediate {
            showResults()
        } else {
            resultsTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(GameController.resultsDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.showResults()
            }
        }
    }

    private func showResults() {
        guard let summary else { return }
        clearRunPauses()
        feedback.silence()
        levelIntro = nil
        // R8: Results sit on the live bog too (Home's attract session behind the card).
        makeHomeSession()
        SceneHooks.setShowsEconomy(scene, false)
        SceneHooks.setHUDKeepOut(scene, nil)
        setRoute(.results)
        let o = summary.outcome
        let celebrated = o.rankedUp || !o.newSpecies.isEmpty || o.showsNewBest
        if celebrated { feedback.celebrate() }
        if !o.newVarieties.isEmpty {
            // R6: a new trap in the Garden gets Feel's fanfare (after the rank-up's own, if there is one).
            feedback.varietyUnlocked(after: celebrated ? 0.8 : 0)
            AppTrace.t("SNAP-T variety grown " + o.newVarieties.map(\.rawValue).joined(separator: ","))
        }
        if !o.goalsDone.isEmpty { AppTrace.t("SNAP-T results goals \(o.goalsDone.count) growth=\(o.goalGrowth)") }
        if demo?.freezeOn == .results { AppTrace.t("SNAP-T freeze results") }
    }

    /// R7 (#7): Feed's Results title. Pure; tested.
    nonisolated static func feedTitle(newBest: Bool) -> String { newBest ? "What a feast!" : "Your trap is tired" }

    private func makeSummary(_ result: RunResult, outcome: RecordOutcome) -> ResultSummary {
        let title: String
        let again: String
        switch result.mode {
        case .feed:
            // R7 (#7: "YOUR TRAP IS TIRED" over "New best!" in 26, 50, P09): a new best is a feast, not a tired trap.
            title = Self.feedTitle(newBest: outcome.showsNewBest)
            again = "Again"
        case let .daily(day, scored):
            title = scored ? AppRules.dailyTitle(day: day) : "Daily practice · " + AppRules.dailyDate(day: day)
            again = "Practise this bog"
        case .attract:
            title = "Demo run"
            again = "Again"
        case .lesson:
            title = "First Bite"
            again = "Feed"
        case let .level(id):
            title = LevelWords.levelName(id)
            again = "Retry"
        case .zen:
            title = "Zen Bog"
            again = "Back to the bog"
        }
        let rank = outcome.rankAfter
        let next = rank + 1 < PlantRanks.count ? PlantRanks.title(rank + 1) : nil
        let before = outcome.rankedUp ? 0 : ProgressRules.rankProgress(lifetime: outcome.lifetimeBefore, rank: rank)
        let after = ProgressRules.rankProgress(lifetime: outcome.lifetimeAfter, rank: rank)
        return ResultSummary(result: result, outcome: outcome, title: title, story: AppRules.story(result),
                             rankTitle: PlantRanks.title(rank), nextRankTitle: next, rankProgressBefore: before,
                             rankProgressAfter: after, againLabel: again,
                             nearMiss: AppRules.nearMiss(score: result.score, best: outcome.best,
                                                         newBest: outcome.isNewBest))
    }

    // MARK: - HUD

    private func publishHUD(_ s: TrapSnapshot, now: TimeInterval, force: Bool, hold: Bool = false) {
        // R5 (REVIEW-4 #5, belt and braces): never "Hungry… bite!" while a bee's halo is inside the trap zone.
        let haloInTrap = AppRules.protectedHaloInTrap(s, geometry: sessionLayout.geometry)
        let live = AppRules.isLive(s.phase)
        // R8 (founder rule 2: no pose demands): flat, laptop, any angle plays, so there is no too-flat prompt.
        var core = AppRules.guardedHint(s.hint, haloInTrap: haloInTrap)
        if let h = core, AppRules.hintText(h, touch: touchWording) == nil { core = nil }
        // R8 (founder rule 3): the round starts with the phone closed; while Core waits for it, the big calm card
        // says so and the plate is quiet.
        let waiting = s.waitingForClose && live
        if waiting { core = nil }
        // R6 (#6): one message at a time. The queue's toast or tag, else the state hint (Core's, a teaching level's
        // coach, or the opening's fold line); a warning keeps a waiting toast's clock still.
        var state: HUDHint? = core.map { HUDHint.trap($0) }
        let teaching = levelSpec.flatMap { AppRules.teachNeed(level: LevelBridge.id($0)) } != nil
        if state == nil, !waiting, let id = levelID {
            let counts = AppRules.trapCounts(s)
            if let line = AppRules.coachLine(level: id, sipping: counts.sipping, beeInTrap: counts.beeInTrap,
                                             armed: s.armed, touch: hintTouch) {
                state = .coach(line)
            }
        }
        if state == nil && !waiting && AppRules.showsFoldHint(mode: s.mode, wave: s.wave, snapsMade: tally.snaps,
                                                              time: s.time, after: Self.bannerSeconds,
                                                              coreHint: core) {
            state = .foldInput
        }
        let warning = core.map { AppRules.hintIsWarning($0) } ?? false
        // R7 (#5): a toast with no clear spot (PlayLayer: both slots on the trap's bugs) keeps its clock still.
        var message = messages.shown(now: s.time, hint: state, warning: warning, hold: plateHeld)
        if let m = message, AppRules.hidesMessage(m, paused: isPaused, frozen: frozen, live: live) { message = nil }
        var hint: HUDHint?
        var tag: HUDTag?
        switch message {
        case let .plate(h)?: hint = h
        case let .tag(t)?: tag = t
        case nil: break
        }
        var values = HUDValues()
        values.tag = tag
        values.zen = s.mode == .zen
        values.score = s.score
        values.best = s.best
        values.snapsMax = s.snapsMax
        values.chain = s.chain
        values.chainMultiplier = s.chainMultiplier
        values.chainHeld = live && s.time < chainHeldUntil && s.chainMultiplier > 1.01
        values.hint = hint
        values.banner = message == nil && s.time < Self.bannerSeconds && !isPaused ? bannerText : nil
        values.passedBest = passedBest
        values.dayPhase = s.dayPhase
        values.waitingForClose = waiting && levelIntro == nil
        if let spec = levelSpec {
            let left = LevelBridge.timeLimit(spec).map { max(Int(($0 - s.time).rounded(.up)), 0) }
            values.level = LevelHUD(id: LevelBridge.id(spec), goal: LevelWords.goal(spec, touch: hintTouch),
                                    done: levelPassed,
                                    secondsLeft: left)
        }
        values.hunger = AppRules.hudHunger(s.hunger, live: AppRules.isLive(s.phase))
        values.wilts = wilts
        values.stings = stings
        // Scene R3 (#14): the numeral and the glyphs change as each flying glyph lands, and drop only once a sting's
        // crack has shown (`BogScene.snapsShownOffset`). R4 (QA-2 #2–#4): never the wrong way, and held on the frame
        // whose events the Scene hasn't drawn yet.
        let candidate = AppRules.shownSnaps(s.snapsLeft, offset: scene?.snapsShownOffset ?? 0, max: s.snapsMax)
        let truthful = AppRules.truthfulSnaps(previous: shownSnaps, target: s.snapsLeft, candidate: candidate,
                                              max: s.snapsMax, hold: hold)
        // R5 (REVIEW-4 #4): in the tired moment the numeral reaches 0 by `tiredNumeralLimit` at the latest, and the
        // banner shows only once it has (and ≥ 0.45 s after the bite): never "Out of snaps" over a 1 or a 2.
        let shown = AppRules.tiredNumeral(truthful, phase: s.phase)
        shownSnaps = shown
        values.snapsLeft = shown
        // R7 (#5, frame 19): the banner waits for the last bite's pops to go (to `tiredBannerLatest`).
        let popsLive = AppRules.tiredElapsed(s.phase) != nil && !SceneHooks.livePopRects(scene).isEmpty
        values.tired = AppRules.showsTiredBanner(phase: s.phase, shownSnaps: shown, popsLive: popsLive)
        values.plateMayCover = messages.holdSpent
        values.rowFlashing = scene?.snapsRowFlashing ?? false
        values.freeFlash = live && s.time < freeFlashUntil
        // QA-2 #10 (Core R4): keyed on Core's own `hungry` hint, which stays up through a dry snap or a bee bite until a
        // catch or the wilt, and drops while the clock is paused (an empty or bee-only trap). R5: never beside a halo.
        values.hungry = live && !isPaused && s.hint == .hungry && !haloInTrap
        if hint != nil || values.banner != nil {
            values.popRects = SceneHooks.livePopRects(scene)
            // R6 (#6, frame 43): and the bugs in the trap (a plate never covers its subject).
            values.subjectRects = AppRules.subjectRects(s)
        }
        // R8: the teaching levels ring the bugs (the First Bite's pointer), until the level's goal is met.
        if teaching && !isPaused && !waiting && !levelPassed {
            values.lessonTargets = AppRules.lessonTargets(s)
            values.lessonAvoid = AppRules.lessonAvoidPoints(s)
        }
        // A glyph landing or the row flash shows on its frame, not up to 1/15 s later.
        let urgent = force || hint != lastHint || values.tired != hud.values.tired
            || values.waitingForClose != hud.values.waitingForClose || values.level != hud.values.level
            || values.snapsLeft != hud.values.snapsLeft || values.rowFlashing != hud.values.rowFlashing
            || values.freeFlash != hud.values.freeFlash || values.chainHeld != hud.values.chainHeld
            || values.tag != hud.values.tag || values.plateMayCover != hud.values.plateMayCover
        guard urgent || now - lastHUD >= Self.hudInterval else { return }
        lastHUD = now
        lastHint = hint
        hud.update(values)
    }

    // MARK: - Pauses

    private func setPause(_ reason: PauseReason, _ on: Bool) {
        let was = isPaused
        if on {
            let inserted = pauseReasons.insert(reason).inserted
            if inserted && route.isPlay { AppTrace.t("SNAP-T paused \(reason.rawValue)") }
        } else {
            pauseReasons.remove(reason)
        }
        if isPaused && !was {
            feedback.silence()
            // QA-1 #7: a tap made just before the pause never bites on the first frame after it.
            touch.reset()
        } else if !isPaused && was && route.isPlay {
            // Every resume: a fresh detector, so a stroke made in the menu never reads as a bite. R8: not after the
            // shut's own pose change (the outer display and back): the reopen IS the re-arm, Core must see it whole.
            if input == .hinge && hinge.hasHinge && reason != .pose { hinge.reset(at: CACurrentMediaTime()) }
            AppTrace.t("SNAP-T resumed")
        }
        if isPaused != was { refreshIdleTimer() }
    }

    private func clearRunPauses() {
        pauseReasons.remove(.menu)
        pauseReasons.remove(.intro)
        if isMenuOpen { isMenuOpen = false }
    }

    /// The screen may sleep while paused (a Duo left half-closed), never mid-run.
    private func refreshIdleTimer() {
        let keepAwake = !isDemo && isLiveRun && !isPaused
        if UIApplication.shared.isIdleTimerDisabled != keepAwake { UIApplication.shared.isIdleTimerDisabled = keepAwake }
    }

    // MARK: - Demo

    private func launchDemo(_ d: DemoMode) {
        AppTrace.t("SNAP-T demo '\(d.raw)' starts")
        let day = today
        store.replace(DemoPresets.progress(d.progress, today: day))
        if !d.sound { settings.muted = true }
        switch d.effectiveScreen {
        case .home:
            goHome()
        case .play:
            start(d.runMode(today: day))
            if let wave = d.wave, wave > 1 { AppTrace.t("SNAP-T start wave \(wave)") }
        case .results where d.mode == .level:
            demoLevelResults(d)
        case .results:
            start(d.runMode(today: day))
            if let session {
                var t = tally
                var g = goalRun
                // R6: the goals tick as the pilot really plays (Results shows them done, with their growth).
                let zen = session.mode == .zen
                DemoRunner.play(session, skill: d.pilot ?? .casual, seed: session.seed,
                                seconds: zen ? Self.zenResultsSeconds : 900,
                                onEvent: { e in t.note(e) },
                                onStep: { events, _ in _ = g.note(events) })
                tally = t
                goalRun = g
                if zen {
                    endZen()
                } else if session.isFinished {
                    handleFinished(immediate: true)
                } else {
                    goHome()
                }
            }
        case .book:
            goHome()
            setRoute(.book)
        case .settings:
            goHome()
            setRoute(.settings)
        case .daily:
            goHome()
            setRoute(.daily)
        case .garden:
            goHome()
            setRoute(.garden)
        case .levels:
            goHome()
            setRoute(.levels)
        case .levelIntro:
            // The intro card held (no pilot: a phone sim's touch run waits for Go).
            start(.level(d.level ?? DemoMode.defaultLevel))
        case .levelResults:
            demoLevelResults(d)
        case .chomp:
            demoChomp(d)
        case .shut:
            // R8: a run just started, the phone shut before its first bite: the outer display's "Open to start".
            start(d.mode != nil ? d.runMode(today: day) : .feed)
            forcedPose = .cover
        case .pose:
            // R8: the pose card is gone; `screen=pose` is the portrait layout (`demoPortrait`: RootView lays the app
            // out turned on the landscape simulator), over a run of `mode` if given, else Home.
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .cover:
            // R8: the outer display off a run: the closed trap at rest, "Open to play" and the next level.
            goHome()
            forcedPose = .cover
        case .icon:
            showsIcon = true
            goHome()
        case .badges:
            goHome()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                BadgeExport.renderAll()
            }
        }
    }

    /// R8 demo `screen=chomp`: the longest the pilot plays (session s) looking for the bite the card shows.
    static let chompSearchSeconds: Double = 300
    /// R8 demo `screen=levelResults`: the longest the pilot plays a level (session s).
    static let levelSearchSeconds: Double = 300

    /// R8 demo `screen=chomp[;chomp=catch|sting|dry]`: a run really played by the pilot (default casual, `expert` for
    /// a catch) until a bite of that kind (a catch of 3+ bugs for `catch`), then the Duo shown shut on that bite: the
    /// outer display's CHOMP card. If the pilot never makes one, a bite of that kind is made up (logged).
    private func demoChomp(_ d: DemoMode) {
        let want = d.chomp ?? .catchBite
        start(d.mode != nil ? d.runMode(today: today) : .feed)
        guard let session else { return }
        var found: BiteReport?
        var t = tally
        var played = 0.0
        let skill = d.pilot ?? (want == .catchBite ? .expert : .novice)
        // R9: one pilot for the whole search (a fresh one per slice never finished a close).
        var pilot = DemoRunner.pilot(skill: skill, seed: session.seed &+ 101, mode: session.mode)
        while found == nil && played < Self.chompSearchSeconds && !session.isFinished {
            played += DemoRunner.play(session, pilot: &pilot, seconds: 0.5,
                                      onEvent: { e in
                                          t.note(e)
                                          guard case let .snapped(r) = e else { return }
                                          if AppRules.demoChompMatches(r, want: want) { found = r }
                                      })
        }
        tally = t
        if session.isFinished {
            // Over before the bite came: a fresh run, so the card is mid-run.
            start(d.mode != nil ? d.runMode(today: today) : .feed)
        }
        let score = self.session?.snapshot.score ?? 0
        if let r = found {
            coverChomp = ChompInfo(r, score: score)
            bitesThisRun = max(bitesThisRun, 1)
            AppTrace.t("SNAP-T chomp card \(want) caught=\(r.caught.count) t=" + AppTrace.fixed(played, 1))
        } else {
            coverChomp = AppRules.demoChomp(want, score: score)
            bitesThisRun = 1
            AppTrace.t("SNAP-T chomp card \(want) made up")
        }
        if let s = self.session { publishHUD(s.snapshot, now: CACurrentMediaTime(), force: true) }
        forcedPose = .cover
    }

    /// R8 demo `screen=levelResults[;level=n]` (and `screen=results;mode=level`): the level really played by the
    /// pilot (default perfect) until its goal is met or it ends, then its Results: the stars as Core judged them.
    private func demoLevelResults(_ d: DemoMode) {
        let id = d.level ?? DemoMode.defaultLevel
        start(.level(id))
        guard let session, levelSpec != nil else { return }
        dismissIntro()
        var t = tally
        var played = 0.0
        // R9 (frames 08, 62 scored 0): one pilot for the whole level, reading its goal (`DemoRunner.pilot`).
        var pilot = DemoRunner.pilot(skill: d.pilot ?? .perfect, seed: session.seed &+ 101, mode: session.mode)
        // Core ends a level itself (its goal met, or its bites or time out).
        while played < Self.levelSearchSeconds && !session.isFinished {
            played += DemoRunner.play(session, pilot: &pilot, seconds: 0.5, onEvent: { e in t.note(e) })
        }
        tally = t
        AppTrace.t("SNAP-T level demo \(id) played=" + AppTrace.fixed(played, 1))
        finishLevelNow()
    }
    /// R6 demo `screen=results;mode=zen`: session seconds of the Zen Bog played before End.
    static let zenResultsSeconds: Double = 150

    private func demoAfterStep(_ s: TrapSnapshot, events: [TrapEvent]) {
        guard let demo, !frozen else { return }
        if let at = freezePendingAt {
            if playTime >= at {
                freeze(freezePendingTag?.rawValue ?? "after", holdScene: freezePendingTag != nil,
                       atOnce: freezePendingTag?.holdsSceneAtOnce ?? false)
            }
            return
        }
        if let after = demo.holdAfter, playTime < after { return }
        if let tag = demo.freezeOn {
            guard tag != .results, Self.matches(tag, s, events: events, hint: lastHint) else { return }
            if tag.isEvent {
                freezePendingAt = playTime + tag.holdDelay
                freezePendingTag = tag
            } else {
                freeze(tag.rawValue, holdScene: false)
            }
        } else if demo.holdAfter != nil {
            freeze("after", holdScene: false)
        }
    }

    /// Whether this frame is the demo freeze moment `tag`. Pure; tested.
    nonisolated static func matches(_ tag: DemoMode.Freeze, _ s: TrapSnapshot, events: [TrapEvent],
                                    hint: HUDHint? = nil) -> Bool {
        switch tag {
        case .landed:
            return s.bugs.contains { $0.activity == .sipping && $0.inTrap }
        case .crowd:
            return s.bugs.filter { $0.activity == .sipping && $0.inTrap && !$0.species.isProtected }.count >= 3
        case .bee:
            return s.bugs.contains { $0.activity == .sipping && $0.inTrap && $0.species.isProtected }
        case .snap:
            return events.contains { e in
                if case .snapped = e { return true }
                return false
            }
        case .feast, .feastOpen:
            return events.contains { e in
                if case .feast = e { return true }
                return false
            }
        case .sting:
            return events.contains { e in
                if case .stung = e { return true }
                return false
            }
        case .dusk:
            return s.dayPhase >= .dusk
        case .night:
            return s.dayPhase >= .night
        case .lastSnap:
            return events.contains(.lastSnap)
        case .hungry:
            return events.contains { e in
                if case .hungry = e { return true }
                return false
            }
        case .wilted:
            return events.contains { e in
                if case .wilted = e { return true }
                return false
            }
        case .tired:
            // R5 (REVIEW-4 #4): once the numeral is at 0 and the banner is up (19 froze it over a 1).
            return (AppRules.tiredElapsed(s.phase) ?? -1) >= AppRules.tiredFreezeAt
        case .results:
            return false
        case .firstHint:
            return hint == .foldInput
        case .chain5:
            return events.contains { e in
                if case let .chainUp(count, _) = e { return count >= 5 }
                return false
            }
        case .costlySting:
            return events.contains { e in
                if case let .stung(_, _, cost) = e { return cost > 0 }
                return false
            }
        case .drySnap:
            return events.contains(.drySnap)
        case .held:
            return AppRules.chainHeld(events, chain: s.chain)
        case .bigFeast:
            return AppRules.isBigFeast(events)
        case .feastGulp:
            return AppRules.isCrowdFeast(events)
        case .goalDone:
            if case .goalDone? = hint { return true }
            return false
        }
    }

    /// Stops stepping. An event freeze also pauses the scene after a beat, so the CHOMP, "Bzzt!" and the score pop
    /// are still on screen when CI's shot lands.
    /// R7: `atOnce` (`DemoMode.Freeze.holdsSceneAtOnce`): the scene is paused now, not a beat later.
    private func freeze(_ tag: String, holdScene: Bool, atOnce: Bool = false) {
        frozen = true
        freezePendingAt = nil
        feedback.silence()
        AppTrace.t("SNAP-T freeze \(tag)")
        guard holdScene else { return }
        if atOnce {
            sceneHeld = true
            scene?.isPaused = true
            return
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.sceneHoldDelay * 1_000_000_000))
            guard let self, self.frozen else { return }
            self.sceneHeld = true
            self.scene?.isPaused = true
        }
    }
}

// MARK: - R7 (#4): the Scene's clear zones reach Core's sessions

extension GameController: SceneKeepOutReceiver {
    /// The Scene (main actor) sends `coreKeepOut` when it gets this driver, when the plates, Home or the layout
    /// change, and on every `reset()`. The protocol isn't actor-bound, so the witness is nonisolated and hops onto the
    /// main actor it is always called from.
    nonisolated func sceneKeepOutChanged(_ rects: [CGRect]) {
        MainActor.assumeIsolated {
            self.applyKeepOut(rects)
        }
    }
}
