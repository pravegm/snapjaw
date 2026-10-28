import Combine
import QuartzCore
import SpriteKit
import SwiftUI
import UIKit

/// The hub of the frame loop (ARCHITECTURE "The frame loop"): BogScene.update → advance(dt:now:) → trap source (hinge,
/// touch, pilot, fixed) → TrapSession.step → FeedbackDirector → HUD. Owns the session, the scene, the sources, the
/// app's route, the First Bite lesson and the Duo states (pose card, closing pause, shut).
///
/// Pauses (no stepping): the phone closing (θ < `Tuning.closingAngle` for `Tuning.closingDwell`, Feel's
/// `HingeTrapSource.isClosing`), the app inactive or in the background, the pause menu, and a pose card (portrait, the
/// cover display). The closing pause lifts once the hinge is open again past `AppRules.resumeAngle` (never near 90°).
/// The "tired" ending plays out under a closing or pose pause, so a finished run always reaches Results.
@MainActor
final class GameController: ObservableObject, SceneDriver {
    private enum PauseReason: String, Hashable { case menu, closing, background, pose }

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
    /// "Open it a little to carry on".
    @Published private(set) var isClosingPaused = false
    @Published private(set) var summary: ResultSummary?
    @Published private(set) var lessonDisplay: LessonDisplay?
    @Published private(set) var pose: AppPose = .play
    /// Demo `screen=pose|cover` forces a pose.
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
    /// The demo pilot, in fixed steps (Core R3 `PilotRun`, REVIEW-2 #21).
    private var pilotRun: PilotRun?
    private var lessonScript: LessonScript?
    private var lessonReplay = false
    /// The lesson's bugs still in play → the nectar drop each was sent to (so two never share one).
    private var lessonClaims: [Int: Int] = [:]
    /// The lesson started on the pose step (its numbering keeps counting it).
    private var lessonHasPose = false
    private var layout: ScreenLayout?
    private var lastCanvasSize: CGSize = .zero
    private var lastCanvasFold = false
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
    /// R3: "Bees cost a snap!" shows until this session time (Sprout's free first sting).
    private var beesToastUntil: Double = -1
    /// R3: Core's `hungry` fired and no bite or wilt has followed yet.
    private var hungryOn = false
    /// R3: the first Feast's one-time "+1 snap" label.
    private var feastsAtStart = 0
    private var snapGainShown = false
    private var snapGainUntil: Double = -1
    private var snapGainLabel = ""

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
    var demoFold: Bool { demo?.fold ?? false }
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
    var lessonReplaying: Bool { lessonReplay }
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
        if route == .home { return advanceHome(dt: dt, now: now) }
        guard let session else { return (homeSession?.snapshot ?? TrapSnapshot(), []) }
        guard route.isPlay, !session.isFinished else { return (session.snapshot, []) }
        checkClosing(now: now, phase: session.snapshot.phase)
        applyDrawnClosure(now: now)
        let width = sessionLayout.size.width
        if frozen {
            feedback.handle([], telemetry: AppRules.telemetry(session.snapshot, sceneWidth: width, playing: false))
            return (session.snapshot, [])
        }
        if isPaused && !stepsThroughPause(session.snapshot.phase) {
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

        if var script = lessonScript {
            let actions = script.update(lessonInput(session.snapshot, events: events))
            lessonScript = script
            // Each scripted bug lands ON a real nectar drop, so it sips (QA-1 #3): one drop per bug still in play.
            if !actions.isEmpty {
                lessonClaims = AppRules.liveClaims(lessonClaims, snapshot: session.snapshot)
                var taken = Set(lessonClaims.values)
                for action in actions {
                    switch action {
                    case let .spawn(species, slot, linger):
                        let spot = AppRules.lessonSpot(slot: slot, geometry: sessionLayout.geometry,
                                                       nectar: session.snapshot.nectar, taken: taken)
                        let id = session.spawnScripted(species, entry: spot.entry, target: spot.target, linger: linger)
                        if let drop = spot.drop {
                            taken.insert(drop)
                            if id >= 0 { lessonClaims[id] = drop }
                        }
                    }
                }
            }
            publishLesson(script)
        }

        let snapshot = session.snapshot
        let live = AppRules.isLive(snapshot.phase)
        feedback.handle(events, telemetry: AppRules.telemetry(snapshot, sceneWidth: width, playing: live))
        var snapped = false
        for event in events {
            tally.note(event)
            switch event {
            case .snapped:
                snapped = true
                hungryOn = false
            case .tired: watchTheEnd()
            case .newBest: passedBest = true
            case .wilted:
                wilts += 1
                snapped = true
                hungryOn = false
            case .stung:
                stings += 1
                // Sprout's free first bee (REVIEW-2 #9): the toast says what it would have cost.
                if AppRules.isFreeSting(event, mode: session.mode) {
                    beesToastUntil = snapshot.time + Self.toastSeconds
                    snapped = true
                    AppTrace.t("SNAP-T toast bees-cost")
                }
            case .hungry:
                hungryOn = true
                snapped = true
            case let .feast(_, back):
                // The first Feast ever: its flying glyph is labelled once (REVIEW-2 #12).
                if back > 0 && !snapGainShown && feastsAtStart == 0 && session.mode != .lesson {
                    snapGainShown = true
                    snapGainUntil = snapshot.time + Self.snapGainSeconds
                    snapGainLabel = AppRules.snapGainText(back)
                    snapped = true
                }
            default: break
            }
            AppTrace.t("SNAP-T event " + AppTrace.describe(event))
        }
        if AppTrace.enabled && now - lastTrapLog >= Self.trapLogInterval {
            lastTrapLog = now
            let ref = input == .hinge ? hinge.reference : AppTrace.reference(trap)
            AppTrace.t(AppTrace.trapLine(trap, reference: ref))
        }
        publishHUD(snapshot, now: now, force: snapped)
        demoAfterStep(snapshot, events: events)
        if session.isFinished { handleFinished(immediate: false) }
        return (snapshot, events)
    }

    /// A tap anywhere on the scene: snaps when there is no hinge (ignored otherwise).
    func sceneTapped(at point: CGPoint, time: TimeInterval) {
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
        if store.data.lessonDone {
            goHome()
        } else {
            // First launch: the First Bite (GAME-DESIGN §8).
            startLesson(replay: false)
        }
    }

    /// The play canvas changed (fold, size, HUD side). The scene is built once and then re-laid out.
    func updateCanvas(_ size: CGSize, hasFold: Bool) {
        guard size.width > 10, size.height > 10 else { return }
        lastCanvasSize = size
        lastCanvasFold = hasFold
        let newLayout = ScreenLayout.make(viewSize: size, hasFold: hasFold, hudOnLeft: hudOnLeft)
        let line = "SNAP-T canvas \(Int(size.width.rounded()))x\(Int(size.height.rounded())) "
            + "fold=\(hasFold ? 1 : 0) hudLeft=\(hudOnLeft ? 1 : 0)"
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
        sceneGeneration += 1
        newScene.reset()
        if let p = snapsAnchor { SceneHooks.setSnapsAnchor(newScene, p) }
        homeTicker?.stop()
    }

    /// Only `.background` opens the pause menu (folding shut may pass through `.inactive` on hardware, and then every
    /// close would end on the menu). Inactive (Control Centre, a call banner) pauses quietly.
    func setScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            appActive = true
            // A fresh snap detector from the last reading: a stale reference can't make the first frames snap.
            if hinge.hasHinge { hinge.reset(at: CACurrentMediaTime()) }
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
            if ProgressRules.worthRecording(partial) {
                store.saveCheckpoint(partial)
                checkpointSaved = true
            }
            if !isShut { openMenu() }
        }
        setPause(.background, true)
        homeTicker?.stop()
        feedback.silence()
    }

    /// The display's pose changed (portrait card, the cover display). Logs `SNAP-T pose <pose>`.
    func setPose(_ newPose: AppPose) {
        guard newPose != pose else { return }
        // Keep the bog as it was last drawn for the menus.
        if pose == .play && (route.isPlay || route == .home) { captureStill() }
        pose = newPose
        AppTrace.t("SNAP-T pose \(newPose.rawValue)")
        setPause(.pose, newPose != .play)
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

    func hingeSample(angle: Double, time: TimeInterval) {
        guard angle.isFinite else { return }
        hinge.ingest(angleDegrees: angle, at: time)
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
        // QA-1 #1 (P0): the closing pause pauses the scene, so `advance()` (and its `checkClosing`) stops. Hinge
        // reports keep arriving while the Duo is opened again, so the pause is lifted from here.
        if isClosingPaused, let s = session { checkClosing(now: time, phase: s.snapshot.phase) }
    }

    /// After a hinge has been seen, a nil is a display handover, never "no hinge" (Brim research).
    func hingeUnavailable() {}

    /// The closing pause: Feel's gate (θ < `Tuning.closingAngle` for `Tuning.closingDwell`) pauses; it lifts once the
    /// hinge is open past `AppRules.resumeAngle` and not shut. Only while the trap is in play (the tired moment plays
    /// out).
    private func checkClosing(now: TimeInterval, phase: RunPhase) {
        guard input == .hinge, route.isPlay, session != nil else {
            if isClosingPaused { setClosing(false) }
            return
        }
        if isClosingPaused {
            if AppRules.mayResume(angle: hinge.angle, isClosing: hinge.isClosing, isShut: isShut) {
                setClosing(false)
            }
        } else if hinge.isClosing && AppRules.isLive(phase) {
            setClosing(true)
            #if DEBUG
            // A literal of its own, DEBUG only: a TestFlight guard may grep the Release binary for it.
            if AppTrace.enabled {
                print("SNAP-T paused closing")
                fflush(stdout)
            }
            #endif
        }
    }

    private func setClosing(_ on: Bool) {
        if isClosingPaused != on { isClosingPaused = on }
        setPause(.closing, on)
    }

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

    /// The HUD's snaps row centre in scene space (PlayLayer reports it on layout).
    func setSnapsAnchor(_ p: CGPoint) {
        guard p.x.isFinite, p.y.isFinite, p != snapsAnchor else { return }
        snapsAnchor = p
        SceneHooks.setSnapsAnchor(scene, p)
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
        let c01 = trap.closure.isFinite ? trap.closure / max(Tuning.snapDepth, 1) : 0
        homeTrap.update(closure01: min(max(c01, 0), 1), chomped: chomped)
        applyDrawnClosure(now: now)
        return (home.snapshot, events)
    }

    /// A fresh attract bog for Home (its own seed; demo runs keep theirs so frames are stable).
    private func makeHomeSession() {
        let l = layout ?? ScreenLayout(hasFold: false, hudOnLeft: hudOnLeft)
        sessionLayout = l
        if let scene, scene.layout != l { scene.layout = l }
        let seed: UInt64 = isDemo ? (demo?.seed ?? DemoMode.defaultSeed) : UInt64.random(in: 1...UInt64.max)
        homeSession = TrapSession(mode: .attract, seed: seed, best: 0, geometry: l.geometry,
                                  options: SessionOptions.`for`(.attract))
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
        let c01 = trap.closure.isFinite ? trap.closure / max(Tuning.snapDepth, 1) : 0
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

    func play() {
        feedback.uiConfirm()
        start(.feed)
    }

    func playDaily() {
        feedback.uiConfirm()
        start(.daily(day: today, scored: true))
    }

    func practiseDaily() {
        feedback.uiConfirm()
        start(.daily(day: today, scored: false))
    }

    /// Results' Again (a Daily is always practised: `AppRules.againMode`).
    func again() {
        feedback.uiConfirm()
        start(summary.map { AppRules.againMode($0.result.mode) } ?? .feed)
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
        case .lesson:
            startLesson(replay: lessonReplay)
        case let .daily(day, _):
            start(.daily(day: day, scored: false))
        case .feed, .attract:
            start(mode)
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
        lessonScript = nil
        lessonDisplay = nil
        lessonClaims = [:]
        clearRunPauses()
        frozen = false
        sceneHeld = false
        scene?.isPaused = false
        feedback.silence()
        hud.update(HUDValues())
        if freshBog { makeHomeSession() }
        // A snap made on a menu is never delivered on Home's first frame either.
        if hinge.hasHinge { hinge.reset(at: CACurrentMediaTime()) }
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

    // MARK: - The First Bite lesson

    func startLesson(replay: Bool, at step: LessonScript.Step = .pose) {
        lessonReplay = replay
        start(.lesson)
        lessonClaims = [:]
        lessonHasPose = lessonHingeLike()
        let script = LessonScript(start: step, replay: replay)
        lessonScript = script
        publishLesson(script)
    }

    func replayLesson() {
        feedback.uiConfirm()
        startLesson(replay: true)
    }

    /// A Duo's first hinge report can lag the first frame: a fold layout keeps the pose step (real runs). Demo
    /// `lessonStep=1` on a phone sim keeps it on screen too (a frame of it).
    private func lessonHingeLike() -> Bool {
        let foldLayout = (layout?.hasFold ?? false) && !isDemo
        return input == .hinge || foldLayout || demo?.lessonStep == 1
    }

    /// Skip (offered on every step): the lesson counts as done.
    func skipLesson() {
        store.markLessonDone()
        goHome()
    }

    /// The final card's "Start feeding": the first run.
    func finishLesson() {
        store.markLessonDone()
        feedback.uiConfirm()
        start(.feed)
    }

    func finishLessonHome() {
        store.markLessonDone()
        goHome()
    }

    private func lessonInput(_ s: TrapSnapshot, events: [TrapEvent]) -> LessonScript.Input {
        var flies = 0
        var bees = 0
        var inTrap = 0
        for b in s.bugs where AppRules.inPlay(b.activity) {
            if b.species.isProtected {
                bees += 1
            } else {
                flies += 1
                if b.inTrap && b.activity != .arriving { inTrap += 1 }
            }
        }
        return LessonScript.Input(time: s.time, angle: input == .hinge ? hinge.angle : nil,
                                  hasHinge: lessonHingeLike(), armed: s.armed, events: events, liveFlies: flies,
                                  liveBees: bees, fliesInTrap: inTrap, touch: touchWording)
    }

    private func publishLesson(_ script: LessonScript) {
        let display = script.display(touch: touchWording, hasPose: lessonHasPose)
        guard display != lessonDisplay else { return }
        if display.step != lessonDisplay?.step || display.praise != lessonDisplay?.praise
            || display.warning != lessonDisplay?.warning {
            AppTrace.t("SNAP-T lesson step \(display.step) '\(display.praise ?? display.warning ?? display.line)'")
        }
        lessonDisplay = display
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
            layout = ScreenLayout.make(viewSize: screen, hasFold: false, hudOnLeft: hudOnLeft)
        }
        sessionLayout = layout ?? ScreenLayout(hasFold: false, hudOnLeft: hudOnLeft)
        let runSeed = seed(for: m)
        var options: SessionOptions = m == .lesson
            ? SessionOptions(snapsRunOut: false, waves: false, stingCosts: false)
            : SessionOptions.`for`(m)
        // Demo `wave=`: Core starts the run at that wave (its nectar block and day follow).
        if m != .lesson, let wave = demo?.wave, wave > 1 { options.firstWave = wave }
        // First runs (GAME-DESIGN §5): 12 snaps while the plant rank is Sprout.
        options.startSnaps = AppRules.startSnaps(mode: m, lifetimeBugs: store.data.lifetimeBugs)
        // R3 (ROUND-3 founder call): Sprout's first run never wilts and its first bee is free.
        let firstRun = AppRules.isSproutFirstRun(mode: m, runs: store.data.runs, lifetimeBugs: store.data.lifetimeBugs)
        Self.applyFirstRun(firstRun, to: &options)
        if firstRun { AppTrace.t("SNAP-T first run options") }
        let newSession = TrapSession(mode: m, seed: runSeed, best: store.best(for: m), geometry: sessionLayout.geometry,
                                     options: options)
        session = newSession
        if let scene, scene.layout != sessionLayout { scene.layout = sessionLayout }
        homeSession = nil
        wilts = 0
        stings = 0
        beesToastUntil = -1
        hungryOn = false
        feastsAtStart = store.data.feasts
        snapGainShown = false
        snapGainUntil = -1
        touch = TouchTrapSource()
        fixedSource.closure = demo?.closure ?? 0
        pilotRun = demo?.pilot.map { PilotRun(skill: $0, seed: runSeed &+ 101) }
        if m != .lesson {
            lessonScript = nil
            lessonDisplay = nil
        }
        setInput(chooseInput(), force: true)
        // QA-1 #2: a snap made on Results, a menu or the pause menu must never fire at t = 0 of this run.
        if input == .hinge && hinge.hasHinge { hinge.reset(at: CACurrentMediaTime()) }
        tally = RunTally(hingeTiming: input == .hinge || input == .pilot)
        recorded = false
        playTime = 0
        passedBest = false
        lastHUD = -1
        lastHint = nil
        bannerText = AppRules.startBanner(m, touch: touchWording)
        scene?.reset()
        setRoute(m == .lesson ? .lesson : .playing)
        publishHUD(newSession.snapshot, now: CACurrentMediaTime(), force: true)
        refreshIdleTimer()
    }

    /// Core's first-run switches (design/notes/core-R3.md): no hunger, and the first stinger bite costs nothing (its
    /// `stung(cost: 0)` shows the toast). Pure; tested.
    nonisolated static func applyFirstRun(_ on: Bool, to options: inout SessionOptions) {
        guard on else { return }
        options.hunger = false
        options.freeFirstSting = true
    }

    private func seed(for mode: RunMode) -> UInt64 {
        switch mode {
        case .feed:
            if let s = demo?.seed { return s }
            if isDemo { return DemoMode.defaultSeed }
            return UInt64.random(in: 1...UInt64.max)
        case let .daily(day, _):
            return DailySeed.seed(day: day)
        case .attract:
            return demo?.seed ?? DemoMode.defaultSeed
        case .lesson:
            return 1
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
        guard ProgressRules.worthRecording(partial) else {
            store.clearCheckpoint()
            return
        }
        let outcome = store.recordAbandoned(partial, today: today)
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
            for e in session.step(dt: AppRules.maxStep, input: open) { tally.note(e) }
            steps += 1
        }
        AppTrace.t("SNAP-T ending finished headless steps=\(steps)")
    }

    /// Files the finished run once (the store, Game Center, the `SNAP-T run` line) and builds its summary.
    @discardableResult
    private func recordFinished() -> ResultSummary? {
        guard !recorded, let session, let result = session.result else { return nil }
        recorded = true
        checkpointSaved = false
        endWatchTask?.cancel()
        let outcome = store.record(result, today: today)
        GameCenterManager.shared.report(result: result, outcome: outcome, progress: store.data)
        AppTrace.t("SNAP-T run score=\(result.score) bugs=\(result.bugsCaught) snaps=\(result.snaps) "
                   + "seconds=\(Int(result.seconds.isFinite ? result.seconds : 0))")
        let made = makeSummary(result, outcome: outcome)
        summary = made
        return made
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
        setRoute(.results)
        if summary.outcome.rankedUp || !summary.outcome.newSpecies.isEmpty || summary.outcome.showsNewBest {
            feedback.celebrate()
        }
        if demo?.freezeOn == .results { AppTrace.t("SNAP-T freeze results") }
    }

    private func makeSummary(_ result: RunResult, outcome: RecordOutcome) -> ResultSummary {
        let title: String
        let again: String
        switch result.mode {
        case .feed:
            title = "Your trap is tired"
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

    private func publishHUD(_ s: TrapSnapshot, now: TimeInterval, force: Bool) {
        var core = s.hint
        // The lesson shows only the hints it teaches with ("Bee! Wait…", "Now!" once all three sip).
        if route == .lesson, let h = core, !AppRules.lessonShowsHint(h) { core = nil }
        if let h = core, AppRules.hintText(h, touch: touchWording) == nil { core = nil }
        let live = AppRules.isLive(s.phase)
        var hint: HUDHint? = core.map { HUDHint.trap($0) }
        if s.time < beesToastUntil {
            // The free sting's toast wins over everything for its beat.
            hint = .beesCost
        } else if AppRules.showsFoldHint(mode: s.mode, wave: s.wave, snapsMade: tally.snaps, time: s.time,
                                         after: Self.bannerSeconds, coreHint: core) {
            hint = .foldInput
        }
        if isPaused || frozen || !live { hint = nil }
        var values = HUDValues()
        values.score = s.score
        values.best = s.best
        values.snapsMax = s.snapsMax
        values.chain = s.chain
        values.chainMultiplier = s.chainMultiplier
        values.hint = hint
        values.banner = hint == nil && s.time < Self.bannerSeconds && !isPaused ? bannerText : nil
        values.tired = AppRules.isTired(s.phase)
        values.passedBest = passedBest
        values.dayPhase = s.dayPhase
        values.lesson = route == .lesson
        values.hunger = AppRules.hudHunger(s.hunger, live: AppRules.isLive(s.phase))
        values.wilts = wilts
        values.stings = stings
        // Scene R3 (#14): the numeral and the glyphs change as each flying glyph lands, and drop only once a sting's
        // crack has shown (`BogScene.snapsShownOffset`).
        values.snapsLeft = AppRules.shownSnaps(s.snapsLeft, offset: scene?.snapsShownOffset ?? 0, max: s.snapsMax)
        values.rowFlashing = scene?.snapsRowFlashing ?? false
        values.hungry = hungryOn && live && !isPaused
        values.snapGain = s.time < snapGainUntil && live ? snapGainLabel : nil
        if route == .lesson {
            values.lessonSnaps = lessonDisplay?.showsSnaps ?? false
            values.ringSnaps = lessonDisplay?.isFinal ?? false
        }
        if route == .lesson && !isPaused { values.lessonTargets = AppRules.lessonTargets(s) }
        // A glyph landing or the row flash shows on its frame, not up to 1/15 s later.
        let urgent = force || hint != lastHint || values.tired != hud.values.tired
            || values.snapsLeft != hud.values.snapsLeft || values.rowFlashing != hud.values.rowFlashing
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
            if inserted && route.isPlay && reason != .closing { AppTrace.t("SNAP-T paused \(reason.rawValue)") }
        } else {
            pauseReasons.remove(reason)
        }
        if isPaused && !was {
            feedback.silence()
            // QA-1 #7: a tap made just before the pause never bites on the first frame after it.
            touch.reset()
        } else if !isPaused && was && route.isPlay {
            // Every resume: a fresh detector, so the reopening stroke never reads as a snap or a creep.
            if input == .hinge && hinge.hasHinge { hinge.reset(at: CACurrentMediaTime()) }
            AppTrace.t("SNAP-T resumed")
        }
        if isPaused != was { refreshIdleTimer() }
    }

    private func clearRunPauses() {
        pauseReasons.remove(.menu)
        pauseReasons.remove(.closing)
        if isMenuOpen { isMenuOpen = false }
        if isClosingPaused { isClosingPaused = false }
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
        case .results:
            start(d.runMode(today: day))
            if let session {
                var t = tally
                DemoRunner.playToEnd(session, skill: d.pilot ?? .casual, seed: session.seed, onEvent: { e in t.note(e) })
                tally = t
                if session.isFinished {
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
        case .lesson:
            let step = LessonScript.Step(rawValue: d.lessonStep ?? 1) ?? .pose
            startLesson(replay: false, at: step)
        case .pose:
            forcedPose = .pose
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .cover:
            // R3 (REVIEW-2 #24): the cover shows a run in progress ("Open it up to carry on" and its score), so a
            // run is really played for a few seconds first (the casual pilot, headless).
            start(d.mode != nil ? d.runMode(today: day) : .feed)
            if let session {
                var t = tally
                DemoRunner.play(session, skill: d.pilot ?? .casual, seed: session.seed, seconds: Self.coverPlaySeconds,
                                onEvent: { e in t.note(e) })
                tally = t
                publishHUD(session.snapshot, now: CACurrentMediaTime(), force: true)
            }
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

    /// Demo `screen=cover`: session seconds played before the cover card shows.
    static let coverPlaySeconds: Double = 24

    private func demoAfterStep(_ s: TrapSnapshot, events: [TrapEvent]) {
        guard let demo, !frozen else { return }
        if let at = freezePendingAt {
            if playTime >= at { freeze(freezePendingTag?.rawValue ?? "after", holdScene: freezePendingTag != nil) }
            return
        }
        if let after = demo.holdAfter, playTime < after { return }
        if let tag = demo.freezeOn {
            guard tag != .results, Self.matches(tag, s, events: events) else { return }
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
    nonisolated static func matches(_ tag: DemoMode.Freeze, _ s: TrapSnapshot, events: [TrapEvent]) -> Bool {
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
        case .feast:
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
            return AppRules.isTired(s.phase)
        case .results:
            return false
        }
    }

    /// Stops stepping. An event freeze also pauses the scene after a beat, so the CHOMP, "Bzzt!" and the score pop
    /// are still on screen when CI's shot lands.
    private func freeze(_ tag: String, holdScene: Bool) {
        frozen = true
        freezePendingAt = nil
        feedback.silence()
        AppTrace.t("SNAP-T freeze \(tag)")
        guard holdScene else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.sceneHoldDelay * 1_000_000_000))
            guard let self, self.frozen else { return }
            self.sceneHeld = true
            self.scene?.isPaused = true
        }
    }
}
